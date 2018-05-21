open! Core_kernel
open! Async_kernel

module Model = struct
  type t = string

  let initial = ""

  let cutoff a b = a = b
end

module Action = struct
  type t =
    | User_input of string
    | Value_changed of string
  [@@deriving sexp_of]

  let should_log _ = false
end

module App
  : Incr_dom.App_intf.S_simple
    with module Model = Model
    with module Action = Action
= struct
  module Model  = Model
  module Action = Action
  module State  = State

  let apply_action (action : Action.t) _model _state =
    match action with
    | User_input s -> s (* TODO send a thing to the server *)
    | Value_changed s -> s
  ;;

  let update_visibility = Fn.id

  let view model ~inject =
    let open Incr_dom.Incr.Let_syntax in
    let%map model = model in
    Virtual_dom.Vdom.(
      Node.input
        [ Attr.on_input (fun _ input -> inject (Action.User_input input))
        ; Attr.value model ]
        [])
  ;;

  let on_startup ~schedule _model =
    let%bind state =
      State.create
        ~uri:(Uri.of_string "ws://localhost:8080/")
    in
    let%map (r, _) = State.subscribe state in
    don't_wait_for (
      Pipe.iter' r ~f:(fun q ->
        let value = Queue.last_exn q in
        schedule (Action.Value_changed value);
        Deferred.unit));
    state
  ;;

  let on_display ~old:_ _model _state = ()
end

let () =
  Incr_dom.Start_app.simple (module App)
    ~initial_model:Model.initial
    ~bind_to_element_with_id:"app"
;;