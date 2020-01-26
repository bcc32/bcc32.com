open! Core_kernel
open! Async_kernel
open Async_rpc_kernel
module Message = Message
module Message_request = Message_request

let send =
  Rpc.Rpc.create
    ~name:"message-send"
    ~version:0
    ~bin_query:Message_request.bin_t
    ~bin_response:Unit.bin_t
;;

let subscribe =
  Rpc.State_rpc.create
    ()
    ~name:"message-subscribe"
    ~version:0
    ~bin_query:Unit.bin_t
    ~bin_state:(List.bin_t Message.bin_t)
    ~bin_update:Message.bin_t
    ~bin_error:Unit.bin_t
;;
