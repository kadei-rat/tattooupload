import database
import gleam/option.{None}
import models/submissions_db
import postgleam
import simplifile
import test_helpers.{setup_test_db}

pub fn create_submission_with_image_test() {
  let assert Ok(db) = setup_test_db()
  let assert Ok(image_data) = simplifile.read_bits("test/test.png")

  let assert Ok(submission) =
    submissions_db.create(db, image_data, "test.png", "image/png", 5.0, None)

  cleanup_submission(db, submission.id)
}

fn cleanup_submission(db, id: Int) {
  let query =
    database.query("DELETE FROM submissions WHERE id = $1")
    |> database.parameter(postgleam.int(id))
  let _ = database.execute(query, db)
  Nil
}
