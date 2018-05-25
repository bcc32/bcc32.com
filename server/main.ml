open! Core
open! Async

let state = State.create ""

let implementations =
  Rpc.Implementations.create_exn
    ~implementations:[]
    ~on_unknown_rpc:`Close_connection
;;

let handle_tcp_connection addr reader writer =
  Log.Global.debug !"connection from %{sexp: Socket.Address.Inet.t}" addr;
  Rpc_ws_transport.handle_connection reader writer
    ~handshake_timeout:None
    ~heartbeat_config:None
    ~implementations
    ~description:(Info.of_string "simple state server")
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
