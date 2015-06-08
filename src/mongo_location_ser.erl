-module(mongo_location_ser).
-behaviour(gen_server).
-export([start_link/0, count/1, insert/1, update/2, getCursorList/2, get_latest_gps_location/1, get_gps_locations/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	terminate/2, code_change/3]).

%%% Client API
start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [ localhost, 27017, <<"tracking">>, <<"location">>], []).

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

%% @doc return the GPS location for the given student Id.
-spec get_latest_gps_location(StudentId :: string()) -> ok.
get_latest_gps_location(StudentId) ->
	gen_server:call(?MODULE, { get_latest_gps_location, StudentId }).

%% @doc return the GPS location for the given student Id.
-spec get_gps_locations(Msg :: string()) -> ok.
get_gps_locations(Msg) ->
	gen_server:cast(?MODULE, { get_gps_locations, Msg }).

%%% Server functions
init([ Host, Port, Database, Collection ]) ->
	case mongo:connect(Host, Port, Database) of
		{ok, Connection} ->
%% 			io:format("Connected to here ~p DB Collection : ~p.~n",[Collection, Connection]),
			{ok, [{ Connection, Collection }]};
		{error, Reason} ->
			io:format("Error Connecting to ~p DB Collection : ~p.~n",[Collection, Reason]),
			{stop, normal, Reason}
	end.

%% Insert Data into Mongo Db.
handle_call({ count, Doc }, _From, [{ Connection, Collection }]) ->
	{reply, mongo:count(Connection, Collection, Doc) , [{ Connection, Collection }] };

handle_call({ insert, Doc }, _From, [{ Connection, Collection }]) ->
	{reply, mongo:insert(Connection, Collection, Doc), [{ Connection, Collection }] };

handle_call({update, Cond, Docs}, _From, [{ Connection, Collection }]) ->
	{reply, mongo:update(Connection, Collection, Cond, Docs) , [{ Connection, Collection }] };

handle_call({ get_latest_gps_location, StudentId }, _From, [{ Connection, Collection }]) ->
	case mongo_devices_ser:getDeviceId({ student_id, StudentId }) of
		{ok, error} ->
			io:format("Device is not registered for the Student : ~p.~n", [StudentId]),
			{reply, { error, device_id_not_found }, [{ Connection, Collection }] };
		{device, DeviceId} ->
			{true, {result, Result}} = mongo:command(Connection,
												{aggregate, Collection, pipeline,
													[
														{'$match', { device, DeviceId }},
														{'$sort', {timestamp, -1}},
														{'$limit', 1},
														{'$project', { location, 1, speed, 1, timestamp, 1, '_id', 0 } }
													]}),
			case Result of
				[{location, Location, speed, Speed, timestamp, Timestamp}] ->
					Rep = {ok, {location, Location, speed, Speed, timestamp, Timestamp}},
					{reply, Rep, [{ Connection, Collection }] };
				[] ->
					{reply, { error, location_not_found }, [{ Connection, Collection }] }
			end
	end;

handle_call(_Request, _From, State) ->
	{reply, ok, State}.

handle_cast({ get_gps_locations, { Pid, StudentId, Timestamp } }, [{ Connection, Collection }]) ->
	case mongo_devices_ser:getDeviceId({ student_id, StudentId }) of
		{ok, error} ->
			io:format("Device is not registered for the Student : ~p.~n", [StudentId]),
			irc ! { error, Pid, device_id_not_found };
		{device, DeviceId} ->
%% 			Todo : Need to update the condition to use the timestamp value.
%% 			io:format("History Got : ~p.~n", [{ Timestamp, DeviceId}]),
			case mongo:command(Connection,
							{aggregate, Collection, pipeline,
								[
									{'$match', { device, DeviceId , timestamp, { '$lte', Timestamp } } },
									{'$sort', {timestamp, -1}},
									{'$limit', 200},
									{'$project', { location, 1, speed, 1, timestamp, 1, '_id', 0 } }
								]}) of
				{true, {result, Result}} ->
					locations_skip_logic(Pid, Result);
				_X -> history_not_found
			end
	end,
	{noreply, [{ Connection, Collection }]};

handle_cast(_Msg, State) ->
	{noreply, State}.

handle_info(Info, State) ->
	io:format("Mongo Info Got : ~p.~n", [Info]),
	{noreply, State}.

terminate(_Reason, _State) ->
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

getCursorList(Col, Cursor) ->
	getCursorList(mc_cursor:next(Cursor), Col, Cursor, []).

getCursorList({}, _Col, Cursor,  Acc) ->
	mc_cursor:close(Cursor),
	Acc;

getCursorList({{Col, L}}, Col, Cursor, Acc) ->
	getCursorList(mc_cursor:next(Cursor), Col, Cursor, L ++ Acc).

%% timestamp_bool_to_num(T) ->
%% 	case is_binary(T) of
%% 		true -> binary_to_integer(T);
%% 		false -> T
%% 	end.

locations_skip_logic(Pid, Result) ->
	locations_skip_logic(Pid, Result, 0, 0, []).

locations_skip_logic(Pid, [], _Count, Total, Acc) ->
	Pid ! {irc, #{ event => todays_loc, data => Acc }},
	io:format("Total : ~p.~n",[Total]), ok;

locations_skip_logic(Pid, _Result, _Count, Total, Acc) when Total > 100->
	Pid ! {irc, #{ event => todays_loc, data => Acc }},
	io:format("Done Total : ~p.~n",[Total]), ok;

locations_skip_logic(Pid, [ { location, {lat, _Lat, lon, _Lan}, speed, Speed, timestamp, _Timestamp} | T ], Count, Total, Acc) when Speed < 5, Count < 2 ->
	locations_skip_logic(Pid, T, Count+1, Total, Acc);

locations_skip_logic(Pid, [ { location, {lat, Lat, lon, Lan}, speed, Speed, timestamp, Timestamp} | T ], _Count, Total, Acc) ->
	locations_skip_logic(Pid, T, 0, Total+1, [ #{ lat => Lat, lan => Lan, speed => Speed, timestamp => Timestamp } | Acc]).