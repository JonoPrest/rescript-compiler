(** File dependencies collected during AST processing.

    Tracks which files reference which other files with a mutable [builder].
    Reactive merge consumes builders through extraction helpers. *)

type builder
(** Mutable builder - for AST processing *)

(** {2 Builder API - for AST processing} *)

val create_builder : unit -> builder

val add_file : builder -> string -> unit
(** Register a file as existing (even if it has no outgoing refs). *)

val add_dep : builder -> from_file:string -> to_file:string -> unit
(** Add a dependency from one file to another. *)

(** {2 Merge API} *)

val merge_into_builder : from:builder -> into:builder -> unit
(** Merge one builder into another. *)

(** {2 Builder extraction for reactive merge} *)

val builder_files : builder -> File_set.t
(** Get files set from builder *)

val builder_deps_to_list : builder -> (string * File_set.t) list
(** Extract all deps as a list for reactive merge *)
