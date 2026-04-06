import config.{type Config}
import errors.{type AppError, public_5xx_msg}
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import gleam/uri
import logging
import postgleam/config as pg_config
import postgleam/decode.{type RowDecoder}
import postgleam/error as pg_error
import postgleam/pool
import postgleam/value.{type Value}
import rescue

pub type Db {
  Db(
    pool: Subject(pool.PoolMessage),
    config: pg_config.Config,
    query_timeout: Int,
    max_attempts: Int,
  )
}

pub type Returned(t) {
  Returned(count: Int, rows: List(t))
}

pub fn start(conf: Config) -> Result(Db, String) {
  logging.log(logging.Info, "Initialising DB connection")
  let pg_conf = make_config(conf)
  case pool.start(pg_conf, conf.db_pool_size) {
    Ok(started) -> {
      logging.log(logging.Info, "DB connection successful")
      Ok(Db(
        pool: started.data,
        config: pg_conf,
        query_timeout: conf.db_query_timeout,
        max_attempts: conf.db_query_max_attempts,
      ))
    }
    Error(err) -> {
      logging.log(logging.Warning, "DB connection failed: " <> err)
      Error(err)
    }
  }
}

fn make_config(conf: Config) -> pg_config.Config {
  let assert Ok(uri) = uri.parse(conf.db_url)
  let assert Ok(#(username, password)) = parse_userinfo(uri.userinfo)
  let host = option.unwrap(uri.host, "localhost")
  let port = option.unwrap(uri.port, 5432)
  let database =
    uri.path
    |> string.drop_start(1)

  let ssl = case conf.env {
    config.Prod -> pg_config.SslUnverified
    config.Dev -> pg_config.SslDisabled
  }

  pg_config.default()
  |> pg_config.host(host)
  |> pg_config.port(port)
  |> pg_config.database(database <> conf.db_name_suffix)
  |> pg_config.username(username)
  |> pg_config.password(password)
  |> pg_config.timeout(conf.db_query_timeout)
  |> pg_config.ssl(ssl)
  |> pg_config.idle_interval(1000)
  |> pg_config.queue_timeout(5000)
}

fn parse_userinfo(userinfo: Option(String)) -> Result(#(String, String), Nil) {
  case userinfo {
    option.Some(info) ->
      case string.split(info, ":") {
        [user, pass] -> Ok(#(user, pass))
        [user] -> Ok(#(user, ""))
        _ -> Error(Nil)
      }
    option.None -> Error(Nil)
  }
}

pub fn ping(db: Db) -> Bool {
  pool.simple_query(db.pool, "SELECT 1", db.query_timeout)
  |> result.is_ok
}

pub type Query(t) {
  Query(
    sql: String,
    params: List(Option(Value)),
    decoder: Option(RowDecoder(t)),
  )
}

pub fn query(sql: String) -> Query(t) {
  Query(sql: sql, params: [], decoder: option.None)
}

pub fn parameter(q: Query(t), param: Option(Value)) -> Query(t) {
  Query(..q, params: list.append(q.params, [param]))
}

pub fn returning(q: Query(t), decoder: RowDecoder(t)) -> Query(t) {
  Query(..q, decoder: option.Some(decoder))
}

pub fn execute(q: Query(t), db: Db) -> Result(Returned(t), AppError) {
  do_execute(q, db, 1)
}

fn do_execute(
  q: Query(t),
  db: Db,
  attempt: Int,
) -> Result(Returned(t), AppError) {
  case execute_with_logging(q, db) {
    Ok(Ok(result)) -> Ok(result)
    Ok(Error(pg_error.SocketError(_) as err)) ->
      maybe_retry(q, db, attempt, "Socket error: " <> pg_error_to_string(err))
    Ok(Error(pg_error.TimeoutError)) ->
      maybe_retry(q, db, attempt, "Query timeout")
    Error(crash) ->
      case is_retryable_crash(crash) {
        True ->
          maybe_retry(q, db, attempt, "Retryable crash: " <> crash.stacktrace)
        False -> {
          logging.log(
            logging.Warning,
            "Non-retryable query crash: " <> crash.stacktrace,
          )
          Error(errors.internal_error(
            public_5xx_msg,
            "DB query crashed: " <> crash.stacktrace,
          ))
        }
      }
    Ok(Error(other_error)) -> Error(to_app_error(other_error))
  }
}

fn maybe_retry(
  q: Query(t),
  db: Db,
  attempt: Int,
  reason: String,
) -> Result(Returned(t), AppError) {
  case attempt < db.max_attempts {
    True -> {
      logging.log(
        logging.Warning,
        reason
          <> " — retrying (attempt "
          <> int.to_string(attempt + 1)
          <> "/"
          <> int.to_string(db.max_attempts)
          <> ")",
      )
      process.sleep(100 * attempt)
      do_execute(q, db, attempt + 1)
    }
    False -> {
      logging.log(
        logging.Warning,
        reason <> " — giving up after " <> int.to_string(attempt) <> " attempts",
      )
      Error(errors.internal_error(public_5xx_msg, reason))
    }
  }
}

fn execute_with_logging(
  q: Query(t),
  db: Db,
) -> Result(Result(Returned(t), pg_error.Error), rescue.Crash) {
  let query_str =
    "Query(" <> string.inspect(q.sql) <> ", " <> string.inspect(q.params) <> ")"
  logging.log(logging.Debug, "DB query: " <> query_str)
  let start = timestamp.system_time()

  let result =
    rescue.rescue(fn() {
      case q.decoder {
        option.Some(decoder) -> {
          case
            pool.query_with(db.pool, q.sql, q.params, decoder, db.query_timeout)
          {
            Ok(response) ->
              Ok(Returned(count: response.count, rows: response.rows))
            Error(e) -> Error(e)
          }
        }
        option.None -> {
          case pool.query(db.pool, q.sql, q.params, db.query_timeout) {
            Ok(response) -> {
              let count = parse_tag_count(response.tag)
              Ok(Returned(count: count, rows: []))
            }
            Error(e) -> Error(e)
          }
        }
      }
    })

  let elapsed = timestamp.difference(start, timestamp.system_time())
  let ms = duration.to_seconds(elapsed) *. 1000.0
  let ms_str = float.to_string(ms) <> "ms"
  case result {
    Error(crash) ->
      logging.log(
        logging.Warning,
        "DB query crashed in "
          <> ms_str
          <> ": "
          <> query_str
          <> " — "
          <> crash.stacktrace,
      )
    Ok(Error(err)) ->
      logging.log(
        logging.Warning,
        "DB query error in " <> ms_str <> ": " <> string.inspect(err),
      )
    Ok(Ok(returned)) ->
      logging.log(
        logging.Debug,
        "DB query OK ("
          <> int.to_string(returned.count)
          <> " rows) in "
          <> ms_str
          <> ": "
          <> query_str,
      )
  }
  result
}

pub fn to_app_error(error: pg_error.Error) -> AppError {
  case error {
    pg_error.PgError(fields, _, _) -> {
      case fields.code, fields.constraint {
        "23505", option.Some(_) ->
          errors.validation_error(option.unwrap(fields.detail, fields.message))
        code, _ ->
          errors.internal_error(
            public_5xx_msg,
            "PostgreSQL error: " <> code <> ": " <> fields.message,
          )
      }
    }
    pg_error.ConnectionError(message) ->
      errors.internal_error(public_5xx_msg, "Connection error: " <> message)
    pg_error.AuthenticationError(message) ->
      errors.internal_error(public_5xx_msg, "Authentication error: " <> message)
    pg_error.EncodeError(message) ->
      errors.internal_error(public_5xx_msg, "Encode error: " <> message)
    pg_error.DecodeError(message) ->
      errors.internal_error(public_5xx_msg, "Decode error: " <> message)
    pg_error.ProtocolError(message) ->
      errors.internal_error(public_5xx_msg, "Protocol error: " <> message)
    pg_error.SocketError(message) ->
      errors.internal_error(public_5xx_msg, "Socket error: " <> message)
    pg_error.TimeoutError ->
      errors.internal_error(public_5xx_msg, "Database query timed out")
  }
}

fn pg_error_to_string(err: pg_error.Error) -> String {
  case err {
    pg_error.PgError(fields, _, _) -> fields.message
    pg_error.ConnectionError(m) -> m
    pg_error.AuthenticationError(m) -> m
    pg_error.EncodeError(m) -> m
    pg_error.DecodeError(m) -> m
    pg_error.ProtocolError(m) -> m
    pg_error.SocketError(m) -> m
    pg_error.TimeoutError -> "Timeout"
  }
}

fn parse_tag_count(tag: String) -> Int {
  tag
  |> string.split(" ")
  |> list.last
  |> result.try(int.parse)
  |> result.unwrap(0)
}

fn is_retryable_crash(crash: rescue.Crash) -> Bool {
  let crash_str = string.inspect(crash.term)
  !string.contains(crash_str, "FunctionClause")
  && !string.contains(crash_str, "BadMatch")
  && !string.contains(crash_str, "BadArg")
  && !string.contains(crash_str, "CaseClause")
}
