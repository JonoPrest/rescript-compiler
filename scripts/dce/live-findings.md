# DCE live findings

Working notes for warnings that look actionable in `_dce/report.txt`, but are
live after manual validation.

## Live warnings

### `Reanalyze.run_analysis ?file_stats`

- Report: `Warning Unused Argument`, `analysis/reanalyze/src/reanalyze.ml`,
  optional argument `file_stats` of `run_analysis`.
- Verdict: live; false positive.
- Validation: `analysis/reanalyze/src/reanalyze_server.ml` calls
  `state.run_analysis ... ~file_stats ()` in the server request path, then reads
  `file_stats.processed` and `file_stats.from_cache` for response stats.
- Implementation: `run_analysis` forwards `?file_stats` to
  `process_cmt_files`; `process_cmt_files` mutates it from
  `Reactive_analysis.process_files` stats when reactive mode is active.

### `Ast_helper0` compatibility helper surface

- Report: many `Warning Dead Value`, `Warning Dead Module`, and
  `Warning Redundant Optional Argument` entries in `compiler/ml/ast_helper0.ml`
  / `.mli`, plus frozen v0 constructors in `compiler/ml/parsetree0.ml`,
  including helper submodules such as `Const`, `Typ`, `Pat`, `Exp`, `Mty`,
  `Mod`, and `Te`, plus optional labels on `Te.constructor`, `Te.mk`,
  `Type.field`, and `Type.constructor`.
- Verdict: live compatibility surface; do not remove as part of this DCE pass.
- Validation: `compiler/ml/ast_mapper_to0.ml` opens `Ast_helper0` and uses these
  helpers while converting the current `Parsetree` to `Parsetree0`, supplying
  locations, attributes, privacy flags, constructor arguments, and similar data
  from the source tree.
- Context: `Ast_helper0` mirrors the helper shape for the frozen v0 parsetree.
  The repository guidance says `parsetree0.ml` must not be modified and v0 PPX
  compatibility must be preserved, so changing this helper API or pruning v0
  AST constructors for locally redundant labels is higher risk than the DCE
  warning suggests.

### `Ast_mapper` PPX compatibility API

- Report: `Warning Dead Value` / `Warning Dead Module`,
  `compiler/ml/ast_mapper.ml` / `.mli`, including `attribute_of_warning`,
  `String_map`, `get_cookie`, `set_cookie`, `tool_name`, `apply`,
  `run_main`, `register_function`, `register`, and convenience exports.
- Verdict: live compatibility surface; do not remove as part of this DCE pass.
- Validation: compiler code uses the core mapper through
  `compiler/syntax/src/jsx_v4.ml`, `jsx_ppx.ml`, and `compiler/ml/subst.ml`.
  `compiler/core/cmd_ppx_apply.ml` uses the ppx context add/drop helpers around
  external mapper execution. The remaining API is the documented standalone
  `-ppx` mapper surface in `ast_mapper.mli`, including registration and cookie
  functions for mapper authors/drivers.
- Context: reanalyze sees repository-internal roots but not external compiler
  library consumers. This module intentionally mirrors the OCaml PPX mapper API,
  so pruning apparently unused public functions would risk breaking ppx tooling.

### `Type_utils` type argument contexts

- Report: `Warning Unused Argument`, `analysis/src/type_utils.ml`, optional
  arguments on `instantiate_type2` and the local `extract_type` binding inside
  `resolve_nested`.
- Verdict: live; false positive.
- Validation: `instantiate_type2` immediately matches `type_arg_context` and uses
  its `type_args` and `type_params` to substitute type variables. `extract_type`
  forwards `type_arg_context_from_type_manifest` into `maybe_set_type_arg_ctx`,
  and recursive calls use `print_opening_debug:false` to avoid repeated verbose
  logging.
- Context: reanalyze appears to lose this through optional forwarding/local
  aliasing in the recursive type-extraction helpers. Removing these labels would
  break generic type instantiation and manifest traversal.

### `Res_driver.parse_* ?ignore_parse_errors`

- Report: `Warning Redundant Optional Argument`, `compiler/syntax/src/res_driver.ml`,
  optional argument `ignore_parse_errors` on `parse_implementation` and
  `parse_interface`.
- Verdict: live parser option; do not remove as part of this DCE pass.
- Validation: `compiler/bsc/rescript_compiler_main.ml` passes
  `~ignore_parse_errors:!Clflags.ignore_parse_errors` into both parser functions
  so the `-ignore-parse-errors` CLI flag controls whether syntax diagnostics
  exit compilation. The declarations in `res_driver.mli` are also marked
  `[@@live]`.
- Context: the warning only says all known callers supply the option. The option
  itself is behaviorally live and part of the syntax driver surface used by the
  compiler entry point.

### `from_type` in unbound name errors

- Report: `Warning Unused Argument`, `compiler/ml/typecore.ml` and
  `compiler/ml/typetexp.ml`, optional argument `from_type` on label and
  constructor unbound-name error helpers.
- Verdict: live for labels; intentionally shared/ignored for constructors.
- Validation: `compiler/ml/typecore.ml` calls `Label.disambiguate
  ~from_type:ty_exp` for field access, and `compiler/ml/typetexp.ml` stores that
  value in `Unbound_label`. The error printer uses it to emit the specific
  option-unwrapping diagnostic when the attempted field access is on an
  `option`.
- Context: constructors share the `Name_choice` functor interface but currently
  ignore `from_type`. Splitting that interface for DCE would risk the shared
  lookup/error plumbing for little practical cleanup.

### `Env.lookup_* ?loc`

- Report: `Warning Unused Argument`, `compiler/ml/env.ml` and
  `compiler/ml/env.mli`, optional argument `loc` on the generic lookup helpers
  and value/type/constructor/label/modtype wrappers.
- Verdict: live; false positive.
- Validation: `compiler/ml/typetexp.ml` passes `~loc` through `find_component`
  into `Env.lookup_type`, `Env.lookup_constructor`,
  `Env.lookup_all_constructors`, `Env.lookup_all_labels`, `Env.lookup_value`,
  `Env.lookup_module`, and `Env.lookup_modtype`. For dotted paths, the generic
  Env lookup helpers forward `?loc` into `lookup_module_descr`, which uses it
  for deprecated-module warnings.
- Context: `compiler/ml/env.mli` documents that `?loc` reports deprecated-module
  warnings. Removing the labels from the wrappers would drop source locations for
  those diagnostics even though reanalyze does not see the cross-module flow.

### `Env` external roots

- Report: `Warning Dead Value` / `Warning Dead Type`, `compiler/ml/env.ml` and
  `compiler/ml/env.mli`, for `reset_cache_toplevel` and the
  `Persistent_signature.t` fields `filename` and `cmi`.
- Verdict: live; false positives.
- Validation: `compiler/jsoo/jsoo_playground_main.ml` calls
  `Env.reset_cache_toplevel` from the playground reset path.
  `compiler/core/bs_cmi_load.ml` returns
  `Env.Persistent_signature.t option`, `compiler/core/bs_conditional_initial.ml`
  installs that loader into `Env.Persistent_signature.load`, and
  `compiler/ml/env.ml` reads both `filename` and `cmi` when acknowledging the
  persistent signature.
- Context: the playground and core CMI loader are outside the roots reanalyze is
  following for this report, so the exported reset hook and loader payload fields
  look dead even though they are part of the live compiler setup.

### Experimental feature set and reset hook

- Report: `Warning Dead Module` / `Warning Dead Value`,
  `compiler/ml/experimental_features.ml` and `.mli`, for `Feature_set`,
  `Feature_set.compare`, and `reset`.
- Verdict: live; false positive.
- Validation: `compiler/bsc/rescript_compiler_main.ml` enables feature flags
  through `Experimental_features.enable_from_string`, while
  `compiler/frontend/bs_builtin_ppx.ml` and `compiler/ml/typecore.ml` query
  `Experimental_features.is_enabled`. `Feature_set.add`, `mem`, and `empty`
  back that state. `compiler/jsoo/jsoo_playground_main.ml` calls
  `Experimental_features.reset` from the playground compiler reset path, next to
  other global compiler-state resets.
