open! Core_kernel
open! Async_kernel

type t

val create
  :  uri:Uri.t
  -> schedule:(Action.t -> unit)
  -> t Deferred.t

val send
  :  t
  -> Protocol.Message_request.t
  -> unit
