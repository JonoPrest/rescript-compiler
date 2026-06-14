// Non-exhaustive tuple match: exercises the Tpat_tuple / Tpat_or witness
// printer in parmatch.ml (pretty_val).
let f = (x: (bool, bool)) =>
  switch x {
  | (true, true) => 1
  | (false, false) => 2
  }
