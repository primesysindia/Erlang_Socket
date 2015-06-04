%%%-------------------------------------------------------------------
%%% @author Piyush Sable
%%% @copyright (C) 2015, <Primesys Technologies LLP >
%%% @doc
%%%     Module to handle the Users Friends Mapping.
%%% @end
%%% Created : 16. Apr 2015 1:19 PM
%%%-------------------------------------------------------------------
-module(mongo_friends_ser).
-author("Piyush sable").

-behaviour(gen_server).

%% API
-export([start_link/0, addFriend/1, listFriends/1, updateFriendStatus/1, getFriendsNameById/1]).

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
	gen_server:start_link({local, ?MODULE}, ?MODULE, [ localhost, 27017, <<"chat">>, <<"friends">>], []).

%%--------------------------------------------------------------------
%% @doc
%% Map Friend to the User.
%%
%% @end
%%--------------------------------------------------------------------
-spec addFriend(tuple()) -> any().
addFriend(Msg) ->
	gen_server:call(?MODULE, { add_friend, Msg }).

%%--------------------------------------------------------------------
%% @doc
%% Map Friend to the User.
%%
%% @end
%%--------------------------------------------------------------------
-spec listFriends(tuple()) -> any().
listFriends(UserId) ->
	gen_server:call(?MODULE, { list_friends, UserId }).

%%--------------------------------------------------------------------
%% @doc
%% Update Friends Status to A (Accepted) / R (Rejected) / D (Deleted).
%%
%% @end
%%--------------------------------------------------------------------
-spec updateFriendStatus(tuple()) -> any().
updateFriendStatus(Msg) ->
	gen_server:call(?MODULE, { update_friend_status, Msg }).

%%--------------------------------------------------------------------
%% @doc
%% UReturn User Name in Friends List by Id.
%%
%% @end
%%--------------------------------------------------------------------
-spec getFriendsNameById(tuple()) -> any().
getFriendsNameById(UserId) ->
	gen_server:call(?MODULE, { get_friends_name_by_id, UserId }).

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
init([ Host, Port, Database, Collection ]) ->
	case mongo:connect(Host, Port, Database) of
		{ok, Connection} ->
%% 			io:format("Connected to ~p DB Collection : ~p.~n",[Collection, Connection]),
			{ok, [{ Connection, Collection }]};
		{error, Reason} ->
			io:format("Error Connecting to ~p DB Collection : ~p.~n",[Collection, Reason]),
			{stop, normal, Reason}
	end.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling add friend.
%%
%% @end
%%--------------------------------------------------------------------
handle_call({ add_friend, { UserId, UserName, FriendId, FriendName } }, _From, [{ Connection, Collection }]) ->
	case mongo:count(Connection, Collection, { '$or', [ { user_id, UserId, friend_id, FriendId }, { user_id, FriendId, friend_id, UserId } ] } ) of
		0 ->
			Doc = { user_id, UserId, user_name, UserName, friend_id, FriendId, friend_name, FriendName, status, <<"N">>},
			mongo:insert(Connection, Collection, Doc),
			{reply, { friends, friend_added_successfully }, [{ Connection, Collection }] };
		_N ->
			{reply, { error, already_a_friend }, [{ Connection, Collection }] }
	end;

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Return list of Groups belongs to the User.
%%
%% @end
%%--------------------------------------------------------------------
handle_call({ list_friends, UserId }, _From, [{ Connection, Collection }]) ->
%% 	Cond = { '$and', [ { '$or', [ { user_id, UserId }, { friend_id, UserId } ] }, { '$or', [ { status, <<"N">> }, { status, <<"A">> } ] } ] },
	Cond = { '$and', [ { '$or', [ { user_id, UserId }, { friend_id, UserId } ] }, { '$or', [ { status, <<"N">> }, { status, <<"A">> } ] } ] },
	case mongo:find(Connection, Collection, Cond, { '_id', 0 }) of
		Cursor ->
			Result = mc_cursor:rest(Cursor),
			case length(Result) of
				0 -> {reply, { error, friends_not_found }, [{ Connection, Collection }] };
				_N -> {reply, { friends, format_friends(UserId, Result) }, [{ Connection, Collection }] }
			end
	end;

