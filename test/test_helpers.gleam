import config
import db_coordinator
import errors.{type AppError}
import gleam/erlang/process
import gleam/string
import global_value
import pog

pub fn setup_test_db() -> Result(db_coordinator.DbCoordName, AppError) {
  use <- global_value.create_with_unique_name("test_db")

  let conf = config.load()
  let test_config = config.Config(..conf, db_name_suffix: "_test")

  let db_coord_name = process.new_name(prefix: "test_db_coord")
  case db_coordinator.start(test_config, db_coord_name) {
    Ok(_) -> Ok(db_coord_name)
    Error(err) ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "Test database coordinator failed to start: " <> string.inspect(err),
      ))
  }
}

pub fn cleanup_by_id(
  db_coord_name: db_coordinator.DbCoordName,
  table: String,
  id: Int,
) {
  let query =
    pog.query("DELETE FROM " <> table <> " WHERE id = $1")
    |> pog.parameter(pog.int(id))

  let _ = db_coordinator.noresult_query(query, db_coord_name)
  Nil
}
