-module(rescue_test_ffi).
-export([force_function_clause_error/0]).

force_function_clause_error() ->
    do_match(nomatch).

do_match(match) -> ok.
