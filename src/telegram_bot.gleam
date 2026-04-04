import config.{type Config}
import db_coordinator.{type DbCoordName}
import gleam/option.{Some}
import gleam/result
import telega
import telega/bot.{type Context}
import telega/error.{type TelegaError}
import telega/reply
import telega/router
import telega/update
import telega_httpc

fn build_router(_db: DbCoordName, _conf: Config) {
  router.new("app_bot")
  |> router.fallback(handle_fallback)
}

fn handle_fallback(
  ctx: Context(Nil, Nil),
  _update: update.Update,
) -> Result(Context(Nil, Nil), Nil) {
  Ok(ctx)
}

pub fn start(
  conf: Config,
  db: DbCoordName,
) -> Result(telega.Telega(Nil, Nil), TelegaError) {
  let assert Some(webhook_host) = conf.webhook_host
  telega.new(
    api_client: telega_httpc.new(token: conf.telegram_bot_token),
    url: webhook_host,
    webhook_path: "telegram/webhook",
    secret_token: Some(conf.webhook_secret),
  )
  |> telega.with_router(build_router(db, conf))
  |> telega.with_nil_session
  |> telega.init
}