- Context: the playground entry point and several frontend/type-checker call
  sites are outside the roots followed by this DCE report. The `compare`
  callback is consumed by `Set.Make`, and removing the reset hook would let
  experimental feature flags leak between playground compilations.

### `Location` diagnostic hooks

- Report: `Warning Redundant Optional Argument`, `compiler/ml/location.ml` and
  `compiler/ml/location.mli`, optional arguments `custom_intro` and `src` on
  `report_error`; and `Warning Dead Value`, `compiler/ml/location.mli`, for
  warning-printer hook exports such as `warning_printer`,
  `formatter_for_warnings`, and `default_warning_printer`.
- Verdict: live; false positive.
- Validation: `compiler/syntax/src/res_diagnostics.ml` calls
  `Location.report_error ~custom_intro ~src:(Some src)` when rendering syntax
  diagnostics, and `compiler/jsoo/jsoo_playground_main.ml` uses the default
  wrapper form. The local exception reporter also passes explicit `None` values.
  The playground entry point installs a custom `formatter_for_warnings` and
  `warning_printer`, and calls `default_warning_printer` from its custom hook.
- Context: these labels select syntax-error intro text and source rendering for
  diagnostics. The warning hooks are public so the playground can intercept
  compiler warnings. Reanalyze only counts the local wrapper call and misses the
  jsoo cross-module diagnostic hooks.

### Reactive combinator internals

- Report: many `Warning Dead Value` entries in
  `analysis/reactive/src/reactive.ml`, including `merge_entries`,
  `count_changes`, `Registry.register`, nested `process` functions, and
  combinator-local helpers such as `recompute_target`.
- Verdict: live; false positive.
- Validation: `analysis/reanalyze/src/reactive_liveness.ml`,
  `reactive_solver.ml`, `reactive_merge.ml`, `reactive_decl_refs.ml`,
  `reactive_type_deps.ml`, and related modules build the DCE pipeline with
  `Reactive.source`, `Reactive.flat_map`, `Reactive.join`, `Reactive.union`, and
  `Reactive.fixpoint`. Those public combinators call these local helpers when
  sources emit and the scheduler propagates updates.
- Context: these warnings are cascading from the known cross-module liveness
  blind spot: reanalyze does not mark the exported combinators live from their
  users, so the implementation below them looks dead even though it runs in the
  analyzer's reactive mode.

### `Reactive_file_collection` live helpers

- Report: `Warning Dead Value`, `analysis/reactive/src/reactive_file_collection.ml`
  and `.mli`, for collection operations used by the reactive analyzer.
- Verdict: live; false positive.
- Validation: `analysis/reanalyze/src/reactive_analysis.ml` uses
  `Reactive_file_collection.create`, `process_files_batch`, `mem`, `iter`, and
  `to_collection`; `analysis/reanalyze/src/reanalyze.ml` uses
  `process_files_batch` and `remove_batch` directly for churn tests.
- Context: the single-file/cache-management helpers were removed, but the
  remaining collection operations are part of the live reactive analyzer path.

### `Reactive_fixpoint` internals

- Report: `Warning Dead Value`, `analysis/reactive/src/reactive_fixpoint.ml`
  and `.mli`, including `analyze_edge_change`, `Metrics.update`,
  `Invariants.*`, `has_live_predecessor`, and `apply`.
- Verdict: live; false positive.
- Validation: `analysis/reactive/src/reactive.ml` implements
  `Reactive.fixpoint` by calling `Reactive_fixpoint.create`, `initialize`,
  `apply`, `iter_current`, `get_current`, and `current_length`. The analyzer
  liveness pipeline calls `Reactive.fixpoint` from
  `analysis/reanalyze/src/reactive_liveness.ml`, so these private-module helpers
  run when the reactive analyzer computes live declarations.
- Context: `reactive_fixpoint` is a private implementation module in the
  `reactive` library. Reanalyze misses the cross-module root through
  `Reactive.fixpoint`, so the implementation below `apply` looks dead even
  though it is the incremental transitive-closure engine.

### Reanalyze collection functor callbacks

- Report: `Warning Dead Module` and `Warning Dead Value`,
  `analysis/reanalyze/src/file_hash.ml`, `loc_set.ml`, `pos_hash.ml`,
  `pos_set.ml`, and `Name.compare` in `name.ml` / `.mli`.
- Verdict: live; false positive.
- Validation: `Pos_hash` and `Pos_set` are used throughout the DCE liveness,
  reference, declaration, annotation, and reactive pipelines. `Loc_set` is used
  by exception analysis, `File_hash` is the file-keyed table helper, and
  `module_path.ml` builds `Name_map = Map.Make (Name)`.
- Context: `hash`, `equal`, and `compare` are callbacks consumed by
  `Hashtbl.Make`, `Set.Make`, or `Map.Make`. Reanalyze can miss those callback
  edges and report the callback definitions as ordinary unused values.

### Analysis collection functor callbacks

- Report: `Warning Dead Module` and `Warning Dead Value`,
  `analysis/src/shared_types.ml`, `Location_set.compare`.
- Verdict: live; false positive.
- Validation: `Shared_types.Location_set` stores file references in
  `Shared_types.extra.file_references`; `analysis/src/process_extra.ml` adds
  locations with `Location_set.add` / `singleton`, and
  `analysis/src/references.ml` reads them with `Location_set.elements`.
- Context: the `compare` function is consumed by `Set.Make`, so it can look
  unused as a plain value even though every set operation depends on it.

### ML type-checker collection callbacks

- Report: `Warning Dead Module` and `Warning Dead Value`,
  `compiler/ml/ctype.ml`, `Type_pairs.equal` and `Type_pairs.hash`.
- Verdict: live; false positive.
- Validation: `Ctype.Type_pairs` is the hashtable used throughout type
  equality, unification, subtyping, and generalization paths. `ctype.ml` calls
  `Type_pairs.create`, `find`, `add`, `mem`, and `clear` in those algorithms.
- Context: `equal` and `hash` are callbacks consumed by `Hashtbl.Make`, so they
  can look unreferenced as ordinary values even though every generated table
  operation depends on them.

### ML collection and variance callbacks

- Report: `Warning Dead Module`, `Warning Dead Value`, and constructor warnings
  in `compiler/ml/depend.ml`, `env.ml`, `experimental_features.ml`,
  `matching.ml`, `parmatch.ml`, `path.ml` / `.mli`, `switch.ml`,
  `typedecl.ml`, `typemod.ml`, and `types.ml` / `.mli`.
- Verdict: live; false positives.
- Validation: `Depend.String_set`, `Env.String_set`, `Typedecl.String_set`,
  and `Typemod.String_set` are all local set helpers whose generated `empty`,
  `add`, `mem`, `union`, `fold`, or `elements` functions are used in those
  modules. `Types.Type_ops` feeds `Btype.Type_set`, `Type_map`, and
  `Type_hash`; `Types.Ordered_string` feeds `Meths`, `Vars`, and `Concr`.
  `Path.compare` is consumed by `Map.Make (Path)` / `Set.Make (Path)` in
  `env.ml`, `mtype.ml`, `printtyp.ml`, and `subst.ml`, while `Path.heads` is
  called by the `Typedtree_iter.Make_iterator` instance in `parmatch.ml`.
  `Switch.Store.A_map` is the action-sharing map used by `Switch.Store`, and
  `matching.ml` instantiates that functor as `Store_exp`. The same module
  instantiates `Switch.Make (S_arg)` and calls the resulting `Switcher`
  functions from pattern-matching compilation. `Parmatch.Constructor_tag_hashtbl`
  is used by constructor-coverage checks, and the local `enter_expression` /
  `leave_expression` callbacks are invoked by `Typedtree_iter.Make_iterator`.
  `Types.Variance.May_weak` is set and queried by `typedecl.ml`, `typemod.ml`,
  and `ctype.ml` while computing weak variance for type declarations.
- Context: these warnings are all callback, functor-instantiation, manifest
  signature, or cross-module edges. Removing them would break dependency
  analysis, environment consistency, variance checks, match compilation, or
  exhaustiveness analysis.

### `Shared_types.package.rescript_version`

