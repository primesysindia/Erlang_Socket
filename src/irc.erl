-module(irc).
-author("Piyush Sable").

-behaviour(gen_server).

%% API
-export([start_link/0, broadcast/1, broadcast/2, get_date_time/0 ]).

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
%% 	io:format("Started IRC Server.~n"),
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
handle_info({ join, Pid, Name, Data }, State) ->
	case mongo_users_ser:count({ name, Name }) of
		0 ->
			Doc = { name, Name, pid, [term_to_binary(Pid)], status, online, data, Data },
			mongo_users_ser:insert(Doc);
		_N ->
			%%io:format("Cnt : ~p.~n", [N]),
			{pids , L} = mongo_users_ser:getPids(Name),
			Command = {'$set', {
				pid, [ term_to_binary(Pid) | L ],
				status, online,
				data, Data
			}},
			mongo_users_ser:update({ name, Name }, Command)
	end,
	irc ! { broadcast, #{ event => online, data => #{ name => Name } } },
	msg_to({ name, Name }, #{ event => reg_success, data => #{} } ),
	{noreply, State};

%% irc ! { get_prev_msgs, self(), { name, <<"505257">>, timestamp, <<"00000">>, type, <<"a">> } }.
handle_info({ get_prev_msgs, Pid, Data }, State) ->
	{msgs, L} = mongo_messages_ser:get_chat_messages(Data),
	SendMsg = fun() -> [ Pid ! {irc, Msgs} || Msgs <- L ] end,
	spawn(SendMsg),

%% 	io:format("Got at : ~p.~n",[mongo_messages_ser:get_group_messages(Data)]),

	case mongo_messages_ser:get_group_messages(Data) of
		{ msgs, Grp_list } ->
			SendGrpMsg = fun() -> [ Pid ! {irc, Msgs} || Msgs <- Grp_list ] end,
			spawn(SendGrpMsg);
		{ error, groups_not_found } -> ok
	end,
	{noreply, State};

%% { msgs, L } = {msgs,[#{data => #{from => <<"505167">>, msg => <<"hiiii to alll ">>, timestamp => 1430737499, to => <<"13294161">>, type => <<"g">>}, event => msg_received}]}.

%% @doc Return Current Location and start the Tracking for the student.
handle_info({ start_track, Pid, { student_id, StudentId } }, State) ->
	%% Send the Tracker Current Location.
	case mongo_location_ser:get_latest_gps_location(StudentId) of
		{ok, {location, {lat, Lat, lon, Lan}, speed, Speed, timestamp, Timestamp }} ->
			Pid ! {irc, #{ event => current_location, data=> #{ lat => Lat, lan => Lan, speed => Speed, timestamp => Timestamp } }};
		{ error, Error } ->
			io:format(Error),
			irc ! { error, Pid, Error }
	end,

	%% Start Real Time tracking of the device.
	mongo_devices_ser:addDeviceTrackPid({ track_pid, Pid, student_id, StudentId }),

	{noreply, State};
%% irc ! { get_tracking_history, self(), { student_id, 5164, timestamp, 1429785234} }.
%% @doc Return Current Location and start the Tracking for the student.
handle_info({ get_tracking_history, Pid, { student_id, StudentId, timestamp, Timestamp} }, State) ->
	%% Send the history From the Given Timestamp.
	mongo_location_ser:get_gps_locations({ Pid, StudentId, Timestamp }),
	{noreply, State};

%% @doc Return Current Location and start the Tracking for the student.
handle_info({ stop_track, Pid }, State) ->
	mongo_devices_ser:removeDeviceTrackPid({ track_pid, term_to_binary(Pid) }),
	{noreply, State};

%% @doc Handles when the user left the logout from the System.
handle_info({ leave, Pid }, State) ->
	mongo_users_ser:removePid(term_to_binary(Pid)),
	mongo_devices_ser:removeDeviceTrackPid({ track_pid, term_to_binary(Pid) }),
	{noreply, State};

%% @doc Add group for the Chat.
handle_info({ add_group, Pid, GrpName, AdminId }, State) ->
	case mongo_group_ser:add({ GrpName, AdminId }) of
		{ group_id, GrpId } -> Pid ! {irc, #{ event => group_created, data=> #{ group_id => GrpId } }}
	end,
	{noreply, State};

%% @doc Add member to the Chat Group.
handle_info({ add_group_member, Pid, GrpId, UserId  }, State) ->
	case mongo_group_ser:addMember({  GrpId, UserId }) of
		ok -> Pid ! {irc, #{ event => group_member_added }};
		{ error, Error } -> irc ! { error, Pid, Error }
	end,
	{noreply, State};

%% @doc Remove member from the Chat Group.
handle_info({ remove_group_member, Pid, GrpId, UserId  }, State) ->
	case mongo_group_ser:removeMember({  GrpId, UserId }) of
		ok -> Pid ! {irc, #{ event => group_member_removed }};
		{ error, Error } -> irc ! { error, Pid, Error }
	end,
	{noreply, State};

%% @doc List the groups belongs to the User.
handle_info({ get_groups_listing, Pid, UserId  }, State) ->
	case mongo_group_ser:listGroups(UserId) of
		{ groups, List } -> Pid ! {irc, #{ event => groups_listing, data => #{ groups => List } }};
		{ error, Error } -> irc ! { error, Pid, Error }
	end,
	{noreply, State};

%% irc ! { get_group_members_listing, self(), <<"260449110">> }.
%% @doc List the members belongs to the group.
handle_info({ get_group_members_listing, Pid, GrpId }, State) ->
	case mongo_group_ser:listGroupMembers(GrpId) of
		{ members, List } -> Pid ! {irc, #{ event => group_members_listing, data => #{ members => List } }};
		{ error, Error } -> irc ! { error, Pid, Error }
	end,
	{noreply, State};

%% irc ! { group_msg, self(), <<"13294161">>, <<"505167">>, <<"Msg Id Testing..">> }.
%% @doc Handle message sent to the Group.
handle_info({ group_msg, Pid, GrpId, UserId, Msg, RefId }, State) ->
	Timestamp = get_date_time(),
	{ members, List } =	mongo_group_ser:getMembers(GrpId),
	[ msg_to( { name, Name }, { pid, Pid }, #{ event => msg_received, data => #{ from => UserId, to => GrpId, msg => Msg, timestamp => Timestamp, type => <<"g">> }} ) || Name <- List ],
	irc ! { store_msg, { timestamp, Timestamp, from, UserId, to, GrpId, msg, Msg, type, <<"g">> } },
	irc ! { msg_ack, Pid, #{ ref_id => RefId,  timestamp => Timestamp } },
	{noreply, State};

%% irc ! { add_friend, self(), <<"505167">>, <<"Piyush">>, <<"505268">>, <<"Amit">>  }.
%% @doc Find Friend with the Given Entity and Add Found Friend to the Current Users Friends Mappin.
handle_info({ add_friend, Pid, UserId, UserName, FriendId, FriendName }, State) ->
	case mongo_friends_ser:addFriend({ UserId, UserName, FriendId, FriendName }) of
		{ friends, friend_added_successfully } -> Pid ! {irc, #{ event => friend_added_successfully } };
		{ error, Error } -> irc ! { error, Pid, Error }
	end,
	{noreply, State};

%% @doc Return the list of friends associated with the user.
handle_info({ list_friends, Pid, UserId }, State) ->
	case mongo_friends_ser:listFriends(UserId) of
		{ error, Error } -> irc ! { error, Pid, Error };
		{ friends, L } -> Pid ! {irc, #{ event => friend_list , data => L } }
	end,
	{noreply, State};

%% @doc Update Friends Status to A (Accepted) / R (Rejected) / D (Deleted).
handle_info({ update_friend_status, Pid, UserId, FriendId, Status }, State) ->
	case mongo_friends_ser:updateFriendStatus({ UserId, FriendId, Status }) of
		ok -> Pid ! {irc, #{ event => friend_status_updated } };
		{ error, Error } -> irc ! { error, Pid, Error }
	end,
	{noreply, State};

handle_info({ msg_ack, Pid, Data }, State) ->
	Pid ! {irc, #{event => msg_ack, data => Data }},
	{noreply, State};

handle_info({ error, Pid, Error }, State) ->
	Pid ! {irc, #{event => error, data => #{ error_msg => Error } }},
	{noreply, State};

handle_info({ broadcast, Msg }, State) ->
	spawn(?MODULE, broadcast, [ Msg ]),
	{noreply, State};

handle_info({ broadcast, Data, Msg }, State) ->
	spawn(?MODULE, broadcast, [ Data, Msg ]),
	{noreply, State};

handle_info({ store_msg, Msg }, State) ->
	mongo_messages_ser:insert(Msg),
	{noreply, State};

%% irc ! {send_msg, self(), { <<"1234">>, <<"567">>, <<"Ack Testing">>, <<"s">>, 54321 }}.
handle_info({send_msg, Pid, { From, To, Message, Type, RefId }}, State) ->
	Timestamp = get_date_time(),
	case Type of
		<<"b">> ->
			io:format("No Ack Msg @ : ~p.~n",[{ From, To, Message, Type, RefId, Timestamp }]),
			msg_to( { name, To }, { pid, Pid }, #{ event => msg_received, data => #{ from => From, to => To, msg => Message, timestamp => Timestamp, type => <<"s">> } } );
		_T ->
			io:format("Ack Msg @ : ~p.~n",[{ From, To, Message, Type, RefId, Timestamp }]),
			msg_to({ msg_to_users_list, [ To, From ] }, { pid, Pid }, #{ event => msg_received, data => #{ from => From, to => To, msg => Message, timestamp => Timestamp, type => <<"s">> } } ),
			irc ! { msg_ack, Pid, #{ ref_id => RefId,  timestamp => Timestamp } }
	end,
	irc ! { store_msg, { timestamp, Timestamp, from, From, to, To, msg, Message, type, Type } },
	{noreply, State};

%% irc ! { bulk_msg, self(), { <<"100006">>, { <<"user_type">>, <<"3">>}, <<"Bulk Msg Testing...">>, <<"b">> } }.
handle_info({ bulk_msg, Pid, { From, UserType, Msg, Type } }, State) ->
	Timestamp = get_date_time(),
	case mongo_users_ser:getSchoolUsersPids( { From, UserType } ) of
		{ error, Error } -> irc ! { error, Pid, Error };
		{ school_users_pids, Result } ->
				[ send_msg_to( Pids, #{ event => msg_received, data => #{ from => From, to => Name, msg => Msg, timestamp => Timestamp, type => Type }} ) || { name, Name, pid, Pids, status, Status } <- Result, Status == online ],

				[ irc ! { store_msg, { timestamp, Timestamp, from, From, to, Name, msg, Msg, type, Type } } || { name, Name, pid, _Pids, status, _Status } <- Result ]

	end,
	{noreply, State};

%% irc ! { school_msg, self(), { <<"505165">>, <<"505167">>, <<"5252">>, <<"Message from student">>, <<"s">>, 12345 } }.
handle_info({ school_msg, Pid, { From, To, StudentId, Message, Type, RefId } }, State) ->
	Timestamp = get_date_time(),

	io:format("Ack Msg @ : ~p.~n",[{ From, To, Message, Type, RefId, Timestamp }]),
	msg_to({ msg_to_users_list, [ To, From ] }, { pid, Pid }, #{ event => msg_received, data => #{ from => From, to => To, msg => Message, timestamp => Timestamp, type => Type, student_id =>StudentId } } ),
	irc ! { msg_ack, Pid, #{ ref_id => RefId,  timestamp => Timestamp } },

	irc ! { store_msg, { timestamp, Timestamp, from, From, to, To, msg, Message, type, Type, student_id, StudentId } },
	{noreply, State};

handle_info(Info, State) ->
	io:format("irc received Unexpected Message :~p.~n",[Info]),
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

%% @doc Send message to the given User Name.
-spec msg_to({ name , Name :: string() }, Msg :: map()) -> ok.
msg_to( { name, Name }, Msg) ->
	{pids , L} = mongo_users_ser:getPids(Name),
	[ binary_to_term(Pid) ! {irc, Msg} || Pid <- L ].

%% @doc Send message to the given User Name Except given Pid.
-spec msg_to({ name , Name :: string() }, { pid, Pid :: pid() }, Msg :: map()) -> ok.
msg_to( { name, Name }, { pid, Pid }, Msg) ->
	{pids , L} = mongo_users_ser:getPids(Name),
	L1 = lists:delete(term_to_binary(Pid), L),
	[ binary_to_term(Pid1) ! {irc, Msg} || Pid1 <- L1 ];

%% @doc Send message to the given list of User Name.
msg_to( { msg_to_users_list, L }, { pid, Pid }, Msg ) ->
	[ msg_to( { name, Name }, { pid, Pid }, Msg ) || Name <- L ].

%% @doc Send Message to the all users into the Currently set AppId.
-spec broadcast(Msg :: map()) -> ok.
broadcast(Msg) ->
	{pids, L} = mongo_users_ser:getPids(),
	[ binary_to_term(Pid) ! {irc, Msg} || Pid <- L ].

%% @doc Send Message to the all users into the provided group eg { class : "3" }.
-spec broadcast(Data :: tuple(), Msg :: map()) -> ok.
broadcast(Data, Msg) ->
	{pids, L} = mongo_users_ser:getgroupPids(Data),
	[ binary_to_term(Pid) ! {irc, Msg} || Pid <- L ].

%% @doc Return the Date and time stamp.
-spec get_date_time() -> binary().
get_date_time() -> bson:unixtime_to_secs(os:timestamp()).

send_msg_to(Pids, Msg) ->
	[ binary_to_term(Pid) ! {irc, Msg} || Pid <- Pids ].
