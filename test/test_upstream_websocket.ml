open! Core
open! Async

(* TODO change to Websocket.Frame and inline when vbmithr/ocaml-websocket#100
   gets merged. *)
module Frame = Websocket_async.Frame

let with_connection ~f =
  let websocket_serve reader writer =
    let (ws_to_app_r, ws_to_app_w) = Pipe.create () in
    let (app_to_ws_r, app_to_ws_w) = Pipe.create () in
    let%map () =
      Pipe.transfer' ws_to_app_r app_to_ws_w
        ~f:(fun q ->
          q
          |> Queue.filter_map ~f:(fun ({ Frame.opcode; extension = _; final = _; content } as frame) ->
            match opcode with
            | Continuation | Text | Binary -> Some { frame with content = String.rev content }
            | Close -> Pipe.close app_to_ws_w; Some (Frame.close 1000)
            | Ping -> Some (Frame.create () ~opcode:Pong ~content)
            | Pong -> None
            | Ctrl _ | Nonctrl _ -> Some (Frame.close 1002))
          |> return)
    and () =
      Websocket_async.server ()
        ~reader
        ~writer
        ~app_to_ws:app_to_ws_r
        ~ws_to_app:ws_to_app_w
      |> Deferred.Or_error.ok_exn
    in
    ()
  in
  let%bind tcp_server =
    Tcp.Server.create
      ~on_handler_error:`Raise
      Tcp.Where_to_listen.of_port_chosen_by_os
      (fun _ r w -> websocket_serve r w)
  in
  let%bind (_, client_reader, client_writer) =
    tcp_server
    |> Tcp.Server.listening_on_address
    |> Tcp.Where_to_connect.of_inet_address
    |> Tcp.connect
  in
  let (ws_to_app, app_to_ws) =
    Websocket_async.client_ez (Uri.of_string "http://localhost")
      (Socket.create Socket.Type.unix)
      client_reader
      client_writer
  in
  f ~app_to_ws ~ws_to_app
;;

let%expect_test "websocket reverse echo" =
  with_connection ~f:(fun ~app_to_ws ~ws_to_app ->
    let content = "hello world" in
    let%bind () = Pipe.write app_to_ws content in
    let%bind _ = Pipe.downstream_flushed app_to_ws in
    let%bind result = Pipe.read ws_to_app in
    print_s [%sexp (result : [ `Eof | `Ok of string ])];
    let%bind () = [%expect {| (Ok "dlrow olleh") |}] in
    Pipe.close app_to_ws;
    let%bind result = Pipe.read ws_to_app in
    print_s [%sexp (result : [ `Eof | `Ok of string ])];
    [%expect {| Eof |}])
;;
