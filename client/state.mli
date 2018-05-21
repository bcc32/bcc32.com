open! Core_kernel
open! Async_kernel
open Async_rpc_kernel

type t

val create
  :  uri:Uri.t
  -> t Deferred.t

val query_set
  :  t
  -> string
  -> unit

val subscribe
  :  t
  -> (string Pipe.Reader.t * Rpc.Pipe_rpc.Metadata.t) Deferred.t
