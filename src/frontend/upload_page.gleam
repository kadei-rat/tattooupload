import frontend/login_components.{type LoginState, LoggedIn, LoggedOut}
import gleam/option.{None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn view(
  login_state: LoginState,
  error: option.Option(String),
) -> List(Element(Nil)) {
  [
    html.div([attribute.class("upload-container")], [
      html.p([], [
        html.strong([], [
          html.text("Upload an image to get it printed as a temporary tattoo! "),
        ]),
        html.text(
          "When it's done, pick it up from Kadei at the Furry High Commission.",
        ),
      ]),
      notification_hint(login_state),
      case error {
        Some(msg) ->
          html.div([attribute.class("error-banner")], [html.text(msg)])
        None -> element.none()
      },
      upload_form(),
      instructions(),
    ]),
  ]
}

fn instructions() -> Element(Nil) {
  html.div([attribute.class("instructions")], [
    html.h2([], [html.text("Advice for those with dark skin")]),
    html.p([], [
      html.text(
        "My printer can't do white ink, white is equivalent to transparent. That means that if you have darker skin, I recommend using ",
      ),
      html.strong([], [html.text("fully-saturated light colours ")]),
      html.text("(like yellow) for light areas of the tattoo"),
    ]),
    html.h2([], [html.text("Accessibility")]),
    html.p([], [
      html.text(
        "If you are unable to pick up in person at the FHC for accessibility reasons, message me on telegram ",
      ),
      html.a([attribute.href("https://t.me/kadei_rat")], [
        html.text("@kadei_rat"),
      ]),
      html.text(" or signal "),
      html.a(
        [
          attribute.href(
            "https://signal.me/#eu/cbNjdbFvsmKnInXqszOJoJkycyexcAhkAHZNw_DBhWc_xGIKy3NGs4FpRXdnQo_r",
          ),
        ],
        [
          html.text("@kadei.69"),
        ],
      ),
      html.text(" to arrange delivery (by me or through emfcamp post)"),
    ]),
  ])
}

fn upload_form() -> Element(Nil) {
  html.form(
    [
      attribute.action("/upload"),
      attribute.method("post"),
      attribute.attribute("enctype", "multipart/form-data"),
      attribute.class("upload-form"),
    ],
    [
      html.div([attribute.class("form-group")], [
        html.label([attribute.for("image")], [html.text("Image file")]),
        html.input([
          attribute.type_("file"),
          attribute.name("image"),
          attribute.id("image"),
          attribute.accept([
            "image/png",
            "image/jpeg",
            "image/gif",
            "image/webp",
            "image/svg+xml",
            "image/bmp",
          ]),
          attribute.attribute("required", ""),
        ]),
      ]),
      html.div([attribute.class("form-group")], [
        html.label([attribute.for("width_cm")], [
          html.text("Requested width (cm)"),
        ]),
        html.input([
          attribute.type_("number"),
          attribute.name("width_cm"),
          attribute.id("width_cm"),
          attribute.attribute("min", "1"),
          attribute.attribute("max", "20"),
          attribute.attribute("step", "0.1"),
          attribute.value("5"),
          attribute.attribute("required", ""),
        ]),
      ]),
      html.button([attribute.type_("submit"), attribute.class("submit-btn")], [
        html.text("Upload"),
      ]),
    ],
  )
}

fn notification_hint(login_state: LoginState) -> Element(Nil) {
  case login_state {
    LoggedIn(user) ->
      html.p([attribute.class("notification-hint")], [
        html.text(
          "Uploading as "
          <> case user.username {
            Some(u) -> "@" <> u
            None -> user.first_name
          }
          <> " — you'll be notified on Telegram when your tattoo is ready.",
        ),
      ])
    LoggedOut(bot_name, dev_mode, return_url) ->
      html.div([attribute.class("notification-hint")], [
        html.text(
          "Want to be notified when your tattoo is printed? Log in to get a Telegram notification: ",
        ),
        case dev_mode {
          True ->
            html.form(
              [
                attribute.action("/login"),
                attribute.method("post"),
                attribute.style("display", "inline"),
              ],
              [
                html.input([
                  attribute.type_("hidden"),
                  attribute.name("return_url"),
                  attribute.value(return_url),
                ]),
                html.button(
                  [
                    attribute.type_("submit"),
                    attribute.class("inline-login-btn"),
                  ],
                  [html.text("Log in")],
                ),
              ],
            )
          False ->
            html.div(
              [
                attribute.id("telegram-login"),
                attribute.attribute("data-telegram-login", bot_name),
                attribute.attribute("data-size", "small"),
                attribute.attribute("data-radius", "5"),
                attribute.attribute("data-request-access", "write"),
                attribute.attribute("data-return-url", return_url),
              ],
              [],
            )
        },
      ])
  }
}
