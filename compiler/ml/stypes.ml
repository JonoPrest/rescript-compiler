(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*           Damien Doligez, projet Moscova, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 2003 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(* Recording and dumping (partial) type information *)

(*
  We record all types in a list as they are created.
  This means we can dump type information even if type inference fails,
  which is extremely important, since type information is most
  interesting in case of errors.
*)

open Typedtree

type annotation =
  | Ti_pat of pattern
  | Ti_expr of expression
  | Ti_mod of module_expr
  | An_ident of Location.t * string * Annot.ident

let get_location ti =
  match ti with
  | Ti_pat p -> p.pat_loc
  | Ti_expr e -> e.exp_loc
  | Ti_mod m -> m.mod_loc
  | An_ident (l, _s, _k) -> l

let annotations = ref ([] : annotation list)

let record ti =
  if !Clflags.annotations && not (get_location ti).Location.loc_ghost then
    annotations := ti :: !annotations

let record_phrase _loc = ()