- Report: `Warning Dead Type`, `analysis/src/shared_types.ml`,
  `package.rescript_version`.
- Verdict: live compatibility state; leave in place for now.
- Validation: `analysis/src/packages.ml` populates this from
  `Packages.get_rescript_version`, which honors `RESCRIPT_VERSION` and the
  analysis-test `// ^ve+` / `// ^ve-` commands parsed in `analysis/src/cli.ml`.
- Context: no current reader was found, but removing the field cascades into the
  version override test-command surface. Keep this documented until the version
  override path is intentionally retired or reconnected to feature gating.

### Compiler-common cross-module hooks

- Report: `Warning Dead Value` / `Warning Dead Module`,
  `compiler/common/bs_loc.ml` and `.mli` (`t` fields),
  `compiler/common/bs_version.ml` and `.mli` (`header`),
  `compiler/common/ext_log.ml` and `.mli` (`dwarn`), and
  `compiler/common/js_config.ml` and `.mli` (`js_stdout`).
- Verdict: live; false positive.
- Validation: `compiler/frontend/ast_external_process.ml` and `.mli` use
  `Bs_loc.t`; `compiler/core/js_dump_program.ml` emits `Bs_version.header`;
  `compiler/core/lam_compile_main.cppo.ml`, `lam_util.cppo.ml`,
  `lam_stats_export.ml`, and `js_pass_debug.cppo.ml` call `Ext_log.dwarn`;
  `compiler/core/lam_compile_main.cppo.ml` and `lam_compile_primitive.ml` read
  `Js_config.js_stdout`.
- Context: these are cross-module and, for several callers, `.cppo.ml` paths.
  They are live in the compiler pipeline even though the current DCE report
  misses those edges.

### Typed artifact readers and raw statement classification

- Report: `Warning Dead Value` / `Warning Dead Type`,
  `compiler/ml/classify_function.ml` / `.mli`,
  `compiler/ml/cmi_format.ml` / `.mli`, `compiler/ml/cmt_format.mli`,
  `compiler/ml/cmt_utils.ml`, and typedtree artifact fields such as
  `open_description.open_loc`, `package_type.pack_type`, `package_type.pack_txt`,
  `type_extension.tyext_txt`, and `extension_constructor.ext_name`.
- Verdict: live; false positives for compiler, GenType, and analysis tooling.
- Validation: `compiler/core/lam_convert.ml` calls
  `Classify_function.classify_stmt` when lowering raw JavaScript statement
  literals. `compiler/ml/cmt_format.cppo.ml` calls `Cmi_format.input_cmi`,
  `Cmi_format.output_cmi`, and its own `read_magic_number` while reading and
  writing `.cmi`, `.cmt`, and `.cmti` artifacts. `analysis/src/*`,
  `analysis/reanalyze/src/*`, and `compiler/gentype/*` call
  `Cmt_format.read_cmt`, inspect `Partial_interface` / `Packed` typed
  artifacts, and traverse `Partial_class_expr` where present. The reported
  typedtree fields are filled by `typemod.ml`, `typetexp.ml`, and
  `typedecl.ml`, then carried in the typedtree payload serialized into `.cmt`
  files.
- Context: the reported `cmt_infos` fields are serialized into typed artifact
  files by `cmt_format.cppo.ml` and are part of the reader/writer schema even
  when a specific field is not read back by current in-repo code. The
  deprecation hook is installed from `cmt_format.cppo.ml` into
  `Cmt_utils.record_deprecated_used` and invoked through
  `compiler/ml/builtin_attributes.ml`, with `deprecated_text` carried in the
  recorded payload.

### Typedtree iterators

- Report: `Warning Dead Value`, `compiler/ml/typedtree_iter.ml` / `.mli`, for
  `Make_iterator` and traversal callbacks such as `iter_structure_item`,
  `iter_signature_item_desc`, `iter_module_expr_desc`, `iter_class_expr_desc`,
  and `iter_expression_desc`.
- Verdict: live; false positive.
- Validation: `compiler/jsoo/jsoo_playground_main.ml` instantiates
  `Typedtree_iter.Make_iterator` with `Default_iterator_argument` and calls
  `Iter.iter_structure_item` while building playground type hints.
  `compiler/ml/parmatch.ml` also instantiates the functor to collect expression
  identifiers for pattern-match analysis.
- Context: reanalyze does not root these callbacks through functor
  instantiation and the jsoo playground entry point, so the generated iterator
  methods look unused even though they run in live compiler tooling.

### `Misc` live utility surface

- Report: remaining `Warning Dead Value`, `Warning Dead Module`, and constructor
  warnings in `compiler/ext/misc.ml` / `.mli`, including
  `output_to_bin_file_directly`, `String_map`, `String_set`, and
  `Color.setting`.
- Verdict: live; false positive for the remaining reported entries.
- Validation: `compiler/ml/cmt_format.cppo.ml` calls
  `Misc.output_to_bin_file_directly`. `Misc.String_map` is used by the analysis
  package metadata and completion paths; `Misc.String_set` is used through
  `open Misc` in `compiler/ml/printtyp.ml`. `Color.Auto`, `Always`, and `Never`
  are constructed by `compiler/ml/clflags.ml`, while `Color.setup` is used by
  `compiler/ml/location.ml` and `analysis/reanalyze/src/log_.ml`.
- Context: the truly unused inherited helpers were removed. The survivors are
  `.cppo.ml`, open-module, functor-callback, or cross-module edges that the DCE
  report does not root correctly.

### `Literals` shared constants

- Report: remaining `Warning Dead Value` entries in
  `compiler/ext/literals.ml`, including `js_type_*`, `param`, `partial_arg`,
  `tmp`, `create`, `setter_suffix_len`, node path constants, and `pure`.
- Verdict: live; false positive for the remaining reported constants.
- Validation: `compiler/core/js_exp_make.ml` imports
  `module L = Literals` and reads the `js_type_*` constants.
  `Lam_eta_conversion` uses `param` and `partial_arg`,
  `Ext_ident.create_tmp` uses `tmp`, `Js_exp_make` uses `create` and `pure`,
  `Lam_convert` uses `setter_suffix_len`, and `Ext_path` uses `node_sep`,
  `node_parent`, and `node_current`.
- Context: unused constants with no `Literals.*` or alias callers were removed.
  The survivors are cross-module or alias-qualified uses that DCE reports as
  unrooted.

### `Primitive_modules` runtime module names

- Report: `Warning Dead Value`, `compiler/ext/primitive_modules.ml`, for runtime
  module-name constants such as `bool`, `int`, `float`, `bigint`, `string`,
  `array`, `object_`, `hash`, and `exceptions`.
- Verdict: live; false positive for the reported constants.
- Validation: these names are used directly by lambda and JS lowering. Examples
  include `lam_compile_primitive.ml` for primitive runtime calls,
  `js_exp_make.ml` for checked integer/bigint operations and exception
  creation, and `js_of_lam_option.ml` for option runtime helpers. Syntax and ML
  frontend code also uses the same module-name table for dictionary, promise,
  module, pervasives, and utility paths.
- Context: Reanalyze misses the cross-module roots even though these constants
  determine generated runtime import names.

### Frontend literal and UTF-8 helpers

- Report: `Warning Dead Value`, `compiler/frontend/ast_literal.ml` / `.mli`,
  `Lid.ignore_id`; and `compiler/frontend/ast_utf8_string.ml` / `.mli`,
  `check_no_escapes_or_unicode` and `simple_comparison`.
- Verdict: live; false positives for the remaining reported entries.
- Validation: `compiler/frontend/ast_comb.ml` uses
  `Ast_literal.Lid.ignore_id` to build calls to the compiler's ignore
  primitive. `compiler/core/js_exp_make.ml` calls
  `Ast_utf8_string.simple_comparison` from `str_equal` so string literal
  equality can be folded only when there are no escape or unicode surprises; the
  private `check_no_escapes_or_unicode` helper feeds that exported function.
- Context: stale `Ast_literal.Lid` exports, unused literal constructors,
  orphaned frontend helpers, and the `Ast_utf8_string.pp_error` export were
  removed. `Ast_utf8_string.transform_test` is retained as a unit-test support
  hook and marked `[@@live]`.

