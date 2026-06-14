# Pattern-matching coverage notes

Companion to [`ERROR_VARIANTS.md`](./ERROR_VARIANTS.md), scoped to the two
central pattern-matching modules:

- `compiler/ml/matching.ml` — pattern compilation to Lambda IR
- `compiler/ml/parmatch.ml` — exhaustiveness / redundancy analysis

It records which uncovered (cold) lines are **reachable** from `.res`
fixtures and which are **structurally unreachable** (dead code, debug-only,
or defensive). The goal is to stop coverage reviews from chasing lines that
no test can ever hit, and to point future fixtures at the lines that remain.

Baseline (fresh `make coverage` off `master` @ `7d96fe384`):

| Module | Coverage | Cold lines |
|---|---|---|
| `compiler/ml/matching.ml` | 72.6% | 366 |
| `compiler/ml/parmatch.ml`  | 75.6% | 256 |

> **Why the common paths are already covered.** Every `switch` in the stdlib
> and the existing test suite flows through `matching.ml`, so the ordinary
> per-category dispatchers (constants, constructors, variants, tuples,
> records, arrays, or-patterns) are already exercised. The cold lines are the
> *residue*: dead OCaml-heritage branches, debug printers, and genuinely
> exotic edge cases. Adding fixtures for "common" shapes does **not** move the
> metric — they overlap existing coverage. Realistic ceiling for both files is
> roughly **82–88%**, not ~100%.

Line numbers are as of `master` @ `7d96fe384` and will drift; treat them as
approximate anchors and re-confirm against the current source.

---

## Structurally unreachable — do not chase

### `compiler/ml/matching.ml`

| Lines | What | Why unreachable |
|---|---|---|
| ~1530–1600 | `expand_stringswitch`, `do_make_string_test_tree`, `make_string_test_sequence`, `split`, `tree_way_test`, `bind_sw` | **Dead for the JS target.** `combine_constant` routes `Const_string` to `Lstringswitch` (≈ line 2060); the dichotomic string-search tree is only used by the OCaml bytecode compiler (`bytegen.ml`), which ReScript does not use. |
| 2064–2065 | `Const_int32 -> assert false`, `Const_int64 -> assert false` | ReScript has no `int32`/`int64` literal patterns, so these constant cases never reach `combine_constant`. |
| ~2175, ~2190 | `... when false ->` branches in `combine_constructor` | Guarded by a literal `false` ("relies on tag being an int"); intentionally disabled. |
| 1976–1979, 2007–2009, 2013, 2015–2019 | `if dbg then (...)` blocks in `mk_failaction_pos` | `dbg` is a compile-time `false`; debug tracing only. |
| 69–75, 377–428, 1084–1089, 2540–2552 | `pretty_*` / `pretty_pm` / `pretty_precompiled` / `prerr_endline "** SPLIT **"` / `"COMPILE: "` | Debug pretty-printers, reachable only under `dbg`. |
| 153–155, 227, 1158–1161, 1665, 1679 | `fatal_error "Matching.filter_matrix"` / `"Matching.ctx_matcher"` / `"BAD: " ^ caller; assert false` / `Invalid_argument "cut"` / `fatal_error "Matching.do_tests_nofail"` | Defensive assertions guarding internal invariants; not reachable from well-typed input. |

### `compiler/ml/parmatch.ml`

| Lines | What | Why unreachable |
|---|---|---|
| ~364–434 | `pretty_const`, `pretty_val`, `pretty_car`, `pretty_cdr`, `pretty_arg`, `pretty_lvals` | **Debug-only.** These are *not* the user-facing witness printer. The non-exhaustive warning builds its counter-example via `!print_res_pat` (parmatch.ml:2088), which is bound to `Pattern_printer.print_pattern` in `compiler/common/pattern_printer.ml` (already ~88% covered). The `pretty_*` family here is reachable only from the `dbg` tracing in this module. |
| 369–370 | `Const_int32 -> "%ldl"`, `Const_int64 -> "%LdL"` in `pretty_const` | (Subsumed by the row above; also: no `int32`/`int64` literal patterns exist.) |
| 461–476 | `pretty_line` / `pretty_matrix` (`prerr_endline "begin matrix"` …) | Debug-only matrix dumpers. |
| 981–986 | `fatal_error "Parmatch.get_variant_constructors"` | Defensive; the guarded shapes are guaranteed by typing. |

