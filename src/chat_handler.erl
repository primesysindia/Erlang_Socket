%% @doc Chat handler for handling the Websocket Chat Requests.
-module(chat_handler).

-export([init/4]).
-export([stream/3]).
-export([info/3]).
-export([terminate/2]).

-define(PERIOD, 1000).
-define(SEPARATOR, "@@@").

init(_Transport, Req, _Opts, _Active) ->
	%%io:format('here at handler'),
	{ok, Req, undefined_state}.

stream(Msg, Req, State) ->
	event_decoder ! {event_received, self(), Msg},
	{ok, Req, State}.

info({irc, Map}, Req, State) ->
	{reply, jsx:encode(Map), Req, State};

info(Info, Req, State) ->
	io:format("Chat Handler Unexpected Message : ~p.~n", [Info]),
	{ok, Req, State}.

terminate(_Req, _State) ->
	irc ! {leave, self()},
	ok.