### Frontend FFI and lambda constants

- Report: `Warning Dead Value`, `compiler/frontend/external_ffi_types.mli`,
  `from_string`; and `compiler/frontend/lam_constant.ml` / `.mli`,
  `string_of_pointer_info`, `eq_approx`, `lam_none`, and `is_allocating`.
- Verdict: live; false positives for the remaining reported entries.
- Validation: `compiler/core/lam_convert.ml` calls
  `External_ffi_types.from_string` while lowering primitive externals.
  `compiler/core/lam_compile_const.ml` calls
  `Lam_constant.string_of_pointer_info` for generated integer comments,
  `compiler/core/lam.ml` calls `Lam_constant.eq_approx` when comparing
  constants, `compiler/core/lam_constant_convert.ml` uses `Lam_constant.lam_none`
  for `Pt_shape_none`, and `compiler/core/lam_util.cppo.ml` calls
  `Lam_constant.is_allocating` before preserving constant bindings.
- Context: the orphaned `Bs_syntaxerr.untagged_variant` type, the over-exported
  `External_arg_spec.empty_label`, unused `Lam_constant.constructor_tag` fields,
  and the unconstructed `Lam_constant.pointer_info.Some` case were removed.
  What remains is cross-module compiler-core use that reanalyze does not root.

### Untagged variant dynamic checks

- Report: `Warning Dead Value` / `Warning Dead Value With Side Effects`,
  `compiler/ml/ast_untagged_variants.ml`, for `Dynamic_checks.*` builders and
  combinators such as `size`, `typeof`, literal check constructors,
  `is_a_literal_case`, `is_int_tag`, and `add_runtime_type_check`.
- Verdict: live; false positives.
- Validation: `compiler/core/js_exp_make.ml` exposes `emit_check`,
  `is_a_literal_case`, and `is_int_tag` by calling
  `Ast_untagged_variants.Dynamic_checks`; `compiler/core/lam_compile.ml` uses
  `Dynamic_checks.add_runtime_type_check` and the `( == )` builder while
  compiling untagged variant comparisons and runtime checks.
- Context: unused standalone helpers `tag_can_be_undefined` and
  `block_is_object` were removed. The remaining warnings are a cross-module
  pipeline edge from ML variant analysis into JS lowering.

### Untagged switch defaults and declarations

- Report: `Warning Unused Argument`, `compiler/core/lam_compile.ml`, optional
  arguments `default` and `declaration` on the local `switch` helper inside
  `compile_untagged_cases`.
- Verdict: live; false positive.
- Validation: `compile_general_cases` calls its switch callback as
  `switch ?default ?declaration switch_exp body`. The untagged-variant callback
  partitions `instanceof` clauses away from `typeof` clauses, then forwards
  `?default` and `?declaration` to `S.string_switch (E.typeof e)` from its
  `typeof_switch` closure. The `default` body is also read directly when the
  helper inserts null/array guards before the typeof switch.
- Context: reanalyze appears to lose the optional-label flow through the local
  callback and nested closure. Removing these labels would drop default handling
  or declaration threading for generated untagged-variant switch code.

### GenType map/set helpers

- Report: `Warning Dead Module` / `Warning Dead Value`,
  `compiler/gentype/gen_ident.ml`, `module_name.ml` / `.mli`, and
  `resolved_name.ml`, for `Int_map`, `Module_name.compare`, and
  `Resolved_name.Name_set`.
- Verdict: live; false positives.
- Validation: `compiler/gentype/gen_ident.ml` uses `Int_map.empty`, `find`, and
  `add` to assign stable generated names for anonymous type ids.
  `Gentype_config.Module_name_map`, `module_resolver.ml`, and `emit_js.ml` build
  maps with `Module_name` as the ordered key module, so `Module_name.compare` is
  consumed by `Map.Make`. `Resolved_name.Name_set` is used by
  `apply_equations_to_elements`, which is reached from
  `compiler/gentype/translation.ml` through `Resolved_name.apply_equations`.
- Context: the unused `Paths.concat` alias and the stored-but-unread
  `Gentype_config.t.bsb_project_root` field were removed. The remaining
  warnings are callback/cross-module edges missed by DCE.

### `Ext_util` table helpers

- Report: `Warning Dead Value`, `compiler/ext/ext_util.ml` / `.mli`, for
  `power_2_above`.
- Verdict: live; false positive.
- Validation: `Ext_util.power_2_above` sizes compiler hash tables in
  `hash_gen.ml`, `hash_set_gen.ml`, `hash_set_ident_mask.ml`, and
  `ordered_hash_map_gen.ml`. `string_of_int_as_char` is also live through
  `lam_print.ml`, `js_dump.ml`, and `pprintast.ml`.
- Context: the truly unused `stats_to_string` debug helper was removed. The
  remaining warning is a cross-module utility edge missed by DCE.

### `Ext_buffer` production and test helpers

- Report: `Warning Dead Value`, `compiler/ext/ext_buffer.ml` / `.mli`, for
  `is_empty`, `not_equal`, and the `add_int_*` helpers.
- Verdict: live or intentionally retained.
- Validation: `Ext_buffer.is_empty` is used by `ext_modulename.ml` while
  deriving JavaScript identifier names. `not_equal` and `add_int_1` through
  `add_int_4` are unit-test support helpers exercised by the string/util OUnit
  suites, so they are marked live rather than removing the unit-test surface.
- Context: unused `clear` and `digest` were removed. The remaining production
  warning depends on the known `Ext_modulename` cross-module false positive.

### `Ext_filename` test helpers

- Report: `Warning Dead Value` / `Warning Dead Type`,
  `compiler/ext/ext_filename.ml` / `.mli`, for `chop_all_extensions_maybe`,
  `as_module`, and the `module_info` fields.
- Verdict: intentionally retained unit-test helper surface.
- Validation: these helpers are exercised by `ounit_string_tests.ml` and have
  no production callers. They are marked live so unit-test-only validation code
  remains available while DCE ignores test modules.
- Context: the fully unused `chop_extension_maybe` helper was removed.

### `Ext_fmt` and `Ext_ident` compiler helpers

- Report: `Warning Dead Module`, `Warning Dead Value`, and
  `Warning Dead Value With Side Effects`, `compiler/ext/ext_fmt.ml` and
  `compiler/ext/ext_ident.ml` / `.mli`, for formatting helpers, JavaScript
  identifier flags, temporary identifiers, and identifier comparison helpers.
- Verdict: live; false positive for cross-module and `.cppo.ml` callers.
- Validation: `Ext_fmt.with_file_as_pp` is called from
  `lam_compile_main.cppo.ml`, while `Ext_fmt.failwithf` is used by
  `lam_dce.ml` and `ext_path.ml`. `Ext_ident.create_tmp`, `make_js_object`,
  `make_unused`, and `is_js_or_global` are used throughout lambda and JS
  lowering (`lam_compile*.ml`, `js_ast_util.ml`, `js_dump.ml`, and
  `lam_dce.ml`). `Ext_ident.compare` and `equal` feed identity maps, hash sets,
  and module identifier equality.
- Context: Reanalyze does not root these references through the cross-module
  compiler pipeline. The unused `is_js_object`, `reset`, JS-module table, and
  public `is_uppercase_exotic` export were removed.

### `compiler/ext` cross-module helpers

- Report: `Warning Dead Module`, `Warning Dead Type`, and
  `Warning Dead Value` entries across `compiler/ext/config.ml`,
  `ext_char.ml`, `ext_int.ml`, `ext_js_file_kind.ml`, `ext_modulename.ml`,
  `ext_namespace.ml`, `ext_option.ml`, `ext_path.ml`, `ext_pervasives.ml`,
  `ext_pp.ml`, `ext_scc.ml`, and `ext_sys.mli`.
- Verdict: live; false positive for production callers hidden behind
  `.cppo.ml`, module aliases, or public type signatures.
