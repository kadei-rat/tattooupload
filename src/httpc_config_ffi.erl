-module(httpc_config_ffi).
-export([increase_max_sessions/1]).

increase_max_sessions(Max) ->
    httpc:set_options([{max_sessions, Max}, {max_pipeline_length, Max}]).
