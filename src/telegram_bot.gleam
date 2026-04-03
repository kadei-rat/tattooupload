import config.{type Config}
import db_coordinator.{type DbCoordName}
import gleam/option.{Some}
import gleam/result
import telega
import telega/bot.{type Context}
import telega/error.{type TelegaError}
import telega/update
import telega/reply
import telega/router
import telega_httpc

fn build_router(_db: DbCoordName, _conf: Config) {
  router.new("app_bot")
  |> router.on_command("start", handle_start)
  |> router.fallback(handle_fallback)
}

fn handle_start(
  ctx: Context(Nil, Nil),
  _cmd: update.Command,
) -> Result(Context(Nil, Nil), Nil) {
  reply.with_text(
    ctx: ctx,
    text: "Hi! I'll notify you when your tattoo sticker is ready for pickup at EMF Camp!",
  )
  |> result.replace(ctx)
  |> result.map_error(fn(_) { Nil })
}

fn handle_fallback(
  ctx: Context(Nil, Nil),
  _update: update.Update,
) -> Result(Context(Nil, Nil), Nil) {
  reply.with_text(
    ctx: ctx,
    text: "I'll message you when your tattoo sticker is ready. No need to send me anything!",
  )
  |> result.replace(ctx)
  |> result.map_error(fn(_) { Nil })
}

pub fn start(
  conf: Config,
  db: DbCoordName,
) -> Result(telega.Telega(Nil, Nil), TelegaError) {
  let assert Some(webhook_host) = conf.webhook_host
  let webhook_url = webhook_host <> "/telegram/webhook"

  telega.new(
    api_client: telega_httpc.new(token: conf.telegram_bot_token),
    url: webhook_url,
    webhook_path: "telegram/webhook",
    secret_token: Some(conf.webhook_secret),
  )
  |> telega.with_router(build_router(db, conf))
  |> telega.with_nil_session
  |> telega.init
}
