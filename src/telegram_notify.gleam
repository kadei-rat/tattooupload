import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleam/option.{type Option}
import logging
import session.{type SessionData}

pub fn notify_upload(
  token: String,
  admin_chat_id: Int,
  user: Option(SessionData),
) -> Nil {
  let user_info = case user {
    option.Some(s) ->
      case s.username {
        option.Some(username) -> s.first_name <> " (@" <> username <> ")"
        option.None -> s.first_name
      }
    option.None -> "Anonymous (not logged in)"
  }
  send_message(token, admin_chat_id, "New image uploaded by " <> user_info)
}

pub fn notify_ready(token: String, chat_id: Int) -> Nil {
  send_message(
    token,
    chat_id,
    "Your temporary tattoo is ready for picking up at the Furry High Commission.\n\nIf you're unable to pick up in person at the FHC for accessibility reasons, message @kadei_rat to arrange delivery.",
  )
}

fn send_message(token: String, chat_id: Int, text: String) -> Nil {
  let body =
    json.object([
      #("chat_id", json.int(chat_id)),
      #("text", json.string(text)),
    ])
    |> json.to_string

  let url = "https://api.telegram.org/bot" <> token <> "/sendMessage"

  case request.to(url) {
    Error(_) -> {
      logging.log(logging.Error, "Failed to build Telegram API request URL")
      Nil
    }
    Ok(req) -> {
      let req =
        req
        |> request.set_method(http.Post)
        |> request.set_header("content-type", "application/json")
        |> request.set_body(body)

      case httpc.send(req) {
        Ok(resp) -> {
          case resp.status {
            200 ->
              logging.log(
                logging.Info,
                "Telegram notification sent to chat_id "
                  <> int.to_string(chat_id),
              )
            status ->
              logging.log(
                logging.Warning,
                "Telegram API returned status "
                  <> int.to_string(status)
                  <> " for chat_id "
                  <> int.to_string(chat_id),
              )
          }
          Nil
        }
        Error(_) -> {
          logging.log(
            logging.Error,
            "Failed to send Telegram notification to chat_id "
              <> int.to_string(chat_id),
          )
          Nil
        }
      }
    }
  }
}
