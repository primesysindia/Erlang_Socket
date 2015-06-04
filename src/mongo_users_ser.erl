-module(mongo_users_ser ).
-behaviour(gen_server).
-export([start_link/0, set_app_id/1, count/1, insert/1, getPids/1, getPids/2, update/2, removePid/1, getPids/0, getgroupPids/1, getCursorList/2, getSchoolUsersPids/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
terminate/2, code_change/3]).

%%% Client API
start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [ localhost, 27017, <<"chat">>, <<"users">>, null], []).

%%% API's
%% @doc set the AppId value into the process state.
-spec set_app_id(AppId :: string()) -> ok.
set_app_id(AppId) ->
	gen_server:call(?MODULE, { set_app_id, AppId }).

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

%% @doc Return the list of Pids for the Current set AppId.
-spec getPids() -> [ Pid :: pid() ].
getPids() ->
	gen_server:call(?MODULE, get_pids).

%% @doc Get the User Name and return the list of Pids.
-spec getPids(Name :: string()) -> [ Pid :: pid() ].
getPids(Name) ->
	gen_server:call(?MODULE, {get_pids, Name}).

%% @doc Get the data tuple and return the list of Pids.
-spec getgroupPids(Data :: tuple()) -> [ Pid :: pid() ].
getgroupPids(Data) ->
	gen_server:call(?MODULE, {get_group_pids, Data}).

%% @doc Get the AppId and User Name and return the list of Pids.
%% Older Inplementation.
-spec getPids(AppId :: string(), Id :: string()) -> [ Pid :: pid() ].
getPids(AppId, Id) ->
	gen_server:call(?MODULE, {get_pids, AppId, Id}).

%% @doc Remove the inactive Pid from the Users Documents.
-spec removePid(Pid :: pid()) -> ok.
removePid(Pid) ->
	gen_server:cast(?MODULE, {remove_pid, Pid}).

%% @doc Get the list of Pids registered for the users belongs to the school by the Principal Id.
-spec getSchoolUsersPids(Data :: string()) -> [ Pid :: pid() ].
getSchoolUsersPids(Data) ->
	gen_server:call(?MODULE, {get_school_users_pids, Data}).

%%% Server functions
init([ Host, Port, Database, Collection, AppId ]) ->
	case mongo:connect(Host, Port, Database) of
		{ok, Connection} ->
%% 			io:format("Connected to ~p DB Collection : ~p.~n",[Collection, Connection]),
			{ok, [{ Connection, Collection, AppId }]};
		{error, Reason} ->
			io:format("Error Connecting to ~p DB Collection : ~p.~n",[Collection, Reason]),
			{stop, normal, Reason}
	end.

%% Insert Data into Mongo Db.
handle_call({ set_app_id, AppId }, _From, [{ Connection, Collection, _AppIdOld }]) ->
	{reply, ok, [{ Connection, Collection, AppId }] };

handle_call({ count, Doc }, _From, [{ Connection, Collection, AppId }]) ->
	{reply, mongo:count(Connection, Collection, bson:append({ app_id, AppId }, Doc)) , [{ Connection, Collection, AppId }] };

handle_call({ insert, Doc }, _From, [{ Connection, Collection, AppId }]) ->
	{reply, mongo:insert(Connection, Collection, bson:append({ app_id, AppId }, Doc)) , [{ Connection, Collection, AppId }] };

handle_call({get_pids, Name}, _From, [{ Connection, Collection, AppId }]) ->
	Pids = case mongo:find_one(Connection, Collection, { name, Name }, { pid, 1, '_id', 0 }) of
		       {{pid, L}} ->
					L;
				{} ->
					[]
			end,
	{reply, {pids, Pids} , [{ Connection, Collection, AppId }] };

handle_call(get_pids, _From, [{ Connection, Collection, AppId }]) ->
	Cursor = mongo:find(Connection, Collection, { app_id, AppId, status, online }, { pid, 1, '_id', 0 }),
	Result = getCursorList(pid, Cursor),
	{reply, {pids, Result} , [{ Connection, Collection, AppId }] };

