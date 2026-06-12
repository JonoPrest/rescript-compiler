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
