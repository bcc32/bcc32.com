open! Core
open! Async

let echo_protocol =
  Rpc.Rpc.create
    ~name:"echo"
    ~version:0
    ~bin_query:String.bin_t
    ~bin_response:String.bin_t
;;

let server () =
  let implementations = [ Rpc.Rpc.implement' echo_protocol (Fn.const Fn.id) ] in
  let implementations =
    Rpc.Implementations.create_exn ~implementations ~on_unknown_rpc:`Raise
  in
  let handle_connection _addr reader writer =
    Rpc_ws_transport.handle_connection
      reader
      writer
      ~implementations
      ~description:(Info.of_string "ws rpc test server")
      ~connection_state:(Fn.const ())
      ~on_handshake_error:`Raise
    |> Deferred.Or_error.ok_exn
  in
  Tcp.Server.create
    ~on_handler_error:`Raise
    Tcp.Where_to_listen.of_port_chosen_by_os
    handle_connection
;;

let ws_client () =
  let%bind server = server () in
  let server_addr = Tcp.Server.listening_on_address server in
  let%bind _sock, reader, writer =
    Tcp.connect (Tcp.Where_to_connect.of_inet_address server_addr)
  in
  let uri =
    let (`Inet (host, port)) = server_addr in
    Uri.make () ~host:(Unix.Inet_addr.to_string host) ~port
  in
  Rpc_ws_transport.client ~connection_state:(Fn.const ()) uri reader writer
;;

module Frame = Websocket_async.Frame

let%expect_test "echo RPC over websocket" =
  let%bind connection = ws_client () |> Deferred.Or_error.ok_exn in
  let dispatch = Rpc.Rpc.dispatch_exn echo_protocol connection in
  let%bind result = dispatch "hello, world" in
  print_string result;
  [%expect {| hello, world |}]
;;