- Validation: `Config.cmt_magic_number` is used by `cmt_format.cppo.ml`;
  `Ext_char.is_lower_case`, `Ext_path.package_dir`, and
  `Ext_pervasives.with_file_as_chan` are used by `lam_compile_main.cppo.ml`;
  `Ext_int` feeds the integer map/hash/set functors and JS int32 lowering;
  `Ext_js_file_kind.case` is stored in CMJ data and lambda compile env
  signatures; `Ext_modulename.js_id_name_of_hint_name` is used by
  `lam_compile_env.ml`; `Ext_namespace` is used by JS module-name lowering and
  outcome printing; `Ext_option.map` / `exists` are used throughout lambda
  passes; `Ext_path.node_rebase_file` is used by `js_name_of_module_id.cppo.ml`;
  `Ext_pp.from_channel` and `brace_group` drive JS dumping; `Ext_scc.graph` is
  used by `lam_scc.ml`; and `Ext_sys.is_windows_or_cygwin` is used by JS module
  path generation.
- Context: several helper implementations are reported only because their
  exported wrapper is itself reported as dead; the wrapper has a production
  caller. Dead pretty-printer scope/debug helpers and extra `Ext_ref` protect
  variants were removed.

### `Ext_namespace` package-name helpers

- Report: `Warning Dead Value`, `compiler/ext/ext_namespace.ml` / `.mli`, for
  `is_valid_npm_package_name` and `namespace_of_package_name`.
- Verdict: intentionally retained unit-test-covered utility surface for now.
- Validation: grep finds only OUnit callers in
  `tests/ounit_tests/ounit_string_tests.ml` and documentation references in
  `ext_namespace_encode.mli`; there are no production callers in the current
  compiler pipeline.
- Context: these helpers validate and encode npm package names for namespace
  derivation. Since unit tests are excluded from DCE roots and this pass is
  avoiding unit-test edits, they are documented rather than removed in this
  batch.

### `Ext_pervasives` unit-test number parsers

- Report: `Warning Dead Value`, `compiler/ext/ext_pervasives.ml` / `.mli`, for
  `nat_of_string_exn`, `parse_nat_of_string`, and their local helper.
- Verdict: intentionally retained unit-test-covered utility surface for now.
- Validation: the number parsers are exercised only by
  `ounit_util_tests.ml`. Since unit tests are excluded from the DCE roots and
  this pass is avoiding unit-test edits, they are documented rather than
  removed in this batch.
- Context: `with_file_as_chan` from the same module is production-live through
  `.cppo.ml` callers.

### `Ext_obj` and `Ext_scc` unit-test helpers

- Report: `Warning Dead Module` / `Warning Dead Value`,
  `compiler/ext/ext_obj.ml` / `.mli` and `compiler/ext/ext_scc.ml` / `.mli`,
  for object dumping and SCC graph checking helpers.
- Verdict: intentionally retained unit-test helper surface where still used.
- Validation: `Ext_obj.dump` is the shared OUnit printer in several unit-test
  modules, and `Ext_scc.graph_check` is used only by `ounit_scc_tests.ml`.
  Both are marked live while unit tests are excluded from DCE roots.
- Context: unused `Ext_obj` debug helpers (`dump_endline`, `pp_any`, `bt`) were
  removed. `Ext_scc.graph` remains production-live through `lam_scc.ml`.

### `Ident` and SCC vector helpers

- Report: `Warning Dead Value` / `Warning Dead Module`,
  `compiler/ext/ident.ml` / `.mli`, `int_vec_util.ml` / `.mli`, and
  `int_vec_vec.ml` / `.mli`.
- Verdict: live; false positive for the remaining reported identifiers.
- Validation: `Ident.is_predef_exn` is used by lambda conversion,
  `Ident.print` is used by lambda and typed-tree printers, and
  `Ident.compare` / `equal` are used by path comparison, type checking, maps,
  and hash tables. `Int_vec_util.mem` and `Int_vec_vec` are used by
  `lam_scc.ml` and `ext_scc.ml`.
- Context: the unused `Identifiable` helper module was removed. The remaining
  warnings are cross-module edges missed by DCE.

### Runtime package, warnings, and hash collections

- Report: `Warning Dead Value` and `Warning Dead Module` entries in
  `compiler/ext/runtime_package.ml` / `.mli`, `warnings.ml` / `.mli`,
  `hash_gen.ml`, `hash_set_gen.ml`, `hash_set_ident_mask.ml` / `.mli`, and
  `hash_set_poly.mli`.
- Verdict: live; false positive for the remaining production callers, with
  some unit-test-only hash-set exports retained while unit tests are not being
  edited.
- Validation: `Runtime_package.name` and `path` are used by compiler package
  path resolution and JS package-info generation. `Warnings.reset_fatal` is used
  by the playground entry point, and `Warnings.has_warnings` is used by
  `lam_compile_main.cppo.ml`. `Hash_gen` / `Hash_set_gen` are wrapped by
  `hash.cppo.ml` and `hash_set.cppo.ml`; `Hash_set_ident_mask` is used by
  `lam_scc.ml`; `Hash_set_poly` is used by `used_attributes.ml` and covered by
  unit tests for the extra collection operations.
- Context: unused `Warnings.Bad_module_name`, `mk_lazy`, and unused interface
  exports were removed.

### `Ext_list` production helpers

- Report: remaining `Warning Dead Value` entries in
  `compiler/ext/ext_list.ml` / `.mli`, including `map_snd`, `append`,
  `append_one`, `fold_right3`, `split_at`, `length_ge`,
  `length_larger_than_n`, `stable_group`, `nth_opt`, `iter_snd`,
  `exists_snd`, `fold_left2`, and `singleton_exn`.
- Verdict: live; false positive for the remaining reported helpers.
- Validation: the remaining helpers have production callers across the lambda
  and JS pipelines. Examples include `Lam_convert` using `append_one`,
  `length_ge`, `length_larger_than_n`, and `singleton_exn`;
  `Lam_eta_conversion`, `Lam_compile`, and `Lam_pass_alpha_conversion` using
  `split_at`; `Js_fun_env` using `filter_mapi`; `Js_pass_tailcall_inline` using
  `fold_right3`; and many lambda/JS passes using `map_snd`, `iter_snd`,
  `exists_snd`, `nth_opt`, and `fold_left2`.
- Context: helper functions with no production callers were removed, along with
  unit tests that only exercised that dead helper surface. The remaining
  warnings are ordinary cross-module `Ext_list.*` uses missed by DCE.

### `Map_gen` and `Set_gen` collection cores

- Report: `Warning Dead Module`, `Warning Dead Value`, and constructor warnings
  across `compiler/ext/map_gen.ml` / `.mli` and
  `compiler/ext/set_gen.ml` / `.mli`.
- Verdict: live; false positive.
- Validation: `compiler/ext/map.cppo.ml` defines concrete map modules by
  wrapping `Map_gen.empty`, `is_empty`, `iter`, `fold`, `for_all`, `exists`,
  `singleton`, `cardinal`, `bindings`, sorted-array helpers, `map`, `mapi`,
  balancing helpers, `merge`, `join`, and tree constructors. Similarly,
  `compiler/ext/set.cppo.ml` wraps `Set_gen.empty`, `iter`, `fold`,
  `singleton`, `cardinal`, `elements`, `choose`, balancing and join/concat
  helpers, and validation helpers. `map_ident.mli`, `map_int.mli`,
  `map_string.mli`, `set_ident.mli`, `set_int.mli`, and `set_string.mli`
  expose those generated concrete modules.
- Context: this is a `.cppo.ml` rooting issue. The report sees the generic tree
  implementation as dead, but those functions are the shared implementation of
  the compiler's generated map and set modules.

### `Ext_array` production helpers

- Report: remaining `Warning Dead Value` entries in
  `compiler/ext/ext_array.ml` / `.mli`, currently `reverse_range`,
  `of_list_map`, and `fold_left`.
- Verdict: live; false positive.
- Validation: `compiler/ext/vec.cppo.ml` calls `Ext_array.reverse_range`;
  `compiler/core/lam_util.cppo.ml` and `lam_stats_export.ml` call
  `Ext_array.of_list_map`; and `compiler/ext/map.cppo.ml` calls
  `Ext_array.fold_left`.
- Context: helpers with no production callers were removed with their
  unit-only tests. The remaining warnings are `.cppo.ml` and cross-module uses
  missed by DCE.

### Core JS analyzer and delimiters

