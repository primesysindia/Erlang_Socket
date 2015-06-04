-module(chat_app).
-behaviour(application).

-export([start/2]).
-export([stop/1]).

start(_Type, _Args) ->
	app_supervisor:start_link(),
	Dispatch = cowboy_router:compile([
		{'_',   [
					{"/", cowboy_static, {priv_file, chat, "static/index.html" }},
					{"/assets/[...]", cowboy_static, {priv_dir, chat, "static/assets" }},

					%% Start RESTFULL apis to set the Device Configuration.
					{"/apis/devices", cowboy_static, {priv_dir, chat, "static/assets" }},
					%% End RESTFULL apis to set the Device Configuration.

					{"/set_device", set_device_handler, []},
					{"/bullet", bullet_handler, [{handler, chat_handler}]}
				]
		}
	]),

	{ok, _} = cowboy:start_http(http, 100, [{port, 8181}], [{env, [{dispatch, Dispatch}]}] ),

	{ok, _} = ranch:start_listener(tcp_chat, 1,	ranch_tcp, [{port, 5555}], handle_mobile_tcp_protocol, []),

	{ok, _} = ranch:start_listener(tcp_tracker, 1,	ranch_tcp, [{port, 6464}], device_tracker_protocol, []),
%% 	Data = <<120,120,13,1,3,85,72,128,32,16,116,133,0,12,136,226,13,10>>,
%% 	tracker_data_decoder ! { Data, self() },
	chat_sup:start_link().

stop(_State) ->
	ok.