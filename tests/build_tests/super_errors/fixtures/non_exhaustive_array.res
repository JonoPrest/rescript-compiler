// Non-exhaustive array match: exercises array-length exhaustiveness and its
// witness.
let f = (x: array<int>) =>
  switch x {
  | [] => 0
  | [_] => 1
  }
