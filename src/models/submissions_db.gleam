import db_coordinator.{type DbCoordName}
import errors.{type AppError}
import gleam/dynamic/decode
import gleam/option.{type Option}
import gleam/result
import models/submissions.{type ImageData, type Submission, ImageData, Submission}
import pog

pub fn create(
  db: DbCoordName,
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
    pog.query(sql)
    |> pog.parameter(pog.bytea(image_data))
    |> pog.parameter(pog.text(image_filename))
    |> pog.parameter(pog.text(image_content_type))
    |> pog.parameter(pog.float(width_cm))
    |> pog.parameter(pog.nullable(pog.int, user_id))
    |> pog.returning(decode_submission())
    |> db_coordinator.submission_query(db),
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

pub fn get_all(db: DbCoordName) -> Result(List(Submission), AppError) {
  let sql =
    "
    SELECT id, image_filename, image_content_type, width_cm, user_id, status, created_at::text
    FROM submissions
    ORDER BY created_at DESC
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.returning(decode_submission())
    |> db_coordinator.submission_query(db),
  )

  Ok(rows.rows)
}

pub fn get_image_data(
  db: DbCoordName,
  id: Int,
) -> Result(ImageData, AppError) {
  let sql =
    "
    SELECT image_data, image_content_type, image_filename
    FROM submissions
    WHERE id = $1
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.int(id))
    |> pog.returning(decode_image_data())
    |> db_coordinator.image_data_query(db),
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

pub fn get_all_pending_images(
  db: DbCoordName,
) -> Result(List(ImageData), AppError) {
  let sql =
    "
    SELECT image_data, image_content_type, image_filename
    FROM submissions
    WHERE status = 'pending'
    ORDER BY created_at ASC
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.returning(decode_image_data())
    |> db_coordinator.image_data_query(db),
  )

  Ok(rows.rows)
}

pub fn mark_done(
  db: DbCoordName,
  id: Int,
) -> Result(Submission, AppError) {
  let sql =
    "
    UPDATE submissions
    SET status = 'done', updated_at = NOW()
    WHERE id = $1
    RETURNING id, image_filename, image_content_type, width_cm, user_id, status, created_at::text
  "

  use rows <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.int(id))
    |> pog.returning(decode_submission())
    |> db_coordinator.submission_query(db),
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

fn decode_submission() -> decode.Decoder(Submission) {
  use id <- decode.field("id", decode.int)
  use image_filename <- decode.field("image_filename", decode.string)
  use image_content_type <- decode.field("image_content_type", decode.string)
  use width_cm <- decode.field("width_cm", pog.numeric_decoder())
  use user_id <- decode.field("user_id", decode.optional(decode.int))
  use status <- decode.field("status", decode.string)
  use created_at <- decode.field("created_at", decode.string)

  decode.success(Submission(
    id: id,
    image_filename: image_filename,
    image_content_type: image_content_type,
    width_cm: width_cm,
    user_id: user_id,
    status: status,
    created_at: created_at,
  ))
}

fn decode_image_data() -> decode.Decoder(ImageData) {
  use data <- decode.field("image_data", decode.bit_array)
  use content_type <- decode.field("image_content_type", decode.string)
  use filename <- decode.field("image_filename", decode.string)

  decode.success(ImageData(
    data: data,
    content_type: content_type,
    filename: filename,
  ))
}
