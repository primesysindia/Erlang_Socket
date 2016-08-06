-module(app_supervisor).
-author("Piyush Sable").

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%%===================================================================
%%% API functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the supervisor
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link() ->
	{ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link() ->
	supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a supervisor is started using supervisor:start_link/[2,3],
%% this function is called by the new process to find out about
%% restart strategy, maximum restart frequency and child
%% specifications.
%%
%% @end
%%--------------------------------------------------------------------
-spec(init(Args :: term()) ->
	{ok, {SupFlags :: {RestartStrategy :: supervisor:strategy(),
		MaxR :: non_neg_integer(), MaxT :: non_neg_integer()},
		[ChildSpec :: supervisor:child_spec()]
	}} |
	ignore |
	{error, Reason :: term()}).
init([]) ->
	RestartStrategy = one_for_one,
	MaxRestarts = 1000,
	MaxSecondsBetweenRestarts = 3600,

	SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},

	Restart = permanent,
	Shutdown = 2000,
	Type = worker,

	EventDecoderChild = { 'event_decoder', { 'event_decoder', start_link, [] }, Restart, Shutdown, Type, ['event_decoder'] },
	IrcChild = { 'irc', { 'irc', start_link, [] }, Restart, Shutdown, Type, ['irc'] },
	TrackerDataDecoderChild = { 'tracker_data_decoder', { 'tracker_data_decoder', start_link, [] }, Restart, Shutdown, Type, ['tracker_data_decoder'] },
	MongoUsersSerChild = { 'mongo_users_ser', { 'mongo_users_ser', start_link, [] }, Restart, Shutdown, Type, ['mongo_users_ser'] },
	MongoMessagesSerChild = { 'mongo_messages_ser', { 'mongo_messages_ser', start_link, [] }, Restart, Shutdown, Type, ['mongo_messages_ser'] },
	MongoGroupSerChild = { 'mongo_group_ser', { 'mongo_group_ser', start_link, [] }, Restart, Shutdown, Type, ['mongo_group_ser'] },
	GetGpsLocationChild = { 'get_gps_location', { 'get_gps_location', start_link, [] }, Restart, Shutdown, Type, ['get_gps_location'] },
	MongoDevicesSerChild = { 'mongo_devices_ser', { 'mongo_devices_ser', start_link, [] }, Restart, Shutdown, Type, ['mongo_devices_ser'] },
	MongoLocationSerChild = { 'mongo_location_ser', { 'mongo_location_ser', start_link, [] }, Restart, Shutdown, Type, ['mongo_location_ser'] },
	MongoFriendsSerChild = { 'mongo_friends_ser', { 'mongo_friends_ser', start_link, [] }, Restart, Shutdown, Type, ['mongo_friends_ser'] },
	MongoGeoFenceSerChild = { 'mongo_geo_fence_ser', { 'mongo_geo_fence_ser', start_link, [] }, Restart, Shutdown, Type, ['mongo_geo_fence_ser'] },
	CleanupSerChild = { 'cleanup', { 'cleanup', start_link, [] }, Restart, Shutdown, Type, ['cleanup'] },

	{ok, {SupFlags, [ EventDecoderChild, IrcChild, TrackerDataDecoderChild, MongoUsersSerChild, MongoMessagesSerChild, MongoGroupSerChild, GetGpsLocationChild, MongoDevicesSerChild, MongoLocationSerChild, MongoFriendsSerChild, MongoGeoFenceSerChild, CleanupSerChild ]}}.

%%%===================================================================
%%% Internal functions
%%%===================================================================