// Every clause is guarded, so exhaustiveness cannot be proven:
// exercises Warnings.All_clauses_guarded in parmatch.ml.
let f = (x: int) =>
  switch x {
  | n if n > 0 => "pos"
  | n if n <= 0 => "nonpos"
  }
