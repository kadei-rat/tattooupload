-module(zip_ffi).
-export([create/1]).

create(Files) ->
    ErlFiles = [{binary_to_list(Name), Data} || {Name, Data} <- Files],
    case zip:create("download.zip", ErlFiles, [memory]) of
        {ok, {_, Bytes}} -> {ok, Bytes};
        {error, Reason} -> {error, Reason}
    end.
