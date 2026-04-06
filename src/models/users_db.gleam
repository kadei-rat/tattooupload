import database.{type Db}
import errors.{type AppError}
import gleam/option
import gleam/result
import models/role
import models/users.{type User, User}
import postgleam
import postgleam/decode as pg_decode
import telegram_auth.{type TelegramLoginData}

pub fn get_all(db: Db) -> Result(List(User), AppError) {
  let sql =
    "
    SELECT id, first_name, last_name, username, photo_url, role, ban
    FROM users
    ORDER BY id
  "

  use rows <- result.try(
    database.query(sql)
    |> database.returning(decode_user())
    |> database.execute(db),
  )

  Ok(rows.rows)
}

pub fn get_by_id(db: Db, id: Int) -> Result(User, AppError) {
  let sql =
    "
    SELECT id, first_name, last_name, username, photo_url, role, ban
    FROM users
    WHERE id = $1
  "

  use rows <- result.try(
    database.query(sql)
    |> database.parameter(postgleam.int(id))
    |> database.returning(decode_user())
    |> database.execute(db),
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
  db: Db,
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
    database.query(sql)
    |> database.parameter(postgleam.int(login_data.id))
    |> database.parameter(postgleam.text(login_data.first_name))
    |> database.parameter(
      postgleam.text(option.unwrap(login_data.last_name, "")),
    )
    |> database.parameter(postgleam.nullable(
      login_data.username,
      postgleam.text,
    ))
    |> database.parameter(postgleam.nullable(
      login_data.photo_url,
      postgleam.text,
    ))
    |> database.returning(decode_user())
    |> database.execute(db),
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

pub fn ban_user(db: Db, user_id: Int, reason: String) -> Result(Nil, AppError) {
  let sql =
    "
    UPDATE users
    SET ban = $2, updated_at = NOW()
    WHERE id = $1
  "

  use _ <- result.try(
    database.query(sql)
    |> database.parameter(postgleam.int(user_id))
    |> database.parameter(postgleam.text(reason))
    |> database.execute(db),
  )

  Ok(Nil)
}

pub fn unban_user(db: Db, user_id: Int) -> Result(Nil, AppError) {
  let sql =
    "
    UPDATE users
    SET ban = NULL, updated_at = NOW()
    WHERE id = $1
  "

  use _ <- result.try(
    database.query(sql)
    |> database.parameter(postgleam.int(user_id))
    |> database.execute(db),
  )

  Ok(Nil)
}

fn decode_user() -> pg_decode.RowDecoder(User) {
  use id <- pg_decode.element(0, pg_decode.int)
  use first_name <- pg_decode.element(1, pg_decode.text)
  use last_name <- pg_decode.element(2, pg_decode.text)
  use username <- pg_decode.element(3, pg_decode.optional(pg_decode.text))
  use photo_url <- pg_decode.element(4, pg_decode.optional(pg_decode.text))
  use role_str <- pg_decode.element(5, pg_decode.text)
  use ban <- pg_decode.element(6, pg_decode.optional(pg_decode.text))

  pg_decode.success(User(
    id: id,
    first_name: first_name,
    last_name: last_name,
    username: username,
    photo_url: photo_url,
    role: role.from_string(role_str) |> result.unwrap(role.User),
    ban: ban,
  ))
}
