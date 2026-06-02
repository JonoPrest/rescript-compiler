open Mocha
open Test_utils

/* Exercises `divide_array` in compiler/ml/matching.ml: dispatch on array
 length and element projection. */

let sum = a =>
  switch a {
  | [] => 0
  | [x] => x
  | [x, y] => x + y
  | [x, y, z] => x + y + z
  | _ => -1
  }

let describeLen = a =>
  switch a {
  | [] => "empty"
  | [_] => "one"
  | [_, _] => "two"
  | _ => "many"
  }

describe(__MODULE__, () => {
  test("array match by length", () => {
    eq(__LOC__, sum([]), 0)
    eq(__LOC__, sum([7]), 7)
    eq(__LOC__, sum([1, 2]), 3)
    eq(__LOC__, sum([1, 2, 3]), 6)
    eq(__LOC__, sum([1, 2, 3, 4]), -1)
  })

  test("array match by length (wildcards)", () => {
    eq(__LOC__, describeLen([]), "empty")
    eq(__LOC__, describeLen([9]), "one")
    eq(__LOC__, describeLen([1, 2]), "two")
    eq(__LOC__, describeLen([1, 2, 3, 4]), "many")
  })
})
