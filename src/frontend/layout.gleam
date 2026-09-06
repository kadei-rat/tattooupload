import frontend/login_components.{type LoginState}
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

const js_hash = "e8af5244"

const css_hash = "c403d5f4"

pub fn view(
  elements: List(Element(Nil)),
  login_state: LoginState,
) -> Element(Nil) {
  html.html([], [
    html.head([], [
      html.meta([attribute.attribute("charset", "utf-8")]),
      html.title([], "Kadei's LWCW temporary tattoos"),
      html.meta([
        attribute.name("viewport"),
        attribute.attribute("content", "width=device-width, initial-scale=1"),
      ]),
      html.link([
        attribute.rel("preload"),
        attribute.href("/static/fonts/raleway-latin.woff2"),
        attribute.attribute("as", "font"),
        attribute.type_("font/woff2"),
        attribute.attribute("crossorigin", ""),
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
