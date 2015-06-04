-module(get_gps_location).
-behaviour(gen_server).
-export([start_link/0, get_latest_gps_location/1, set_device/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	terminate/2, code_change/3]).

%% Insert Data into Mongo Db.
-define(DeviceTab, <<"devices">>).
-define(LocationTab, <<"location">>).

%%% Client API
start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [ localhost, 27017, <<"tracking">> ], []).

%%% API's
%% @doc return the GPS location for the given student Id.
-spec get_latest_gps_location(StudentId :: string()) -> ok.
get_latest_gps_location(StudentId) ->
	gen_server:call(?MODULE, { get_latest_gps_location, StudentId }).

%%% API's
%% @doc Set the Provided Student Id for the Device Id.
-spec set_device(StudentId :: number(), DeviceId :: number()) -> ok | tuple().
set_device(StudentId, DeviceId) ->
	gen_server:call(?MODULE, { set_device, StudentId, DeviceId }).

%%% Server functions
init([ Host, Port, Database ]) ->
	{ok, [{ Host, Port, Database }]}.

handle_call({ get_latest_gps_location, StudentId }, _From, [{ Host, Port, Database }]) ->
	case connect({Host, Port, Database }) of
		{ok, error} ->
			{reply, { error, error_establishing_db_connection }, [{ Host, Port, Database }] };
		{ok, Connection} ->
			case getDeviceId({ StudentId, Connection }) of
				{ok, error} ->
					io:format("Device is not registered for the Student : ~p.~n", [StudentId]),
					{reply, { error, device_id_not_found }, [{ Host, Port, Database }] };
				{ok, DeviceId} ->
					case mongo:find_one(Connection, ?LocationTab, { device, DeviceId }, { location, 1, speed, 1, '_id', 0 }) of
						{{location, Location, speed, Speed}} ->
							Rep = {ok, {location, Location, speed, Speed}},
							{reply, Rep, [{ Host, Port, Database }] };
						{} ->
							{reply, { error, location_not_found }, [{ Host, Port, Database }] }
					end
			end
		end;

handle_call({ set_device, StudentId, DeviceId }, _From, [{ Host, Port, Database }]) ->
	case connect({Host, Port, Database }) of
		{ok, error} ->
			{reply, { error, error_establishing_db_connection }, [{ Host, Port, Database }] };
		{ok, Connection} ->
			case count(Connection, { device, DeviceId }) of
				0 ->
					io:format("Device ID (IMEI Number) is not registered.~n"),
					{reply, <<"Device ID (IMEI Number) is not registered.">>, [{ Host, Port, Database }] };
				_N ->
					Command = {'$set', {
						student, StudentId
					}},

					case mongo:update(Connection, ?DeviceTab, { device, DeviceId }, Command) of
						ok ->
							{reply, <<"ok">>, [{ Host, Port, Database }] };
						_X ->
							{reply, <<"Error while updating the Record.">>, [{ Host, Port, Database }] }
					end
			end
		end;

handle_call(_Request, _From, State) ->
	{reply, ok, State}.

count(Connection, Doc) ->
	mongo:count(Connection, ?DeviceTab, Doc).

handle_cast(_Msg, State) ->
	{noreply, State}.

handle_info(Info, State) ->
	io:format("Mongo Info Got : ", Info),
	{noreply, State}.

terminate(_Reason, _State) ->
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

%% Internal Functions

%% @doc Return the Device Id registered for the Student.
getDeviceId({ StudentId, Connection }) ->
	case mongo:find_one(Connection, ?DeviceTab, { student, StudentId }, { device, 1, '_id', 0 }) of
       {{device, DeviceId}} ->
	       {ok, DeviceId};
       {} ->
	       {ok, error}
   end.

%% @doc Establish Connection with the Provided Database.
connect({Host, Port, Database }) ->
	case mongo:connect(Host, Port, Database) of
		{ok, Connection} ->
			io:format("Connected to ~p DB : ~p.~n",[Database, Connection]),
			{ok, Connection };
		{error, Reason} ->
			io:format("Error Connecting to ~p DB : ~p.~n",[Database, Reason]),
			{ok, error}
	end.

%% getCursorList(Col, Cursor) ->
%% 	getCursorList(mc_cursor:next(Cursor), Col, Cursor, []).
%%
%% getCursorList({}, _Col, Cursor,  Acc) ->
%% 	mc_cursor:close(Cursor),
%% 	Acc;
%%
%% getCursorList({{Col, L}}, Col, Cursor, Acc) ->
%% 	getCursorList(mc_cursor:next(Cursor), Col, Cursor, L ++ Acc).