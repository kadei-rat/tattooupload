import gleam/option.{type Option}
import models/role.{type Role}

pub type User {
  User(
    id: Int,
    first_name: String,
    last_name: String,
    username: Option(String),
    photo_url: Option(String),
    role: Role,
    ban: Option(String),
  )
}
