open! Core_kernel
open! Async_kernel

module M = struct
  type t =
    { messages      : Protocol.Message.t Fqueue.t
    ; input_content : string
    ; input_name    : string }
  [@@deriving compare, fields, sexp]
end
include M
include Comparable.Make(M)

let empty = { messages = Fqueue.empty; input_content = ""; input_name = "Anonymous" }

let input_to_message_request t =
  Protocol.Message_request.Fields.create
    ~name:t.input_name
    ~content:t.input_content
;;

let limit = 10

let add_with_limit t msg =
  let messages = Fqueue.enqueue t.messages msg in
  let messages =
    if Int.(>) (Fqueue.length messages) limit
    then (snd (Fqueue.dequeue_exn messages))
    else messages
  in
  { t with messages }
;;

let clear_input_content t = { t with input_content = "" }

let with_messages t msgs = { t with messages = Fqueue.of_list msgs }

let cutoff = (=)
