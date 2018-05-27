open! Core_kernel
open! Async_kernel

module State = State

let is_localhost =
  Dom_html.window##.location##.hostname
  |> Js.to_string
  |> List.mem [ "localhost"; "127.0.0.1" ] ~equal:String.equal
;;

let ws_uri =
  if is_localhost
  then (Uri.of_string "ws://localhost:8080/")
  else (Uri.of_string "wss://ws.bcc32.com/")
;;

module Model = struct
  type t = string

  let cutoff a b = a = b
end

module Action = struct
  type t =
    | User_input of string
    | Value_changed of string
  [@@deriving sexp_of]

  let should_log _ = true
end

let apply_action (action : Action.t) _model state =
  match action with
  | User_input s -> State.query_set state s; s
  | Value_changed s -> s
;;

let update_visibility = Fn.id

let view model ~inject =
  let open Incr_dom.Incr.Let_syntax in
  let%map model = model in
  Virtual_dom.Vdom.(
    Node.input
      [ Attr.on_input (fun _ input -> inject (Action.User_input input))
      ; Attr.autofocus true
      ; Attr.string_property "value" model ]
      [])
;;

let on_startup ~schedule _model =
  let%bind state = State.create ~uri:ws_uri in
  let%map (r, _) = State.subscribe state in
  don't_wait_for (
    Pipe.iter' r ~f:(fun q ->
      let value = Queue.last_exn q in
      schedule (Action.Value_changed value);
      Deferred.unit));
  state
;;

let on_display ~old:_ _model _state = ()
