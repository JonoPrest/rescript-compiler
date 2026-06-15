(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*      Daniel de Rauglaudre, projet Cristal, INRIA Rocquencourt          *)
(*                                                                        *)
(*   Copyright 2001 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(* Module [Outcometree]: type and signature output displayed by diagnostics and
   editor tooling. The rendering is customizable through [Oprint] hooks. *)

type out_ident =
  | Oide_apply of out_ident * out_ident
  | Oide_dot of out_ident * string
  | Oide_ident of string

type out_type =
  | Otyp_abstract
  | Otyp_open
  | Otyp_alias of out_type * string
  | Otyp_arrow of string * out_type * out_type * Asttypes.arity
  | Otyp_class of bool * out_ident * out_type list
  | Otyp_constr of out_ident * out_type list
  | Otyp_manifest of out_type * out_type
  | Otyp_object of (string * out_type) list * bool option
  | Otyp_record of (string * bool * bool * out_type) list
  | Otyp_stuff of string
  | Otyp_sum of (string * out_type list * out_type option * string option) list
  | Otyp_tuple of out_type list
  | Otyp_var of bool * string
  | Otyp_variant of bool * out_variant * bool * string list option
  | Otyp_poly of string list * out_type
  | Otyp_module of string * string list * out_type list

and out_variant =
  | Ovar_fields of (string * bool * out_type list) list
  | Ovar_typ of out_type

type out_module_type =
  | Omty_abstract
  | Omty_functor of string * out_module_type option * out_module_type
  | Omty_ident of out_ident
  | Omty_signature of out_sig_item list
  | Omty_alias of out_ident
and out_sig_item =
  | Osig_typext of out_extension_constructor * out_ext_status
  | Osig_modtype of string * out_module_type
  | Osig_module of string * out_module_type * out_rec_status
  | Osig_type of out_type_decl * out_rec_status
  | Osig_value of out_val_decl
  | Osig_ellipsis
and out_type_decl = {
  otype_name: string;
  otype_params: (string * (bool * bool)) list;
  otype_type: out_type;
  otype_private: Asttypes.private_flag;
  otype_immediate: bool;
  otype_unboxed: bool;
  otype_cstrs: (out_type * out_type) list;
}
and out_extension_constructor = {
  oext_name: string;
  oext_type_name: string;
  oext_type_params: string list;
  oext_args: out_type list;
  oext_ret_type: out_type option;
  oext_repr: string option;
  oext_private: Asttypes.private_flag;
}
and out_type_extension = {
  otyext_name: string;
  otyext_params: string list;
  otyext_constructors:
    (string * out_type list * out_type option * string option) list;
  otyext_private: Asttypes.private_flag;
}
and out_val_decl = {
  oval_name: string;
  oval_type: out_type;
  oval_prims: string list;
}
and out_rec_status = Orec_not | Orec_first | Orec_next
and out_ext_status = Oext_first | Oext_next | Oext_exception
