import config.{type Config}
import database
import errors.{type AppError, public_5xx_msg}
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/string
import logging
import models/submissions.{type ImageData, type Submission}
import models/users.{type User}
import pog
import rescue

const max_fresh_conn_retries = 5

// Public api

pub type DbCoordName =
  process.Name(Message)

// Add a variant here for each return type you need to query for
pub type Message {
  UserQuery(
    query: pog.Query(User),
    reply_to: Subject(Result(pog.Returned(User), AppError)),
  )
  StringQuery(
    query: pog.Query(String),
    reply_to: Subject(Result(pog.Returned(String), AppError)),
  )
  NoResultQuery(
    query: pog.Query(Nil),
    reply_to: Subject(Result(pog.Returned(Nil), AppError)),
  )
  BoolQuery(
    query: pog.Query(Bool),
    reply_to: Subject(Result(pog.Returned(Bool), AppError)),
  )
  SubmissionQuery(
    query: pog.Query(Submission),
    reply_to: Subject(Result(pog.Returned(Submission), AppError)),
  )
  ImageDataQuery(
    query: pog.Query(ImageData),
    reply_to: Subject(Result(pog.Returned(ImageData), AppError)),
  )
}

pub fn user_query(
  query: pog.Query(User),
  db_coord_name: DbCoordName,
) -> Result(pog.Returned(User), AppError) {
  call_db_coordinator(UserQuery(query, _), db_coord_name)
}

pub fn string_query(
  query: pog.Query(String),
  db_coord_name: DbCoordName,
) -> Result(pog.Returned(String), AppError) {
  call_db_coordinator(StringQuery(query, _), db_coord_name)
}

pub fn noresult_query(
  query: pog.Query(Nil),
  db_coord_name: DbCoordName,
) -> Result(pog.Returned(Nil), AppError) {
  call_db_coordinator(NoResultQuery(query, _), db_coord_name)
}

pub fn bool_query(
  query: pog.Query(Bool),
  db_coord_name: DbCoordName,
) -> Result(pog.Returned(Bool), AppError) {
  call_db_coordinator(BoolQuery(query, _), db_coord_name)
}

pub fn submission_query(
  query: pog.Query(Submission),
  db_coord_name: DbCoordName,
) -> Result(pog.Returned(Submission), AppError) {
  call_db_coordinator(SubmissionQuery(query, _), db_coord_name)
}

pub fn image_data_query(
  query: pog.Query(ImageData),
  db_coord_name: DbCoordName,
) -> Result(pog.Returned(ImageData), AppError) {
  call_db_coordinator(ImageDataQuery(query, _), db_coord_name)
}

pub fn start(
  conf: Config,
  name: DbCoordName,
) -> Result(actor.Started(_), actor.StartError) {
  actor.new(State(
    conn: None,
    conf: conf,
    pool_name: process.new_name(prefix: "db_pool"),
  ))
  |> actor.named(name)
  |> actor.on_message(handle_message)
  |> actor.start
}

// Private

type DbPool {
  DbPool(conn: pog.Connection, pid: process.Pid)
}

type State {
  State(
    conn: Option(DbPool),
    conf: Config,
    pool_name: process.Name(pog.Message),
  )
}

fn call_db_coordinator(
  query: _,
  db_coord_name: DbCoordName,
) -> Result(_, AppError) {
  process.call(process.named_subject(db_coord_name), 10_000, query)
}

fn handle_message(state: State, message: Message) -> actor.Next(State, Message) {
  case message {
    UserQuery(query, reply_to) -> run_query(state, query, reply_to)
    StringQuery(query, reply_to) -> run_query(state, query, reply_to)
    NoResultQuery(query, reply_to) -> run_query(state, query, reply_to)
    BoolQuery(query, reply_to) -> run_query(state, query, reply_to)
    SubmissionQuery(query, reply_to) -> run_query(state, query, reply_to)
    ImageDataQuery(query, reply_to) -> run_query(state, query, reply_to)
  }
}

