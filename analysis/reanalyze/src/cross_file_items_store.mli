(** Abstraction over cross-file items storage.

    Allows iteration over optional arg calls and function refs from either:
    - [Frozen]: Collected [CrossFileItems.t] 
    - [Reactive]: Direct iteration over reactive collection (no intermediate allocation) *)

type t =
  | Frozen of Cross_file_items.t
  | Reactive of (string, Cross_file_items.t) Reactive.t
      (** Cross-file items store with exposed constructors for pattern matching *)

val of_frozen : Cross_file_items.t -> t
(** Wrap a frozen [CrossFileItems.t] *)

val of_reactive : (string, Cross_file_items.t) Reactive.t -> t
(** Wrap reactive collection directly (no intermediate collection) *)

val compute_optional_args_state :
  t ->
  find_decl:(Lexing.position -> Decl.t option) ->
  is_live:(Lexing.position -> bool) ->
  Optional_args_state.t
(** Compute optional args state from calls and function references *)
