%%%-------------------------------------------------------------------
%%% @author Piyush D. Sable
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%     This module is used to handle the geofence data.
%%% @end
%%% Created : 06. Jul 2015 4:14 PM
%%%-------------------------------------------------------------------

-module(mongo_geo_fence_ser).
-author("Piyush D. Sable").

-behaviour(gen_server).

%% External API
-export([start_link/0, count/1, insert/1, update/2 ]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%%% Client API
start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [ localhost, 27017, <<"tracking">>, <<"geo_fence">>], []).

%%% API's

%% @doc get number of documents into the collection.
-spec count(Docs :: tuple()) -> N :: number().
count(Doc) ->
	gen_server:call(?MODULE, { count, Doc }).

%% @doc insert the document into the collection.
-spec insert(Docs :: tuple()) -> tuple().
insert(Docs) ->
	gen_server:call(?MODULE, {insert, Docs}).

%% @doc Select the record by condition and update the document with Docs.
-spec update(Cond :: tuple(), Docs :: tuple()) -> ok.
update(Cond, Docs) ->
	gen_server:call(?MODULE, {update, Cond, Docs}).

%%% Server functions
init([ Host, Port, Database, Collection ]) ->
	case mongo:connect(Host, Port, Database) of
		{ok, Connection} ->
			io:format("Connected to ~p DB Collection : ~p.~n",[Collection, Connection]),
			{ok, [{ Connection, Collection }]};
		{error, Reason} ->
			io:format("Error Connecting to ~p DB Collection : ~p.~n",[Collection, Reason]),
			{stop, normal, Reason}
	end.

%% Insert Data into Mongo Db.
handle_call({ count, Doc }, _From, [{ Connection, Collection }]) ->
	{reply, mongo:count(Connection, Collection, Doc) , [{ Connection, Collection }] };

handle_call({ insert, Doc }, _From, [{ Connection, Collection }]) ->
	io:format("Got insert : ~p.~n",[mongo:insert(Connection, Collection, Doc)]),
	{reply, mongo:insert(Connection, Collection, Doc), [{ Connection, Collection }] };

handle_call({update, Cond, Docs}, _From, [{ Connection, Collection }]) ->
	{reply, mongo:update(Connection, Collection, Cond, Docs) , [{ Connection, Collection }] };

handle_call(_Request, _From, State) ->
	{reply, ok, State}.

handle_cast(_Msg, State) ->
	{noreply, State}.

handle_info(Info, State) ->
	io:format("Mongo Info Got : ~p.~n", [Info]),
	{noreply, State}.

terminate(_Reason, _State) ->
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

% Internal Functions