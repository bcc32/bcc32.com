open! Core
open! Async

(** The [Uri.t] argument is used for calculating the correct HTTP headers. *)
val client
  :  ?implementations:'s Rpc.Implementations.t
  -> connection_state:(Rpc.Connection.t -> 's)
  -> ?handshake_timeout:Time_ns.Span.t
  -> ?heartbeat_config:Rpc.Connection.Heartbeat_config.t
  -> ?description:Info.t
  -> Uri.t
  -> Reader.t
  -> Writer.t
  -> Rpc.Connection.t Deferred.Or_error.t

val handle_connection
  :  ?handshake_timeout:Time.Span.t
  -> ?heartbeat_config:Rpc.Connection.Heartbeat_config.t
  -> implementations:'s Rpc.Implementations.t
  -> ?description:Info.t
  -> connection_state:(Rpc.Connection.t -> 's)
  -> on_handshake_error:[ `Call of exn -> unit | `Ignore | `Raise ]
  -> Reader.t
  -> Writer.t
  -> unit Deferred.Or_error.t
