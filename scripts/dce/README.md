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

## Status: it RUNS, but the output is NOT yet trustworthy

The tooling runs end-to-end and produces a full report over all dune-built cmts.
That is the mechanical milestone. **But the results cannot currently be acted on**,
for two stacked reasons:

### 1. (Fixed) Entry-point roots — use `dune build @check`

reanalyze DCE is a whole-program reachability analysis anchored at **roots** (entry
points = the executable mains). A plain `dune build` does native compilation and
emits only `.cmti` (no impl `.cmt`) for modules with an `.mli` — including the `bsc`
main — so reanalyze never sees the entry-point bodies and over-reports. The runner
now uses `dune build @check`, which typecheck-builds everything and emits the impl
`.cmt` for all modules. This fixed the `Bs_version`-class false positives and cut
Dead Value ~2740 → ~2130, Dead Module ~203 → ~146.

Residual root gap: the playground `jsoo` main is `enabled_if profile=browser` with
`(modes js wasm)` (no bytecode `.cmt`), and the dune comment says not to build it by
default (slow). So code used only by the playground still shows as dead.

### 2. (BLOCKER) reanalyze#203's 5.3 dependency tracking is incomplete

Even with roots fixed, the report flags **obviously-live core modules as dead** —
e.g. `Ast_helper` (510 references in-tree), `Lam_compile`, `Js_dump`, `Lam_convert`.
The cause is stated in the PR itself: reanalyze#203 derives value dependencies
*"just based on the type of what's available in the new `Cmt_format.cmt_infos`"* —
a **tentative, incomplete** method that does not capture the real use edges in 5.3
cmts. As a result the cross-reference-based categories (Dead Value / Dead Module /
Dead Type / "never constructed") are unreliable: there are real positives buried in
there, but you can't tell which without manually re-verifying every one, which
defeats the purpose.

Local, call-site-based categories fare better — e.g. `transl_apply`'s `~inlined` is
correctly reported as always-supplied — but they rely on the same reference tracking,
so they're only trustworthy when a function has few, simple call sites.

#### Root cause (investigated) and why the fix is non-trivial

reanalyze's DCE is **location-keyed**: declarations are registered by source
position, and a use is connected to a declaration when the use's recorded "target
location" equals the declaration's. OCaml 5.3 broke this on two fronts:

1. `cmt_value_dependencies` (direct location-based use→def edges) was replaced by
   `cmt_declaration_dependencies`, which identifies declarations by `Shape.Uid`. A
   cmt's `cmt_uid_to_decl` only maps the uids it *defines*, so cross-module uids
   can't be resolved locally. (#203 also only carries a small subset of edges here —
   e.g. `typecore.cmt` exposes ~35 — so this is not the main reference source anyway.)
2. The dominant reference source is the **typedtree walk** (`DeadValue.collectExpr`,
   `Texp_ident` → `val_loc`). In 5.3 the `val_loc` on a cross-module reference's
   `value_description` no longer matches where the declaration is registered, so the
   use→decl edge is dropped → widely-used modules look dead.

**Experiments (in a local reanalyze fix branch):**
- Added a global, order-independent `Shape.Uid → declaration` table (pre-pass over
  all cmts) and resolved `cmt_declaration_dependencies` against it. Correct and
  necessary foundation, but ~no effect (that channel carries few edges).
- Then resolved `Texp_ident` references via the value's `val_uid` through that table
  instead of `val_loc`. This **regressed** (Dead Value 2129 → 2526), because
  declarations are still registered at their old location key, so moving only the
  *reference* side just relocates the mismatch.

**Conclusion:** the fix is a real refactor, not a patch — reanalyze's DCE core must
key declarations *and* references by the same canonical identity (uid-based) so the
two sides agree. Best done upstream on reanalyze#203 (issue #202), ideally with its
author. Until then, treat the report as a lead generator needing per-item manual
verification, not a worklist.

## Making it actionable (once #203's dependency tracking is solid)

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

Once roots are fixed and a clean baseline exists, gate CI on **new** dead code:
run `run-dce.sh`, diff against a checked-in baseline, fail on additions. Open
question: how to depend on the external unmerged reanalyze#203 (pin a commit, vendor
it, or wait for merge).
