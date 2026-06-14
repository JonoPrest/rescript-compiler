type t = A | B | C

// `B` in the second clause is already covered by the first, exercising the
// Upartial (partially-redundant or-pattern) path in parmatch.ml.
let f = x =>
  switch x {
  | A | B => 1
  | B | C => 2
  | _ => 3
  }
