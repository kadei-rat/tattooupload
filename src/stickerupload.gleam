import config
import db_coordinator
import gleam/erlang/process
import gleam/option.{None, Some}
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import logging
import mist
import router
import telega/error as telega_error
import telegram_bot
import wisp
import wisp/wisp_mist

pub fn main() {
  process.sleep_forever()
}

pub fn start(_app, _type) -> Result(process.Pid, actor.StartError) {
  wisp.configure_logger()
  logging.configure()

  let conf = config.load()
  logging.set_level(conf.log_level)

  logging.log(logging.Info, "Starting top-level supervisor")

  let db_coord_name = process.new_name(prefix: "db_coordinator")

  let db_worker =
    supervision.worker(fn() { db_coordinator.start(conf, db_coord_name) })

  let bot_enabled = conf.telegram_bot_token != ""
  let webhook_enabled = option.is_some(conf.webhook_host)

  let bot = case bot_enabled, webhook_enabled {
    True, True -> {
      case telegram_bot.start(conf, db_coord_name) {
        Ok(bot) -> {
          logging.log(logging.Info, "Telegram bot started with webhooks")
          Some(bot)
        }
        Error(err) -> {
          logging.log(
            logging.Warning,
            "Failed to start telegram bot: "
              <> telega_error.to_string(err)
              <> ", bot disabled",
          )
          None
        }
      }
    }
    True, False -> {
      logging.log(
        logging.Warning,
        "WEBHOOK_HOST not set, telegram bot disabled",
      )
      None
    }
    _, _ -> {
      logging.log(logging.Warning, "TELEGRAM_BOT_TOKEN not set, bot disabled")
      None
    }
  }

  let web_server =
    wisp_mist.handler(
      router.handle_request(_, db_coord_name, conf, bot),
      conf.secret_key_base,
    )
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(conf.server_port)
    |> mist.supervised

  let sup =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(db_worker)
    |> supervisor.add(web_server)

  case supervisor.start(sup) {
    Ok(actor.Started(pid, _data)) -> Ok(pid)
    Error(reason) -> Error(reason)
  }
}
