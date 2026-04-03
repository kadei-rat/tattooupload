pub type Role {
  User
  Admin
}

pub fn to_string(role: Role) -> String {
  case role {
    User -> "user"
    Admin -> "admin"
  }
}

pub fn from_string(str: String) -> Result(Role, Nil) {
  case str {
    "user" -> Ok(User)
    "admin" -> Ok(Admin)
    _ -> Error(Nil)
  }
}
