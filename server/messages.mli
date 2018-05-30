open! Core
open! Async

type t [@@deriving sexp_of]

(** default [capacity] is 20. *)
val create
  :  ?capacity:int
  -> unit
  -> t

(** [add t msg] adds a message to the queue, removing the first one if the new
    size would exceed the capacity. *)
val add : t -> Protocol.Message_request.t -> unit

(** [to_list t] gets the current messages in the queue. *)
val to_list : t -> Protocol.Message.t list

(** [pipe t] returns a pipe of future messages added. *)
val pipe    : t -> Protocol.Message.t Pipe.Reader.t

include Invariant.S with type t := t
