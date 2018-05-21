open! Core
open! Async

(* TODO change to Websocket.Frame and inline when vbmithr/ocaml-websocket#100
   gets merged. *)
module Frame = Websocket_async.Frame

let tap_r reader =
  let r1, w1 = Pipe.create () in
  let r2, w2 = Pipe.create () in
  Reader.pipe reader
  |> Pipe.iter ~f:(fun x ->
    let%map () = Pipe.write w1 x
    and     () = Pipe.write w2 x in
    ())
  |> don't_wait_for;
  Deferred.both
    (Reader.of_pipe (Info.create ~here:[%here] "r1" () sexp_of_unit) r1)
    (Reader.of_pipe (Info.create ~here:[%here] "r2" () sexp_of_unit) r2)
;;

let make_transport tcp_reader tcp_writer =
  let%bind tcp_reader, hook = tap_r tcp_reader in

  Reader.pipe hook
  |> Pipe.iter_without_pushback ~f:(Debug.eprintf !"read %{String.Hexdump#hum}")
  |> don't_wait_for;

  let (app_to_ws_r, app_to_ws_w) = Pipe.create () in
  let (app_to_rpc_r, app_to_rpc_w) = Pipe.create () in

  let write_frame = Pipe.write app_to_ws_w in
  let write_content_to_ws content =
    Frame.create ()
      ~opcode:Binary
      ~content
    |> write_frame
  in
  let write_content_to_rpc = Pipe.write app_to_rpc_w in

  let rpc_to_app_w =
    Pipe.create_writer (fun r -> Pipe.iter r ~f:write_content_to_ws)
  in

  let ws_to_app_w =
    Pipe.create_writer (fun r ->
      (* ignore [final] because we don't really care about the actual WebSocket
         frames; Rpc server will just take a stream of binary data *)
      Pipe.iter r ~f:(fun ({ Frame.opcode; extension; final = _; content } as f) ->
        Debug.eprintf "%s" (Frame.show f);
        Debug.eprintf !"%{String.Hexdump#hum}" content;
        match opcode with
        | Continuation | Text | Binary -> write_content_to_rpc content
        (* FIXME how should we close the connection? *)
        | Close ->
          Log.Global.info "client closed connection";
          Deferred.all_unit
            [ Reader.close tcp_reader
            ; Writer.close tcp_writer ]
        | Ping ->
          Frame.create ()
            ~opcode:Pong
            ~extension
            ~content
          |> write_frame
        | Pong -> Deferred.unit
        | Ctrl _ | Nonctrl _ -> failwith "unrecognized opcode"))
  in
  don't_wait_for begin
    match%map
      Monitor.try_with_join_or_error ~here:[%here] (fun () ->
        Websocket_async.server ()
          ~log:(force Log.Global.log)
          ~reader:tcp_reader
          ~writer:tcp_writer
          ~app_to_ws:app_to_ws_r
          ~ws_to_app:ws_to_app_w)
    with
    | Ok () -> ()
    | Error e -> Log.Global.error !"%{Error#hum}" e
  end;
  Async_rpc_kernel.Pipe_transport.(create Kind.string app_to_rpc_r rpc_to_app_w)
  |> Deferred.return
;;

let serve
      ~handshake_timeout
      ~heartbeat_config
      ~implementations
      ~description
      ~connection_state
      ~on_handshake_error
      reader
      writer
  =
  make_transport reader writer
  >>= Rpc.Connection.serve_with_transport
        ~handshake_timeout
        ~heartbeat_config
        ~implementations
        ~description
        ~connection_state
        ~on_handshake_error
;;
