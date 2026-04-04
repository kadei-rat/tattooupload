import config.{type Config}
import errors.{type AppError, public_5xx_msg}
import gleam/erlang/process
import gleam/int
import gleam/otp/actor
import gleam/result
import gleam/string
import logging
import pog
import rescue
import utils

const max_attempts = 3

pub type Db {
  Db(conn: pog.Connection)
}

pub fn start(conf: Config) -> Result(Db, actor.StartError) {
  let pool_name = process.new_name(prefix: "db_pool")
  logging.log(logging.Info, "Initialising DB connection")
  case connect(conf, pool_name) {
    Ok(actor.Started(_pid, conn)) -> {
      logging.log(logging.Info, "DB connection successful")
      Ok(Db(conn: conn))
    }
    Error(err) -> {
      logging.log(
        logging.Warning,
        "DB connection failed: " <> string.inspect(err),
      )
      Error(err)
    }
  }
}

pub fn execute(query: pog.Query(t), db: Db) -> Result(pog.Returned(t), AppError) {
  do_execute(query, db, 1)
}

fn connect(config: Config, pool_name) {
  let url_conf =
    pog.url_config(pool_name, config.db_url)
    |> result.lazy_unwrap(fn() { panic as "Invalid DATABASE_URL" })

  let db_config =
    pog.Config(
      ..url_conf,
      database: url_conf.database <> config.db_name_suffix,
      pool_size: config.db_pool_size,
      rows_as_map: True,
      ip_version: case config.env {
        config.Prod -> pog.Ipv6
        config.Dev -> pog.Ipv4
      },
    )

  pog.start(db_config)
}

pub fn to_app_error(error: pog.QueryError) -> AppError {
  case error {
    pog.ConstraintViolated(_message, _constraint, detail) ->
      errors.validation_error(detail)
    pog.PostgresqlError("23505", _, message) -> errors.validation_error(message)
    pog.PostgresqlError(code, name, message) ->
      errors.internal_error(
        public_5xx_msg,
        "PostgreSQL error: " <> code <> " (" <> name <> "): " <> message,
      )
    pog.UnexpectedArgumentCount(expected, got) ->
      errors.internal_error(
        public_5xx_msg,
        "Unexpected argument count: expected "
          <> int.to_string(expected)
          <> ", got "
          <> int.to_string(got),
      )
    pog.UnexpectedArgumentType(expected, got) ->
      errors.internal_error(
        public_5xx_msg,
        "Unexpected argument type: expected " <> expected <> ", got " <> got,
      )
    pog.UnexpectedResultType(decode_errors) ->
      errors.internal_error(
        public_5xx_msg,
        utils.decode_errors_to_string(decode_errors),
      )
    pog.QueryTimeout ->
      errors.internal_error(public_5xx_msg, "Database query timed out")
    pog.ConnectionUnavailable ->
      errors.internal_error(public_5xx_msg, "Database connection unavailable")
  }
}

fn do_execute(
  query: pog.Query(t),
  db: Db,
  attempt: Int,
) -> Result(pog.Returned(t), AppError) {
  case rescue.rescue(fn() { pog.execute(query, db.conn) }) {
    Ok(Ok(result)) -> Ok(result)
    Ok(Error(pog.QueryTimeout)) ->
      maybe_retry(db, query, attempt, "Query timeout")
    Error(crash) ->
      case is_retryable_crash(crash) {
        True ->
          maybe_retry(
            db,
            query,
            attempt,
            "Retryable crash: " <> crash.stacktrace,
          )
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
  db: Db,
  query: pog.Query(t),
  attempt: Int,
  reason: String,
) -> Result(pog.Returned(t), AppError) {
  case attempt < max_attempts {
    True -> {
      logging.log(
        logging.Warning,
        reason
          <> " — retrying (attempt "
          <> int.to_string(attempt + 1)
          <> "/"
          <> int.to_string(max_attempts)
          <> ")",
      )
      process.sleep(100 * attempt)
      do_execute(query, db, attempt + 1)
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

fn is_retryable_crash(crash: rescue.Crash) -> Bool {
  let crash_str = string.inspect(crash.term)
  !string.contains(crash_str, "FunctionClause")
  && !string.contains(crash_str, "BadMatch")
  && !string.contains(crash_str, "BadArg")
  && !string.contains(crash_str, "CaseClause")
}
