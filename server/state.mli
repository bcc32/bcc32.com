open! Core
open! Async

type 'a t

val create : 'a -> 'a t
val bus : 'a t -> ('a -> unit) Bus.Read_only.t
val set : 'a t -> 'a -> unit
