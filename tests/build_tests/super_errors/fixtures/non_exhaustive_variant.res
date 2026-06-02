type t = A | B(int) | D(int, int)

// Non-exhaustive variant match: exercises the Tpat_construct (with-args)
// witness printer.
let f = x =>
  switch x {
  | A => 0
  }
