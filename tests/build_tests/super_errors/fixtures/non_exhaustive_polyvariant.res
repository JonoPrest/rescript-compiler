// Non-exhaustive polymorphic-variant match: exercises the Tpat_variant
// witness printer.
let f = (x: [#A | #B(int)]) =>
  switch x {
  | #A => 0
  }
