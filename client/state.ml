open! Core_kernel
open! Async_kernel
open Async_rpc_kernel

type t =
  { connection : Rpc.Connection.t
  }

let create ~uri =
  let%map connection = Async_js.Rpc.Connection.client_exn () ~uri in
  { connection }
;;

let query_set t value = Rpc.One_way.dispatch_exn Protocol.set t.connection value

let subscribe t = Rpc.Pipe_rpc.dispatch_exn Protocol.subscribe t.connection ()
