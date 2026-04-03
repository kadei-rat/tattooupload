import config
import db_coordinator.{type DbCoordName}
import gleam/http.{Get, Post}
import gleam/http/request
import gleam/json
import gleam/option.{type Option, None, Some}
import handlers
import logging
import telega
import telega/model/decoder
import wisp.{type Request, type Response}

pub fn handle_request(
  req: Request,
  db: DbCoordName,
  conf: config.Config,
  bot: Option(telega.Telega(Nil, Nil)),
) -> Response {
  use req <- middleware(req)

  case wisp.path_segments(req), req.method {
    ["static", ..], Get -> handlers.static(req)

    [], Get -> handlers.upload_page(req, db, conf)

    ["upload"], Post -> handlers.handle_upload(req, db, conf)
    ["upload", "success"], Get -> handlers.upload_success_page(req, conf)

    ["health"], Get -> {
      wisp.response(200)
      |> wisp.string_body("OK")
    }

    // Login routes
    ["auth"], Get -> handlers.auth_status(req, conf)
    ["login"], Post -> handlers.login(req, db, conf)
    ["logout"], Post -> handlers.logout(req)

    // Admin routes
    ["admin"], Get -> handlers.admin_page(req, db, conf)
    ["admin", "submissions", "download-all"], Get ->
      handlers.download_all_pending(req, db, conf)
    ["admin", "submissions", id, "done"], Post ->
      handlers.mark_done(req, db, conf, id)
    ["submissions", id, "image"], Get -> handlers.serve_image(req, db, conf, id)

    // Telegram webhook
    ["telegram", "webhook"], Post -> handle_webhook(req, bot)

    _, _ ->
      wisp.response(404)
      |> wisp.string_body("Not Found")
  }
}

fn handle_webhook(
  req: Request,
  bot: Option(telega.Telega(Nil, Nil)),
) -> Response {
  case bot {
    None -> wisp.response(503)
    Some(bot) -> {
      let valid_token = case
        request.get_header(req, "x-telegram-bot-api-secret-token")
      {
        Ok(token) -> telega.is_secret_token_valid(bot, token)
        _ -> False
      }

      case valid_token {
        False -> {
          logging.log(
            logging.Warning,
            "Webhook request with invalid secret token",
          )
          wisp.response(401)
        }
        True -> {
          use body <- wisp.require_string_body(req)
          case json.parse(from: body, using: decoder.update_decoder()) {
            Ok(update) -> {
              telega.handle_update(bot, update)
              wisp.response(200)
            }
            Error(_) -> {
              logging.log(logging.Warning, "Failed to decode webhook update")
              wisp.response(400)
            }
          }
        }
      }
    }
  }
}

fn middleware(req: Request, handle_request: fn(Request) -> Response) -> Response {
  let req = wisp.method_override(req)
  let req = wisp.set_max_body_size(req, 10_485_760)
  let req = wisp.set_max_files_size(req, 10_485_760)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)

  handle_request(req)
}
