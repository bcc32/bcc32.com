open! Core_kernel
open! Async_kernel

type t =
  | Init_msgs     of Protocol.Message.t list
  | Input_content of string
  | Input_name    of string
  | Receive_msg   of Protocol.Message.t
  | Send_msg
[@@deriving sexp_of]

let should_log _ = true
