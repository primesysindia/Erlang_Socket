-module(device_tracker_protocol).
-author("Piyush Sable").

-behaviour(gen_server).
-behaviour(ranch_protocol).

%% API
-export([start_link/4]).

%% gen_server callbacks
-export([init/1,
	init/4,
	handle_call/3,
	handle_cast/2,
	handle_info/2,
	terminate/2,
	code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {socket, transport}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link(Ref :: pid(), Socket :: port(), Transport :: string(), Opts :: map()) ->
	{ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link(Ref, Socket, Transport, Opts) ->
	proc_lib:start_link(?MODULE, init, [Ref, Socket, Transport, Opts]).

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
	{ok, #state{}}.

init(Ref, Socket, Transport, _Opts = []) ->
	ok = proc_lib:init_ack({ok, self()}),
	ok = ranch:accept_ack(Ref),
	io:format("~n~n-----------------------------~nDevice Tracking Started.~n"),
	ok = Transport:setopts(Socket, [{active, once}]),
	gen_server:enter_loop(?MODULE, [], #state{socket=Socket, transport=Transport}).

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

handle_info({tcp, Socket, Data}, State=#state{socket=Socket, transport=Transport}) ->
	io:format("Data received from device: ~p.~n", [Data]),
	io:format("Data received from device : <<~s>>~n", [[io_lib:format("~2.16.0B",[X]) || <<X:8>> <= Data ]]),
	tracker_data_decoder ! { Data, self()},
	Transport:setopts(Socket, [{active, once}]),
	{noreply, State};

handle_info({tcp_closed, _Socket}, State) ->
	io:format("Socket Closed by Device.~n"),
	mongo_devices_ser:removePid(term_to_binary(self())),
	{stop, normal, State};

handle_info({tcp_error, _, Reason}, State) ->
	{stop, Reason, State};

handle_info(timeout, State) ->
	{stop, normal, State};

%% handle_info({irc, Map}, State=#state{socket=Socket, transport=Transport}) ->
%% 	Transport:send(Socket, [ jsx:encode(Map) , <<"\r\n">> ]),
%% 	{noreply, State};

% Handle responce messages from tracking Platform to device.
handle_info({reply, Msg}, State=#state{socket=Socket, transport=Transport}) ->
%% 	io:format("Reply to device : ~p.~n", [Msg]),
	io:format("Reply to device : <<~s>>~n", [[io_lib:format("~2.16.0B",[X]) || <<X:8>> <= Msg ]]),
	Transport:send(Socket, Msg),
	{noreply, State};

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
%% -spec(handle_info(Info :: timeout() | term(), State :: #state{}) ->
%% 	{noreply, NewState :: #state{}} |
%% 	{noreply, NewState :: #state{}, timeout() | hibernate} |
%% 	{stop, Reason :: term(), NewState :: #state{}}).
handle_info(_Info, State) ->
	io:format("Unexpected message : ~p.~n",[_Info]),
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
%%
	%% 7878 - Start Bit
	%% 11 - Packet Length
	%% 01 - Protocol Number
	%% 	0358740050123644 - Terminal ID
	%% 	101C - Identifier
	%% 	3202 - Extension bit
	%% 0001 - Information Serial Number
	%% DCC9 - CRC verify
	%% 0D0A - Stop Bit
%%
%% 0123456789012345


%% 787811010358740050123644101C32020001DCC90D0A

%% 	Send Geo fence IN Message.
%send(Pid)->
%	tracker_data_decoder ! { <<120,120,37,22,16,7,23,18,28,27,201,1,254,152,187,7,234,52,55,5,20,239,9,1,149,161,19,158,0,229,27,104,6,4,0,2,0,132,50,34,13,10>>, Pid },
%	io:format("Done Sending Geo fence IN Message.~n").

%% Send	Geo fence Out Message.
%% send(out)->
%% 	tracker_data_decoder ! { <<120,120,37,22,16,7,23,18,31,50,201,1,254,151,242,7,234,33,239,19,21,13,9,1,149,161,19,158,0,56,47,112,6,4,0,2,0,166,211,43,13,10>>, self() },
%% 	io:format("Done Sending Geo fence OUT Message.~n").

%% device_tracker_protocol:send( self() ).

%% pid(0,251,0) ! { irc, #{ event => geo_fence_alert, data => #{ lat => 18.590255, lan => 73.771835, speed => 5, timestamp => 1469346453, geo_fence_status => in, fence_det => #{ fence_id => 1, fence_no => 1, fence_name => <<"First Fence">>, type => circle, center => #{ lat => 18.590255, lan => 73.771835 }, radius => 100 } } } }.

%% Data received from device: <<120,120,37,22,16,7,24,22,39,45,204,1,254,152,157,
%% 7,234,52,19,4,21,8,9,1,148,27,0,201,0,205,178,104,
%% 6,4,0,2,0,97,143,34,13,10>>.
%% Data received from device : <<7878251610071816272DCC01FE989D07EA34130415080901941B00C900CDB2680604000200618F220D0A>>
