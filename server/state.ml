open! Core
open! Async

type 'a t =
  { mutable value : 'a
  ; bus : ('a -> unit) Bus.Read_write.t
  }

let create init =
  let bus =
    Bus.create
      [%here]
      Bus.Callback_arity.Arity1
      ~on_subscription_after_first_write:Allow_and_send_last_value
      ~on_callback_raise:(fun e -> Log.Global.error !"%{Error#hum}" e)
  in
  { value = init; bus }
;;

let bus t = Bus.read_only t.bus

let set t value =
  t.value <- value;
  Bus.write t.bus value
;;
