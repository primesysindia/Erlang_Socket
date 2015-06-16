%%%-------------------------------------------------------------------
%%% @author primesys001
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%        Handles the Files Upload handling.
%%% @end
%%% Created : 13. Jun 2015 4:30 PM
%%%-------------------------------------------------------------------
-module(upload_handler).
-author("Piyush Sable").

-export([init/3]).
-export([handle/2]).
-export([terminate/3]).

-define(FILE_UPLOAD_DIR_PATH, <<"../../uploads/">>).

%% API
init(_Transport, Req, []) ->
	{ok, Req, undefined}.

handle(Req, State) ->
%% 	io:format("Got Req : ~p.~n",[cowboy_req:qs_val(<<"inputfile">>,Req)]),
	case cowboy_req:parse_header(<<"content-type">>, Req) of
		{ok, {<<"multipart">>, <<"form-data">>, _}, Req1} ->
			case decode_req(cowboy_req:multipart_data(Req1)) of
				{ file_not_selected, Req2 } ->
					{ok, Req3} = cowboy_req:reply(411, [{<<"content-type">>, <<"text/plain">>}], "file_not_selected", Req2),
					{ok, Req3, State};
				{file_uploaded, Req2} ->
					{ok, Req3} = cowboy_req:reply(200, [{<<"content-type">>, <<"text/plain">>}], "file_upload_success!", Req2),
					{ok, Req3, State}
			end;
		{ok, _, Req1} ->
			{ok, Req2} = cowboy_req:reply(415, [{<<"content-type">>, <<"text/plain">>}], "only_multipart/form-data_requests_are_allowed !", Req1),
			{ok, Req2, State}
	end.

terminate(_Reason, _Req, _State) ->
	ok.

%% Private Functions

%% Decode the Multipart/form-data Request.
%% Accept the Headers, extract file name and create the file descriptor with the given file name.
decode_req({headers, Headers, Req}) ->
	{ filename, FileName } = parse_headers(Headers),
	case size(FileName) of
		0 ->
			{ file_not_selected, Req };
		_N ->
			Timestamp = integer_to_binary(irc:get_date_time()),
			{ok, Fd} = file:open(<< ?FILE_UPLOAD_DIR_PATH/binary, Timestamp/binary, <<"_">>/binary, FileName/binary >>, [write, binary]),
			decode_req(cowboy_req:multipart_data(Req), Fd)
	end.

%% Accept the Body Part the the request recursively and write it to the File.
decode_req({body, Body, Req}, Fd) ->
	ok = file:write(Fd, Body),
	decode_req(cowboy_req:multipart_data(Req), Fd);

%% Accept the end of the Body part and closes the File descriptor.
decode_req({end_of_part, Req}, Fd) ->
	file:close(Fd),
	{file_uploaded, Req}.

%% Parse File Headers and returns the filename.
parse_headers(Headers) ->
	case proplists:get_value(<<"content-disposition">>,Headers) of
		undefined ->
			{error,"No content disposition in header"};
		Value ->
			{_FormData,Props} = cowboy_multipart:content_disposition(Value),
%% 			Name = proplists:get_value(<<"ref_id">>,Props),
			FileName = proplists:get_value(<<"filename">>,Props),
			{ filename, FileName }
	end.

%% Return the FileName from the Request.
%% get_file_name({_, Bin}) ->
%% 	[_,F] = binary:split(Bin, <<"filename=\"">>),
%% 	hd(binary:split(F, <<"\"">>)).