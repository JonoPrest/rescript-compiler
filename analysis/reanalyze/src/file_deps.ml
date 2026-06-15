(** File dependencies collected during AST processing.
    
    Tracks which files reference which other files. *)

(* File-keyed hashtable *)
module File_hash = Hashtbl.Make (struct
  type t = string

  let hash (x : t) = Hashtbl.hash x
  let equal (x : t) y = x = y
end)

type builder = {mutable files: File_set.t; deps: File_set.t File_hash.t}

(** {2 Builder API} *)

let create_builder () : builder =
  {files = File_set.empty; deps = File_hash.create 256}

let add_file (b : builder) file =
  b.files <- File_set.add file b.files;
  (* Ensure file has an entry even if no deps *)
  if not (File_hash.mem b.deps file) then
    File_hash.replace b.deps file File_set.empty

let add_dep (b : builder) ~from_file ~to_file =
  let set =
    match File_hash.find_opt b.deps from_file with
    | Some s -> s
    | None -> File_set.empty
  in
  File_hash.replace b.deps from_file (File_set.add to_file set)

(** {2 Merge API} *)

let merge_into_builder ~(from : builder) ~(into : builder) =
  into.files <- File_set.union into.files from.files;
  File_hash.iter
    (fun from_file to_files ->
      let existing =
        match File_hash.find_opt into.deps from_file with
        | Some s -> s
        | None -> File_set.empty
      in
      File_hash.replace into.deps from_file (File_set.union existing to_files))
    from.deps
