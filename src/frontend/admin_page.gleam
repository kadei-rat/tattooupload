import gleam/float
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import models/submissions.{type Submission}

pub fn view(submissions: List(Submission)) -> List(Element(Nil)) {
  let pending = list.filter(submissions, fn(s) { s.status == "pending" })
  let done = list.filter(submissions, fn(s) { s.status == "done" })

  [
    html.div([attribute.class("admin-container")], [
      html.h1([], [html.text("Admin — Submissions")]),
      html.div([attribute.class("admin-stats")], [
        html.span([], [
          html.text(
            int.to_string(list.length(pending))
            <> " pending, "
            <> int.to_string(list.length(done))
            <> " done",
          ),
        ]),
      ]),
      html.h2([], [html.text("Pending")]),
      case pending {
        [] -> element.none()
        _ ->
          html.a(
            [
              attribute.href("/admin/submissions/download-all"),
              attribute.class("download-btn"),
            ],
            [html.text("Download All Pending")],
          )
      },
      case pending {
        [] ->
          html.p([attribute.class("empty-state")], [
            html.text("No pending submissions."),
          ])
        _ -> submissions_grid(pending)
      },
      html.h2([], [html.text("Done")]),
      case done {
        [] ->
          html.p([attribute.class("empty-state")], [
            html.text("No completed submissions yet."),
          ])
        _ -> submissions_grid(done)
      },
    ]),
  ]
}

fn submissions_grid(submissions: List(Submission)) -> Element(Nil) {
  html.div(
    [attribute.class("submissions-grid")],
    list.map(submissions, submission_card),
  )
}

fn submission_card(submission: Submission) -> Element(Nil) {
  let id_str = int.to_string(submission.id)
  html.div([attribute.class("submission-card")], [
    case submission.status {
      "pending" ->
        html.img([
          attribute.src("/submissions/" <> id_str <> "/image"),
          attribute.alt(submission.image_filename),
          attribute.class("submission-thumbnail"),
          attribute.attribute("loading", "lazy"),
        ])
      _ -> element.none()
    },
    html.div([attribute.class("submission-info")], [
      html.div([attribute.class("submission-filename")], [
        html.text(submission.image_filename),
      ]),
      html.div([attribute.class("submission-width")], [
        html.text(float.to_string(submission.width_cm) <> " cm"),
      ]),
      html.div(
        [
          attribute.class("status-badge status-" <> submission.status),
        ],
        [html.text(submission.status)],
      ),
      case submission.user_id {
        Some(_) ->
          html.div([attribute.class("has-telegram")], [
            html.text("Will notify on Telegram"),
          ])
        None ->
          html.div([attribute.class("no-telegram")], [
            html.text("No Telegram notification"),
          ])
      },
    ]),
    html.div([attribute.class("submission-actions")], [
      html.a(
        [
          attribute.href("/submissions/" <> id_str <> "/image?download=true"),
          attribute.class("download-btn"),
        ],
        [html.text("Download")],
      ),
      case submission.status {
        "pending" ->
          html.form(
            [
              attribute.action("/admin/submissions/" <> id_str <> "/done"),
              attribute.method("post"),
            ],
            [
              html.button(
                [
                  attribute.type_("submit"),
                  attribute.class("mark-done-btn"),
                ],
                [html.text("Mark Done")],
              ),
            ],
          )
        _ -> element.none()
      },
    ]),
  ])
}
