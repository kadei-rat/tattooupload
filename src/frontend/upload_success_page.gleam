import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn view() -> List(Element(Nil)) {
  [
    html.div([attribute.class("success-container")], [
      html.h1([], [html.text("Image uploaded!")]),
      html.p([], [
        html.text(
          "Your image has been submitted. If you logged in with Telegram, you'll be notified when your tattoo is ready for pickup. Otherwise, check in at the Furry High Commission in a day, or poke me on telegram ",
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
        html.text(" to ask if it's done."),
      ]),
      html.a([attribute.href("/"), attribute.class("upload-another-btn")], [
        html.text("Upload another image"),
      ]),
    ]),
  ]
}
