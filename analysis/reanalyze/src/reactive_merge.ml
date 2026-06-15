(** Reactive merge of per-file DCE data into global collections.

    Given a reactive collection of (path, file_data), this creates derived
    reactive collections that automatically update when source files change. *)

(** {1 Types} *)

type t = {
  decls: (Lexing.position, Decl.t) Reactive.t;
  annotations: (Lexing.position, File_annotations.annotated_as) Reactive.t;
  value_refs_from: (Lexing.position, Pos_set.t) Reactive.t;
  type_refs_from: (Lexing.position, Pos_set.t) Reactive.t;
  cross_file_items: (string, Cross_file_items.t) Reactive.t;
  (* Reactive type/exception dependencies *)
  type_deps: Reactive_type_deps.t;
  exception_refs: Reactive_exception_refs.t;
}
(** All derived reactive collections from per-file data *)

(** {1 Creation} *)

let create (source : (string, Dce_file_processing.file_data option) Reactive.t)
    : t =
  (* Declarations: (pos, Decl.t) with last-write-wins *)
  let decls =
    Reactive.flat_map ~name:"decls" source
      ~f:(fun _path file_data_opt ->
        match file_data_opt with
        | None -> []
        | Some file_data ->
          Declarations.builder_to_list file_data.Dce_file_processing.decls)
      ()
  in

  (* Annotations: (pos, annotated_as) with last-write-wins *)
  let annotations =
    Reactive.flat_map ~name:"annotations" source
      ~f:(fun _path file_data_opt ->
        match file_data_opt with
        | None -> []
        | Some file_data ->
          File_annotations.builder_to_list
            file_data.Dce_file_processing.annotations)
      ()
  in

  (* Value refs_from: (posFrom, PosSet of targets) with PosSet.union merge *)
  let value_refs_from =
    Reactive.flat_map ~name:"value_refs_from" source
      ~f:(fun _path file_data_opt ->
        match file_data_opt with
        | None -> []
        | Some file_data ->
          References.builder_value_refs_from_list
            file_data.Dce_file_processing.refs)
      ~merge:Pos_set.union ()
  in

  (* Type refs_from: (posFrom, PosSet of targets) with PosSet.union merge *)
  let type_refs_from =
    Reactive.flat_map ~name:"type_refs_from" source
      ~f:(fun _path file_data_opt ->
        match file_data_opt with
        | None -> []
        | Some file_data ->
          References.builder_type_refs_from_list
            file_data.Dce_file_processing.refs)
      ~merge:Pos_set.union ()
  in

  (* Cross-file items: (path, CrossFileItems.t) with merge by concatenation *)
  let cross_file_items =
    Reactive.flat_map ~name:"cross_file_items" source
      ~f:(fun path file_data_opt ->
        match file_data_opt with
        | None -> []
        | Some file_data ->
          let items =
            Cross_file_items.builder_to_t
              file_data.Dce_file_processing.cross_file
          in
          [(path, items)])
      ~merge:(fun a b ->
        Cross_file_items.
          {
            exception_refs = a.exception_refs @ b.exception_refs;
            optional_arg_calls = a.optional_arg_calls @ b.optional_arg_calls;
            function_refs = a.function_refs @ b.function_refs;
          })
      ()
  in

  (* Extract exception_refs from cross_file_items for ReactiveExceptionRefs *)
  let exception_refs_collection =
    Reactive.flat_map ~name:"exception_refs_collection" cross_file_items
      ~f:(fun _path items ->
        items.Cross_file_items.exception_refs
        |> List.map (fun (r : Cross_file_items.exception_ref) ->
               (r.exception_path, r.loc_from)))
      ()
  in

  (* Create reactive type-label dependencies *)
  let type_deps =
    Reactive_type_deps.create ~decls
      ~report_types_dead_only_in_interface:
        Dead_common.Config.report_types_dead_only_in_interface
  in

  (* Create reactive exception refs resolution *)
  let exception_refs =
    Reactive_exception_refs.create ~decls
      ~exception_refs:exception_refs_collection
  in

  {
    decls;
    annotations;
    value_refs_from;
    type_refs_from;
    cross_file_items;
    type_deps;
    exception_refs;
  }
