open Core
open Ppx_yojson_conv_lib.Yojson_conv

module Time_ns = struct
  module Span = struct
    module Of_ms = struct
      include Time_ns.Span

      let t_of_yojson = function
        | `Int ms -> Time_ns.Span.of_int_ms ms
        | `Float ms -> Time_ns.Span.of_ms ms
        | `String ms | `Intlit ms -> Time_ns.Span.of_int_ms (Int.of_string ms)
        | yojson ->
          of_yojson_error
            "Time_ns.Span.Of_ms.of_yojson: integer, float or string needed"
            yojson
      ;;

      let yojson_of_t span = `Int (Time_ns.Span.to_int_ms span)
    end
  end
end

let variant_of_assoc ~key = function
  | `Assoc assoc as msg ->
    (match List.Assoc.find assoc ~equal:String.equal key with
     | Some value -> `List [ value; msg ]
     | None -> of_yojson_error "variant_of_assoc: key not found" msg)
  | `List _ as msg -> msg
  | yojson -> of_yojson_error "variant_of_assoc: assoc or list expected" yojson
;;

type event = { txn_time_ms : Time_ns.Span.Of_ms.t [@key "T"] }
[@@deriving of_yojson] [@@yojson.allow_extra_fields]

type public_event_data =
  | Trade of event [@name "trade"]
  | Depth_update of event [@name "depthUpdate"]
[@@deriving of_yojson]

let public_event_data_of_yojson yojson =
  variant_of_assoc ~key:"e" yojson |> public_event_data_of_yojson
;;

type public_event =
  { stream : string
  ; data : public_event_data
  }
[@@deriving of_yojson]

let timestamp x = match x.data with
  | Trade { txn_time_ms } -> txn_time_ms
  | Depth_update { txn_time_ms } -> txn_time_ms

let public_event_of_string s = Yojson.Safe.from_string s |> public_event_of_yojson
