let typeIsUncurriedFun (typ : Types.type_expr) =
  match typ.desc with
  | Tconstr (Pident {name = "function$"}, [{desc = Tarrow _}; _], _) ->
    true
  | _ -> false



(* let typeExtractUncurriedFun (typ : Types.type_expr) =  *)
  (* match typ.ptyp_desc with *)
  (**)
  (* | Tconstr (Pident {name = "function$"}, [{desc = Tarrow _}; _], _) -> *)
  (* (* | Tconstr ({txt = Lident "function$"}, [tArg; tArity]) -> *) *)
  (*   (tArg) *)
  (* | _ -> assert false *)

