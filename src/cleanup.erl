%%%-------------------------------------------------------------------
%%% @author Piyush D. Sable
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%     The cleanUp Process, To remove the unnecessary Data from the MongoDb.
%%% @end
%%% Created : 06. Jul 2015 4:14 PM
%%%-------------------------------------------------------------------
-module(cleanup).
-author("Piyush D. Sable").

-behaviour(gen_server).

%% External API
-export([start_link/0]).

%% gen_server callbacks
-export([init/1,
	handle_call/3,
	handle_cast/2,
	handle_info/2,
	terminate/2,
	code_change/3]).

-define(SERVER, ?MODULE).

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
	gen_server:start_link({local, ?SERVER}, ?MODULE, [mongo_users_ser, mongo_messages_ser], []).

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
	{ok, State ::  #{}} | {ok, State ::  #{}, timeout() | hibernate} |
	{stop, Reason :: term()} | ignore).
init(L) ->
%% 	io:format("Started CleanUp for ~p Databases.~n", [L]),
	self() ! init,
	{ok, L}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
	State ::  #{}) ->
	{reply, Reply :: term(), NewState ::  #{}} |
	{reply, Reply :: term(), NewState ::  #{}, timeout() | hibernate} |
	{noreply, NewState ::  #{}} |
	{noreply, NewState ::  #{}, timeout() | hibernate} |
	{stop, Reason :: term(), Reply :: term(), NewState ::  #{}} |
	{stop, Reason :: term(), NewState ::  #{}}).
handle_call(_Request, _From, State) ->
	{reply, ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_cast(Request :: term(), State ::  #{}) ->
	{noreply, NewState ::  #{}} |
	{noreply, NewState ::  #{}, timeout() | hibernate} |
	{stop, Reason :: term(), NewState ::  #{}}).
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
-spec(handle_info(Info :: timeout() | term(), State ::  #{}) ->
	{noreply, NewState ::  #{}} |
	{noreply, NewState ::  #{}, timeout() | hibernate} |
	{stop, Reason :: term(), NewState ::  #{}}).
handle_info(init, L) ->
	[ Proc ! cleanup || Proc <- L],
	timer:sleep(24*60*60*1000), %% Sleep the Process for a day
	self() ! init,
	{noreply, L};

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
	State ::  #{}) -> term()).
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
-spec(code_change(OldVsn :: term() | {down, term()}, State ::  #{},
	Extra :: term()) ->
	{ok, NewState ::  #{}} | {error, Reason :: term()}).
code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
