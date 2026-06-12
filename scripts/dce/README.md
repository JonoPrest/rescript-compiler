# Compiler dead-code analysis (reanalyze DCE)

Tooling to run reanalyze's dead-code-elimination (DCE) over the **compiler's own
OCaml source**, to find removable dead code. This is the native-OCaml analog of
the `tests/analysis_tests/tests-reanalyze` suite (which analyzes ReScript code).

## Quick start

```bash
scripts/dce/run-dce.sh            # writes _dce/report.txt
```

Requires the host OCaml switch (5.3) with `dune` available (`eval $(opam env)`).
The script fetches + builds a pinned standalone reanalyze on first run (cached in
`~/.cache/rescript-dce/reanalyze-cmt-sourcefile-fallback`).

The runner excludes `tests/ounit_tests` from DCE by default. Unit tests should not
keep compiler implementation details live, and test-only helpers are intentionally
out of scope for the dead-code removal pass. Override `DCE_EXCLUDE_PATHS` only when
you explicitly want to experiment with a different exclusion set.

## Why the vendored `rescript-tools reanalyze` does NOT work here

The compiler's OCaml is compiled by the **host OCaml (5.3)** via dune, producing
`.cmt`/`.cmi` in the **5.3 format** (`Caml1999I035`). The vendored
`rescript-tools reanalyze` links the ReScript `ml` library, which only understands
the old **4.06-era** ReScript cmt format (used for `.res` → `.cmt`). Pointed at the
compiler's own cmts it fails immediately with `Fatal error: Cmi_format.Error`.

So we use the **standalone** reanalyze (`rescript-lang/reanalyze`), built against
the host `compiler-libs.common`. OCaml 5.3 support started in
[reanalyze#203](https://github.com/rescript-lang/reanalyze/pull/203), with
follow-up source-file/dependency fixes on JonoPrest's
`jono/cmt-sourcefile-fallback` branch. The runner pins that branch commit.

## Status: actionable, still manually validated

The tooling runs end-to-end and produces a full report over all dune-built cmts.
The pinned `jono/cmt-sourcefile-fallback` build fixes the large cross-module
false-positive class seen with the earlier `ocaml-5-3` branch. Treat the report as
an actionable worklist, but still manually validate each warning with source
searches and `dune build @check` before committing removals.

### 1. (Fixed) Entry-point roots — use `dune build @check`

reanalyze DCE is a whole-program reachability analysis anchored at **roots** (entry
points = the executable mains). A plain `dune build` does native compilation and
emits only `.cmti` (no impl `.cmt`) for modules with an `.mli` — including the `bsc`
main — so reanalyze never sees the entry-point bodies and over-reports. The runner
now uses `dune build @check`, which typecheck-builds everything and emits the impl
`.cmt` for all modules. This fixed the `Bs_version`-class false positives.

Residual root gap: the playground `jsoo` main is `enabled_if profile=browser` with
`(modes js wasm)` (no bytecode `.cmt`), and the dune comment says not to build it by
default (slow). So code used only by the playground can still show as dead.

## Keeping the report actionable

- declare entry points live with `-live-paths` / `-live-names`,
- `@live`/`@dead` source annotations (precedent: ~38 already exist in
  `compiler/gentype` and `compiler/syntax`), plus `-suppress` for whole subtrees,
- handle the `jsoo` root gap (annotate live, or a check-only browser-profile build).

## Lowest-noise categories to start from

These depend on **call-site** analysis within the set, so they're far less
sensitive to the missing-roots problem and are the best first targets:

- **Redundant Optional Argument** — optional arg *always supplied* at every call,
  e.g. `transl_apply`'s `~inlined`/`~transformed_jsx` (`compiler/ml/translcore.ml`),
  `Typ.poly`'s `~loc` (`compiler/ml/ast_helper`). Can be made mandatory.
- **Unused Argument** — optional arg *never used* in the body, e.g.
  `type_open_`'s `~used_slot` (`compiler/ml/typemod.ml`),
  `disjoint_union`'s `~eq`/`~print` (`compiler/ext/identifiable.ml`).

## Relationship to the manual "unreachable OCaml variant" survey

Complementary, with a subtle boundary:

- reanalyze **does** detect "variant case which is never constructed" (~278 found),
  overlapping the manual survey — but with false positives when the only
  construction site sits outside the analyzed cmt set.
- reanalyze **misses** variants that *are* constructed but only inside **unreachable
  code**. Example: `Longident.Lapply` is "constructed" in `ctype.ml`'s `lid_of_path`
  (a branch that never runs), so reanalyze sees it as live and does not flag it —
  yet it is genuinely dead. That class still needs the manual reachability reasoning.

## CI integration (proposed, not yet wired)

Once the backlog is cleaned up, gate CI on **new** dead code: run `run-dce.sh`,
diff against the checked-in baseline, and fail on additions. Open question: how to
depend on the external unmerged analyzer fix long-term (pin a commit, vendor it,
or wait for merge).
