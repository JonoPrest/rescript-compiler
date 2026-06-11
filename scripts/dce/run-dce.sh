#!/bin/bash
# Run reanalyze dead-code-elimination (DCE) over the compiler's OWN OCaml source.
#
# WHY A SEPARATE TOOL: the compiler's OCaml is built by the host OCaml (5.3) via
# dune, producing 5.3-format .cmt/.cmi. The vendored `rescript-tools reanalyze`
# links the ReScript `ml` library, which only understands the old (4.06-era)
# ReScript cmt format used for .res -> .cmt, so it CANNOT read the compiler's own
# cmts (fails with Cmi_format.Error). We therefore use the STANDALONE reanalyze
# built against the host compiler-libs. OCaml 5.3 support comes from
# rescript-lang/reanalyze#203 (branch `ocaml-5-3`), which is not yet merged, so we
# pin its commit here.
#
# Usage: scripts/dce/run-dce.sh [output-file]
#   Output defaults to _dce/report.txt
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

# Pinned standalone reanalyze with OCaml 5.3 support (PR #203).
REANALYZE_REPO="https://github.com/rescript-lang/reanalyze.git"
REANALYZE_REF="${REANALYZE_REF:-1327343}" # head of branch ocaml-5-3 at time of writing
REANALYZE_SRC="${REANALYZE_SRC:-$HOME/.cache/rescript-dce/reanalyze}"

OUT="${1:-_dce/report.txt}"
mkdir -p "$(dirname "$OUT")"

# 1. Fetch + build the standalone reanalyze (cached).
if [ ! -x "$REANALYZE_SRC/_build/default/src/Reanalyze.exe" ]; then
  echo "==> Fetching standalone reanalyze ($REANALYZE_REF)"
  rm -rf "$REANALYZE_SRC"
  git clone --quiet "$REANALYZE_REPO" "$REANALYZE_SRC"
  git -C "$REANALYZE_SRC" checkout --quiet "$REANALYZE_REF"
  echo "==> Building reanalyze against $(ocaml -version)"
  (cd "$REANALYZE_SRC" && dune build 2>&1 | tail -5)
fi
BIN="$REANALYZE_SRC/_build/default/src/Reanalyze.exe"

# 2. Typecheck-build so dune emits fresh .cmt for EVERY module, including the
#    executable mains (bsc, res_cli). A plain `dune build` does native compilation
#    and emits only `.cmti` for modules that have an `.mli` (e.g. the bsc main),
#    leaving reanalyze blind to the entry-point bodies and over-reporting dead code.
#    `@check` is typecheck-only and emits the impl `.cmt` for all of them.
echo "==> dune build @check (producing .cmt files incl. entry points)"
dune build @check

# 3. Run DCE over the whole dune build tree (compiler + tools + analysis +
#    executables). All are host-OCaml 5.3 cmts; the ReScript runtime (4.06 cmts)
#    lives outside _build/default so it is not picked up.
echo "==> Running DCE -> $OUT"
"$BIN" -dce-cmt _build/default > "$OUT" 2>&1 || true

echo "==> Done. Summary:"
grep -oE "Warning [A-Za-z ]+" "$OUT" | sort | uniq -c | sort -rn || true
echo "    never-constructed variants: $(grep -c 'never constructed' "$OUT" || echo 0)"
echo "Full report: $OUT"
