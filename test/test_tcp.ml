open! Core
open! Async

let echo_handle_connection _ reader writer =
  Reader.transfer reader (Writer.pipe writer)
;;

let server () =
  Tcp.Server.create
    ~on_handler_error:`Raise
    Tcp.Where_to_listen.of_port_chosen_by_os
    echo_handle_connection
;;

let make_echo_connection () =
  let%bind server = server () in
  let port = Tcp.Server.listening_on server in
  let%map (_, reader, writer) =
    Tcp.connect
      (Tcp.Where_to_connect.of_host_and_port
         (Host_and_port.create ~host:"localhost" ~port))
  in
  (reader, writer)
;;

let%expect_test "echo connection hello world" =
  let%bind (reader, writer) = make_echo_connection () in
  Writer.write_line writer "hello world";
  let%bind () = Writer.flushed writer in
  match%bind Reader.read_line reader with
  | `Eof -> failwith "eof"
  | `Ok s ->
    print_string s;
    [%expect {| hello world |}]
;;
