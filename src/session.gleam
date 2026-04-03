import errors.{type AppError}
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri
import models/role.{type Role}
import models/users.{type User}
import wisp.{type Request, type Response}

pub type SessionData {
  SessionData(
    id: Int,
    first_name: String,
    username: Option(String),
    photo_url: Option(String),
    role: Role,
    // ...add more session fields as needed
  )
}

const session_cookie_name = "app_session"

const session_duration = 2_592_000

pub fn create_session(
  response: Response,
  request: Request,
  user: User,
) -> Response {
  let session_value =
    int.to_string(user.id)
    <> "|"
    <> uri.percent_encode(user.first_name)
    <> "|"
    <> option_to_string(user.username)
    <> "|"
    <> option_to_string(user.photo_url)
    <> "|"
    <> role.to_string(user.role)
  wisp.set_cookie(
    response,
    request,
    session_cookie_name,
    session_value,
    wisp.Signed,
    session_duration,
  )
}

fn option_to_string(opt: Option(String)) -> String {
  opt |> option.map(uri.percent_encode) |> option.unwrap("")
}

fn string_to_option(s: String) -> Option(String) {
  case s {
    "" -> None
    _ -> Some(uri.percent_decode(s) |> result.unwrap(s))
  }
}

pub fn to_user(session: SessionData) -> User {
  users.User(
    id: session.id,
    first_name: session.first_name,
    last_name: "",
    username: session.username,
    photo_url: session.photo_url,
    role: session.role,
    ban: None,
  )
}

pub fn get_session(request: Request) -> Result(SessionData, AppError) {
  case wisp.get_cookie(request, session_cookie_name, wisp.Signed) {
    Ok(session_value) -> parse_session_value(session_value)
    Error(_) -> Error(errors.authentication_error("No session found"))
  }
}

pub fn destroy_session(response: Response, request: Request) -> Response {
  wisp.set_cookie(response, request, session_cookie_name, "", wisp.Signed, 0)
}

pub fn require_session(
  request: Request,
  redirect_url: String,
  next: fn(SessionData) -> Response,
) -> Response {
  case get_session(request) {
    Ok(session_data) -> next(session_data)
    Error(_) -> wisp.redirect(redirect_url)
  }
}

pub fn require_admin(
  session_data: SessionData,
  redirect_url: String,
  next: fn() -> Response,
) -> Response {
  case session_data.role == role.Admin {
    True -> next()
    False -> wisp.redirect(redirect_url)
  }
}

fn parse_session_value(session_value: String) -> Result(SessionData, AppError) {
  case string.split(session_value, "|") {
    [id_str, first_name_enc, username_enc, photo_url_enc, role_str] -> {
      case int.parse(id_str), role.from_string(role_str) {
        Ok(id), Ok(role) -> {
          let first_name =
            uri.percent_decode(first_name_enc) |> result.unwrap(first_name_enc)
          Ok(SessionData(
            id: id,
            first_name: first_name,
            username: string_to_option(username_enc),
            photo_url: string_to_option(photo_url_enc),
            role: role,
          ))
        }
        _, _ -> Error(errors.authentication_error("Invalid session format"))
      }
    }
    _ -> Error(errors.authentication_error("Invalid session format"))
  }
}
