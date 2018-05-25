open! Core
open! Async

let set = Rpc.One_way.implement Protocol.set State.set

let subscribe =
  Rpc.Pipe_rpc.implement_direct Protocol.subscribe (fun state () writer ->
    let r = Bus.pipe1_exn (State.bus state) [%here] in
    don't_wait_for (
      Pipe.iter r ~f:(fun x ->
        match Rpc.Pipe_rpc.Direct_stream_writer.write writer x with
        | `Closed -> Pipe.close_read r; Deferred.unit
        | `Flushed f -> f));
    Deferred.(ok unit))
;;

let implementations =
  Rpc.Implementations.create_exn
    ~implementations:[ set; subscribe ]
    ~on_unknown_rpc:`Close_connection
;;

let state = State.create ""

let handle_tcp_connection addr reader writer =
  Log.Global.info !"connection from %{sexp: Socket.Address.Inet.t}" addr;
  Rpc_ws_transport.handle_connection reader writer
    ~implementations
    ~connection_state:(fun _ -> state)
    ~on_handshake_error:`Ignore
  |> Deferred.Or_error.ok_exn
;;

let serve port =
  let%bind server =
    Tcp.Server.create
      ~on_handler_error:`Ignore
      (Tcp.Where_to_listen.of_port port)
      handle_tcp_connection
  in
  Log.Global.info "listening on port %d" port;
  Tcp.Server.close_finished server
;;

let main =
  Command.async ~summary:"run a server" begin
    let open Command.Let_syntax in
    let%map_open port =
      flag "port" (optional_with_default 8080 int)
        ~doc:"PORT port to listen on"
    in
    fun () -> serve port
  end
;;

let () = Command.run main
