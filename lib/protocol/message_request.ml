open! Core_kernel
open! Async_kernel

module M = struct
  type t =
    { name : string
    ; content : string
    }
  [@@deriving bin_io, compare, fields, sexp]
end

include M
include Comparable.Make_binable (M)
