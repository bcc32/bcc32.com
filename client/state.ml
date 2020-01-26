open! Core_kernel
open! Async_kernel
open Async_rpc_kernel

type t =
  { connection : Rpc.Connection.t
  ; schedule_action : Action.t -> unit
  }

let create ~uri ~schedule_action =
  let%bind connection = Async_js.Rpc.Connection.client_exn () ~uri in
  match%map Rpc.State_rpc.dispatch Protocol.subscribe connection () with
  | Error e -> Error.raise e
  | Ok (Error ()) -> raise_s [%message "protocol error" [%here] (uri : Uri_sexp.t)]
  | Ok (Ok (init, updates, _metadata)) ->
    schedule_action (Action.Init_msgs init);
    don't_wait_for
      (Pipe.iter_without_pushback updates ~f:(fun msg ->
         schedule_action (Action.Receive_msg msg)));
    { connection; schedule_action }
;;

let send t value = don't_wait_for (Rpc.Rpc.dispatch_exn Protocol.send t.connection value)
