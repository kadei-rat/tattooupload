import config.{type Config}
import db_coordinator.{type DbCoordName}
import errors
import frontend/admin_page as frontend_admin_page
import frontend/layout
import frontend/login_components.{type LoginState, LoggedIn, LoggedOut}
import frontend/upload_page as frontend_upload_page
import frontend/upload_success_page as frontend_upload_success
import gleam/bytes_tree
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri
import lenient_parse
import logging
import lustre/element
import models/role
import models/submissions.{type ImageData}
import models/submissions_db
import models/users_db
import session
import simplifile
import telegram_auth
import telegram_notify
import wisp.{type Request, type Response}

fn log_and_redirect_error(
  url: String,
  action: String,
  err: errors.AppError,
) -> Response {
  logging.log(
    logging.Error,
    action <> " failed: " <> errors.to_internal_string(err),
  )
  let error_param = "error=" <> uri.percent_encode(errors.to_public_string(err))
  wisp.redirect(url <> "?" <> error_param)
}

// HTML routes //

pub fn static(req: Request) -> Response {
  let assert Ok(priv) = wisp.priv_directory("stickerupload")
  use <- wisp.serve_static(req, under: "/static", from: priv)
  wisp.not_found()
}

pub fn upload_page(req: Request, _db: DbCoordName, conf: Config) -> Response {
  let login_state = get_login_state(req, conf)
  let error = get_query_param(req, "error")
  layout.view(frontend_upload_page.view(login_state, error), login_state)
  |> element.to_document_string
  |> wisp.html_response(200)
}

pub fn upload_success_page(req: Request, conf: Config) -> Response {
  let login_state = get_login_state(req, conf)
  layout.view(frontend_upload_success.view(), login_state)
  |> element.to_document_string
  |> wisp.html_response(200)
}

fn parse_float(s: String) -> Result(Float, errors.AppError) {
  lenient_parse.to_float(s)
  |> result.map_error(fn(e) { errors.validation_error(string.inspect(e)) })
}

