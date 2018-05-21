open! Core
open! Async

val serve
  :  handshake_timeout:Time.Span.t option
  -> heartbeat_config:Rpc.Connection.Heartbeat_config.t option
  -> implementations:'s Rpc.Implementations.t
  -> description:Info.t
  -> connection_state:(Rpc.Connection.t -> 's)
  -> on_handshake_error:[ `Call of exn -> unit | `Ignore | `Raise ]
  -> Reader.t
  -> Writer.t
  -> unit Deferred.t
