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

### `Ast_helper0` helper labels

- Report: many `Warning Redundant Optional Argument` entries in
  `compiler/ml/ast_helper0.ml`, starting with `Te.constructor`, `Te.mk`,
  `Type.field`, and `Type.constructor`.
- Verdict: live compatibility surface; do not remove as part of this DCE pass.
- Validation: `compiler/ml/ast_mapper_to0.ml` opens `Ast_helper0` and uses these
  helpers while converting the current `Parsetree` to `Parsetree0`, supplying
  locations, attributes, privacy flags, constructor arguments, and similar data
  from the source tree.
- Context: `Ast_helper0` mirrors the helper shape for the frozen v0 parsetree.
  The repository guidance says v0 PPX compatibility must be preserved, so
  changing this helper API for locally redundant labels is higher risk than the
  DCE warning suggests.

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

### `Location.report_error ?custom_intro ?src`

- Report: `Warning Redundant Optional Argument`, `compiler/ml/location.ml` and
  `compiler/ml/location.mli`, optional arguments `custom_intro` and `src` on
  `report_error`.
- Verdict: live; false positive.
- Validation: `compiler/syntax/src/res_diagnostics.ml` calls
  `Location.report_error ~custom_intro ~src:(Some src)` when rendering syntax
  diagnostics, and `compiler/jsoo/jsoo_playground_main.ml` uses the default
  wrapper form. The local exception reporter also passes explicit `None` values.
- Context: these labels select syntax-error intro text and source rendering for
  diagnostics. Reanalyze only counts the local wrapper call, so it misses the
  cross-module diagnostic call that supplies real values.

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
  and `.mli`, currently including `length`.
- Verdict: live; false positive.
- Validation: `analysis/reanalyze/src/reactive_analysis.ml` uses
  `Reactive_file_collection.create`, `process_files_batch`, `mem`, `iter`,
  `length`, and `to_collection`; `analysis/reanalyze/src/reanalyze.ml` uses
  `process_files_batch` and `remove_batch` directly for churn tests.
- Context: the single-file/cache-management helpers were removed, but the
  remaining collection operations are part of the live reactive analyzer path.
