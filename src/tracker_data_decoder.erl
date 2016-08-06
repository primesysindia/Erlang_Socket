-module(tracker_data_decoder).
-author("Piyush Sable").

-behaviour(gen_server).

%% API
-export([start_link/0, send/1, sendLatLanToTrackPids/2, send_gcm_msg/2]).

%% gen_server callbacks
-export([init/1,
	handle_call/3,
	handle_cast/2,
	handle_info/2,
	terminate/2,
	code_change/3]).

-define(SERVER, ?MODULE).

-define(StartBit, 16#7878).
-define(StopBit, 16#0D0A).
-define(Login_Info_Protocol_Number, 16#01).
-define(GPS_Info_Protocol_Number, 16#10).
-define(LBS_Info_Protocol_Number, 16#11).
-define(GPS_LBS_Merged_Info_Protocol_Number, 16#12).
-define(Status_Protocol_Number, 16#13).
-define(SNR_Protocol_Number, 16#14).
-define(String_Protocol_Number, 16#15).
-define(GFENCE_Protocol_Number, 16#16).
-define(GPS_LBS_Status_Merged_Protocol_Number, 16#96).
-define(LBS_Check_Loc_Via_Phone_No_Protocol_Number, 16#97).
-define(LBS_Extension_Protocol_Number, 16#18).
-define(LBS_Status_Merged_Protocol_Number, 16#99).
-define(GPS_Check_Loc_Via_Phone_No_Protocol_Number, 16#9A).
-define(Geo_Fence_Alarm_Protocol_Number, 16#9B).
-define(GPS_LBS_Extension_Protocol_Number, 16#1E).
-define(Sync_Protocol_Number, 16#1F).
-define(Server_Send_Cmd_To_Terminal_For_Setting_Protocol_Number, 16#80).
-define(Server_Send_Cmd_To_Terminal_For_Checking_Protocol_Number, 16#81).
-define(VT268_StartBit, "TRV").
-define(VT268_StopBit, "#").
-define(VT268_REQ_Login_Packet, "AP00").
-define(VT268_RES_Login_Packet, "BP00").
-define(VT268_REQ_GPS_LBS_Packet, "AP01").
-define(VT268_RES_GPS_LBS_Packet, "BP01").
-define(VT268_REQ_Alarm_Packet, "AP10").
-define(VT268_RES_Alarm_Packet, "BP10").


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
%% 	io:format("Started Tracker Data Decoder Server.~n"),
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
%% Handle the Login Information Packet. (0x01)
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info({<<?StartBit:16, _PacketLength:8, ?Login_Info_Protocol_Number:8, DeviceId:64, _Identifier:16, _ExtensionBit:16, InformationSerialNumber:16, _CRCVerify:16, ?StopBit:16 >>, Pid}, _State) ->
%% 	io:format("Event Got : ~p.~n.", [{?StartBit, PacketLength, ProtocolNumber, TerminalId, Identifier, ExtensionBit, InformationSerialNumber, CRCVerify}]),
	io:fwrite("Got Login Info Packet.~n"),
	io:fwrite("Got Terminal Id : ~.16B\n", [DeviceId]),
%% TODO : Register Terminal Id and associate it with the Student.
	DeviceIdDec = to_dec(DeviceId),
	case mongo_devices_ser:count({ device, DeviceIdDec }) of
		0 ->
			Doc = { device, DeviceIdDec, pid, term_to_binary(Pid), student, 0, parent, 0, track_pids, [] },
			mongo_devices_ser:insert(Doc);
		_N ->
%% 			io:format("Cnt : ~p.~n", [N]),
			Command = {'$set', {
				pid, term_to_binary(Pid)
			}},
			mongo_devices_ser:update({ device, DeviceIdDec }, Command)
	end,

	<<InformationSerialNumber_1:8 , InformationSerialNumber_2:8 >> = <<InformationSerialNumber:16>>,
	{{Crc_1, Crc_2}} = crc:get_crc([ 05, ?Login_Info_Protocol_Number, InformationSerialNumber_1, InformationSerialNumber_2]),
	Res_Packet = iolist_to_binary([5, ?Login_Info_Protocol_Number, InformationSerialNumber_1, InformationSerialNumber_2, Crc_1, Crc_2 ]),
	Pid ! {reply, << ?StartBit:16, Res_Packet/binary, ?StopBit:16 >> },
	{noreply, _State};

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handle the GPS Information package. (0x10)
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info({<<?StartBit:16, _PacketLength:8, ?GPS_Info_Protocol_Number:8, _Date_Time:48, _GPS_Msg_Len:8, Lat:32, Lan:32, Speed:8, Status:16, _Extension:16, SerialNumber:16, _CRCVerify:16, ?StopBit:16 >>, Pid}, _State) ->
%% 	io:format("Event Got : ~p.~n.", [{?StartBit, PacketLength, ProtocolNumber, TerminalId, Identifier, ExtensionBit, InformationSerialNumber, CRCVerify}]),
%% 	io:fwrite("Got GPS Info Packet.~n"),
	io:format("Lat Val : ~p.~n.", [ { getLatLanValDD(Lat), getLatLanValDD(Lan) }]),
%% 	io:format("Speed : ~p.~n.", [ Speed ]),
%% 	io:format("GPS Status : ~p.~n.", [ decodeGPSStatus(<<Status:16>>) ]),

	sendNSaveGPSData( { Lat, Lan, Pid, Speed, Status } ),

	<<SerialNumber_1:8 , SerialNumber_2:8 >> = <<SerialNumber:16>>,
	{{Crc_1, Crc_2}} = crc:get_crc([ 05, ?GPS_Info_Protocol_Number, SerialNumber_1, SerialNumber_2]),
	Res_Packet = iolist_to_binary([5, ?GPS_Info_Protocol_Number, SerialNumber_1, SerialNumber_2, Crc_1, Crc_2 ]),
	Pid ! {reply, << ?StartBit:16, Res_Packet/binary, ?StopBit:16 >> },
	{noreply, _State};

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handle the Status Information package. (0x13)
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
%% 7878 0A 13   C0 00 64 0001      007A CFC6 0D0A
handle_info({<<?StartBit:16, _PacketLength:8, ?Status_Protocol_Number:8, Terminal_Info:8, Voltage_Level:8, GSM_Signal_Strength:8, _Extension:16, SerialNumber:16, _CRCVerify:16, ?StopBit:16 >>, Pid}, _State) ->
%% 	io:fwrite("Got Status Info Packet.~n"),
%%
%% 	io:format("Got Ter info : ~p.~n", [ decodeTerminalInfo({ tk102b, <<Terminal_Info:8>> }) ]),
%%
%% 	io:format("Voltage Level : ~p.~n", [ Voltage_Level ]),
%%
%% 	io:format("GSM Signal Strength : ~p.~n", [ GSM_Signal_Strength ]),

	sendMsgViaPid({ pid, term_to_binary(Pid) }, #{ event => device_status, data=> #{ terminal_info =>  decodeTerminalInfo({ tk102b, <<Terminal_Info:8>> }), voltage_level => Voltage_Level, gsm_signal_strength => GSM_Signal_Strength } }),

	<<SerialNumber_1:8 , SerialNumber_2:8 >> = <<SerialNumber:16>>,
	{{Crc_1, Crc_2}} = crc:get_crc([ 05, ?Status_Protocol_Number, SerialNumber_1, SerialNumber_2]),
	Res_Packet = iolist_to_binary([5, ?Status_Protocol_Number, SerialNumber_1, SerialNumber_2, Crc_1, Crc_2 ]),
	Pid ! {reply, << ?StartBit:16, Res_Packet/binary, ?StopBit:16 >> },
	{noreply, _State};

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Send the Command to the Terminal. (0x80)
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info({ send_command, Cmd, ParentId }, _State) ->

	io:format("Got Command to Send : ~p.~n", [ { Cmd, ParentId }]),

	case mongo_devices_ser:getPid({ parent, ParentId }) of
		{ pid, Pid } ->
			io:format("Pid : ~p.~n",[ Pid ]),
			SerialNumber = 0001,
			ServerIdentifier = 16#0000A039,

			Cmd_Bin = list_to_binary(Cmd++"#"),
			Cmd_Len = string:len(Cmd)+1+4,
			Res_Len = Cmd_Len+6,

			<< SerialNumber_1:8, SerialNumber_2:8 >> = <<SerialNumber:16>>,
			<< ServerIdentifier_1:8, ServerIdentifier_2:8, ServerIdentifier_3:8, ServerIdentifier_4:8 >> = <<ServerIdentifier:32>>,
			{{Crc_1, Crc_2}} = crc:get_crc([ Res_Len, ?Server_Send_Cmd_To_Terminal_For_Setting_Protocol_Number, Cmd_Len, ServerIdentifier_1, ServerIdentifier_2, ServerIdentifier_3, ServerIdentifier_4 ] ++ cmd_to_list(Cmd++"#") ++ [ SerialNumber_1, SerialNumber_2 ]),

		io:format("CRC : ~p.~n",[ { [ Res_Len, ?Server_Send_Cmd_To_Terminal_For_Setting_Protocol_Number, Cmd_Len, ServerIdentifier_1, ServerIdentifier_2, ServerIdentifier_3, ServerIdentifier_4 ] ++ cmd_to_list(Cmd++"#") ++ [ SerialNumber_1, SerialNumber_2 ] } ]),

		io:format("Cmd : ~p. ~n", [ { Res_Len, Cmd_Len, Cmd_Bin, Crc_1, Crc_2 } ]),

			Pid ! {reply, list_to_binary([<< ?StartBit:16, Res_Len:8, ?Server_Send_Cmd_To_Terminal_For_Setting_Protocol_Number:8, Cmd_Len:8, ServerIdentifier:32>>, Cmd_Bin, <<SerialNumber:16, Crc_1:8, Crc_2:8, ?StopBit:16 >> ]) },
			ok;
		{error, pid_not_found} -> pid_not_found
	end,
	{noreply, _State};

%% tracker_data_decoder:send({ send_command, "#smslink#190914", 505167 }).

%% tracker_data_decoder:send({ send_command, "GFENCE", 505254 }).
%% tracker_data_decoder:send({ send_command, "GFENCE,1,ON,0,N18.590489,E73.771062,1,,1", 505254 }).
%% tracker_data_decoder:send({ send_command, "GFENCE,1,ON,0,N18.590489,E73.771062,1,,", 505254 }).
%% tracker_data_decoder:send({ send_command, "GFENCE,1,ON,0,N18.590489,E73.771062,5,,1", 505254 }).

%% tracker_data_decoder:send({ send_command, "GPSON", 505254 }).
%% tracker_data_decoder:send({ send_command, "SERVER,0,54.68.103.211,6666,0", 505254 }).

%% tracker_data_decoder:send({ send_command, "FN,A,Dad,7030983483,Uncle,8446443142,Uncle_Demo,9970040544", 505163 }).
%% SOS,A,13790774051,13790774051,13790774051,13790774051#
%% tracker_data_decoder:send({ send_command, "SOS,A,7030983483,8446443142,9970040544", 505163 }).
%% FENCE,1,ON,0,N18.590526,E73.771260,1,,1#
%% tracker_data_decoder:send({ send_command, "FENCE,1,ON,0,N18.590526,E73.771260,1,,1", 505163 }).

%% FN,A,Dad,7030983483,Uncle,8446443142,Uncle_Demo,9970040544

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handle the Syncronization Information package. (0x1F)
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info({<<_StartBit:16, _PacketLength:8, ?Sync_Protocol_Number:8, _Date_Time:48, _Extension:16, _SerialNumber:16, _CRCVerify:16, _StopBit:16 >>, _Pid}, _State) ->
%% 	io:fwrite("Got Sync Info Packet.~n"),
%% 	<<SerialNumber_1:8 , SerialNumber_2:8 >> = <<SerialNumber:16>>,
%% 	{{Crc_1, Crc_2}} = crc:get_crc([ 05, ?Status_Protocol_Number, SerialNumber_1, SerialNumber_2]),
%% 	Res_Packet = iolist_to_binary([5, ?Status_Protocol_Number, SerialNumber_1, SerialNumber_2, Crc_1, Crc_2 ]),
%% 	Pid ! {reply, << ?StartBit:16, Res_Packet/binary, ?StopBit:16 >> },
	{noreply, _State};

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handle the Setting Command from server to terminal Information package. (0x81)
%% Format 1: Content less than 255 bytes.
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info({<<_StartBit:16, _PacketLength:8, ?Server_Send_Cmd_To_Terminal_For_Checking_Protocol_Number:8, Cmd_Len:8, Cmd_Content:Cmd_Len/binary-unit:8, _SerialNumber:16, _CRCVerify:16, _StopBit:16 >>, _Pid}, _State) ->
%% 	io:fwrite("Got Command ( Less That 255 Bytes. ) Info Packet.~n"),
%% 	io:format("Cmd Len : ~p.~n",[Cmd_Len]),
	Len = Cmd_Len-8,
%% 	io:format("Cmd Len in Dec : ~p.~n",[Len]),
%% 	io:format("Data received from device : <<~s>>~n", [[io_lib:format("~2.16.0B",[X]) || <<X:8>> <= Cmd_Content ]]),
	<<_Ser_Flag_Bit:32, _Cmd:Len/binary-unit:8, _Reserved_Bit:32>> = Cmd_Content,
%% 	io:format("Data received from device : <<~s>>~n", [[io_lib:format("~2.16.0B",[X]) || <<X:8>> <= Cmd ]]),
%% 	io:format("Cmd : ~s.~n",[Cmd]),


%% 	io:format("Cmd : ~p.~t : <<~s>>~n", [[io_lib:format("~2.16.0B",[X]) || <<X:8>> <= Rem ]]),
%% 	<<SerialNumber_1:8 , SerialNumber_2:8 >> = <<SerialNumber:16>>,
%% 	{{Crc_1, Crc_2}} = crc:get_crc([ 05, ?Status_Protocol_Number, SerialNumber_1, SerialNumber_2]),
%% 	Res_Packet = iolist_to_binary([5, ?Status_Protocol_Number, SerialNumber_1, SerialNumber_2, Crc_1, Crc_2 ]),
%% 	Pid ! {reply, << ?StartBit:16, Res_Packet/binary, ?StopBit:16 >> },
	{noreply, _State};

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handle the Setting Command from server to terminal Information package. (0x81)
%% Format 2: Content longer than 255 bytes.
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info({<<_StartBit:16, _PacketLength:8, ?Server_Send_Cmd_To_Terminal_For_Checking_Protocol_Number:8, Cmd_Len:16, Cmd_Content:Cmd_Len/binary-unit:8, _SerialNumber:16, _CRCVerify:16, _StopBit:16 >>, _Pid}, _State) ->
%% 	io:fwrite("Got Command ( longer That 255 Bytes. ) Info Packet.~n"),
%% 	io:format("Cmd Len : ~p.~n",[Cmd_Len]),
	Len = Cmd_Len-8,
%% 	io:format("Data received from device : <<~s>>~n", [[io_lib:format("~2.16.0B",[X]) || <<X:8>> <= Cmd_Content ]]),
	<<_Ser_Flag_Bit:32, _Cmd:Len/binary-unit:8, _Reserved_Bit:32>> = Cmd_Content,
%% 	io:format("Data received from device : <<~s>>~n", [[io_lib:format("~2.16.0B",[X]) || <<X:8>> <= Cmd ]]),
%% 	io:format("Large Cmd : ~s.~n",[Cmd]),

%% 	<<SerialNumber_1:8 , SerialNumber_2:8 >> = <<SerialNumber:16>>,
%% 	{{Crc_1, Crc_2}} = crc:get_crc([ 05, ?Status_Protocol_Number, SerialNumber_1, SerialNumber_2]),
%% 	Res_Packet = iolist_to_binary([5, ?Status_Protocol_Number, SerialNumber_1, SerialNumber_2, Crc_1, Crc_2 ]),
%% 	Pid ! {reply, << ?StartBit:16, Res_Packet/binary, ?StopBit:16 >> },
	{noreply, _State};

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handle the GFENCE alarm packet from Terminal to the Server. (0x16)
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info({<<_StartBit:16, _PacketLength:8, ?GFENCE_Protocol_Number:8, _Date_Time:48, _GPS_Msg_Len:8, Lat:32, Lan:32, Speed:8, Status:16, _UnknownBits1:72, GeoFenceStatus:8, _UnknownBits2:32, _SerialNumber:16, _CRCVerify:16, ?StopBit:16 >>, Pid}, _State) ->

	io:fwrite("Got GFENCE Alarm Packet.~n"),
	io:fwrite("Got PID at GFENCE Alarm : ~p.~n", [Pid]),
%	io:format("GFence Data : ~p.~n",[Data]),
%	io:format("GFence Data : <<~s>>~n", [[io_lib:format("~2.16.0B",[X]) || <<X:8>> <= Data ]]),

    io:format("Lat / Lan Val : ~p.~n.", [ { getLatLanValDD(Lat), getLatLanValDD(Lan) }]),
    io:format("GeoFenceStatus : ~p.~n.", [ getGeoFenceStatus(GeoFenceStatus) ]),
    io:format("Speed : ~p.~n.", [ Speed ]),
    io:format("GPS Status : ~p.~n.", [ decodeGPSStatus(<<Status:16>>) ]),
	sendNSaveGeoFenceData( { Lat, Lan, Pid, Speed, Status, getGeoFenceStatus(GeoFenceStatus), getFenceDet(1) } ),

%	<<SerialNumber_1:8 , SerialNumber_2:8 >> = <<SerialNumber:16>>,
%	{{Crc_1, Crc_2}} = crc:get_crc([ 05, ?GFENCE_Protocol_Number, SerialNumber_1, SerialNumber_2]),
%	Res_Packet = iolist_to_binary([5, ?GPS_Info_Protocol_Number, SerialNumber_1, SerialNumber_2, Crc_1, Crc_2 ]),
%	Pid ! { reply, << ?StartBit:16, Res_Packet/binary, ?StopBit:16 >> },

% Protocol Implemented.
%<<?StartBit:16, _PacketLength:8, ?GPS_Info_Protocol_Number:8, _Date_Time:48, _GPS_Msg_Len:8, Lat:32, Lan:32, Speed:8, Status:16, _Extension:16, SerialNumber:16, _CRCVerify:16, ?StopBit:16 >>
%
%7878 25 16 (_Date_Time:48)-100702132F05 _GPS_Msg_Len:8-C9 Lat:32-01FE9846 Lan:32-07EA36DD Speed:8-03 Status:16-145C
%_UnknownBits1:72-090195A1139E00E51B, GeoFenceStatus:8-70, _UnknownBits2:40-7004040002, SerialNumber:16-00CE _CRCVerify:16-A6CE ?StopBit:16-0D0A

%%  Out Message -
%% 	Reply to device : <<7878051000C6B4260D0A>>
%% 	Data received from device : <<78782516100702132F05C901FE984607EA36DD03145C090195A1139E00E51B700404000200CEA6CE0D0A>>
%% 	Got GFENCE Alarm Packet.
%% GFence Data : <<16,7,2,19,47,5,201,1,254,152,70,7,234,54,221,3,20,92,9,1,149,
%% 161,19,158,0,229,27,112,4,4,0,2,0,206,166,206,13,10>>.
%% GFence Data : <<100702132F05C901FE984607EA36DD03145C090195A1139E00E51B700404000200CEA6CE0D0A>>
%%
%% 1007 02132F05 C901FE984607EA36DD03145C090195A1139E00E51B7004040002 00CE A6CE 0D0A
%%
%% M = C901FE984607EA36DD03145C090195A1139E00E51B 70 04040002

%%  In Message -
%% Reply to device : <<7878051001E0E9CA0D0A>>
%% Data received from device : <<78782516100702140E16CA01FE98EB07EA34DF021512090195A1139E00382E 68 04040002 01E8A97E0D0A>>
%% Got GFENCE Alarm Packet.
%% GFence Data : <<16,7,2,20,14,22,202,1,254,152,235,7,234,52,223,2,21,18,9,1,149,
%% 161,19,158,0,56,46,104,4,4,0,2,1,232,169,126,13,10>>.
%% GFence Data : <<100702140E16CA01FE98EB07EA34DF021512090195A1139E00382E680404000201E8A97E0D0A>>

	{noreply, _State};

%%%===================================================================
%%% Protocol Implementation for the TK102B Device
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handle the Login Information Packet. (0x01)
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info({ <<?StartBit:16, _PacketLength:8, ?Login_Info_Protocol_Number:8, DeviceId:64, InformationSerialNumber:16, _CRCVerify:16, ?StopBit:16 >>, Pid }, _State) ->
%% 	io:format("Event Got : ~p.~n.", [{?StartBit, PacketLength, ProtocolNumber, TerminalId, Identifier, ExtensionBit, InformationSerialNumber, CRCVerify}]),
	io:fwrite("Got TK102B Login Info Packet.~n"),
	io:fwrite("Got TK102B Terminal Id : ~.16B\n", [DeviceId]),
%% TODO : Register Terminal Id and associate it with the Student.
	DeviceIdDec = to_dec(DeviceId),
	case mongo_devices_ser:count({ device, DeviceIdDec }) of
		0 ->
			Doc = { device, DeviceIdDec, pid, term_to_binary(Pid), student, 0, parent, 0, track_pids, [] },
			mongo_devices_ser:insert(Doc);
		N ->
			io:format("Cnt : ~p.~n", [N]),
			Command = {'$set', {
				pid, term_to_binary(Pid)
			}},
			mongo_devices_ser:update({ device, DeviceIdDec }, Command)
	end,

	<<InformationSerialNumber_1:8 , InformationSerialNumber_2:8 >> = <<InformationSerialNumber:16>>,
	{{Crc_1, Crc_2}} = crc:get_crc([ 05, ?Login_Info_Protocol_Number, InformationSerialNumber_1, InformationSerialNumber_2]),
	Res_Packet = iolist_to_binary([5, ?Login_Info_Protocol_Number, InformationSerialNumber_1, InformationSerialNumber_2, Crc_1, Crc_2 ]),
	Pid ! {reply, << ?StartBit:16, Res_Packet/binary, ?StopBit:16 >> },
	{noreply, _State};

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handle the GPS and LBS Combined Information package. (0x12)
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info({<<?StartBit:16, _PacketLength:8, ?GPS_LBS_Merged_Info_Protocol_Number:8, _Date_Time:48, _GPS_Msg_Len:8, Lat:32, Lan:32, Speed:8, Status:16, _LBS_MCC:16, _LBS_MNC:8,_LBS_LAC:16, _LBS_Cellid:24, SerialNumber:16, _CRCVerify:16, ?StopBit:16 >>, Pid}, _State) ->
%% 	io:format("Event Got : ~p.~n.", [{?StartBit, PacketLength, ProtocolNumber, TerminalId, Identifier, ExtensionBit, InformationSerialNumber, CRCVerify}]),
	io:fwrite("Got TK102B GPS Info Packet.~n"),
	io:format("Lat Val : ~p.~n.", [ { getLatLanValDD(Lat), getLatLanValDD(Lan) }]),
%% 	io:format("Speed : ~p.~n.", [ Speed ]),
%% 	io:format("GPS Status : ~p.~n.", [ decodeGPSStatus(<<Status:16>>) ]),

	sendNSaveGPSData( { Lat, Lan, Pid, Speed, Status } ),

%% 	{ device, DeviceId } = mongo_devices_ser:getDeviceId({pid, term_to_binary(Pid)}),
%% 	LatVal = getLatLanValDD(Lat),
%% 	LanVal = getLatLanValDD(Lan),
%% 	Timestamp = get_date_time(),
%%
%% 	sendLatLanToTrackPids({ device, DeviceId }, #{ event => current_location, data=> #{ lat => LatVal, lan => LanVal, speed => Speed, timestamp => Timestamp } }),
%%
%% 	mongo_location_ser:insert({ device, DeviceId, location, { lat, LatVal, lon, LanVal }, speed, Speed, timestamp, Timestamp, status, decodeGPSStatus(<<Status:16>>) }) ,

	<<SerialNumber_1:8 , SerialNumber_2:8 >> = <<SerialNumber:16>>,
	{{Crc_1, Crc_2}} = crc:get_crc([ 05, ?GPS_Info_Protocol_Number, SerialNumber_1, SerialNumber_2]),
	Res_Packet = iolist_to_binary([5, ?GPS_Info_Protocol_Number, SerialNumber_1, SerialNumber_2, Crc_1, Crc_2 ]),
	Pid ! {reply, << ?StartBit:16, Res_Packet/binary, ?StopBit:16 >> },
	{noreply, _State};

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handle the Login Information package for VT 268 device. (AP00)
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info({<< ?VT268_StartBit, ?VT268_REQ_Login_Packet, DeviceId:120, ?VT268_StopBit >>, Pid}, _State) ->
	io:fwrite("Got VT268 Login Packet.~n"),
	io:format("DeviceId : ~p.~n", [ binary_to_integer(<<DeviceId:120>>) ]),
	DeviceIdInt = binary_to_integer(<<DeviceId:120>>),
	case mongo_devices_ser:count({ device, DeviceIdInt }) of
		0 ->
			Doc = { device, DeviceIdInt, pid, term_to_binary(Pid), student, 0, parent, 0, track_pids, [] },
			mongo_devices_ser:insert(Doc);
		N ->
			io:format("Cnt : ~p.~n", [N]),
			Command = {'$set', {
				pid, term_to_binary(Pid)
			}},
			mongo_devices_ser:update({ device, DeviceIdInt }, Command)
	end,

	Pid ! {reply, << ?VT268_StartBit, ?VT268_RES_Login_Packet, ?VT268_StopBit >> },
	{noreply, _State};


%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handle the GPS and LBS Combined Information package. (0x12)
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info({<< ?VT268_StartBit, ?VT268_REQ_GPS_LBS_Packet, _Date:48, "A", Lat:80, Lan:88, Speed:40, _Data/binary >>, Pid}, _State) ->
%% 	io:format("Event Got : ~p.~n.", [{?StartBit, PacketLength, ProtocolNumber, TerminalId, Identifier, ExtensionBit, InformationSerialNumber, CRCVerify}]),
	io:fwrite("Got VT268 GPS Info Packet.~n"),
	io:format("Lat Val : ~p.~n.", [ { getLatLanValDD({ vt268, <<Lat:80>> }), getLatLanValDD({ vt268,  <<Lan:80>> }) }]),

	sendNSaveGPSData( { vt268, getLatLanValDD({ vt268, <<Lat:80>> }), getLatLanValDD({ vt268,  <<Lan:80>> }), Pid, binary_to_float(<<Speed:40>>) } ),

	Pid ! {reply, << ?VT268_StartBit, ?VT268_RES_GPS_LBS_Packet, ?VT268_StopBit >> },
	{noreply, _State};

%%--------------------------------------------------------------------
%% %% @private
%% %% @doc
%% %% Handling all non call/cast messages
%% %%
%% %% @spec handle_info(Info, State) -> {noreply, State} |
%% %%                                   {noreply, State, Timeout} |
%% %%                                   {stop, Reason, State}
%% %% @end
%% %%--------------------------------------------------------------------
%% handle_info({reply, _Msg}, State) ->
%% 	io:format("Got Unknown Command.~n"),
%% %% 	io:format("event_decoder: Reply Got: ~p~n",[Msg]),
%% 	{noreply, State};

handle_info(_Info, State) ->
	io:format("Got Unknown Command.~n"),
%% 	io:format("event_decoder:received:~p~n",[Info]),
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

%% @doc Return the Date and time stamp.
-spec get_date_time() -> binary().
get_date_time() -> bson:unixtime_to_secs(os:timestamp()).

%% @doc Return the Date and time stamp.
-spec sendLatLanToTrackPids(tuple(), any()) -> atom().
sendLatLanToTrackPids({ device, DeviceId }, Msg) ->
	case mongo_devices_ser:getTrackPidsForDeviceId({ device, DeviceId }) of
		{track_pids, L} ->
			[ binary_to_term(Pid) ! {irc, Msg} || Pid <- L ];
		track_pids_not_found -> track_pids_not_found
	end.

sendNSaveGPSData( { Lat, Lan, _Pid, _Speed, _Status } ) when Lat =< 0; Lan =< 0 ->
	io:format("Got Lat : ~p and Lan : ~p.~n",[Lat, Lan]);

sendNSaveGPSData( { vt268, Lat, Lan, Pid, Speed } ) ->
	{ device, DeviceId } = mongo_devices_ser:getDeviceId({pid, term_to_binary(Pid)}),
	Timestamp = get_date_time(),

	sendLatLanToTrackPids({ device, DeviceId }, #{ event => current_location, data=> #{ lat => Lat, lan => Lan, speed => Speed, timestamp => Timestamp } }),

	mongo_location_ser:insert({ device, DeviceId, location, { lat, Lat, lon, Lan }, speed, Speed, timestamp, Timestamp, status });

sendNSaveGPSData( { Lat, Lan, Pid, Speed, Status } ) ->
	{ device, DeviceId } = mongo_devices_ser:getDeviceId({pid, term_to_binary(Pid)}),
	LatVal = getLatLanValDD(Lat),
	LanVal = getLatLanValDD(Lan),
	Timestamp = get_date_time(),

	sendLatLanToTrackPids({ device, DeviceId }, #{ event => current_location, data=> #{ lat => LatVal, lan => LanVal, speed => Speed, timestamp => Timestamp } }),

	mongo_location_ser:insert({ device, DeviceId, location, { lat, LatVal, lon, LanVal }, speed, Speed, timestamp, Timestamp, status, decodeGPSStatus(<<Status:16>>) }).

sendNSaveGeoFenceData( { Lat, Lan, Pid, Speed, Status, GeoFenceStatus, FenceDet } ) ->
	io:format("Got PID : ~p.~n",[ Pid ]),
	{ device, DeviceId } = mongo_devices_ser:getDeviceId({pid, term_to_binary(Pid)}),
	LatVal = getLatLanValDD(Lat),
	LanVal = getLatLanValDD(Lan),
	Timestamp = get_date_time(),

	FenceDataMap = #{ event => geo_fence_alert, data => #{ lat => LatVal, lan => LanVal, speed => Speed, timestamp => Timestamp, geo_fence_status => GeoFenceStatus, fence_det => FenceDet } },

	send_gcm_msg(<<"APA91bHPFGh7IAQlREo0KL2g2ZmkzzeGHNOUfe44eHDwycU6ysEPpZGRcRGmumqcFETbGGAFAlZ48ky-jTUmHUP4yydPOyIF1ZvQoXAw_uMA9oEMHDMNOA_e-2l3GS07f6hssLtwgWPU">>, FenceDataMap),

	sendLatLanToTrackPids({ device, DeviceId }, FenceDataMap ),

	mongo_geo_fence_ser:insert({ device, DeviceId, geo_fence_data, { lat, LatVal, lon, LanVal }, speed, Speed, timestamp, Timestamp, status, decodeGPSStatus(<<Status:16>>), geo_fence_status, GeoFenceStatus, fence_id, maps:find(fence_id,FenceDet) }).

getFenceDet( _FenceId ) ->
	#{ fence_id => 1, fence_no => 1, fence_name => "First Fence", type => circle, center => #{ lat => 18.590255, lan => 73.771835 }, radius => 100 }.

%% @date05Aug2016 : Piyush : This function is used to Send GCM message to the Client.
%% Map Ex - tracker_data_decoder:send_gcm_msg(<<"APA91bHPFGh7IAQlREo0KL2g2ZmkzzeGHNOUfe44eHDwycU6ysEPpZGRcRGmumqcFETbGGAFAlZ48ky-jTUmHUP4yydPOyIF1ZvQoXAw_uMA9oEMHDMNOA_e-2l3GS07f6hssLtwgWPU">>, #{ lat => 18.590255, lan => 73.771835, speed => 5, timestamp => 1469346453, geo_fence_status => in, fence_det => #{ fence_id => 1, fence_no => 1, fence_name => <<"First Fence">>, type => circle, center => #{ lat => 18.590255, lan => 73.771835 }, radius => 100 } }).
%% Ex - tracker_data_decoder:send_gcm_msg(<<"APA91bHPFGh7IAQlREo0KL2g2ZmkzzeGHNOUfe44eHDwycU6ysEPpZGRcRGmumqcFETbGGAFAlZ48ky-jTUmHUP4yydPOyIF1ZvQoXAw_uMA9oEMHDMNOA_e-2l3GS07f6hssLtwgWPU">>, <<"Hi Again Rupesh...">>).
%% Curl Ex -
%% curl --header "Authorization: key=AIzaSyCSdcZQ3plIXs3zAazsskOaId6Wkq-hA7o" --header "Content-Type: application/json" https://android.googleapis.com/gcm/send -d "{\"registration_ids\":[\"APA91bFsORUIa_-qNaeAQQfN5vSDMC6STnza8pFbJi1g10Lx4dtlgOQnWIfUz8vZjeiP0zRRl3_JndAKgsNd7fqwvOvHeGP1ewVSgDpE_-WiBF_bCZ5zUoQlxsllTcAeGT2WhNcJBOFX\"], \"data\" : { \"message\" : \"Hi Rupesh\" } }"

send_gcm_msg(RegisteredId, Message) ->
	%% Create Json struct
	Method = post,
	URL = "http://android.googleapis.com/gcm/send",
	ServerKey = "key=AIzaSyCSdcZQ3plIXs3zAazsskOaId6Wkq-hA7o",
	Header = [{"Authorization",ServerKey}],
	Type = "application/json",
	Body =  binary_to_list(jsx:encode(#{ registration_ids => [ RegisteredId ], data => #{ message => Message } })),
io:format("Body : ~p.~n", [Body]),
	HTTPOptions = [],
	Options = [],
	_R = httpc:request(Method, {URL, Header, Type, Body}, HTTPOptions, Options).
%% 	try R of
%% 		{ok, {{_,200,_},_,RespBody}} ->
%% 			{ok, RespBody};
%% 		{error, Reason } ->
%% 			{error, Reason};
%% 		{ok, {{StatusLine,_,_},_,RespBody}} ->
%% 			{error, {StatusLine, RespBody}};
%% 		BigError -> {error, BigError}
%% 	catch
%% 		Throw -> {error, caught, Throw}
%% 	end.

sendMsgViaPid(Cond, Msg) ->
	case mongo_devices_ser:getParentId(Cond) of
		{ student_id, StudentId, parent_id, ParentId } ->
			io:format("Studebt & Parent ID : ~p.~n",[ { StudentId, ParentId } ]),
			case mongo_users_ser:getPids( integer_to_binary(ParentId) ) of
				{ pids, [] } -> pids_are_not_found;
				{ pids, L } ->
					[ binary_to_term(Pid) ! {irc, maps:merge(Msg,#{ student_id => StudentId })} || Pid <- L ]
			end,
			ok;
		{error, parent_id_not_found} -> parent_id_not_found
	end.

decodeGPSStatus(<<_:1, _:1, GPSRealTime:1, GPSPosition:1, LonDirection:1, LatDirection:1, Cource:10 >>) ->
	RealTime = case <<GPSRealTime:1>> of
		           <<0:1>> -> {gps_real_time, 0};  %% 0 => Real Time GPS
		           <<1:1>> -> {gps_real_time, 1}   %% 1 => Differential Positioning
	           end,
	Position = case <<GPSPosition:1>> of
		           <<0:1>> -> {gps_position, 0};  %% 0 => GPS has Not been positioned
		           <<1:1>> -> {gps_position, 1}   %% 1 => GPS has been positioned
	           end,
	LonDir = case <<LonDirection:1>> of
		         <<0:1>> -> {lon_direction, e};  %% 0 => East Longitude
		         <<1:1>> -> {lon_direction, w}   %% 1 => West Longitude
	         end,
	LatDir = case <<LatDirection:1>> of
		         <<0:1>> -> {lat_direction, s};  %% 0 => South Latitude
		         <<1:1>> -> {lat_direction, n}   %% 1 => North Latitude
	         end,
	[ RealTime, Position, LonDir, LatDir, {cource, Cource} ].

%% @doc Return the Lat / Lon in Decimal degrees (DD) Format for VT268 device.
%% VT265 Location Calculation Logic
%% In - 18 35.1526N 073 46.2691E
%% Process - .d = 35.1526 / 60
%%           Decimal Degrees (DD) = 18 + .d
getLatLanValDD({ vt268,  Bin }) ->
	B = binary_part(Bin,{0, byte_size(Bin)-1}),
	list_to_integer(binary_to_list(B, 1, 2)) + ( list_to_float(binary_to_list(B, 3, byte_size(B))) / 60);

%% @doc Return the Lat / Lon in Decimal degrees (DD) Format.
getLatLanValDD(Dec) ->
	Lat = (Dec/30000)/60,
%% 	io:format("Lat/Lan : ~p.~n",[Lat]),
	Lat.

%% @doc Return the Lat / Lon in Degrees and decimal minutes (DMM) Format.
%% getLatLandValDMM(Dec) ->
%% 	Dec_1 = (Dec/30000)/60,
%% 	io:format("Dec : ~p.~n",[Dec_1]), %% This is Lat / Lon in Decimal degrees (DD) 18.590185, 73.771110
%% 	Lat = trunc(Dec_1),
%% 	Dec_2 = Dec_1 - Lat,
%% 	io:format("Dec 2 : ~p.~n",[Dec_2]),
%% 	Lan = Dec_2*60,
%% 	{Lat,Lan}. %% This is Lat / Lon in Degrees and decimal minutes (DMM)

%% Search for a place using latitude and longitude coordinates
%% Open Google Maps.
%% Type your coordinates into the search box. Here are examples of accepted formats:
%% Degrees, minutes, and seconds (DMS): 41°24'12.2"N 2°10'26.5"E
%% Degrees and decimal minutes (DMM): 41 24.2028, 2 10.4418
%% Decimal degrees (DD): 41.40338, 2.17403

%%  Logic to get Lat and Lan Values.
%% 	26B3F3E(Hexadecimal)=40582974(Decimal)
%% 	40582974/30000=1352.7658
%% 	1352.7658/60=22.54609666666667
%% 	get 22
%% 	22.54609666666667-22=0.54609666666667
%% 	0.54609666666667*60=32.7658.

%% float_to_int(Dec) ->
%% 	list_to_integer(float_to_list(Dec,[{decimals,0}])).

to_dec(Hex) ->
	list_to_integer(hd(io_lib:format("~.16B", [Hex]))).

%% to_hex(?StartBit, _Len) ->
%% 	hd(io_lib:format("~.16B", [?StartBit])).

send(Msg) ->
	?MODULE ! Msg.

decodeTerminalInfo({ pt103, << _:1, GPSTracking:1, Status:3, Charging:1, _:2 >> }) ->
	GPSTrack    =   case <<GPSTracking:1>> of
						<<0:1>> -> off;
						<<1:1>> -> on
					end,
	Stat    =   case <<Status:3>> of
				   <<000:3>> -> 0;
				   <<001:3>> -> 1
%				   <<010:3>> -> 2;
%				   <<011:3>> -> 3;
%				   <<100:3>> -> 4;
%				   <<101:3>> -> 5;
%				   <<110:3>> -> 6;
%				   <<111:3>> -> 7
		       end,
	Charg   =   case <<Charging:1>> of
					<<0:1>> -> not_charging;
					<<1:1>> -> charging
	            end,
	#{ gps_tracking => GPSTrack, status => Stat, charging => Charg };

%% C0 - 1 1 0 000 0 0
decodeTerminalInfo({ tk102b, << Fortified:1, ACC:1, Charged:1, Status:3, GPS:1, Petrol:1 >> }) ->
	FortifiedVAL    =   case <<Fortified:1>> of
						<<0:1>> -> no;
						<<1:1>> -> yes
					end,
	ACCVAL    =   case <<ACC:1>> of
						<<0:1>> -> low;
						<<1:1>> -> hign
					end,
	ChargedVAL    =   case <<Charged:1>> of
						<<0:1>> -> no;
						<<1:1>> -> yes
					end,
	StatusVAL    =   case <<Status:3>> of
				   <<000:3>> -> 0;
				   <<001:3>> -> 1;
%				   <<010:3>> -> 2;
%				   <<011:3>> -> 3;
%				   <<100:3>> -> 4;
					_ -> 0
		       end,
	GPSVAL   =   case <<GPS:1>> of
					<<0:1>> -> not_located;
					<<1:1>> -> located
	            end,
	PetrolVAL   =   case <<Petrol:1>> of
					<<0:1>> -> on;
					<<1:1>> -> off
	            end,
	#{ fortified => FortifiedVAL, acc => ACCVAL, charged => ChargedVAL, status => StatusVAL, gps => GPSVAL, petrol_electricity => PetrolVAL }.

%% tracker_data_decoder:send({ send_command, "GPSON", 505163 }).

%% tracker_data_decoder:send({ send_command, "TCP", 505167 }).
%% tracker_data_decoder:send({ send_command, "#begin#190914", 505167 }).

%% 78780A13 00 05 04 0002004AE50E0D0A
%%
%% 00000100

%% tracker_data_decoder:send({<<120,120,25,16,15,4,8,16,39,29,199,1,253,195,52,7,235,64,135,0,20,59,0,2,0,42,82,94,13,10>>, self()})

%% tracker_data_decoder:send({<<120,120,25,16,15,4,8,16,44,16,200,1,253,206,143,7,235,46,159,27,21,102,0,2,0,39,20,230,13,10>>, self()})

%% tracker_data_decoder:send({<<120,120,10,19,0,4,1,0,2,0,81,105,35,13,10>>, self()})

cmd_to_list(CmdSt) -> cmd_to_list(CmdSt, []).

cmd_to_list([], Acc) -> Acc;
cmd_to_list([ H | T ], Acc) ->
	Str = io_lib:format("~w", [H]),
%% 	io:format("Str : ~p.~n", [ { Str } ]),
	{Int,[]} = string:to_integer(hd(Str)),
%% 	io:format("Int : ~p.~n", [Int]),
	cmd_to_list(T, Acc ++ [Int]).

%% tracker_data_decoder:send({ send_command, "GPSON", 505163 }).

%% tracker_data_decoder:sendLatLanToTrackPids({ device, 358740050123966 }, #{ event => current_location, data=> #{ lat => 18.664402, lan => 73.778069, speed => 25, timestamp => 1432562051 } }).

%% This function is used to Return the Geo Fence IN / OUT Status.
getGeoFenceStatus(StatusData) ->
	Status    =   case StatusData of
		              104 -> in;
		              112 -> out
	              end,
	Status.