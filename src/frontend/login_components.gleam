import gleam/option.{None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import models/role
import models/users.{type User}

pub type LoginState {
  LoggedIn(user: User)
  LoggedOut(telegram_bot_name: String, dev_mode: Bool, return_url: String)
}

pub fn header(state: LoginState) -> Element(Nil) {
  html.header([attribute.class("site-header")], [
    html.div([attribute.class("header-content")], [
      html.div([attribute.class("header-left")], [
        html.a([attribute.href("/"), attribute.class("site-title")], [
          html.text("Kadei's EMFCamp temporary tattoos"),
        ]),
      ]),
      html.div([attribute.class("header-right")], [login_area(state)]),
    ]),
  ])
}

fn login_area(state: LoginState) -> Element(Nil) {
  case state {
    LoggedIn(user) -> logged_in_display(user)
    LoggedOut(_, _, _) -> element.none()
  }
}

fn logged_in_display(user: User) -> Element(Nil) {
  html.div([attribute.class("user-info")], [
    html.div([attribute.class("user-identity")], [
      case user.photo_url {
        Some(url) ->
          html.img([
            attribute.src(url),
            attribute.alt("Profile"),
            attribute.class("user-avatar"),
          ])
        None -> element.none()
      },
      html.span([attribute.class("user-name")], [
        html.text(display_name(user)),
      ]),
    ]),
    html.div([attribute.class("user-actions")], [
      case user.role {
        role.Admin ->
          html.a([attribute.href("/admin"), attribute.class("header-link")], [
            html.text("Dashboard"),
          ])
        _ -> element.none()
      },
      html.form(
        [
          attribute.action("/logout"),
          attribute.method("post"),
          attribute.class("logout-form"),
        ],
        [
          html.button(
            [attribute.type_("submit"), attribute.class("logout-btn")],
            [html.text("Logout")],
          ),
        ],
      ),
    ]),
  ])
}

fn display_name(user: User) -> String {
  case user.username {
    Some(username) -> "@" <> username
    None -> user.first_name
  }
}
