%%%-------------------------------------------------------------------
%%% @author Piyush Sable
%%% @copyright (C) 2015, <Primesys Technologies LLP >
%%% @doc
%%%     Module to handle the chat Groups.
%%% @end
%%% Created : 16. Apr 2015 1:19 PM
%%%-------------------------------------------------------------------
-module(mongo_group_ser).
-author("Piyush sable").

-behaviour(gen_server).

%% API
-export([start_link/0, add/1, addMember/1, removeMember/1, listGroups/1, getMembers/1, listGroupMembers/1]).

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
	gen_server:start_link({local, ?MODULE}, ?MODULE, [ localhost, 27017, <<"chat">>, <<"groups">>], []).

%%--------------------------------------------------------------------
%% @doc
%% Create New Group for the Chat.
%%
%% @end
%%--------------------------------------------------------------------
-spec add(tuple()) -> any().
add({ GrpName, AdminId }) ->
	gen_server:call(?MODULE, { add_group, GrpName, AdminId }).

%%--------------------------------------------------------------------
%% @doc
%% Add New Member to the Group.
%%
%% @end
%%--------------------------------------------------------------------
-spec addMember(tuple()) -> any().
addMember({ GrpId, UserId }) ->
	gen_server:call(?MODULE, { add_group_member, GrpId, UserId }).

%%--------------------------------------------------------------------
%% @doc
%% Remove New Member to the Group.
%%
%% @end
%%--------------------------------------------------------------------
-spec removeMember(tuple()) -> any().
removeMember({ GrpId, UserId }) ->
	gen_server:call(?MODULE, { remove_group_member, GrpId, UserId }).

%%--------------------------------------------------------------------
%% @doc
%% Return the list Groups belongs to the User.
%%
%% @end
%%--------------------------------------------------------------------
-spec listGroups(any()) -> any().
listGroups(UserId) ->
	gen_server:call(?MODULE, { get_groups_listing, UserId }).

%%--------------------------------------------------------------------
%% @doc
%% Return the list Members belongs to the Group.
%%
%% @end
%%--------------------------------------------------------------------
-spec listGroupMembers(any()) -> any().
listGroupMembers(GrpId) ->
	gen_server:call(?MODULE, { get_group_members_listing, GrpId }).

%%--------------------------------------------------------------------
%% @doc
%% Return the list of members in the Group.
%%
%% @end
%%--------------------------------------------------------------------
-spec getMembers(any()) -> any().
getMembers(GrpId) ->
	gen_server:call(?MODULE, { get_groups_members, GrpId }).

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
handle_call({ add_group, GrpName, AdminId }, _From, [{ Connection, Collection }]) ->
	GrpId = generate_grp_id(Connection, Collection),
	Doc = { grp_id, GrpId, grp_name, GrpName, admin_id, AdminId, members, [AdminId] },
	mongo:insert(Connection, Collection, Doc),
	{reply, { group_id, GrpId }, [{ Connection, Collection }]};

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling add friend.
%%
%% @end
%%--------------------------------------------------------------------
handle_call({ add_group_member, GrpId, UserId  }, _From, [{ Connection, Collection }]) ->
	case mongo:find_one(Connection, Collection, { grp_id, GrpId }, { members, 1, '_id', 0 }) of
		{{members, Members}} ->
			case mongo:count(Connection, Collection, { grp_id, GrpId, members, UserId }) of
				0 ->
					Command = {'$set', {
						members, [ UserId | Members ]
					}},
					{reply, mongo:update(Connection, Collection, { grp_id, GrpId }, Command), [{ Connection, Collection }]};
				_N ->
					{reply, { error, already_group_member }, [{ Connection, Collection }] }
			end;
		{} ->
			{reply, { error, group_not_found }, [{ Connection, Collection }] }
	end;

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling Remove Member from group.
%%
%% @end
%%--------------------------------------------------------------------
handle_call({ remove_group_member, GrpId, UserId  }, _From, [{ Connection, Collection }]) ->
	Cond = { grp_id, GrpId, members, UserId },
	case mongo:find_one(Connection, Collection, Cond, { members, 1, '_id', 0 }) of
		{{members, Members}} ->
			Command = {'$set', {
				members, lists:delete(UserId, Members)
			}},
			{reply, mongo:update(Connection, Collection, Cond, Command), [{ Connection, Collection }]};
		{} ->
			{reply, { error, member_or_group_not_found }, [{ Connection, Collection }] }
	end;

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Return list of Groups belongs to the User.
%%
%% @end
%%--------------------------------------------------------------------
handle_call({ get_groups_listing, UserId }, _From, [{ Connection, Collection }]) ->
	Cond = { members, UserId },
	case mongo:find(Connection, Collection, Cond, { grp_id, 1, grp_name, 1, admin_id, 1, '_id', 0 }) of
		Cursor ->
			Result = mc_cursor:rest(Cursor),
