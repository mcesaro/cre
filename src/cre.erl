%% -*- erlang -*-
%%
%% cre
%%
%% Copyright 2015-2018 Jörgen Brandt
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% -------------------------------------------------------------------
%% @author Jörgen Brandt <joergen.brandt@onlinehome.de>
%% @version 0.1.8
%% @copyright 2015-2018 Jörgen Brandt
%%
%%
%%
%%
%%
%% @end
%% -------------------------------------------------------------------

-module( cre ).
-behaviour( application ).


%%====================================================================
%% Exports
%%====================================================================

-export( [start/0, pid/1] ).
-export( [start/2, stop/1] ).
-export( [main/1] ).

%%====================================================================
%% Includes
%%====================================================================

-include( "cre.hrl" ).


%%====================================================================
%% Definitions
%%====================================================================

-define( PORT, 4142 ).

%%====================================================================
%% API functions
%%====================================================================

-spec start() -> ok | {error, _}.

start() ->
  {ok, _} = application:ensure_all_started( cre ),
  ok.


-spec pid( CreNode :: atom() ) -> {ok, pid()} | {error, undefined}.

pid( CreNode ) when is_atom( CreNode ) ->

  % query cre process pid
  case rpc:call( CreNode, erlang, whereis, [cre_master] ) of
    undefined          -> {error, cre_process_not_registered};
    {badrpc, nodedown} -> {error, cre_node_down};
    CrePid             -> {ok, CrePid}
  end.


%%====================================================================
%% Application callback functions
%%====================================================================

-spec start( Type :: _, Args :: _ ) -> {ok, pid()} | {error, _}.

start( _Type, _Args ) ->

  error_logger:info_report( [{info,        "starting cre"},
                             {application, cre},
                             {vsn,         ?VSN},
                             {node,        node()},
                             {port,        ?PORT}] ),

  Dispatch =
    cowboy_router:compile(
      [{'_', [
              {"/[status.json]", cre_status_handler, []},
              {"/history.json", cre_history_handler, []}
             ]}] ),

  {ok, _} = cowboy:start_clear( status_listener,
                                [{port, ?PORT}],
                                 #{ env => #{ dispatch => Dispatch } } ),

  cre_sup:start_link().


-spec stop( State :: _ ) -> ok.

stop( _State ) ->
  ok.


%%====================================================================
%% Escript main function
%%====================================================================


-spec main( Args :: _ ) -> ok.

main( _Args ) ->



  % start the cre application
  ok = start(),


  % create monitor
  _ = monitor( process, cre_sup ),

  % wait indefinitely
  receive
  	{'DOWN', _Ref, process, _Object, _Info} ->
      timer:sleep( 1000 )
  end.