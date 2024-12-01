open Core
open Eio.Std
open Httpun_ws

type t = Wsd.t

let start_ping_loop ~sw ~clock interval wsd =
  let interval_seconds = Time_ns.Span.to_sec interval in
  let rec ping_loop () =
    if not (Wsd.is_closed wsd)
    then (
      traceln "sending ping from ping_loop";
      Out_channel.flush stdout;
      Wsd.send_ping wsd;
      (* Wsd.flushed wsd (fun () -> traceln "ping flushed"); *)
      Eio.Time.sleep clock interval_seconds;
      ping_loop ())
    else `Stop_daemon
  in
  Eio.Fiber.fork_daemon ~sw ping_loop
;;

let websocket_handler ~sw ~clock ?ping_interval ~on_message promise wsd =
  Option.iter ping_interval ~f:(fun interval -> start_ping_loop ~sw ~clock interval wsd);
  let rec read_loop payload buf n =
    Payload.schedule_read
      payload
      ~on_eof:(fun () -> on_message (Bytes.to_string buf))
      ~on_read:(fun bs ~off ~len ->
        Bigstringaf.blit_to_bytes bs ~src_off:off buf ~dst_off:n ~len;
        let total_len = n + len in
        read_loop payload buf total_len)
  in
  let rec read_noop_loop payload =
    Payload.schedule_read
      payload
      ~on_eof:(fun () -> ())
      ~on_read:(fun _ ~off:_ ~len:_ -> read_noop_loop payload)
  in
  (* here we pong with the same data as the ping *)
  let rec read_ping_loop payload buffer prev_off =
    Payload.schedule_read
      payload
      ~on_eof:(fun () ->
        printf "ping read eof: %s\n" (Bigstring.to_string buffer);
        Out_channel.flush stdout;
        Wsd.send_pong
          wsd
          ~application_data:{ Faraday.off = 0; len = Bigstring.length buffer; buffer })
      ~on_read:(fun bs ~off ~len ->
        Bigstring.blit ~src:bs ~src_pos:off ~len ~dst:buffer ~dst_pos:prev_off;
        read_ping_loop payload buffer (prev_off + len))
  in
  let frame ~opcode ~is_fin ~len:frame_len payload =
    match opcode with
    | `Text -> read_loop payload (Bytes.create frame_len) 0
    | `Ping -> read_ping_loop payload (Bigstring.create frame_len) 0
    | `Pong ->
      printf "received pong %d %s\n" frame_len (if is_fin then "fin" else "not fin");
      Out_channel.flush stdout;
      (* BUG: it doesn't matter if we schedule a read here *)
      (* read_noop_loop payload *)
      ignore read_noop_loop
    | `Connection_close -> Promise.resolve_ok promise ()
    | _ -> failwithf "unexpected opcode: %d" (Websocket.Opcode.to_int opcode) ()
  in
  let eof ?error:_ () = Promise.resolve_ok promise () in
  { Websocket_connection.frame; eof }
;;

let error_handler p (err : Client_connection.error) =
  let error =
    match err with
    | `Exn exn -> Error.of_exn exn
    | `Invalid_response_body_length _ -> Error.of_string "invalid response body length"
    | `Malformed_response str -> Error.createf "malformed response: %s" str
    | `Handshake_failure _ -> Error.of_string "handshake failure"
  in
  Eio.Promise.resolve_error p error
;;

module Client = struct
  module Client_runtime = Gluten_eio.Client

  type t = Client_runtime.t

  let sha1 s = s |> Digestif.SHA1.digest_string |> Digestif.SHA1.to_raw_string

  let connect
    ?(config = Httpun.Config.default)
    ~sw
    ~nonce
    ~host
    ~resource
    ~error_handler
    ~websocket_handler
    socket
    =
    let headers = Httpun.Headers.of_list [ "host", host ] in
    let connection =
      Client_connection.connect
        ~nonce
        ~headers
        ~sha1
        ~error_handler
        ~websocket_handler
        resource
    in
    Client_runtime.create
      ~sw
      ~read_buffer_size:config.read_buffer_size
      ~protocol:(module Client_connection)
      connection
      socket
  ;;

  let is_closed t = Client_runtime.is_closed t
  let shutdown t = Client_runtime.shutdown t
end

let connect ?ssl ?ping_interval ~on_message ~host ?(port = 443) ~resource ~sw env =
  let network = Eio.Stdenv.net env in
  let clock = Eio.Stdenv.clock env in
  printf "connecting to %s:%d%s\n" host port resource;
  Out_channel.flush stdout;
  let socket =
    match ssl with
    | None -> Eio_connect.connect ~sw network ~host ~port
    | Some () ->
      Eio_connect.connect_ssl ~alpn_protos:[ "http/1.1" ] ~sw network ~host ~port
  in
  traceln "connected";
  let p, u = Promise.create () in
  let rand_bytes = String.init 16 ~f:(fun _ -> Random.char ()) in
  printf "rand_bytes: %S\n" (Base64.encode_exn rand_bytes);
  Out_channel.flush stdout;
  let websocket_handler = websocket_handler ?ping_interval ~on_message ~sw ~clock u in
  let client =
    Client.connect
      ~sw
      ~host
      ~resource
      ~nonce:rand_bytes
      ~error_handler:(error_handler u)
      ~websocket_handler
      socket
  in
  let res = Eio.Promise.await p in
  Eio.Promise.await (Client.shutdown client);
  res
;;
