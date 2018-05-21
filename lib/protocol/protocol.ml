open! Core_kernel
open! Async_kernel
open Async_rpc_kernel

let set =
  Rpc.One_way.create
    ~name:"simple-state-set"
    ~version:0
    ~bin_msg:String.bin_t
;;

let subscribe =
  Rpc.Pipe_rpc.create ()
    ~name:"simple-state-subscribe"
    ~version:0
    ~bin_query:Unit.bin_t
    ~bin_response:String.bin_t
    ~bin_error:Unit.bin_t
;;
