open! Core_kernel
open! Async_kernel

let () =
  Incr_dom.Start_app.start
    (module App)
    ~debug:true
    ~initial_model:App.initial_model
    ~bind_to_element_with_id:"app"
;;