%% 			io:format("got Groups : ~p.~n",[Result]),
			case length(Result) of
				0 -> {reply, { error, groups_not_found }, [{ Connection, Collection }] };
				_N -> {reply, { groups, format_groups(Result) }, [{ Connection, Collection }] }
			end
	end;

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Return the Admin Id and the list of Members belongs to the Group.
%%
%% @end
%%--------------------------------------------------------------------
handle_call({ get_group_members_listing, GrpId }, _From, [{ Connection, Collection }]) ->
	io:format("got Group Id : ~p.~n",[GrpId]),
	Cond = { grp_id, GrpId },
	case mongo:find(Connection, Collection, Cond, { admin_id, 1, members, 1, '_id', 0 }) of
		Cursor ->
			Result = mc_cursor:rest(Cursor),
			io:format("got Group Membrs : ~p.~n",[Result]),
			case length(Result) of
				0 -> {reply, { error, group_members_not_found }, [{ Connection, Collection }] };
				_N -> {reply, { members, format_members(Result) }, [{ Connection, Collection }] }
			end
	end;

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Return list of Members belongs to the Group.
%%
%% @end
%%--------------------------------------------------------------------
handle_call({ get_groups_members, GrpId }, _From, [{ Connection, Collection }]) ->
	Cond = { grp_id, GrpId },
	case mongo:find_one(Connection, Collection, Cond, { members, 1, '_id', 0 }) of
		{{members, Members}} ->
%% 			io:format("Members : ~p.~n", [Members]),
			{reply, { members, Members }, [{ Connection, Collection }] };
		{} ->
			{reply, { members, [] }, [{ Connection, Collection }] }
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

%% @doc Generate Unique Group Ids.
generate_grp_id(Connection, Collection) ->
	{A1,A2,A3} = os:timestamp(),
	random:seed(A1, A2, A3),
	Id = random:uniform(999999999),
	case mongo:count(Connection, Collection, {grp_id, Id}) of
		0 -> integer_to_binary(Id);
		_N -> generate_grp_id(Connection, Collection)
	end.

%% @doc Format then Groups Listing.
format_groups(List) -> format_groups(List, []).

format_groups([], Acc) -> Acc;

format_groups([ H | T ], Acc) ->
	{ grp_id, GrpId, grp_name, GrpName, admin_id, AdminId } = H,
	format_groups(T, [ #{grp_id => GrpId, grp_name => GrpName, admin_id => AdminId } | Acc ]).

%% @doc Format then Groups Listing.
format_members(List) -> format_members(List, []).

format_members([], Acc) -> Acc;

format_members([ H | T ], Acc) ->
	{ admin_id, AdminId, members, Members } = H,
	MembersWithName = getMembersName(Members),
	format_members(T, [ #{ admin_id => AdminId, members => MembersWithName } | Acc ]).

getMembersName(L) ->
	getMembersName(L,[]).

getMembersName([], Acc) -> Acc;
getMembersName([ H | T ], Acc) ->
	getMembersName(T, [ mongo_friends_ser:getFriendsNameById(H) | Acc ]).