open Core

let host = "fstream.binance.com"
let port = 443
let resource = "/stream?streams=btcusdt@trade/btcusdt@depth@100ms"
let ping_interval = Time_ns.Span.of_min 1.

(* i added some parsing to calculate delay in events *)
let on_message b = 
  (* printf "received message: %s\n" b; *)
  try
    let ts = Messages.public_event_of_string b |> Messages.timestamp in
    let now = Time_ns.(now () |> to_span_since_epoch) in
    printf "received message: %s\n" Time_ns.Span.(now - ts |> to_string_hum);
  with e -> printf "error: %s\n" (Exn.to_string e);
  Out_channel.flush stdout
;;

let start ~sw ~env =
  Websocket.connect
    ~ssl:()
    ~host
    ~port
    ~resource
    ~on_message
    ~ping_interval
    ~sw
    env
  |> function
  | Ok () ->
    print_endline "websocket connection shutdown";
    Out_channel.flush stdout
  | Error err -> Error.raise err
;;

let () = Eio_main.run @@ fun env -> Eio.Switch.run @@ fun sw -> start ~sw ~env
