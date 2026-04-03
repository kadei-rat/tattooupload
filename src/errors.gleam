import gleam/json
import wisp.{type Response}

pub const public_5xx_msg = "Internal server error. Please try again later."

pub type AppError {
  AuthorizationError(String)
  // 403 - User lacks permission
  AuthenticationError(String)
  // 401 - User not authenticated or invalid session
  ValidationError(public: String)
  // 400 - Bad request data
  NotFoundError(String)
  // 404 - Resource doesn't exist
  InternalError(public: String, internal: String)
  // 500 - Server/database errors
}

pub fn error_to_json_response(error: AppError) -> Response {
  case error {
    AuthorizationError(msg) -> json_error_response(msg, 403)
    AuthenticationError(msg) -> json_error_response(msg, 401)
    ValidationError(msg) -> json_error_response(msg, 400)
    NotFoundError(msg) -> json_error_response(msg, 404)
    InternalError(msg, _internal) -> json_error_response(msg, 500)
  }
}

fn json_error_response(message: String, status: Int) -> Response {
  let error_json = json.object([#("error", json.string(message))])
  wisp.json_response(json.to_string(error_json), status)
}

pub fn to_public_string(error: AppError) -> String {
  case error {
    AuthorizationError(msg) -> msg
    AuthenticationError(msg) -> msg
    ValidationError(public) -> public
    NotFoundError(msg) -> msg
    InternalError(public, _internal) -> public
  }
}

pub fn to_internal_string(error: AppError) -> String {
  case error {
    AuthorizationError(msg) -> msg
    AuthenticationError(msg) -> msg
    ValidationError(msg) -> msg
    NotFoundError(msg) -> msg
    InternalError(_public, internal) -> internal
  }
}

pub fn authorization_error(message: String) -> AppError {
  AuthorizationError(message)
}

pub fn authentication_error(message: String) -> AppError {
  AuthenticationError(message)
}

pub fn validation_error(public: String) -> AppError {
  ValidationError(public)
}

pub fn not_found_error(message: String) -> AppError {
  NotFoundError(message)
}

pub fn internal_error(public: String, internal: String) -> AppError {
  InternalError(public, internal)
}
