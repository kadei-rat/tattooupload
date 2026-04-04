import config.{type Config}
import database.{type Db}
import gleam/option.{Some}
import gleam/result
import telega
import telega/bot.{type Context}
import telega/error.{type TelegaError}
import telega/reply
import telega/router
import telega/update
import telega_httpc

fn build_router(_db: Db, _conf: Config) {
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
  db: Db,
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
