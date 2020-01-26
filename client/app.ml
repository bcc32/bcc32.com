open! Core_kernel
open! Async_kernel
open Js_of_ocaml
module Action = Action
module Model = Model
module State = State

let is_localhost =
  Dom_html.window##.location##.hostname
  |> Js.to_string
  |> List.mem [ "localhost"; "127.0.0.1" ] ~equal:String.equal
;;

let ws_uri =
  if is_localhost
  then Uri.of_string "ws://localhost:8080/"
  else Uri.of_string "wss://ws.bcc32.com/"
;;

let apply_action (action : Action.t) model state =
  match action with
  | Init_msgs msgs -> Model.with_messages model msgs
  | Input_content content -> { model with Model.input_content = content }
  | Input_name name -> { model with Model.input_name = name }
  | Receive_msg msg -> Model.add_with_limit model msg
  | Send_msg ->
    if Model.input_content model <> ""
    then State.send state (Model.input_to_message_request model);
    (Dom_html.getElementById_exn "content")##focus;
    Model.clear_input_content model
;;

let update_visibility = Fn.id

let view_text_input ?(extra_attrs = []) ~inject name value on_input =
  let open Virtual_dom.Vdom in
  Node.label
    []
    [ Node.text name
    ; Node.input
        (Attr.on_keypress (fun kbe ->
           match Incr_dom_widgets.Keyboard_event.key kbe with
           | Enter -> inject Action.Send_msg
           | _ -> Event.Ignore)
         :: Attr.on_input on_input
         :: Attr.string_property "value" value
         :: extra_attrs)
        []
    ]
;;

let view_input_content ~inject content =
  view_text_input
    ~inject
    ~extra_attrs:Virtual_dom.Vdom.Attr.[ autofocus true; id "content" ]
    "content"
    content
    (fun _ value -> inject (Action.Input_content value))
;;

let view_input_name ~inject name =
  view_text_input ~inject "name" name (fun _ value -> inject (Action.Input_name value))
;;

let view_header =
  let open Virtual_dom.Vdom in
  let field name = Node.th [] [ Node.text name ] in
  Node.tr [] [ field "name"; field "content"; field "timestamp" ]
;;

let string_of_time_ns time_ns =
  time_ns
  |> Time_ns.to_span_since_epoch
  |> Time_ns.Span.to_sec
  |> Time.Span.of_sec
  |> Time.of_span_since_epoch
  |> Time.to_string
;;

let view_message msg =
  let open Virtual_dom.Vdom in
  let td text = Node.td [] [ Node.text text ] in
  Node.tr
    []
    [ td (Protocol.Message.name msg)
    ; td (Protocol.Message.content msg)
    ; td (Protocol.Message.timestamp msg |> string_of_time_ns)
    ]
;;

let view model ~inject =
  let open Incr_dom.Incr.Let_syntax in
  let%map name = model >>| Model.input_name
  and content = model >>| Model.input_content
  and messages = model >>| Model.messages >>| Fqueue.to_list in
  let open Virtual_dom.Vdom in
  Node.div
    []
    [ Node.table [] (view_header :: List.map messages ~f:view_message)
    ; view_input_content ~inject content
    ; view_input_name ~inject name
    ]
;;

let on_startup ~schedule _model = State.create ~uri:ws_uri ~schedule
let on_display ~old:_ _model _state = ()
let initial_model = Model.empty
