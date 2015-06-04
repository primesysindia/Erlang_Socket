-module(mongo_messages_ser).
-behaviour(gen_server).

%% API
-export([start_link/0, insert/1, get_chat_messages/1, get_group_messages/1 ]).

%% gen_server callbacks
-export([init/1,
	handle_call/3,
	handle_cast/2,
	handle_info/2,
	terminate/2,
	code_change/3]).

-define(SERVER, ?MODULE).
-define(MAXMSGS, 10).

-record(state, {}).

%%%===================================================================
%%% API
%%%===================================================================

%% @doc insert the document into the collection.
-spec insert(Docs :: tuple()) -> tuple().
insert(Docs) ->
	gen_server:call(?MODULE, {insert, Docs}).

%% @doc Return the list of last 10 messages.
-spec get_chat_messages(tuple()) -> any().
get_chat_messages({ name, Name }) ->
	get_chat_messages({ name, Name, timestamp, <<"00000">> });

%% @doc Return the list of last 10 messages.
get_chat_messages(Cmd) ->
	gen_server:call(?MODULE, {get_chat_messages, Cmd}).

%% @doc Return the list of last 10 messages.
-spec get_group_messages(tuple()) -> any().
get_group_messages({ name, Name }) ->
	get_group_messages({ name, Name, timestamp, <<"00000">> });

%% @doc Return the list of last 10 messages.
get_group_messages(Cmd) ->
	gen_server:call(?MODULE, {get_group_messages, Cmd}).

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link() ->
	{ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [ localhost, 27017, <<"chat">>, <<"messages">>, null], []).

%%%===================================================================
%%% External API's
%%%===================================================================



