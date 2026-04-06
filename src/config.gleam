import envoy
import gleam/int
import gleam/option.{type Option}
import gleam/result
import logging

pub type Environment {
  Dev
  Prod
}

pub type Config {
  Config(
    env: Environment,
    log_level: logging.LogLevel,
    db_url: String,
    db_name_suffix: String,
    db_pool_size: Int,
    db_query_timeout: Int,
    db_query_max_attempts: Int,
    server_port: Int,
    secret_key_base: String,
    telegram_bot_token: String,
    telegram_bot_name: String,
    webhook_host: Option(String),
    webhook_secret: String,
    admin_chat_id: Option(Int),
  )
}

fn parse_environment(env_str: String) -> Environment {
  case env_str {
    "prod" -> Prod
    "dev" -> Dev
    _ -> panic as "Invalid env value"
  }
}

fn parse_log_level(level_str: String) -> Result(logging.LogLevel, Nil) {
  case level_str {
    "emergency" -> Ok(logging.Emergency)
    "alert" -> Ok(logging.Alert)
    "critical" -> Ok(logging.Critical)
    "error" -> Ok(logging.Error)
    "warning" -> Ok(logging.Warning)
    "notice" -> Ok(logging.Notice)
    "info" -> Ok(logging.Info)
    "debug" -> Ok(logging.Debug)
    _ -> Error(Nil)
  }
}

pub fn load() -> Config {
  let env =
    envoy.get("ENV")
    |> result.unwrap("dev")
    |> parse_environment

  let log_level =
    envoy.get("LOG_LEVEL")
    |> result.try(parse_log_level)
    |> result.unwrap(logging.Debug)

  let db_url =
    envoy.get("DATABASE_URL")
    |> result.unwrap("NOT_CONFIGURED")

  let db_name_suffix =
    envoy.get("DB_NAME_SUFFIX")
    |> result.unwrap("")

  let db_pool_size =
    envoy.get("DB_POOL_SIZE")
    |> result.try(int.parse)
    |> result.unwrap(5)

  let db_query_timeout =
    envoy.get("DB_QUERY_TIMEOUT")
    |> result.try(int.parse)
    |> result.unwrap(10_000)

  let db_query_max_attempts =
    envoy.get("DB_QUERY_MAX_ATTEMPTS")
    |> result.try(int.parse)
    |> result.unwrap(3)

  let server_port =
    envoy.get("PORT")
    |> result.try(int.parse)
    |> result.unwrap(8621)

  let secret_key_base =
    envoy.get("SECRET_KEY_BASE")
    |> result.unwrap("dev_secret_key")

  case env, secret_key_base {
    Prod, "dev_secret_key" ->
      panic as "Cannot use default secret key in production! Set SECRET_KEY_BASE environment variable."
    _, _ -> Nil
  }

  let telegram_bot_token =
    envoy.get("TELEGRAM_BOT_TOKEN")
    |> result.unwrap("")

  let telegram_bot_name =
    envoy.get("TELEGRAM_BOT_NAME")
    |> result.unwrap("")

  let webhook_host =
    envoy.get("WEBHOOK_HOST")
    |> option.from_result

  let webhook_secret =
    envoy.get("WEBHOOK_SECRET")
    |> result.unwrap("")

  let admin_chat_id =
    envoy.get("ADMIN_CHAT_ID")
    |> result.try(int.parse)
    |> option.from_result

  Config(
    env: env,
    log_level: log_level,
    db_url: db_url,
    db_name_suffix: db_name_suffix,
    db_pool_size: db_pool_size,
    db_query_timeout: db_query_timeout,
    db_query_max_attempts: db_query_max_attempts,
    server_port: server_port,
    secret_key_base: secret_key_base,
    telegram_bot_token: telegram_bot_token,
    telegram_bot_name: telegram_bot_name,
    webhook_host: webhook_host,
    webhook_secret: webhook_secret,
    admin_chat_id: admin_chat_id,
  )
}
