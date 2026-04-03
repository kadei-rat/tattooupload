import config
import errors.{type AppError, public_5xx_msg}
import gleam/int
import gleam/result
import pog
import utils

pub fn connect(config: config.Config, pool_name) {
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