%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
-spec(init(Args :: term()) ->
	{ok, State :: #state{}} | {ok, State :: #state{}, timeout() | hibernate} |
	{stop, Reason :: term()} | ignore).
init([ Host, Port, Database, Collection, AppId ]) ->
	case mongo:connect(Host, Port, Database) of
		{ok, Connection} ->
%% 			io:format("Connected to ~p DB Collection : ~p.~n",[Collection, Connection]),
			{ok, [{ Connection, Collection, AppId }]};
		{error, Reason} ->
			io:format("Error Connecting to ~p DB Collection : ~p.~n",[Collection, Reason]),
			{stop, normal, Reason}
	end.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Store messages into the DB.
%%
%% @end
%%--------------------------------------------------------------------
handle_call({ insert, Doc }, _From, [{ Connection, Collection, AppId }]) ->
	{reply, mongo:insert(Connection, Collection, Doc) , [{ Connection, Collection, AppId }] };

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Return the list of Chat messages history from the DB.
%%
%% @end
%%--------------------------------------------------------------------
handle_call({get_chat_messages, { name, Name, timestamp, Timestamp, type, Type }}, _From, [{ Connection, Collection, AppId }]) ->
	Cursor = case Timestamp of
		         <<"00000">> ->
%% 					 mongo:find(Connection, Collection, { '$or', [ { from, Name }, { to, Name } ], '$orderby', { timestamp, 1 } }, { '_id', 0 });
			         case Type of
						 <<"1">> ->
							 %%io:format("here"),
							mongo:find(Connection, Collection, { '$or', [ { from, Name }, { to, Name } ], type, <<"s">> }, { '_id', 0 });
				         _X ->
							mongo:find(Connection, Collection, { '$or', [ { from, Name }, { to, Name } ], type, { '$ne', <<"g">> } }, { '_id', 0 })
			         end;
				 T ->
%% 					 mongo:find(Connection, Collection, { '$or', [ { from, Name }, { to, Name } ], timestamp, { '$gt', T }, '$orderby', { timestamp, 1 } }, { '_id', 0 })
					 N = timestamp_bool_to_num(T),
%% 					 io:format("Timestamp : ~p.~n", [N]),
					 case Type of
						 <<"1">> ->
							 mongo:find(Connection, Collection, { '$or', [ { from, Name }, { to, Name } ], timestamp, { '$gt', N }, type, <<"s">> }, { '_id', 0 });
						 _X ->
							 mongo:find(Connection, Collection, { '$or', [ { from, Name }, { to, Name } ], timestamp, { '$gt', N }, type, { '$ne', <<"g">> } }, { '_id', 0 })
					 end
	         end,
%% 	Result = mc_cursor:take( Cursor, ?MAXMSGS ),
	Result = mc_cursor:rest(Cursor),
	{reply, {msgs, convert_msg_to_format(Result)} , [{ Connection, Collection, AppId }] };

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Return the list of Group messages history from the DB.
%%
%% @end
%%--------------------------------------------------------------------
handle_call({get_group_messages, { name, Name, timestamp, Timestamp, type, _Type }}, _From, [{ Connection, Collection, AppId }]) ->

	case mongo_group_ser:listGroups(Name) of
		{ error, groups_not_found } -> {reply, { error, groups_not_found } , [{ Connection, Collection, AppId }] };
		{ groups, Groups } ->
			OrCond = generate_or_cond(Groups),
%% 			io:format("Got Cond : ~p.~n", [OrCond]),
			Cursor = case Timestamp of
				         <<"00000">> ->
							         mongo:find(Connection, Collection, { '$or', OrCond, type, <<"g">> }, { '_id', 0 });
				         T ->
					         N = timestamp_bool_to_num(T),
							         mongo:find(Connection, Collection, { '$or', OrCond, timestamp, { '$gt', N }, type, <<"g">> }, { '_id', 0 })
			         end,
			Result = mc_cursor:rest(Cursor),
%% 			io:format("Msgs : ~p.~n", [Result]),
			{reply, {msgs, convert_msg_to_format(Result)} , [{ Connection, Collection, AppId }] }
	end;

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
%% -spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
%% 	State :: #state{}) ->
%% 	{reply, Reply :: term(), NewState :: #state{}} |
%% 	{reply, Reply :: term(), NewState :: #state{}, timeout() | hibernate} |
%% 	{noreply, NewState :: #state{}} |
%% 	{noreply, NewState :: #state{}, timeout() | hibernate} |
%% 	{stop, Reason :: term(), Reply :: term(), NewState :: #state{}} |
%% 	{stop, Reason :: term(), NewState :: #state{}}).
handle_call(_Request, _From, State) ->
	{reply, ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_cast(Request :: term(), State :: #state{}) ->
	{noreply, NewState :: #state{}} |
	{noreply, NewState :: #state{}, timeout() | hibernate} |
	{stop, Reason :: term(), NewState :: #state{}}).
handle_cast(_Request, State) ->
	{noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
-spec(handle_info(Info :: timeout() | term(), State :: #state{}) ->
	{noreply, NewState :: #state{}} |
	{noreply, NewState :: #state{}, timeout() | hibernate} |
	{stop, Reason :: term(), NewState :: #state{}}).
handle_info(_Info, State) ->
	{noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
-spec(terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()),
	State :: #state{}) -> term()).
terminate(_Reason, _State) ->
	ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
-spec(code_change(OldVsn :: term() | {down, term()}, State :: #state{},
	Extra :: term()) ->
	{ok, NewState :: #state{}} | {error, Reason :: term()}).
code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

timestamp_bool_to_num(T) ->
	case is_binary(T) of
		true -> binary_to_integer(T);
		false -> T
	end.

convert_msg_to_format(Result) ->
	convert_msg_to_format(Result, []).

convert_msg_to_format([], Acc) -> Acc;

convert_msg_to_format([ { timestamp, Timestamp, from, From, to, To, msg, Message, type, Type } | T ], Acc) ->
	convert_msg_to_format(T, [ #{ event => msg_received, data => #{ from => From, to=>To, msg => Message, timestamp => Timestamp, type => Type } } | Acc ]);

convert_msg_to_format([ { timestamp, Timestamp, from, From, to, To, msg, Message, type, Type, student_id, StudentId } | T ], Acc) ->
	convert_msg_to_format(T, [ #{ event => msg_received, data => #{ from => From, to=>To, msg => Message, timestamp => Timestamp, type => Type, student_id => StudentId } } | Acc ]).

generate_or_cond(Groups) ->
	generate_or_cond(Groups,[]).

generate_or_cond( [], Acc) -> Acc;

generate_or_cond([ #{ grp_id := GrpId } | T ], Acc) ->
	generate_or_cond(T, [ { to, GrpId } | Acc ]).