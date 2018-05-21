open! Core_kernel
open! Async_kernel
open Async_rpc_kernel

val set : string Rpc.One_way.t

val subscribe : (unit, string, unit) Rpc.Pipe_rpc.t
