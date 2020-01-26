open! Core_kernel
open! Async_kernel

type t =
  { messages : Protocol.Message.t Fqueue.t
  ; input_content : string
  ; input_name : string
  }
[@@deriving fields, sexp]

include Comparable.S with type t := t

val empty : t
val input_to_message_request : t -> Protocol.Message_request.t
val add_with_limit : t -> Protocol.Message.t -> t
val clear_input_content : t -> t
val with_messages : t -> Protocol.Message.t list -> t
val cutoff : t -> t -> bool