---

## Reachable but cold — worth fixtures

> **Correction / lesson.** An earlier draft of this file claimed the
> `pretty_val` / `pretty_const` family (~364–434) was the reachable witness
> printer and that one non-exhaustive fixture *per pattern shape* would light
> it up. That is **wrong** — those are debug printers (see the dead-code table
> above); the user-facing witness is rendered by `Pattern_printer.print_pattern`.
> Direct measurement (compile each fixture with a dedicated `BISECT_FILE`)
> confirmed the `pretty_*` lines stay cold even when the witness prints. Always
> verify a "reachable" hypothesis against an actual `.coverage` file, not
> against the visible warning text.

### `compiler/ml/parmatch.ml` — analysis edges

These *are* reachable, but the payoff is small (a handful of lines), because the
surrounding exhaustiveness/redundancy machinery is already exercised by the
existing suite.

| Lines | What | Trigger | Status |
|---|---|---|---|
| 2058–2061 | `Warnings.All_clauses_guarded` | every clause carries an `if` guard | partially covered by `all_clauses_guarded` |
| 1649–1652, 1757–1761 | `Upartial` merge in or-pattern redundancy | an or-pattern clause whose *some* sub-branch is redundant | partially covered by `redundant_or_branch` |
| 1814–1859 | `lub` (least upper bound) for tuple/variant/record/array | a clause covered by the *combination* of two overlapping or-branches | still cold — `overlapping_or_lub` did **not** reach the tuple-`lub` branch; needs a sharper trigger |

### `compiler/ml/matching.ml` — compilation edges

| Lines | What | Trigger | Status |
|---|---|---|---|
| 1662–1705 | `make_test_sequence` dichotomic split (`split_sequence`/`cut`) | float/bigint/char match with **≥ 4** value cases | ✓ covered by `pattern_match_constants_test` |
| 2182–2186, 2396–2399, 2479–2482, 2911–2915, 2952–2957 | partial-match failaction / unused-handler / cannot-flatten paths | a *simple* non-exhaustive match is **not** enough; these need an unused or-pattern handler, a `Cannot_flatten` tuple-`let`, or a partial match whose non-constant constructors share an action | still cold — needs targeted fixtures |
| 1295–1300, 1311–1314, 1390–1393, 1491–1494 | `matcher_*` `Tpat_or` (`raise OrPat`) | or-patterns at a column being specialized during precompilation | still cold |
| 1877–1923 | `as_interval_canfail` / `as_interval_nofail` hole logic | integer switches with non-contiguous values and a shared fail action | still cold |

> **Measured contribution of this PR's fixtures.** Confirmed via per-fixture
> `BISECT_FILE` compilation (full JS, not `-bs-cmi-only`): ~10 lines in
> `matching.ml` (the dichotomic split) and ~5 in `parmatch.ml`
> (`All_clauses_guarded`, `Upartial`). The rest of the apparent full-suite
> delta is measurement noise from differing compile sets between runs. The
> behaviour fixtures' main value is **regression protection + cross-`bsc`
> portability**, not the coverage metric — most pattern shapes were already
> covered by the existing suite.

---

## How to re-measure

```bash
# Fresh baseline (records compiler line hits via bisect_ppx):
make coverage            # writes _coverage/coverage.json (Coveralls format)

# Per-file cold lines:
jq -r --arg f compiler/ml/matching.ml \
  '.source_files[] | select(.name|endswith($f)) | .coverage
   | to_entries | map(select(.value==0) | .key+1) | @csv' \
  _coverage/coverage.json
```

To check whether one fixture hits a target line without a full run, compile it
with the bisect-instrumented `bsc` and a dedicated `BISECT_FILE`, then inspect
the resulting `*.coverage`. For witness branches it is usually enough to read
the warning text: if the printed counter-example has the shape you targeted,
the matching `pretty_val` branch executed.
