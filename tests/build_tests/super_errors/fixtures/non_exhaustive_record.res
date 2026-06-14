type point = {a: bool, b: bool}

// Non-exhaustive record match: exercises the Tpat_record witness printer.
let f = x =>
  switch x {
  | {a: true, b: true} => 1
  }
