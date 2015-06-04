%%%-------------------------------------------------------------------
%%% @author primesys001
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%     Set Device Id for the Provided student Id.
%%%
%%% @end
%%% Created : 07. Apr 2015 3:53 PM
%%%-------------------------------------------------------------------
-module(set_device_handler).
-author("Piyush Sable").

-export([init/3]).
-export([handle/2]).
-export([terminate/3]).

init(_Transport, Req, []) ->
	{ok, Req, undefined}.

handle(Req, State) ->
	{StudentId, Req1} = cowboy_req:qs_val(<<"student_id">>, Req, <<"0">>),
	{ParentId, Req2} = cowboy_req:qs_val(<<"parent_id">>, Req1, <<"0">>),
	{DeviceId, Req3} = cowboy_req:qs_val(<<"device_id">>, Req2, <<"0">>),
	Rep = mongo_devices_ser:setDeviceId(binary_to_integer(StudentId),binary_to_integer(ParentId),binary_to_integer(DeviceId)),

	{ok, Req4} = cowboy_req:reply(200, [{<<"content-type">>, <<"text/html">>}], Rep, Req3),
	{ok, Req4, State}.

terminate(_Reason, _Req, _State) ->
	ok.
