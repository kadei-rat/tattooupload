import database.{type Db}
import errors.{type AppError}
import gleam/float
import gleam/option.{type Option}
import gleam/result
import models/submissions.{
  type ImageData, type Submission, ImageData, Submission,
}
import postgleam
import postgleam/decode as pg_decode

pub fn create(
  db: Db,
  image_data: BitArray,
  image_filename: String,
  image_content_type: String,
  width_cm: Float,
  user_id: Option(Int),
) -> Result(Submission, AppError) {
  let sql =
    "
    INSERT INTO submissions (image_data, image_filename, image_content_type, width_cm, user_id)
    VALUES ($1, $2, $3, $4, $5)
    RETURNING id, image_filename, image_content_type, width_cm, user_id, status, created_at::text
  "

  use rows <- result.try(
    database.query(sql)
    |> database.parameter(postgleam.bytea(image_data))
    |> database.parameter(postgleam.text(image_filename))
    |> database.parameter(postgleam.text(image_content_type))
    |> database.parameter(postgleam.numeric(float.to_string(width_cm)))
    |> database.parameter(postgleam.nullable(user_id, postgleam.int))
    |> database.returning(decode_submission())
    |> database.execute(db),
  )

  case rows.rows {
    [submission] -> Ok(submission)
    _ ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "Submission insert returned unexpected rows",
      ))
  }
}

pub fn get_all(db: Db) -> Result(List(Submission), AppError) {
  let sql =
    "
    SELECT id, image_filename, image_content_type, width_cm, user_id, status, created_at::text
    FROM submissions
    ORDER BY created_at DESC
  "

  use rows <- result.try(
    database.query(sql)
    |> database.returning(decode_submission())
    |> database.execute(db),
  )

  Ok(rows.rows)
}

pub fn get_image_data(db: Db, id: Int) -> Result(ImageData, AppError) {
  let sql =
    "
    SELECT image_data, image_content_type, image_filename
    FROM submissions
    WHERE id = $1
  "

  use rows <- result.try(
    database.query(sql)
    |> database.parameter(postgleam.int(id))
    |> database.returning(decode_image_data())
    |> database.execute(db),
  )

  case rows.rows {
    [image_data] -> Ok(image_data)
    [] -> Error(errors.not_found_error("Submission not found"))
    _ ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "Multiple rows for submission image (unexpected)",
      ))
  }
}

pub fn get_all_pending_images(db: Db) -> Result(List(ImageData), AppError) {
  let sql =
    "
    SELECT image_data, image_content_type, image_filename
    FROM submissions
    WHERE status = 'pending'
    ORDER BY created_at ASC
  "

  use rows <- result.try(
    database.query(sql)
    |> database.returning(decode_image_data())
    |> database.execute(db),
  )

  Ok(rows.rows)
}

pub fn mark_done(db: Db, id: Int) -> Result(Submission, AppError) {
  let sql =
    "
    UPDATE submissions
    SET status = 'done', updated_at = NOW()
    WHERE id = $1
    RETURNING id, image_filename, image_content_type, width_cm, user_id, status, created_at::text
  "

  use rows <- result.try(
    database.query(sql)
    |> database.parameter(postgleam.int(id))
    |> database.returning(decode_submission())
    |> database.execute(db),
  )

  case rows.rows {
    [submission] -> Ok(submission)
    [] -> Error(errors.not_found_error("Submission not found"))
    _ ->
      Error(errors.internal_error(
        errors.public_5xx_msg,
        "Mark done returned multiple rows (unexpected)",
      ))
  }
}

fn decode_submission() -> pg_decode.RowDecoder(Submission) {
  use id <- pg_decode.element(0, pg_decode.int)
  use image_filename <- pg_decode.element(1, pg_decode.text)
  use image_content_type <- pg_decode.element(2, pg_decode.text)
  use width_cm_str <- pg_decode.element(3, pg_decode.numeric)
  use user_id <- pg_decode.element(4, pg_decode.optional(pg_decode.int))
  use status <- pg_decode.element(5, pg_decode.text)
  use created_at <- pg_decode.element(6, pg_decode.text)

  let width_cm = float.parse(width_cm_str) |> result.unwrap(0.0)

  pg_decode.success(Submission(
    id: id,
    image_filename: image_filename,
    image_content_type: image_content_type,
    width_cm: width_cm,
    user_id: user_id,
    status: status,
    created_at: created_at,
  ))
}

fn decode_image_data() -> pg_decode.RowDecoder(ImageData) {
  use data <- pg_decode.element(0, pg_decode.bytea)
  use content_type <- pg_decode.element(1, pg_decode.text)
  use filename <- pg_decode.element(2, pg_decode.text)

  pg_decode.success(ImageData(
    data: data,
    content_type: content_type,
    filename: filename,
  ))
}