fn run_query(
  state: State,
  query: pog.Query(t),
  reply_to: Subject(Result(pog.Returned(t), AppError)),
) -> actor.Next(State, Message) {
  case state.conn {
    Some(_) -> execute_query_on_conn(state, query, reply_to, False)
    None -> create_conn_and_execute_query(state, query, reply_to)
  }
}

fn execute_query_on_conn(
  state: State,
  query: pog.Query(t),
  reply_to: Subject(Result(pog.Returned(t), AppError)),
  is_retry: Bool,
) -> actor.Next(State, Message) {
  let assert State(Some(DbPool(conn, pid)), _, _) = state
  case rescue.rescue(fn() { pog.execute(query, conn) }) {
    Error(crash) -> {
      logging.log(
        logging.Warning,
        "DB connection crashed (likely dead socket) - reconnecting; error: "
          <> crash.stacktrace,
      )
      process.send_exit(pid)
      create_conn_and_execute_query(State(..state, conn: None), query, reply_to)
    }
    Ok(Error(pog.QueryTimeout)) ->
      case is_retry {
        True -> {
          process.send(reply_to, Error(database.to_app_error(pog.QueryTimeout)))
          actor.continue(state)
        }
        False -> {
          logging.log(logging.Warning, "Query timeout - retrying")
          execute_query_on_conn(state, query, reply_to, True)
        }
      }
    Ok(Error(other_error)) -> {
      process.send(reply_to, Error(database.to_app_error(other_error)))
      actor.continue(state)
    }
    Ok(Ok(result)) -> {
      process.send(reply_to, Ok(result))
      actor.continue(state)
    }
  }
}

fn create_conn_and_execute_query(
  state: State,
  query: pog.Query(t),
  reply_to: Subject(Result(pog.Returned(t), AppError)),
) -> actor.Next(State, Message) {
  create_conn_and_execute_query_loop(state, query, reply_to, 0)
}

fn create_conn_and_execute_query_loop(
  state: State,
  query: pog.Query(t),
  reply_to: Subject(Result(pog.Returned(t), AppError)),
  attempt: Int,
) -> actor.Next(State, Message) {
  logging.log(logging.Info, "Initialising DB connection")
  case database.connect(state.conf, state.pool_name) {
    Ok(actor.Started(pid, data)) -> {
      logging.log(logging.Info, "DB connection successful")
      let new_state = State(..state, conn: Some(DbPool(conn: data, pid: pid)))
      case rescue.rescue(fn() { pog.execute(query, data) }) {
        Error(crash) -> {
          process.send_exit(pid)
          case is_retryable_crash(crash), attempt < max_fresh_conn_retries {
            True, True -> {
              logging.log(
                logging.Warning,
                "DB query crashed on fresh connection - retrying (attempt "
                  <> string.inspect(attempt + 1)
                  <> "/"
                  <> string.inspect(max_fresh_conn_retries)
                  <> "): "
                  <> crash.stacktrace,
              )
              create_conn_and_execute_query_loop(
                State(..state, conn: None),
                query,
                reply_to,
                attempt + 1,
              )
            }
            _, _ -> {
              logging.log(
                logging.Warning,
                "DB query crashed on fresh connection (not retryable): "
                  <> crash.stacktrace
                  <> "; query was: "
                  <> string.inspect(query),
              )
              process.send(
                reply_to,
                Error(errors.internal_error(
                  public_5xx_msg,
                  "DB query crashed: " <> crash.stacktrace,
                )),
              )
              actor.continue(State(..state, conn: None))
            }
          }
        }
        Ok(Ok(result)) -> {
          process.send(reply_to, Ok(result))
          actor.continue(new_state)
        }
        Ok(Error(err)) -> {
          process.send(reply_to, Error(database.to_app_error(err)))
          actor.continue(new_state)
        }
      }
    }
    Error(err) -> {
      logging.log(
        logging.Warning,
        "DB connection failed: " <> string.inspect(err),
      )
      process.send(
        reply_to,
        Error(errors.internal_error(
          public_5xx_msg,
          "Error connecting to database: " <> string.inspect(err),
        )),
      )
      actor.continue(state)
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
