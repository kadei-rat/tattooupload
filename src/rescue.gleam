import gleam/dynamic.{type Dynamic}

pub type Crash {
  Crash(class: Dynamic, term: Dynamic, stacktrace: String)
}

@external(erlang, "rescue_ffi", "rescue")
pub fn rescue(body: fn() -> a) -> Result(a, Crash)
