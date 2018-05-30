open! Core_kernel
open! Async_kernel

module M = struct
  module M0 = struct
    type t =
      { name      : string
      ; content   : string
      ; timestamp : Time_ns.t }
    [@@deriving bin_io, compare, fields]
  end
  include M0

  module M_sexp = struct
    type t = M0.t =
      { name      : string
      ; content   : string
      ; timestamp : Time_ns.Alternate_sexp.t }
    [@@deriving sexp]
  end

  let sexp_of_t = M_sexp.sexp_of_t
  let t_of_sexp = M_sexp.t_of_sexp
end
include M

include Comparable.Make_binable(M)
