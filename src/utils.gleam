import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/string
import logging

pub fn decode_errors_to_string(errors: List(decode.DecodeError)) -> String {
  errors
  |> list.map(fn(error) {
    let decode.DecodeError(expected, found, path) = error
    "Problem with field "
    <> string.join(path, ".")
    <> " (expected "
    <> expected
    <> ", found "
    <> found
    <> ")"
  })
  |> string.join(". ")
}

pub fn find_first(list: List(a), predicate: fn(a) -> Bool) -> Result(a, Nil) {
  case list {
    [] -> Error(Nil)
    [first, ..rest] ->
      case predicate(first) {
        True -> Ok(first)
        False -> find_first(rest, predicate)
      }
  }
}

pub fn spy_on_result(
  result: Result(a, e),
  fun: fn(Result(a, e)) -> Nil,
) -> Result(a, e) {
  fun(result)
  result
}

pub fn combine2(first: Result(a, e), second: Result(b, e)) -> Result(#(a, b), e) {
  case first, second {
    Error(err), _ -> Error(err)
    _, Error(err) -> Error(err)
    Ok(a), Ok(b) -> Ok(#(a, b))
  }
}

pub fn combine2errs(
  first: Result(Nil, e),
  second: Result(Nil, e),
) -> Result(Nil, e) {
  case first, second {
    Error(err), _ -> Error(err)
    _, Error(err) -> Error(err)
    Ok(_), Ok(_) -> Ok(Nil)
  }
}

// in the result module but deprecated for some reason
pub fn unwrap_both(res: Result(a, a)) -> a {
  case res {
    Ok(a) -> a
    Error(a) -> a
  }
}

pub fn retry_with_backoff(
  operation: fn() -> Result(a, b),
  max_attempts: Int,
  initial_delay_ms: Int,
  max_delay_ms: Int,
  context: String,
) -> Result(a, b) {
  do_retry(operation, max_attempts, max_delay_ms, initial_delay_ms, 1, context)
}

fn do_retry(
  operation: fn() -> Result(a, b),
  max_attempts: Int,
  max_delay_ms: Int,
  current_delay_ms: Int,
  attempt: Int,
  context: String,
) -> Result(a, b) {
  case operation() {
    Ok(result) -> Ok(result)
    Error(err) if attempt >= max_attempts -> {
      logging.log(
        logging.Warning,
        context
          <> " failed after "
          <> int.to_string(attempt)
          <> " attempts, giving up; err ="
          <> string.inspect(err),
      )
      Error(err)
    }
    Error(err) -> {
      logging.log(
        logging.Info,
        context
          <> " failed on attempt "
          <> int.to_string(attempt)
          <> ", retrying in "
          <> int.to_string(current_delay_ms)
          <> "ms; err ="
          <> string.inspect(err),
      )
      process.sleep(current_delay_ms)
      let next_delay = int.min(current_delay_ms * 2, max_delay_ms)
      do_retry(
        operation,
        max_attempts,
        max_delay_ms,
        next_delay,
        attempt + 1,
        context,
      )
    }
  }
}
