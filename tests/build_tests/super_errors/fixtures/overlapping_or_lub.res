// `(1, 2)` is covered by the COMBINATION of the two or-branches above, so the
// redundancy check computes the least upper bound (lub) of `(1, _)` and
// `(_, 2)` — exercising lub for Tpat_tuple in parmatch.ml.
let f = (x: (int, int)) =>
  switch x {
  | (1, _) | (_, 2) => "a"
  | (1, 2) => "b"
  | _ => "c"
  }
