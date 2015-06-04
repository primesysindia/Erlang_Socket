-module(event_decoder).
-author("Piyush Sable").

-behaviour(gen_server).

%% API
-export([start_link/0]).

%% gen_server callbacks
-export([init/1,
	handle_call/3,
	handle_cast/2,
	handle_info/2,
	terminate/2,
	code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link() ->
	{ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link() ->
	gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

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
init([]) ->
	%%io:format("At Event Decoder.~n"),
	{ok, #state{}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
	State :: #state{}) ->
	{reply, Reply :: term(), NewState :: #state{}} |
	{reply, Reply :: term(), NewState :: #state{}, timeout() | hibernate} |
	{noreply, NewState :: #state{}} |
	{noreply, NewState :: #state{}, timeout() | hibernate} |
	{stop, Reason :: term(), Reply :: term(), NewState :: #state{}} |
	{stop, Reason :: term(), NewState :: #state{}}).
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
%% Decode the Request Comming over the Socket.
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
handle_info({event_received, Pid, Msg}, _State) ->
	Msg_list = binary:split(Msg, <<"\n">>, [global]),
	[ fire_event(Pid, M) || M <- Msg_list, jsx:is_json(M) == true ],
	{noreply, _State};

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
handle_info(Info, State) ->
	io:format("event_decoder:received:~p~n",[Info]),
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

%% @doc
%% Decode and fire the supplied event with the Given Data.
-spec fire_event(Pid :: pid(), Msg :: map()) -> ok.
fire_event(Pid, Msg) ->
	case jsx:decode(Msg, [return_maps]) of
		badarg ->
			io:format("Bad JSON Argument to JSX Decoder.~n");
		Map ->
			case maps:find(<<"event">>, Map) of
				{ok, <<"join">> } ->
					case set_app_id(Map) of
						ok ->
							{ok, Name} = maps:find(<<"name">>, Map),
							Data = get_data(Map),
							irc ! { join, Pid, Name, Data },
							Type = get_type(Map),
							case maps:find(<<"timestamp">>, Map) of
								{ok, Timestamp} ->
									irc ! { get_prev_msgs, Pid, { name, Name, timestamp, Timestamp, type, Type } };
								error ->
									irc ! { get_prev_msgs, Pid, { name, Name, timestamp, <<"00000">>, type, Type } }
							end;
						error ->
							irc ! {error, Pid, <<"app_id not found in request.">>}
					end;
				{ok, <<"ping">> } ->
					{ok, Who} = maps:find(<<"who">>, Map),
					% irc ! {ping, Pid, Who};
					Who;
				{ok, <<"msg">> } ->
					case set_app_id(Map) of
						ok ->
							{ok, From } = maps:find(<<"from">>, Map),
							{ok, To } = maps:find(<<"to">>, Map),
							{ok, Message } = maps:find(<<"msg">>, Map),
							{ok, Type } = maps:find(<<"type">>, Map),
							{ok, RefId } = maps:find(<<"ref_id">>, Map),
							irc ! { send_msg, Pid, { From, To, Message, Type, RefId }};
						error ->
							irc ! {error, Pid, <<"app_id not found in request.">>}
					end;
				{ok, <<"bulk_msg">> } ->
					case set_app_id(Map) of
						ok ->
							{ok, From } = maps:find(<<"from">>, Map),
							Data = get_data(Map),
							{ok, Message } = maps:find(<<"msg">>, Map),
							{ok, Type } = maps:find(<<"type">>, Map),
							irc ! { bulk_msg, Pid, { From, first(Data), Message, Type } };
						error ->
							irc ! {error, Pid, <<"app_id not found in request.">>}
					end;
				{ok, <<"school_msg">> } ->
					case set_app_id(Map) of
						ok ->
							{ok, From } = maps:find(<<"from">>, Map),
							{ok, To } = maps:find(<<"to">>, Map),
							{ok, StudentId } = maps:find(<<"student_id">>, Map),
							{ok, Message } = maps:find(<<"msg">>, Map),
							{ok, Type } = maps:find(<<"type">>, Map),
							{ok, RefId } = maps:find(<<"ref_id">>, Map),
							irc ! { school_msg, Pid, { From, To, StudentId, Message, Type, RefId } };
						error ->
							irc ! {error, Pid, <<"app_id not found in request.">>}
					end;
				{ok, <<"start_track">>} ->
					{ok, StudentId } = maps:find(<<"student_id">>, Map),
					irc ! { start_track, Pid, { student_id, StudentId } };
				{ok, <<"stop_track">>} ->
					irc ! { stop_track, Pid };
				{ok, <<"get_tracking_history">>} ->
					{ok, StudentId } = maps:find(<<"student_id">>, Map),
					{ok, Timestamp } = maps:find(<<"timestamp">>, Map),
					irc ! { get_tracking_history, Pid, { student_id, StudentId, timestamp, Timestamp} };
				{ok, <<"add_group">>} ->
					{ok, GrpName } = maps:find(<<"group_name">>, Map),
					{ok, AdminId } = maps:find(<<"admin_id">>, Map),
					irc ! { add_group, Pid, GrpName, AdminId };
				{ok, <<"add_group_member">>} ->
					{ok, GrpId } = maps:find(<<"group_id">>, Map),
					{ok, UserId } = maps:find(<<"user_id">>, Map),
					irc ! { add_group_member, Pid, GrpId, UserId };
				{ok, <<"remove_group_member">>} ->
					{ok, GrpId } = maps:find(<<"group_id">>, Map),
					{ok, UserId } = maps:find(<<"user_id">>, Map),
					irc ! { remove_group_member, Pid, GrpId, UserId };
				{ok, <<"get_groups_listing">>} ->
					{ok, UserId } = maps:find(<<"user_id">>, Map),
					irc ! { get_groups_listing, Pid, UserId };
				{ok, <<"get_group_members_listing">>} ->
					{ok, GrpId } = maps:find(<<"group_id">>, Map),
					irc ! { get_group_members_listing, Pid, GrpId };
				{ok, <<"group_msg">>} ->
					{ok, GrpId } = maps:find(<<"group_id">>, Map),
					{ok, UserId } = maps:find(<<"user_id">>, Map),
					{ok, Message } = maps:find(<<"msg">>, Map),
					{ok, RefId } = maps:find(<<"ref_id">>, Map),
					irc ! { group_msg, Pid, GrpId, UserId, Message, RefId };
				{ok, <<"add_friend">>} ->
					{ok, UserId } = maps:find(<<"user_id">>, Map),
					{ok, UserName } = maps:find(<<"user_name">>, Map),
					{ok, FriendId } = maps:find(<<"friend_id">>, Map),
					{ok, FriendName } = maps:find(<<"friend_name">>, Map),
					irc ! { add_friend, Pid, UserId, UserName, FriendId, FriendName };
				{ok, <<"list_friends">>} ->
					{ok, UserId } = maps:find(<<"user_id">>, Map),
					irc ! { list_friends, Pid, UserId };
				{ok, <<"update_friend_status">>} ->
					{ok, UserId } = maps:find(<<"user_id">>, Map),
					{ok, FriendId } = maps:find(<<"friend_id">>, Map),
					{ok, Status } = maps:find(<<"status">>, Map),
					irc ! { update_friend_status, Pid, UserId, FriendId, Status };
				error ->
					io:format("Event Not Found in : ~p.~n",[Map])
			end
	end.

%% @doc
%% Return the Type of the User.
-spec get_type(Map :: map()) -> binary().
get_type(Map) ->
	case maps:find(<<"data">>, Map) of
		{ok, Data} ->
			case maps:find(<<"user_type">>, Data) of
				{ok, Type} -> Type;
				error -> <<"3">>
			end;
		error ->
			<<"3">>
	end.

%% @doc
%% Set the App Id for the DB Operations.
-spec set_app_id(Map :: map()) -> ok | error.
set_app_id(Map) ->
	case maps:find(<<"app_id">>, Map) of
		{ok, AppId} ->
			mongo_users_ser:set_app_id(AppId);
		error ->
			io:format("App Id not found."),
			error
	end.

%% @doc
%% Return the List of additional data into the request.
-spec get_data(Map :: map()) -> list().
get_data(Map) ->
	case maps:find(<<"data">>, Map) of
		{ok, Data} ->
			io:format("Data : ~p.~n", [Data]),
			maps:to_list(Data);
		error ->
			[]
	end.

%% @doc
%% Return the First element of the list.
-spec first(list()) -> atom() | null.
first([]) -> null;
first([ H | _]) -> H.