handle_call({ get_group_pids, Data}, _From, [{ Connection, Collection, AppId }]) ->
	p("Data : ", Data),
	Cursor = mongo:find(Connection, Collection, { app_id, AppId, status, online, data, Data }, { pid, 1, '_id', 0 }),
	Result = getCursorList(pid, Cursor),
	{reply, {pids, Result} , [{ Connection, Collection, AppId }] };

handle_call({update, Cond, Docs}, _From, [{ Connection, Collection, AppId }]) ->
%% 	{true, {result, Res}} = mongo:command(Connection, {aggregate, Collection, pipeline, [{'$match', {'_id', Id}}, {'$match', {'app_id', AppId }}, {'$sort', {name, 1}}]}),
%% 	ct:log("Got ~p", [Res]),

	{reply, mongo:update(Connection, Collection, Cond, Docs) , [{ Connection, Collection, AppId }] };

handle_call({get_school_users_pids, { From, UserType } }, _From, [{ Connection, Collection, AppId }]) ->
	case mongo:find_one(Connection, Collection, { name, From, data, { user_type, <<"1">> } }, { data, 1, '_id', 0 }) of
		{} ->
			{reply, { error, school_not_registered_for_the_principal } , [{ Connection, Collection, AppId }] };
		{{data, L}} ->
				case proplists:get_value(school, L, false) of
					false ->
						{reply, { error, school_not_registered_for_the_principal } , [{ Connection, Collection, AppId }] };
					SchoolId ->
						case mongo:find(Connection, Collection, { data, { school, SchoolId }, data, format_user_type(UserType) }, { status, 1, name, 1, pid, 1, '_id', 0 }) of
						Cursor ->
							Result = mc_cursor:rest(Cursor),
							{reply, { school_users_pids, Result } , [{ Connection, Collection, AppId }] }
						end
				end
       end;

handle_call(_Request, _From, State) ->
	{reply, ok, State}.

handle_cast({remove_pid, Pid}, [{ Connection, Collection, AppId }]) ->
	Cond = { app_id, AppId, pid, Pid },
	case mongo:find_one(Connection, Collection, Cond, { name, 1, pid, 1, '_id', 0 }) of
		{{name, Name, pid, Pids}} ->
			UpdatedPids = lists:delete(Pid, Pids),
			Docs = {'$set', {
				pid, UpdatedPids,
				status, getStatus(UpdatedPids)
			}},
			mongo:update(Connection, Collection, Cond, Docs),
			case getStatus(UpdatedPids) of
				offline -> irc ! { broadcast, #{ event => offline, data => #{ name => Name } } };
				online -> ok
			end;
		{} ->
%% 			io:format("Pid is not registered."),
			ok
	end,
	{noreply, [{ Connection, Collection, AppId }]};

handle_cast(_Msg, State) ->
	{noreply, State}.

handle_info(Info, State) ->
	p("Mongo Info Got : ", Info),
	{noreply, State}.

terminate(_Reason, _State) ->
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

% Internal Functions
%% p(H) ->
%% 	io:format("~p.~n",[H]).

p(H, T) ->
	io:format("~p : ~p.~n",[H, T]).

%% Internal Functions

%% @doc If the Pid is present the Status is online else status is offline.
-spec getStatus(_L :: list()) -> Status :: binary().
getStatus([]) -> offline;
getStatus(_L) -> online.

getCursorList(Col, Cursor) ->
	getCursorList(mc_cursor:next(Cursor), Col, Cursor, []).

getCursorList({}, _Col, Cursor,  Acc) ->
	mc_cursor:close(Cursor),
	Acc;

getCursorList({{Col, L}}, Col, Cursor, Acc) ->
	getCursorList(mc_cursor:next(Cursor), Col, Cursor, L ++ Acc).

format_user_type( { UserType, TypeVal }) ->
	{ binary_to_atom(UserType, latin1), TypeVal }.