- Report: `Warning Dead Type`, `compiler/core/j.ml`, `delim.DBackQuotes`; and
  many `Warning Dead Value` entries in `compiler/core/js_analyzer.ml` / `.mli`.
- Verdict: live; false positive.
- Validation: `DBackQuotes` is constructed by
  `compiler/frontend/ast_utf8_string_interp.ml` for the processed `"bq"`
  delimiter and printed by `compiler/core/js_dump.ml`. `Js_analyzer` helpers are
  used from `js_pass_flatten.ml`, `js_shake.ml`, `js_exp_make.ml`,
  `js_output.ml`, `js_pass_flatten_and_mark_dead.ml`,
  `lam_compile_external_obj.ml`, `lam_compile_external_call.ml`,
  `lam_compile_primitive.ml`, `lam_compile.ml`, and related JS passes.
- Context: these are cross-module compiler pipeline edges. The warning cluster
  is consistent with the known DCE limitation where anything referenced only
  across modules can appear dead.

### Core JS utility and CMJ helpers

- Report: `Warning Dead Module` / `Warning Dead Value`,
  `compiler/core/js_arr.ml`, `js_ast_util.ml`, `js_block_runtime.ml`,
  `js_call_info.ml`, and `js_cmj_format.ml` / `.mli`.
- Verdict: live; false positive for the remaining reported helpers.
- Validation: `Js_arr.ref_array` and `set_array` are used by
  `compiler/core/lam_compile_external_call.ml`. `Js_ast_util.named_expression`
  is used by `lam_compile_external_obj.ml` and `lam_compile.ml`.
  `Js_block_runtime.check_additional_id` is used by `js_fold_basic.ml` and
  `js_pass_scope.ml`; its reported local ids feed that exported helper.
  `Js_call_info.dummy`, `ml_full_call`, and `na_full_call` are used by
  `lam_compile.ml`, `js_exp_make.ml`, and `lam_compile_external_call.ml`.
  `Js_cmj_format.single_na`, `make`, `to_file`, and `query_by_name` are used by
  `lam_stats_export.ml`, `lam_compile_main.cppo.ml`, and
  `lam_compile_env.ml`; the binary-search helpers are local dependencies of
  `query_by_name`, and `for_sure_not_changed` is a local dependency of
  `to_file`.
- Context: `Js_cmj_format.from_file_with_digest` and `from_string` had no
  callers and were removed. The remaining entries are live through cross-module
  compiler and `.cppo.ml` call sites.

### Core JS dumping pipeline

- Report: `Warning Dead Module` / `Warning Dead Value`,
  `compiler/core/js_cmj_load.ml`, `js_dump.ml`, `js_dump_import_export.ml`,
  `js_dump_lit.ml`, and `js_dump_program.ml` / `.mli`.
- Verdict: live; false positive for the remaining reported helpers.
- Validation: `compiler/core/lam_compile_env.ml` reads
  `Js_cmj_load.load_unit`. `compiler/core/js_output.ml` calls
  `Js_dump.string_of_block`, and `compiler/core/js_dump_program.ml` calls
  `Js_dump.statements`. `compiler/core/js_dump_program.ml` calls
  `Js_dump_import_export.exports`, `requires`, `imports`, and
  `esmodule_export`; those helpers use the reported `Js_dump_lit` strings
  through `module L = Js_dump_lit`. `Js_dump_program.dump_deps_program` is used
  by `lam_compile_main.cppo.ml`, `dump_program` by `js_pass_debug.cppo.ml`, and
  `pp_deps_program` by `compiler/jsoo/jsoo_playground_main.ml`.
- Context: unused `Js_dump_lit` strings and the unused
  `Js_dump.string_of_expression` signature export were removed. The remaining
  dumper warnings are cross-module compiler output paths, including `.cppo.ml`
  and jsoo entry points that this DCE run misses.

### `Js_exp_make` expression builders

- Report: large `Warning Dead Value` cluster in
  `compiler/core/js_exp_make.ml` / `.mli`.
- Verdict: live; false positive for the remaining reported builders and their
  local helper chains.
- Validation: the module is imported as `module E = Js_exp_make` across core
  lowering and JS passes, including `lam_compile.ml`,
  `lam_compile_primitive.ml`, `lam_compile_external_call.ml`,
  `lam_compile_external_obj.ml`, `js_stmt_make.ml`, `js_output.ml`,
  `js_of_lam_array.ml`, `js_of_lam_block.ml`, `js_of_lam_option.ml`,
  `js_of_lam_string.ml`, `js_of_lam_variant.ml`, `js_pass_flatten.ml`,
  `js_pass_flatten_and_mark_dead.ml`, and `js_pass_external_shadow.ml`. Direct
  `Js_exp_make.remove_pure_sub_exp` calls also exist in `lam_compile.ml`, and
  tests use `Js_exp_make.var`.
- Context: `runtime_ref`, `assign_by_int`, and the public signature export for
  `pure_runtime_call` had no callers and were removed. The remaining zero
  direct-call entries, such as `bin`, `str_equal`, `push_negation`, and the
  `simplify_*` helpers, are local dependencies of exported builders that are
  used through `E.*`. `assign_by_exp` is called from
  `compiler/core/js_of_lam_block.ml` through the usual `module E = Js_exp_make`
  alias. The debug-printer ref is intentionally left because removing its
  `Js_dump` hook unroots a large live dump-printer subgraph in the current DCE
  report.

### `Js_stmt_make` statement builders

- Report: large `Warning Dead Value` cluster in
  `compiler/core/js_stmt_make.ml` / `.mli`.
- Verdict: live; false positive.
- Validation: the module is imported as `module S = Js_stmt_make` across the JS
  lowering and pass pipeline. Direct callers cover the reported statement
  builders in `lam_compile.ml`, `lam_compile_external_obj.ml`,
  `js_ast_util.ml`, `js_dump.ml`, `js_of_lam_variant.ml`, `js_output.ml`,
  `js_pass_flatten.ml`, `js_pass_flatten_and_mark_dead.ml`, and
  `js_pass_tailcall_inline.ml`. `debugger_block` is used for the `Pdebugger`
  primitive in `lam_compile.ml`.
- Context: DCE misses the cross-module builder calls through `module S`, so it
  reports exported constructors even though they are part of normal JS statement
  generation.

### `Lam` smart constructors

- Report: `Warning Dead Value` cluster in `compiler/core/lam.ml` / `.mli`,
  including `apply`, `eq_approx`, `switch`, `stringswitch`, `prim`, `if_`,
  sequence/control-flow constructors, and local helper chains.
- Verdict: live; false positive for the remaining reported helpers.
- Validation: the reported `Lam.*` smart constructors are used throughout lambda
  conversion and optimization passes, including `lam_convert.ml`,
  `lam_pass_lets_dce.ml`, `lam_bounded_vars.ml`,
  `lam_pass_eliminate_ref.ml`, `lam_pass_remove_alias.ml`,
  `lam_pass_exits.ml`, `lam_pass_deep_flatten.ml`, `lam_subst.ml`,
  `lam_eta_conversion.ml`, `lam_pass_alpha_conversion.ml`, `lam_analysis.ml`,
  `lam_compile.ml`, and `lam_util.cppo.ml`. Local helpers are live through those
  constructors: `is_eta_conversion_exn` through `apply`, `eq_option` and
  `eq_approx_list` through `eq_approx`, `Lift.*` through `prim`,
  `has_boolean_type`, `complete_range`, and `eval_const_as_bool` through `if_`,
  and `result_wrap` through `handle_bs_non_obj_ffi`.
- Context: the duplicate `Lam.X` type alias module and the unused public
  `inner_map` helper were removed. The remaining `Lam` warnings are exported
  smart constructors used cross-module, which this DCE run does not root
  correctly.

### `Lambda.let_kind.Variable`

- Report: `Warning Dead Type`, `compiler/ml/lambda.ml` and `.mli`,
  `let_kind.Variable`.
- Verdict: live; false positive.
- Validation: `compiler/core/lam_compat.ml` aliases
  `type let_kind = Lambda.let_kind = Strict | Alias | StrictOpt | Variable`.
  The `Variable` constructor is then used through `Lam_compat.let_kind` by
  lambda DCE, conversion, scope, printing, JS statement generation, and JS
  operator metadata.
