import frontend/login_components.{type LoginState}
import gleam/option.{None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn view(
  _login_state: LoginState,
  error: option.Option(String),
) -> List(Element(Nil)) {
  [
    case error {
      Some(msg) -> html.div([attribute.class("error-banner")], [html.text(msg)])
      None -> element.none()
    },
    html.div([attribute.class("upload-container")], [
      html.h1([], [
        html.text(
          "That's it for this year's lwcw, hope you enjoyed the tattoos",
        ),
      ]),
    ]),
  ]
}
