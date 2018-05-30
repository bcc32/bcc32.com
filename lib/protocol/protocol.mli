open! Core_kernel
open! Async_kernel
open Async_rpc_kernel

module Message         = Message
module Message_request = Message_request

val send : (Message_request.t, unit) Rpc.Rpc.t

val subscribe : (unit, Message.t list, Message.t, unit) Rpc.State_rpc.t
