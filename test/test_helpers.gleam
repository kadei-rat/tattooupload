import config
import database.{type Db}
import errors.{type AppError}
import gleam/string
import global_value
import pog

pub fn setup_test_db() -> Result(Db, AppError) {
  use <- global_value.create_with_unique_name("test_db")

  let conf = config.load()
  let test_config = config.Config(..conf, db_name_suffix: "_test")

  case database.start(test_config) {
    Ok(db) -> Ok(db)
    Error(err) ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "Test database failed to start: " <> string.inspect(err),
      ))
  }
}

pub fn cleanup_by_id(db: Db, table: String, id: Int) {
  let query =
    pog.query("DELETE FROM " <> table <> " WHERE id = $1")
    |> pog.parameter(pog.int(id))

  let _ = database.execute(query, db)
  Nil
}