%% { $and : [ { $or : [ { user_id : 505167 }, { friend_id : 505167 } ] }, { $or : [ { status : <<"N">> }, { status : <<"A">> } ] } ] }

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Update Friends Status to A (Accepted) / R (Rejected) / D (Deleted).
%%
%% @end
%%--------------------------------------------------------------------
handle_call({ update_friend_status, { UserId, FriendId, Status } }, _From, [{ Connection, Collection }]) ->
	Cond = { user_id, UserId, friend_id, FriendId },
	case mongo:count(Connection, Collection, Cond, { '_id', 0 }) of
		0 ->
			{reply, { error, friend_not_found }, [{ Connection, Collection }] };
		_N ->
			Command = {'$set', {
				status, Status
			}},
			{reply, mongo:update(Connection, Collection, Cond, Command), [{ Connection, Collection }]}
	end;

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Return User Name in Friends List by Id.
%%
%% @end
%%--------------------------------------------------------------------
handle_call({ get_friends_name_by_id, UserId }, _From, [{ Connection, Collection }]) ->
	Cond = { '$or', [ { user_id, UserId }, { friend_id, UserId } ] },
	case mongo:find_one(Connection, Collection, Cond, { '_id', 0, status, 0 }) of
		{{ user_id, UserId, user_name, UserName, friend_id, _FriendId, friend_name, _FriendName }} ->
			{reply, #{ user_id => UserId, user_name => UserName }, [{ Connection, Collection }] };
		{{ user_id, _FriendId, user_name, _FriendName, friend_id, UserId, friend_name, UserName }} ->
			{reply, #{ user_id => UserId, user_name => UserName }, [{ Connection, Collection }] };
		{} ->
			{reply, #{ user_id => UserId }, [{ Connection, Collection }] }
	end;

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
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

%% @doc Format then Groups Listing.
format_friends(UserId, List) -> format_friends(UserId, List, []).

format_friends(_UserId, [], Acc) -> Acc;

format_friends(UserId, [ { user_id, UserId, user_name, _UserName, friend_id, FriendId, friend_name, FriendName, status, Status} | T ], Acc) ->
	format_friends(UserId, T, [ #{ friend_id => FriendId, friend_name => FriendName, status => Status, sent => 1 } | Acc ]);

format_friends(FriendId, [ { user_id, UserId, user_name, UserName, friend_id, FriendId, friend_name, _FriendName, status, Status} | T ], Acc) ->
	format_friends  (FriendId, T, [ #{ friend_id => UserId, friend_name => UserName, status => Status, sent => 0 } | Acc ]).

%%%===================================================================
%%% For Reference functions
%%%===================================================================

%% %%--------------------------------------------------------------------
%% %% @private
%% %% @doc
%% %% Calling External API's, Curl.
%% %%
%% %% @end
%% %%--------------------------------------------------------------------
%% handle_call({ add_friend, { UserId, UserName, FriendId, FriendName } }, _From, [{ Connection, Collection }]) ->
%% 	io:format("Here at : ~p.~n",[{UserId, FriendEntity}]),
%% 	case httpc:request(post,{ "http://www.mykiddytracker.in/API//ParentAPI.asmx/GetFriendInfo", [], "application/x-www-form-urlencoded", "friend_entity="++binary_to_list(FriendEntity)++"&user_id="++binary_to_list(UserId) }, [], []) of
%% 		{ok, {{_Version, 200, _ReasonPhrase}, _Headers, Body}} ->
%% 			io:format("Server Org Reply : ~p.~n", [Body]),
%% 			Res = jsx:decode(list_to_binary(Body), [return_maps]),
%% 			io:format("Server Reply : ~p.~n", [Res]),
%%
%% 			case maps:find(<<"error">>, Res) of
%% 				{ok, <<"true">>} ->
%% 					{reply, { error, maps:find(<<"msg">>, Res) }, [{ Connection, Collection }] };
%% 				error ->
%% 					{ok, UserName } = maps:find(<<"user_name">>, Res),
%% 					{ok, FriendId } = maps:find(<<"friend_id">>, Res),
%% 					{ok, FriendName } = maps:find(<<"friend_name">>, Res),
%% 					UserIdInt = binary_to_integer(UserId),
%% 					case mongo:count(Connection, Collection, { '$or', [ { user_id, UserIdInt, friend_id, FriendId }, { user_id, FriendId, friend_id, UserIdInt } ] } ) of
%% 						0 ->
%% 							Doc = { user_id, UserIdInt, user_name, UserName, friend_id, FriendId, friend_name, FriendName, status, <<"N">>},
%% 							mongo:insert(Connection, Collection, Doc),
%% 							{reply, { friends, UserIdInt, FriendId, FriendName }, [{ Connection, Collection }] };
%% 						_N ->
%% 							{reply, { error, already_a_friend }, [{ Connection, Collection }] }
%% 					end
%% 			end;
%% 		{ok, {{_Version, 404, _ReasonPhrase}, _Headers, _Body}} ->
%% 			{reply, { error, user_not_found }, [{ Connection, Collection }] };
%% 		{ok, {{_Version, 500, _ReasonPhrase}, _Headers, _Body}} ->
%% 			{reply, { error, server_error_while_finding_user }, [{ Connection, Collection }] };
%% 		Res ->
%% 			io:format("Unidentified Server Responce : ~p.~n", [Res]),
%% 			{reply, { error, server_error_while_finding_user }, [{ Connection, Collection }] }
%% 	end;