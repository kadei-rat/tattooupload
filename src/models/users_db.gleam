import db_coordinator.{type DbCoordName}
import errors.{type AppError}
import gleam/dynamic/decode
import gleam/option
import gleam/result
import models/role
import models/users.{type User, User}
import pog
import telegram_auth.{type TelegramLoginData}

pub fn get_all(db: DbCoordName) -> Result(List(User), AppError) {
  let sql =
    "
    SELECT id, first_name, last_name, username, photo_url, role, ban
    FROM users
    ORDER BY id
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.returning(decode_user())
    |> db_coordinator.user_query(db),
  )

  Ok(rows.rows)
}

pub fn get_by_id(db: DbCoordName, id: Int) -> Result(User, AppError) {
  let sql =
    "
    SELECT id, first_name, last_name, username, photo_url, role, ban
    FROM users
    WHERE id = $1
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.int(id))
    |> pog.returning(decode_user())
    |> db_coordinator.user_query(db),
  )

  case rows.rows {
    [user] -> Ok(user)
    [] -> Error(errors.not_found_error("User not found"))
    _ ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "Multiple users found (unexpected)",
      ))
  }
}

pub fn create_or_update(
  db: DbCoordName,
  login_data: TelegramLoginData,
) -> Result(User, AppError) {
  let sql =
    "
    INSERT INTO users (id, first_name, last_name, username, photo_url, role, created_at, updated_at)
    VALUES ($1, $2, $3, $4, $5, 'user', NOW(), NOW())
    ON CONFLICT (id) DO UPDATE SET
      first_name = EXCLUDED.first_name,
      last_name = EXCLUDED.last_name,
      username = EXCLUDED.username,
      photo_url = COALESCE(EXCLUDED.photo_url, users.photo_url),
      updated_at = NOW()
    RETURNING id, first_name, last_name, username, photo_url, role, ban
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.int(login_data.id))
    |> pog.parameter(pog.text(login_data.first_name))
    |> pog.parameter(pog.text(option.unwrap(login_data.last_name, "")))
    |> pog.parameter(pog.nullable(pog.text, login_data.username))
    |> pog.parameter(pog.nullable(pog.text, login_data.photo_url))
    |> pog.returning(decode_user())
    |> db_coordinator.user_query(db),
  )

  case rows.rows {
    [user] -> Ok(user)
    [] ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "User upsert failed - no rows returned",
      ))
    _ ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "User upsert returned multiple rows (unexpected)",
      ))
  }
}

pub fn ban_user(
  db: DbCoordName,
  user_id: Int,
  reason: String,
) -> Result(Nil, AppError) {
  let sql =
    "
    UPDATE users
    SET ban = $2, updated_at = NOW()
    WHERE id = $1
  "

  use _ <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.int(user_id))
    |> pog.parameter(pog.text(reason))
    |> db_coordinator.noresult_query(db),
  )

  Ok(Nil)
}

pub fn unban_user(db: DbCoordName, user_id: Int) -> Result(Nil, AppError) {
  let sql =
    "
    UPDATE users
    SET ban = NULL, updated_at = NOW()
    WHERE id = $1
  "

  use _ <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.int(user_id))
    |> db_coordinator.noresult_query(db),
  )

  Ok(Nil)
}

fn decode_user() -> decode.Decoder(User) {
  use id <- decode.field("id", decode.int)
  use first_name <- decode.field("first_name", decode.string)
  use last_name <- decode.field("last_name", decode.string)
  use username <- decode.field("username", decode.optional(decode.string))
  use photo_url <- decode.field("photo_url", decode.optional(decode.string))
  use role_str <- decode.field("role", decode.string)
  use ban <- decode.field("ban", decode.optional(decode.string))

  decode.success(User(
    id: id,
    first_name: first_name,
    last_name: last_name,
    username: username,
    photo_url: photo_url,
    role: role.from_string(role_str) |> result.unwrap(role.User),
    ban: ban,
  ))
}
