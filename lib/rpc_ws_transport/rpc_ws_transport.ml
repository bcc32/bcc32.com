open! Core
open! Async

(* TODO change to Websocket.Frame and inline when vbmithr/ocaml-websocket#100
   gets merged. *)
module Frame = Websocket_async.Frame

let client
      ?implementations
      ~connection_state
      ?handshake_timeout
      ?heartbeat_config
      ?description
      uri
      reader
      writer
  =
  let r, w = Websocket_async.client_ez uri reader writer in
  let transport = Async_rpc_kernel.Pipe_transport.(create Kind.string r w) in
  Async_rpc_kernel.Rpc.Connection.create
    transport
    ?implementations
    ~connection_state
    ?handshake_timeout
    ?heartbeat_config
    ?description
  |> Deferred.Or_error.of_exn_result
;;

let handle_connection
      ?handshake_timeout
      ?heartbeat_config
      ~implementations
      ?(description = Info.create_s [%sexp [%here]])
      ~connection_state
      ~on_handshake_error
      reader
      writer
  =
  let app_to_ws_r, app_to_ws_w = Pipe.create () in
  let app_to_rpc_r, app_to_rpc_w = Pipe.create () in
  (* ignore [final] because we don't really care about the actual WebSocket
     frames; Rpc server will simply accept a stream of binary data *)
  let ws_to_app =
    Pipe.create_writer
      (Pipe.iter ~f:(fun ({ Frame.opcode; content; extension = _; final = _ } as frame) ->
         match opcode with
         | Continuation | Text | Binary -> Pipe.write app_to_rpc_w content
         | Close ->
           let%map () = Pipe.write app_to_ws_w (Frame.close 1000) in
           Pipe.close app_to_ws_w
         | Ping -> Pipe.write app_to_ws_w { frame with opcode = Pong }
         | Pong -> Deferred.unit
         | Ctrl _ | Nonctrl _ -> Pipe.write app_to_ws_w (Frame.close 1002)))
  in
  let rpc_to_app =
    Pipe.create_writer
      (Pipe.iter ~f:(fun content ->
         Pipe.write app_to_ws_w (Frame.create () ~opcode:Binary ~content)))
  in
  let ws_server =
    Websocket_async.server () ~reader ~writer ~app_to_ws:app_to_ws_r ~ws_to_app
  in
  let transport =
    Async_rpc_kernel.Pipe_transport.(create Kind.string app_to_rpc_r rpc_to_app)
  in
  let rpc_server =
    Rpc.Connection.serve_with_transport
      transport
      ~handshake_timeout
      ~heartbeat_config
      ~implementations
      ~description
      ~connection_state
      ~on_handshake_error
    |> Deferred.ok
  in
  Deferred.Or_error.all_unit [ ws_server; rpc_server ]
;;
