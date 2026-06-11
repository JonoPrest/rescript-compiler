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
`~/.cache/rescript-dce`).

## Why the vendored `rescript-tools reanalyze` does NOT work here

The compiler's OCaml is compiled by the **host OCaml (5.3)** via dune, producing
`.cmt`/`.cmi` in the **5.3 format** (`Caml1999I035`). The vendored
`rescript-tools reanalyze` links the ReScript `ml` library, which only understands
the old **4.06-era** ReScript cmt format (used for `.res` → `.cmt`). Pointed at the
compiler's own cmts it fails immediately with `Fatal error: Cmi_format.Error`.

So we use the **standalone** reanalyze (`rescript-lang/reanalyze`), built against
the host `compiler-libs.common`. OCaml 5.3 support comes from
[reanalyze#203](https://github.com/rescript-lang/reanalyze/pull/203) (branch
`ocaml-5-3`), **not yet merged** — the runner pins its commit.

## Status: it works

Running DCE over all 529 dune-built cmts produces a full report. Category counts
from a baseline run (`-dce-cmt _build/default`):

| Category | Count |
|---|---|
| Dead Value | ~2740 |
| Dead Type | ~386 |
| Redundant Optional Argument | ~212 |
| Dead Module | ~203 |
| Unused Argument | ~169 |
| Dead Value With Side Effects | ~108 |
| (of which) variant cases "never constructed" | ~278 |

## The big caveat: entry-point false positives

The raw numbers are dominated by false positives. reanalyze DCE is a whole-program
reachability analysis anchored at **roots** (entry points). The compiler's true
entry points are the executable mains — and **dune emits only `.cmti` (no `.cmt`
body) for the `bsc` main**, while the playground (`jsoo`) main isn't built in the
default profile at all. With the entry-point bodies missing, everything reachable
only from them looks dead. Concrete example: `Bs_version` is flagged a "dead
module" even though `compiler/bsc/rescript_compiler_main.ml` and
`compiler/jsoo/jsoo_playground_main.ml` use it.

**To make this actionable, the next step is fixing roots**, via some combination of:
- getting dune to emit `.cmt` for the executable mains (so their call sites are
  analyzed), and/or
- declaring entry points live with `-live-paths` / `-live-names`, and/or
- `@live`/`@dead` source annotations (precedent: ~38 already exist in
  `compiler/gentype` and `compiler/syntax`), plus `-suppress` for whole subtrees.

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

Once roots are fixed and a clean baseline exists, gate CI on **new** dead code:
run `run-dce.sh`, diff against a checked-in baseline, fail on additions. Open
question: how to depend on the external unmerged reanalyze#203 (pin a commit, vendor
it, or wait for merge).
