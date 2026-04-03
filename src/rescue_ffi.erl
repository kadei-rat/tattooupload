-module(rescue_ffi).
-export([rescue/1]).

rescue(F) ->
    try {ok, F()}
    catch
        Class:Term:Stacktrace ->
            FormattedStacktrace = iolist_to_binary(
                erl_error:format_exception(Class, Term, Stacktrace)
            ),
            {error, {crash, Class, Term, FormattedStacktrace}}
    end.
