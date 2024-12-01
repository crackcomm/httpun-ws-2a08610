open StdLabels

let () =
  Ssl_threads.init ();
  Ssl.init ~thread_safe:true ()
;;

let resolve_addr ~host ~port =
  Eio_unix.run_in_systhread (fun () ->
    Unix.getaddrinfo host (string_of_int port) [ Unix.(AI_FAMILY PF_INET) ])
  |> List.filter_map ~f:(fun (addr : Unix.addr_info) ->
    match addr.ai_addr with
    | Unix.ADDR_UNIX _ -> None
    | ADDR_INET (addr, port) -> Some (addr, port))
  |> List.map ~f:(fun (inet, port) -> `Tcp (Eio_unix.Net.Ipaddr.of_unix inet, port))
;;

let[@ocaml.alert "-deprecated"] with_ssl ?(alpn_protos = [ "h2" ]) ~host socket =
  let ctx = Ssl.create_context Ssl.SSLv23 Ssl.Client_context in
  Ssl.honor_cipher_order ctx;
  Ssl.set_context_alpn_protos ctx alpn_protos;
  Ssl.set_min_protocol_version ctx SSLv3;
  Ssl.set_max_protocol_version ctx TLSv1_3;
  let ssl_ctx = Eio_ssl.Context.create ~ctx socket in
  let ssl_sock = Eio_ssl.Context.ssl_socket ssl_ctx in
  Ssl.set_client_SNI_hostname ssl_sock host;
  Ssl.set_hostflags ssl_sock [ No_partial_wildcards ];
  Ssl.set_host ssl_sock host;
  Eio_ssl.connect ssl_ctx
;;

let connect ~sw network ~host ~port =
  let addr = resolve_addr ~host ~port |> List.hd in
  Eio.Net.connect ~sw network addr
;;

let connect_ssl ~sw ?alpn_protos network ~host ~port =
  connect ~sw network ~host ~port |> with_ssl ?alpn_protos ~host
;;
