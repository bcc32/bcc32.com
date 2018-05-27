open! Core_kernel
open! Async_kernel

include Incr_dom.App_intf.S_simple
  with type Model.t = string