- Context: reanalyze reports the original constructor as unconstructed because
  the live construction happens through the cross-module alias. Removing it from
  `Lambda.let_kind` would break the shared let-kind model used by core lowering.

### `Lam_id_kind` block metadata

- Report: `Warning Dead Type` / `Warning Dead Value`,
  `compiler/core/lam_id_kind.ml` and `.mli`, including `element.NA`,
  `element.SimpleForm`, `t.ImmutableBlock`, and `print`.
- Verdict: live; false positive for the remaining metadata constructors.
- Validation: `compiler/core/lam_util.cppo.ml` constructs
  `Lam_id_kind.ImmutableBlock` in `kind_of_lambda_block`, builds
  `SimpleForm` / `NA` entries in `element_of_lambda`, and consumes the block
  metadata in `field_flatten_get`. These helpers are called by
  `lam_beta_reduce.ml`, `lam_pass_collect.ml`, `lam_pass_remove_alias.ml`, and
  `lam_coercion.ml`.
- Context: the truly unused `Undefined`, `MutableBlock`, and `Exception`
  constructors were removed. The remaining warnings are `.cppo.ml` and
  cross-module lambda optimization edges that DCE does not root reliably.

### Core lambda analysis and rewrite passes

- Report: `Warning Dead Module` / `Warning Dead Value` clusters in
  `compiler/core/lam_analysis.ml`, `lam_arity.ml`, `lam_arity_analysis.ml`,
  `lam_beta_reduce.ml`, `lam_beta_reduce_util.ml`, `lam_bounded_vars.ml`,
  `lam_check.ml`, `lam_closure.ml`, `lam_exit_count.ml`,
  `lam_free_variables.ml`, `lam_group.ml`, and `lam_hit.ml` plus their `.mli`
  files.
- Verdict: live; false positive for the remaining reported helpers.
- Validation: `Lam_analysis` is used by lambda DCE/count/remove-alias passes,
  `lam_compile_main.cppo.ml`, `lam_compile.ml`, `lam_stats_export.ml`,
  `lam_beta_reduce.ml`, `lam_dce.ml`, `lam_util.cppo.ml`, and
  `lam_var_stats.ml`. `Lam_arity` and `Lam_arity_analysis` feed
  `lam_pass_alpha_conversion.ml`, `lam_stats_export.ml`, `lam_coercion.ml`,
  and `lam_pass_collect.ml`. `Lam_beta_reduce` is called from
  `lam_pass_lets_dce.ml`, `lam_pass_count.ml`, `lam_pass_remove_alias.ml`, and
  `lam_compile.ml`; it calls `Lam_beta_reduce_util.simple_beta_reduce` and
  `Lam_bounded_vars.rewrite`. `Lam_check.check` is called by
  `lam_compile_main.cppo.ml`. `Lam_closure` is used by
  `lam_pass_remove_alias.ml`, `lam_stats_export.ml`, and `lam_compile.ml`.
  `Lam_exit_count` is called by `lam_pass_exits.ml`; `Lam_free_variables` is
  used by `lam_dce.ml` and `lam_compile.ml`; `Lam_group` is used by
  `lam_pass_deep_flatten.ml`, `lam_coercion.ml`, `lam_dce.ml`, and
  `lam_compile_main.cppo.ml`; and `Lam_hit` is used by
  `lam_pass_eliminate_ref.ml`, `lam_scc.ml`, `lam_pass_remove_alias.ml`,
  `lam_convert.ml`, `lam_pass_deep_flatten.ml`, and `lam_util.cppo.ml`.
- Context: unused `Lam_arity.equal`, `print`, and `print_arities_tbl` exports
  were removed. The remaining entries are cross-module pass plumbing and local
  helper chains under live pass functions.

### `Lam_compat` aliases, comparisons, and field comments

- Report: constructor warnings for `field_dbg_info` and `set_field_dbg_info` in
  `compiler/core/lam_compat.ml` / `.mli`, plus comparison helpers and
  `str_of_field_info`.
- Verdict: live; false positive for the remaining reported entries.
- Validation: `Lam_compat.field_dbg_info` and `set_field_dbg_info` are
  manifest aliases of `Lambda` types. Their constructors are produced in the ML
  lambda layer (`lambda.ml`, `translcore.ml`, `translmod.ml`, `matching.ml`) and
  consumed by core lowering in `lam_convert.ml`, `lam_util.cppo.ml`,
  `lam_arity_analysis.ml`, `lam_analysis.ml`, `lam_pass_remove_alias.ml`,
  `lam_compile.ml`, `lam_print.ml`, `polyvar_pattern_match.ml`, and
  `js_of_lam_block.ml`. `str_of_field_info` is used by `lam_print.ml` and by
  `js_of_lam_block.ml` to preserve record-field comments in generated JS.
  `cmp_int32` and `cmp_float` are called by `Lam.prim`; `eq_comparison` is
  called by `lam_primitive.ml`.
- Context: unused `cmp_int` was removed. The remaining constructor warnings come
  from constructors being built through the aliased `Lambda` type rather than
  directly through `Lam_compat`.

### `Lam_print` lambda printers

- Report: `Warning Dead Value` entries in `compiler/core/lam_print.ml` / `.mli`,
  including `lambda`, `primitive`, `serialize`, and `lambda_to_string`.
- Verdict: live false positives, except `primitive_to_string`, which had no
  callers and was removed.
- Validation: `Lam_group.pp` calls `Lam_print.lambda`,
  `lam_util.cppo.ml` calls `Lam_print.serialize`, and
  `compiler/jsoo/jsoo_playground_main.ml` calls `Lam_print.lambda_to_string`
  when rendering playground lambda output. The `primitive` printer is reached
  from the live lambda printer.
- Context: these are debug/inspection printers reached through cross-module and
  `.cppo.ml` paths that the DCE report does not root correctly. The playground
  call site is not covered by `dune build @check`, so this warning must stay
  documented rather than removed.

### Lambda-to-JS compilation pipeline

- Report: `Warning Dead Module` / `Warning Dead Value` clusters in
  `compiler/core/lam_compile.ml`, `lam_compile_const.ml`, and
  `lam_compile_context.ml` plus their `.mli` files.
- Verdict: live; false positive.
- Validation: `lam_compile_main.cppo.ml` calls
  `Lam_compile.compile_lambda` and `compile_recursive_lets`. The reported
  top-level helpers in `lam_compile.ml` are local dependencies of the recursive
  `compile` closure that produces those functions. `Lam_compile_const.translate`
  and `translate_arg_cst` are used by `lam_compile.ml`,
  `lam_compile_external_call.ml`, and `lam_compile_external_obj.ml`.
  `Lam_compile_context` types and helpers are used by `lam_compile.ml`,
  `lam_compile_main.cppo.ml`, `lam_compile_primitive.ml`,
  `lam_compile_external_call.ml`, and `js_output.ml`.
- Context: DCE does not root the `.cppo.ml` entry point and therefore treats the
  compiler backend and its local helper chains as dead.

### Lambda compile environment and FFI lowering

- Report: `Warning Dead Value` / `Warning Dead Module` clusters in
  `compiler/core/lam_compile_env.ml`, `lam_compile_external_call.ml`,
  `lam_compile_external_obj.ml`, `lam_compile_primitive.ml`, and
  `lam_module_ident.ml` plus their `.mli` files.
- Verdict: live; false positive.
- Validation: `Lam_compile_env` is used by `lam_compile.ml`,
  `lam_pass_remove_alias.ml`, `lam_arity_analysis.ml`,
  `lam_stats_export.ml`, `js_implementation.ml`, `js_name_of_module_id.cppo.ml`,
  and `lam_compile_main.cppo.ml`. `Lam_compile_external_call.translate_ffi` is
  called by `lam_compile_primitive.ml`, and `ocaml_to_js_eff` is used by
  `lam_compile_external_obj.ml`. `Lam_compile_external_obj.assemble_obj_args`
  and `Lam_compile_primitive.translate` are called by `lam_compile.ml`.
  `Lam_module_ident.t` is a manifest alias of `J.module_id`; `dynamic_import`
  is filled by `Lam_module_ident.of_ml` and read by `js_dump_program.ml` when
  emitting dynamic imports. `Lam_module_ident.Cmp` is passed to `Hash.Make` and
  `Hash_set.Make`; the resulting tables and sets are used by
  `lam_compile_env.ml` for module dependency caching and hard-dependency
  collection. The reported helper functions in those modules are local
  dependencies of those exported lowering entry points.
