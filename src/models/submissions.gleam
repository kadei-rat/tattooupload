import gleam/option.{type Option}

pub type Submission {
  Submission(
    id: Int,
    image_filename: String,
    image_content_type: String,
    width_cm: Float,
    user_id: Option(Int),
    status: String,
    created_at: String,
  )
}

pub type ImageData {
  ImageData(data: BitArray, content_type: String, filename: String)
}
