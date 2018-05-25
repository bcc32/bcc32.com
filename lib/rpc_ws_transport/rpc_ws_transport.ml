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
  let (r, w) =
    Websocket_async.client_ez
      uri
      (Socket.create Socket.Type.unix) (* TODO remove when vbmithr/ocaml-websocket#101 fix gets released *)
      reader
      writer
  in
  let transport =
    Async_rpc_kernel.Pipe_transport.(create Kind.string r w)
  in
  Async_rpc_kernel.Rpc.Connection.create transport
    ?implementations
    ~connection_state
    ?handshake_timeout
    ?heartbeat_config
    ?description
  |> Deferred.Or_error.of_exn_result
;;

(* TODO use [Pipe.{create_reader, create_writer}] where possible *)
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
  let (app_to_ws_r, app_to_ws_w) = Pipe.create () in
  let (ws_to_app_r, ws_to_app_w) = Pipe.create () in
  let (app_to_rpc_r, app_to_rpc_w) = Pipe.create () in
  let (rpc_to_app_r, rpc_to_app_w) = Pipe.create () in

  (* ignore [final] because we don't really care about the actual WebSocket
     frames; Rpc server will simply accept a stream of binary data *)
  let pipeline_in =
    Pipe.iter ws_to_app_r ~f:(fun ({ Frame.opcode; content; extension = _; final = _ } as frame) ->
      match opcode with
      | Continuation | Text | Binary -> Pipe.write app_to_rpc_w content
      | Close ->
        let%map () = Pipe.write app_to_ws_w (Frame.close 1000) in
        Pipe.close app_to_ws_w
      | Ping -> Pipe.write app_to_ws_w { frame with opcode = Pong }
      | Pong -> Deferred.unit
      | Ctrl _ | Nonctrl _ -> Pipe.write app_to_ws_w (Frame.close 1002))
    |> Deferred.ok
  in
  let pipeline_out =
    Pipe.iter rpc_to_app_r ~f:(fun content ->
      Pipe.write app_to_ws_w (Frame.create () ~opcode:Binary ~content:(String.copy content)))
    |> Deferred.ok
  in
  let ws_server =
    Websocket_async.server ()
      ~reader
      ~writer
      ~app_to_ws:app_to_ws_r
      ~ws_to_app:ws_to_app_w
  in
  let transport = Async_rpc_kernel.Pipe_transport.(create Kind.string app_to_rpc_r rpc_to_app_w) in
  let rpc_server =
    Rpc.Connection.serve_with_transport transport
      ~handshake_timeout
      ~heartbeat_config
      ~implementations
      ~description
      ~connection_state
      ~on_handshake_error
    |> Deferred.ok
  in
  Deferred.Or_error.all_unit
    [ pipeline_in
    ; pipeline_out
    ; ws_server
    ; rpc_server ]
;;
