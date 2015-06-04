-module(mongo_devices_ser).
-behaviour(gen_server).
-export([start_link/0, count/1, insert/1, update/2, getCursorList/2, removePid/1, getDeviceId/1, setDeviceId/3, addDeviceTrackPid/1, removeDeviceTrackPid/1, getTrackPidsForDeviceId/1, getParentId/1, getPid/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
terminate/2, code_change/3]).

%%% Client API
start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [ localhost, 27017, <<"tracking">>, <<"devices">>], []).

%% Macros
-define(DEMO_STUDENT, <<"demo_student">>).
-define(DEMO_DEVICE, 355488020107485). %% 355488020107485

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

%% @doc Remove the inactive Pid from the Users Documents.
-spec removePid(Pid :: pid()) -> ok.
removePid(Pid) ->
	gen_server:cast(?MODULE, {remove_pid, Pid}).

%% @doc Return Device Id associated with the Current Pid / Student Id.
-spec getDeviceId(Cond :: tuple()) -> tuple().
getDeviceId(Cond) ->
	gen_server:call(?MODULE, {get_device_id, Cond}).

%% @doc Add the Track Pid for the given Student Id.
-spec addDeviceTrackPid(Data :: tuple()) -> tuple().
addDeviceTrackPid(Data) ->
	gen_server:cast(?MODULE, { add_device_track_pid, Data }).

%% @doc Remove Track Pid id exist.
-spec removeDeviceTrackPid(Data :: tuple()) -> tuple().
removeDeviceTrackPid(Data) ->
	gen_server:cast(?MODULE, { remove_device_track_pid, Data }).

%% @doc Remove Track Pid id exist.
-spec getTrackPidsForDeviceId(Cond :: tuple()) -> tuple().
getTrackPidsForDeviceId(Cond) ->
	gen_server:call(?MODULE, { get_track_pids_for_device_id, Cond }).

%%% HTTP API's
%% @doc Set the Provided Student Id and Parent Id for the Device Id.
-spec setDeviceId(StudentId :: number(), ParentId :: number(), DeviceId :: number()) -> ok | tuple().
setDeviceId(StudentId, ParentId, DeviceId) ->
	gen_server:call(?MODULE, { set_device, StudentId, ParentId, DeviceId }).

%%% HTTP API's
%% @doc Set the Provided Student Id and Parent Id for the Device Id.
-spec getParentId(Cond :: tuple()) -> ok | tuple().
getParentId(Cond) ->
	gen_server:call(?MODULE, { get_parent_id, Cond }).

%%% HTTP API's
%% @doc Get Device Process Id associated with the Server.
-spec getPid(Cond :: tuple()) -> ok | tuple().
getPid(Cond) ->
	gen_server:call(?MODULE, { get_pid, Cond }).

%%% Server functions
init([ Host, Port, Database, Collection ]) ->
	case mongo:connect(Host, Port, Database) of
		{ok, Connection} ->
%% 			io:format("Connected to ~p DB Collection : ~p.~n",[Collection, Connection]),
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

handle_call({get_device_id, { pid, Pid } }, _From, [{ Connection, Collection }]) ->
	Id = case mongo:find_one(Connection, Collection, { pid, Pid }, { device, 1, '_id', 0 }) of
		       {{device, DeviceId}} ->
			       DeviceId;
		       {} ->
			       pid_not_registered
	       end,
	{reply, {device, Id} , [{ Connection, Collection }] };


handle_call({get_device_id, { student_id, StudentId } }, _From, [{ Connection, Collection }]) ->
	Id = case mongo:find_one(Connection, Collection, { student, StudentId }, { device, 1, '_id', 0 }) of
		     {{device, DeviceId}} ->
			     {device, DeviceId};
		     {} ->
			     case StudentId == ?DEMO_STUDENT of
					 true -> {device, ?DEMO_DEVICE };
					 false -> {ok, error}
			     end
	     end,
	{reply, Id , [{ Connection, Collection }] };

