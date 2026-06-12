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
