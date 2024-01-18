type nameGen = (string, int) Hashtbl.t

let parens xs = "(" ^ (xs |> String.concat ", ") ^ ")"
let comment x = "/* " ^ x ^ " */"

let genericsString ~typeVars =
  match typeVars == [] with
  | true -> ""
  | false ->
    "<"
    ^ String.concat ","
        (List.map GenTypeCommon.sanitizeReservedKeywords typeVars)
    ^ ">"

let fieldAccess ~label value = value ^ "." ^ label
