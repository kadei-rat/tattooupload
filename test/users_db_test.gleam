import database
import gleam/option.{None, Some}
import models/users_db
import postgleam
import telegram_auth.{TelegramLoginData}
import test_helpers.{setup_test_db}

const test_user_id = 999_999_999

pub fn create_user_with_null_last_name_test() {
  let assert Ok(db) = setup_test_db()

  let login_data =
    TelegramLoginData(
      id: test_user_id,
      first_name: "Sky",
      last_name: None,
      username: Some("skypaw"),
      photo_url: Some("https://example.com/photo.jpg"),
      auth_date: 1_000_000_000,
      hash: "abc123",
    )

  let assert Ok(user) = users_db.create_or_update(db, login_data)

  let assert True = user.id == test_user_id
  let assert True = user.first_name == "Sky"
  let assert True = user.username == Some("skypaw")

  cleanup_test_user(db, test_user_id)
}

pub fn create_user_with_all_fields_test() {
  let assert Ok(db) = setup_test_db()

  let login_data =
    TelegramLoginData(
      id: test_user_id,
      first_name: "Test",
      last_name: Some("User"),
      username: Some("testuser"),
      photo_url: Some("https://example.com/photo.jpg"),
      auth_date: 1_000_000_000,
      hash: "abc123",
    )

  let assert Ok(user) = users_db.create_or_update(db, login_data)

  let assert True = user.id == test_user_id
  let assert True = user.first_name == "Test"
  let assert True = user.username == Some("testuser")

  cleanup_test_user(db, test_user_id)
}

fn cleanup_test_user(db, user_id: Int) {
  let query =
    database.query("DELETE FROM users WHERE id = $1")
    |> database.parameter(postgleam.int(user_id))

  let _ = database.execute(query, db)
  Nil
}
