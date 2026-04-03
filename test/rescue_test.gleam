import gleam/string
import rescue

pub fn rescue_captures_successful_result_test() {
  let assert Ok(42) = rescue.rescue(fn() { 42 })
}

pub fn rescue_catches_erlang_error_test() {
  let assert Error(crash) = rescue.rescue(fn() { panic as "test crash" })

  let assert True = string.contains(crash.stacktrace, "test crash")
}

pub fn rescue_catches_function_clause_error_test() {
  let assert Error(crash) =
    rescue.rescue(fn() { force_function_clause_error() })

  let assert True =
    string.contains(crash.stacktrace, "function_clause")
    || string.contains(crash.stacktrace, "no function clause matching")
}

pub fn rescue_stacktrace_contains_module_info_test() {
  let assert Error(crash) =
    rescue.rescue(fn() { force_function_clause_error() })

  let assert True = string.contains(crash.stacktrace, "rescue_test")
}

@external(erlang, "rescue_test_ffi", "force_function_clause_error")
fn force_function_clause_error() -> Nil
