// Non-exhaustive list match: exercises the cons (`list{_, ..._}`) witness
// printer (pretty_car / pretty_cdr) in parmatch.ml.
let f = (x: list<int>) =>
  switch x {
  | list{} => 0
  }
