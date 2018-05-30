open! Core
open! Async

type t =
  { messages : Protocol.Message.t Queue.t
  ; capacity : int
  ; bus      : (Protocol.Message.t -> unit) Bus.Read_write.t }
[@@deriving sexp_of]

let create ?(capacity = 20) () =
  let t =
    { messages = Queue.create ()
    ; capacity
    ; bus      =
        Bus.create [%here] Bus.Callback_arity.Arity1
          ~name:(Info.of_string "<messages>")
          ~on_subscription_after_first_write:Allow
          ~on_callback_raise:ignore }
  in
  (* cleanup old messages periodically *)
  every (sec 60.0) (fun () ->
    let rec loop () =
      match Queue.peek t.messages with
      | None -> ()
      | Some msg ->
        let diff = Time_ns.diff (Time_ns.now ()) msg.timestamp in
        if Time_ns.Span.(diff > hour)
        then (
          ignore (Queue.dequeue_exn t.messages : Protocol.Message.t);
          loop ())
    in
    loop ());
  t
;;

let invariant t =
  Invariant.invariant [%here] t sexp_of_t (fun () ->
    assert (Queue.length t.messages <= t.capacity))
;;

let add t req =
  let { Protocol.Message_request. name; content } = req in
  let msg =
    Protocol.Message.Fields.create
      ~name
      ~content
      ~timestamp:(Time_ns.now ())
  in
  Queue.enqueue t.messages msg;
  while Queue.length t.messages > t.capacity do
    ignore (Queue.dequeue_exn t.messages : Protocol.Message.t)
  done;
  Bus.write t.bus msg
;;

let to_list t = Queue.to_list t.messages

let pipe t = Bus.pipe1_exn (Bus.read_only t.bus) [%here]
