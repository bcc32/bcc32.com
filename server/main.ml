open! Core
open! Async

let set =
  Rpc.Rpc.implement Protocol.send (fun msgs req ->
    Messages.add msgs req;
    Deferred.unit)
;;

let subscribe =
  Rpc.State_rpc.implement Protocol.subscribe (fun msgs () ->
    Deferred.Result.return (Messages.to_list msgs, Messages.pipe msgs))
;;

let implementations =
  Rpc.Implementations.create_exn
    ~implementations:[ set; subscribe ]
    ~on_unknown_rpc:`Close_connection
;;

let msgs = Messages.create ()

let handle_tcp_connection addr reader writer =
  Log.Global.info !"connection from %{sexp: Socket.Address.Inet.t}" addr;
  let addr = Socket.Address.Inet.addr addr in
  (* only accept loopback connections *)
  if List.mem Unix.Inet_addr.[ localhost; localhost_inet6 ] addr
       ~equal:Unix.Inet_addr.equal
  then (
    Rpc_ws_transport.handle_connection reader writer
      ~implementations
      ~connection_state:(fun _ -> msgs)
      ~on_handshake_error:`Ignore
    |> Deferred.Or_error.ok_exn)
  else (Deferred.unit)
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