- Context: `lam_compile_external_call.arg_expression` is a manifest alias of
  `Js_of_lam_variant.arg_expression`; constructor warnings there are false
  positives for the same aliasing reason documented in the JS lowering section.
  `Cmp.equal` and `Cmp.hash` are functor callbacks consumed by generated hash
  modules, so they can look unused as standalone values.

### Core JS lowering helpers

- Report: `Warning Dead Module`, `Warning Dead Value`, and constructor warnings
  in `compiler/core/js_fold_basic.ml`, `js_fun_env.ml`,
  `js_name_of_module_id.mli`, `js_of_lam_array.ml`,
  `js_of_lam_block.ml`, `js_of_lam_option.ml`, `js_of_lam_string.ml`, and
  `js_of_lam_variant.ml` / `.mli`.
- Verdict: live; false positive for the remaining reported helpers.
- Validation: `lam_compile_main.cppo.ml` calls
  `Js_fold_basic.calculate_hard_dependencies`. `Js_fun_env.make` is used while
  building JS functions in `Js_exp_make`; `js_pass_scope.ml` and
  `js_pass_tailcall_inline.ml` use `set_unbounded`, `mark_unused`,
  `get_mutable_params`, and `no_tailcall`. `Js_name_of_module_id` is used by
  `lam_compile_primitive.ml` and `js_dump_program.ml`. Array, block, option,
  string, and variant lowering helpers are called from `lam_compile.ml`,
  `lam_compile_const.ml`, `lam_compile_primitive.ml`,
  `lam_compile_external_obj.ml`, and `lam_compile_external_call.ml`.
  `Polyvar_pattern_match.Coll` is the hash table used by
  `Polyvar_pattern_match.convert` while coalescing variant tag actions; its
  generated operations are reached through the switcher hooks installed by
  `compiler/core/bs_conditional_initial.ml`.
- Context: `Js_of_lam_option.option_unwrap_time` and `undef_to_opt` had no
  callers and were removed. The `Js_of_lam_variant.arg_expression` constructor
  warnings are false positives: `lam_compile_external_call.ml` re-exports the
  same constructors with
  `type arg_expression = Js_of_lam_variant.arg_expression = ...`, then
  constructs and pattern matches `Splice0`, `Splice1`, and `Splice2`.
  `Polyvar_pattern_match.Coll.equal` and `hash` are callbacks consumed by the
  hash-table functor.

### Core JS operators and output state

- Report: constructor warnings in `compiler/core/js_op.ml` for
  `property.Strict`, `Alias`, `StrictOpt`, and `Variable`; and
  `Warning Dead Value` entries in `js_op_util.ml` / `.mli` and
  `js_output.ml` / `.mli`.
- Verdict: live; false positive for the remaining reported entries.
- Validation: the property constructors are the shared
  `Lam_compat.let_kind` constructors used by lambda DCE, conversion, scope, and
  JS statement generation. `Js_op_util.update_used_stats` is used by
  `js_pass_flatten_and_mark_dead.ml`, `js_pass_tailcall_inline.ml`, and
  `js_pass_get_used.ml`; `same_vident` is used by `js_analyzer.ml` and
  `Js_exp_make`; `of_lam_mutable_flag` is used by `lam_compile_primitive.ml`.
  `Js_output` is central to `lam_compile.ml`, and `lam_compile_main.cppo.ml`
  calls `Js_output.concat` and `output_as_block`.
- Context: unused operator model types/cases (`binop.Bnot`, `int_op`, `level`,
  `access`, `recursive_info`, and `length_object.Bytes`) were removed, along
  with the unused `Js_op_util.str_of_used_stats` and `Js_output.to_string`
  debug exports.

### Core JS package path helpers

- Report: `Warning Dead Value` and record-field warnings in
  `compiler/core/js_packages_info.ml` / `.mli`, plus
  `Js_packages_state.get_packages_info`.
- Verdict: live; false positive for the remaining reported package helpers and
  `package_found_info` fields.
- Validation: `compiler/core/js_name_of_module_id.cppo.ml` calls
  `query_package_infos`, `runtime_package_path`,
  `runtime_dir_of_module_system`, `same_package_by_name`, and
  `is_runtime_package`, then reads `package_found_info.rel_path`,
  `pkg_rel_path`, and `suffix`. `lam_compile_main.cppo.ml` uses
  `Js_packages_info.iter`, `lam_compile_primitive.ml` uses
  `Js_packages_info.map`, and `js_name_of_module_id.cppo.ml` reads
  `Js_packages_state.get_packages_info`.
- Context: the unused package dump formatter and old `get_output_dir` helper
  were removed. The remaining warnings are `.cppo.ml` call sites and record
  fields read by package path generation.

### Core JS pass pipeline and traversals

- Report: `Warning Dead Module` / `Warning Dead Value` clusters in
  `compiler/core/js_pass_debug.mli`, `js_pass_external_shadow.ml`,
  `js_pass_flatten.ml`, `js_pass_flatten_and_mark_dead.ml`,
  `js_pass_get_used.ml`, `js_pass_scope.ml`, `js_pass_tailcall_inline.ml`, and
  the generated traversal helpers `js_record_fold.ml`, `js_record_iter.ml`, and
  `js_record_map.ml`.
- Verdict: live; false positive.
- Validation: `compiler/core/lam_compile_main.cppo.ml` runs the JS pass
  pipeline through `Js_pass_debug.dump`, `Js_pass_flatten.program`,
  `Js_pass_external_shadow.program`, `Js_pass_tailcall_inline.tailcall_inline`,
  `Js_pass_flatten_and_mark_dead.program`, and `Js_pass_scope.program`.
  `js_pass_tailcall_inline.ml` calls `Js_pass_get_used.get_stats`. These passes
  instantiate and call the `Js_record_*` traversal records, so the large helper
  clusters under the traversal modules are live through the pass pipeline.
- Context: the DCE report misses `.cppo.ml` roots and therefore treats entire
  passes and their generated traversal helper methods as dead.

### `File_deps.File_hash` callbacks

- Report: `Warning Dead Module` and `Warning Dead Value`,
  `analysis/reanalyze/src/file_deps.ml`, `File_hash.hash` and `File_hash.equal`.
- Verdict: live; false positive.
- Validation: `File_deps.create_builder`, `add_file`, `add_dep`,
  and `merge_into_builder` all use the `File_hash` table produced by
  `Hashtbl.Make`.
- Context: `hash` and `equal` are callbacks consumed by the hashtable functor,
  so they can look unreferenced as ordinary values even though table operations
  depend on them.

### `Arnold` ordered-set compare callbacks

- Report: `Warning Dead Value`, `analysis/reanalyze/src/arnold.ml`,
  `Function_args.compare_arg`, `Function_args.compare`, and
  `Function_call.compare`; same pattern for `Path_map.compare` in
  `analysis/reanalyze/src/dead_exception.ml` and `dead_type.ml`, and
  `Exn.compare` in `analysis/reanalyze/src/exn.ml`.
- Verdict: live; false positive.
- Validation: `Function_call_set = Set.Make (Function_call)` uses
  `Function_call.compare`, which delegates to `Function_args.compare`. The set is
  used in the termination analyzer call stack (`Call_stack.to_set`,
  `Function_call_set.mem`, `Function_call_set.union`, and
  `Function_call_set.empty`). `dead_exception.ml` and `dead_type.ml` both build
  `Path_map = Map.Make (...)`, then use `Path_map.add`, `find_opt`, and `iter`
  for exception and type-label indexes. `exceptions.ml` and `issue.ml` build
  `Set.Make (Exn)`, which requires `Exn.compare`.
- Context: compare functions supplied to functors can look unreferenced as plain
  values even though the generated set module calls them.
