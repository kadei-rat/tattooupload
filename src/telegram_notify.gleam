import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import logging

pub fn notify_ready(token: String, chat_id: Int) -> Nil {
  let body =
    json.object([
      #("chat_id", json.int(chat_id)),
      #(
        "text",
        json.string(
          "Your temporary tattoo is ready for picking up at the Furry High Commission.\n\nIf you're unable to pick up in person at the FHC for accessibility reasons, message @kadei_rat to arrange delivery.",
        ),
      ),
    ])
    |> json.to_string

  let url =
    "https://api.telegram.org/bot"
    <> token
    <> "/sendMessage"

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
