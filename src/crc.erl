-module(crc).
-export([get_crc/1]).
-on_load(init/0).

init() ->
    ok = erlang:load_nif("lib/chat-0.1.0/priv/chat", 0).

get_crc(_X) ->
    exit(nif_library_not_loaded).