pub fn handle_upload(req: Request, db: DbCoordName, _conf: Config) -> Response {
  use formdata <- wisp.require_form(req)
  let session_data = session.get_session(req) |> option.from_result

  use width <- redirect_on_err(
    req,
    get_form_value(formdata.values, "width_cm")
      |> result.map_error(fn(_) {
        errors.validation_error("No width value provided")
      })
      |> result.try(parse_float),
  )

  use file <- redirect_on_err(req, case formdata.files {
    [#("image", file), ..] -> Ok(file)
    _ -> Error(errors.validation_error("Please select an image file"))
  })

  use image_data <- redirect_on_err(
    req,
    simplifile.read_bits(file.path)
      |> result.map_error(fn(e) {
        errors.validation_error(simplifile.describe_error(e))
      }),
  )

  let content_type = guess_content_type(file.file_name)
  let user_id = option.map(session_data, fn(s) { s.id })

  case
    submissions_db.create(
      db,
      image_data,
      file.file_name,
      content_type,
      width,
      user_id,
    )
  {
    Ok(_) -> wisp.redirect("/upload/success")
    Error(err) -> log_and_redirect_error("/", "Upload", err)
  }
}

pub fn admin_page(req: Request, db: DbCoordName, _conf: Config) -> Response {
  use session_data <- session.require_session(req, "/")
  use <- session.require_admin(session_data, "/")

  let login_state = LoggedIn(session.to_user(session_data))
  case submissions_db.get_all(db) {
    Ok(submissions) -> {
      layout.view(frontend_admin_page.view(submissions), login_state)
      |> element.to_document_string
      |> wisp.html_response(200)
    }
    Error(err) -> {
      logging.log(
        logging.Error,
        "Failed to load submissions: " <> errors.to_internal_string(err),
      )
      wisp.internal_server_error()
    }
  }
}

pub fn serve_image(
  req: Request,
  db: DbCoordName,
  _conf: Config,
  id_str: String,
) -> Response {
  use session_data <- session.require_session(req, "/")
  use <- session.require_admin(session_data, "/")

  case int.parse(id_str) {
    Error(_) -> wisp.not_found()
    Ok(id) -> {
      case submissions_db.get_image_data(db, id) {
        Error(_) -> wisp.not_found()
        Ok(image_data) -> {
          let download =
            wisp.get_query(req)
            |> list.any(fn(pair) { pair.0 == "download" })

          wisp.response(200)
          |> wisp.set_header("content-type", image_data.content_type)
          |> fn(r) {
            case download {
              True ->
                wisp.set_header(
                  r,
                  "content-disposition",
                  "attachment; filename=\"" <> image_data.filename <> "\"",
                )
              False -> r
            }
          }
          |> wisp.set_body(
            wisp.Bytes(bytes_tree.from_bit_array(image_data.data)),
          )
        }
      }
    }
  }
}

pub fn download_all_pending(
  req: Request,
  db: DbCoordName,
  _conf: Config,
) -> Response {
  use session_data <- session.require_session(req, "/")
  use <- session.require_admin(session_data, "/")

  case submissions_db.get_all_pending_images(db) {
    Error(err) -> log_and_redirect_error("/admin", "Download all", err)
    Ok([]) -> wisp.redirect("/admin")
    Ok(images) -> {
      let files =
        list.map(images, fn(img: ImageData) { #(img.filename, img.data) })
      case zip_create(files) {
        Ok(zip_bytes) ->
          wisp.response(200)
          |> wisp.set_header("content-type", "application/zip")
          |> wisp.set_header(
            "content-disposition",
            "attachment; filename=\"pending-stickers.zip\"",
          )
          |> wisp.set_body(wisp.Bytes(bytes_tree.from_bit_array(zip_bytes)))
        Error(_) -> {
          logging.log(logging.Error, "Failed to create zip archive")
          wisp.internal_server_error()
        }
      }
    }
  }
}

@external(erlang, "zip_ffi", "create")
fn zip_create(files: List(#(String, BitArray))) -> Result(BitArray, String)

pub fn mark_done(
  req: Request,
  db: DbCoordName,
  conf: Config,
  id_str: String,
) -> Response {
  use session_data <- session.require_session(req, "/")
  use <- session.require_admin(session_data, "/")

  case int.parse(id_str) {
    Error(_) -> wisp.not_found()
    Ok(id) -> {
      case submissions_db.mark_done(db, id) {
        Error(err) -> log_and_redirect_error("/admin", "Mark done", err)
        Ok(submission) -> {
          case submission.user_id {
            option.Some(uid) ->
              telegram_notify.notify_ready(conf.telegram_bot_token, uid)
            option.None -> Nil
          }
          wisp.redirect("/admin")
        }
      }
    }
  }
}

// Auth routes //

pub fn auth_status(req: Request, _conf: Config) -> Response {
  case session.get_session(req) {
    Ok(sess) -> {
      let user_json =
        json.object([
          #("id", json.int(sess.id)),
          #("first_name", json.string(sess.first_name)),
          #("role", json.string(role.to_string(sess.role))),
        ])
      wisp.json_response(json.to_string(user_json), 200)
    }
    Error(_) -> wisp.json_response("{\"error\": \"not authenticated\"}", 401)
  }
}

pub fn login(req: Request, db: DbCoordName, conf: Config) -> Response {
  use formdata <- wisp.require_form(req)

  let return_url =
    formdata.values
    |> get_form_value("return_url")
    |> result.unwrap("/")

  case conf.env {
    config.Dev -> handle_dev_login(req, db, return_url)
    config.Prod -> handle_telegram_login(req, db, conf, formdata, return_url)
  }
}

pub fn logout(req: Request) -> Response {
  session.destroy_session(wisp.redirect("/"), req)
}

fn handle_dev_login(
  req: Request,
  db: DbCoordName,
  return_url: String,
) -> Response {
  let login_data =
    telegram_auth.TelegramLoginData(
      id: 1,
      first_name: "Dev",
      last_name: option.None,
      username: option.Some("dev_user"),
      photo_url: option.None,
      auth_date: 0,
      hash: "",
    )
  case users_db.create_or_update(db, login_data) {
    Ok(user) -> session.create_session(wisp.redirect(return_url), req, user)
    Error(err) -> log_and_redirect_error(return_url, "Dev login", err)
  }
}

fn handle_telegram_login(
  req: Request,
  db: DbCoordName,
  conf: Config,
  formdata: wisp.FormData,
  return_url: String,
) -> Response {
  case telegram_auth.verify_login(formdata.values, conf.telegram_bot_token) {
    Ok(login_data) -> {
      case users_db.create_or_update(db, login_data) {
        Ok(user) -> session.create_session(wisp.redirect(return_url), req, user)
        Error(err) -> log_and_redirect_error(return_url, "Login", err)
      }
    }
    Error(err) -> log_and_redirect_error(return_url, "Telegram auth", err)
  }
}

fn get_login_state(req: Request, conf: Config) -> LoginState {
  case session.get_session(req) {
    Ok(session_data) -> LoggedIn(session.to_user(session_data))
    Error(_) ->
      LoggedOut(
        telegram_bot_name: conf.telegram_bot_name,
        dev_mode: conf.env == config.Dev,
        return_url: req.path,
      )
  }
}

fn get_form_value(
  values: List(#(String, String)),
  key: String,
) -> Result(String, Nil) {
  case values {
    [] -> Error(Nil)
    [#(k, v), ..] if k == key -> Ok(v)
    [_, ..rest] -> get_form_value(rest, key)
  }
}

fn get_query_param(req: Request, key: String) -> option.Option(String) {
  wisp.get_query(req)
  |> list.find(fn(pair) { pair.0 == key })
  |> result.map(fn(pair) { pair.1 })
  |> option.from_result
}

fn guess_content_type(filename: String) -> String {
  let lower = string.lowercase(filename)
  case get_extension(lower) {
    ".png" -> "image/png"
    ".jpg" | ".jpeg" -> "image/jpeg"
    ".gif" -> "image/gif"
    ".webp" -> "image/webp"
    ".svg" -> "image/svg+xml"
    ".bmp" -> "image/bmp"
    _ -> "application/octet-stream"
  }
}

fn get_extension(filename: String) -> String {
  case string.split(filename, ".") {
    [_, ..rest] -> "." <> last_element(rest, "")
    _ -> ""
  }
}

fn last_element(list: List(String), default: String) -> String {
  case list {
    [] -> default
    [x] -> x
    [_, ..rest] -> last_element(rest, default)
  }
}

fn redirect_on_err(
  req: Request,
  r: Result(a, errors.AppError),
  next: fn(a) -> Response,
) -> Response {
  case r {
    Error(err) -> {
      log_request(req, Some(err))
      wisp.redirect(
        "/?error=" <> uri.percent_encode(errors.to_public_string(err)),
      )
    }

    Ok(a) -> next(a)
  }
}

fn log_request(req: Request, result: Option(errors.AppError)) -> Nil {
  let method = http.method_to_string(req.method)
  let path = req.path

  let message = case result {
    Some(err) -> {
      let error_details = errors.to_internal_string(err)
      method <> " " <> path <> " - " <> error_details
    }
    None -> method <> " " <> path <> " - success"
  }

  logging.log(logging.Info, message)
}
