import frontend/login_components.{type LoginState}
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

const js_hash = "fillmein"

const css_hash = "fillmein"

pub fn view(
  elements: List(Element(Nil)),
  login_state: LoginState,
) -> Element(Nil) {
  html.html([], [
    html.head([], [
      html.title([], "Kadei's EMFCamp temporary tattoos"),
      html.meta([
        attribute.name("viewport"),
        attribute.attribute("content", "width=device-width, initial-scale=1"),
      ]),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/static/main.css?v=" <> css_hash),
      ]),
    ]),
    html.body(
      [],
      list.flatten([
        [login_components.header(login_state)],
        [html.main([], elements)],
        [html.script([attribute.src("/static/app.js?v=" <> js_hash)], "")],
      ]),
    ),
  ])
}
