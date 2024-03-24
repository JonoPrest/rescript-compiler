let typeIsUncurriedFun (typ : Types.type_expr) =
  match typ.desc with
  | Tconstr (Pident {name = "function$"}, [{desc = Tarrow _}; _], _) ->
    true
  | _ -> false



let typeExtractUncurriedFun (typ : Types.type_expr) = 
  match typ.desc with
  | Tconstr (Pident {name = "function$"}, [tArg; _], _) ->
    tArg
  | _ -> assert false

