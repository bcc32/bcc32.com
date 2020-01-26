open! Core_kernel
open! Async_kernel

type t =
  { name : string
  ; content : string
  }
[@@deriving bin_io, fields, sexp]

include Comparable.S with type t := t