handle_call({ get_parent_id, { pid, Pid } }, _From, [{ Connection, Collection }]) ->
	case mongo:find_one(Connection, Collection, { pid, Pid }, { student, 1, parent, 1, '_id', 0 }) of
       {{ student, StudentId, parent, ParentId }} ->
	       {reply, { student_id, StudentId, parent_id, ParentId } , [{ Connection, Collection }] };
       {} ->
            {reply, {error, parent_id_not_found} , [{ Connection, Collection }] }
	end;

handle_call({ get_pid, Cond }, _From, [{ Connection, Collection }]) ->
	case mongo:find_one(Connection, Collection, Cond, { pid, 1, '_id', 0 }) of
       {{ pid, Pid }} ->
	       {reply, { pid, binary_to_term(Pid) } , [{ Connection, Collection }] };
       {} ->
            {reply, {error, pid_not_found} , [{ Connection, Collection }] }
	end;

handle_call({ set_device, StudentId, ParentId, DeviceId }, _From, [{ Connection, Collection }]) ->
	case mongo:count(Connection, Collection, { device, DeviceId }) of
		0 ->
			io:format("Device ID (IMEI Number) is not registered.~n"),
			{reply, <<"Device ID (IMEI Number) is not registered.">>, [{ Connection, Collection }] };
		_N ->
			Command = {'$set', {
				student, StudentId,
				parent, ParentId
			}},

			case mongo:update(Connection, Collection, { device, DeviceId }, Command) of
				ok ->
					{reply, <<"ok">>, [{ Connection, Collection }] };
				_X ->
					{reply, <<"Error while updating the Record.">>, [{ Connection, Collection }] }
			end
	end;

handle_call({ get_track_pids_for_device_id, Cond }, _From, [{ Connection, Collection }]) ->
	case mongo:find_one(Connection, Collection, Cond, { track_pids, 1, '_id', 0 }) of
	     {{track_pids, Pids}} ->
		     {reply, {track_pids, Pids} , [{ Connection, Collection }] };
	     {} ->
		     {reply, track_pids_not_found, [{ Connection, Collection }] }
     end;

handle_call(_Request, _From, State) ->
	{reply, ok, State}.

handle_cast({remove_pid, Pid}, [{ Connection, Collection }]) ->
	Cond = { pid, Pid },
	Docs = {'$set', {
		pid, null
	}},
	mongo:update(Connection, Collection, Cond, Docs),
	{noreply, [{ Connection, Collection }]};

handle_cast({ add_device_track_pid, { track_pid, Pid, student_id, StudentId } }, [{ Connection, Collection }]) ->
	Cond = { student, StudentId },
	case mongo:find_one(Connection, Collection, Cond, { track_pids, 1, '_id', 0 }) of
		{{track_pids, L}} ->
			Command = {'$set', {
				track_pids, [ term_to_binary(Pid) | L ]
			}},
		mongo:update(Connection, Collection, Cond, Command);
		{} ->
			ok
	end,
	{noreply, [{ Connection, Collection }]};

handle_cast({ remove_device_track_pid, { track_pid, Pid } }, [{ Connection, Collection }]) ->
	Cond = {track_pids, Pid},
	case mongo:find_one(Connection, Collection, Cond, { track_pids, 1, '_id', 0 }) of
		{{track_pids, Pids}} ->
			UpdatedPids = lists:delete(Pid, Pids),
			Docs = {'$set', {
				track_pids, UpdatedPids
			}},
			mongo:update(Connection, Collection, Cond, Docs);
		{} ->
%% 			io:format("Pid is not registered for Track.")
			ok
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

% Internal Functions

getCursorList(Col, Cursor) ->
	getCursorList(mc_cursor:next(Cursor), Col, Cursor, []).

getCursorList({}, _Col, Cursor,  Acc) ->
	mc_cursor:close(Cursor),
	Acc;

getCursorList({{Col, L}}, Col, Cursor, Acc) ->
	getCursorList(mc_cursor:next(Cursor), Col, Cursor, L ++ Acc).