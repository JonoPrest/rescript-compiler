open Mocha
open Test_utils

/* Exercises `divide_record` / `divide_tuple` (and guards) in
   compiler/ml/matching.ml: field projection, mutable fields, nested
   constant tests inside record/tuple columns, and `when` guards. */

type point = {x: int, y: int}

let quadrant = p =>
  switch p {
  | {x: 0, y: 0} => "origin"
  | {x: 0, y: _} => "y-axis"
  | {x: _, y: 0} => "x-axis"
  | {x, y} if x > 0 && y > 0 => "q1"
  | _ => "other"
  }

type counter = {mutable count: int, label: string}

let bump = c =>
  switch c {
  | {count: 0, label} => "start-" ++ label
  | {count, label} => label ++ ":" ++ string_of_int(count)
  }

let cmpPair = t =>
  switch t {
  | (0, 0) => "both-zero"
  | (0, _) => "first-zero"
  | (_, 0) => "second-zero"
  | (a, b) if a == b => "equal"
  | _ => "distinct"
  }

describe(__MODULE__, () => {
  test("record field tests + guard", () => {
    eq(__LOC__, quadrant({x: 0, y: 0}), "origin")
    eq(__LOC__, quadrant({x: 0, y: 4}), "y-axis")
    eq(__LOC__, quadrant({x: 4, y: 0}), "x-axis")
    eq(__LOC__, quadrant({x: 1, y: 1}), "q1")
    eq(__LOC__, quadrant({x: -1, y: 2}), "other")
  })

  test("mutable record field match", () => {
    eq(__LOC__, bump({count: 0, label: "a"}), "start-a")
    eq(__LOC__, bump({count: 3, label: "b"}), "b:3")
  })

  test("tuple match with guard", () => {
    eq(__LOC__, cmpPair((0, 0)), "both-zero")
    eq(__LOC__, cmpPair((0, 7)), "first-zero")
    eq(__LOC__, cmpPair((7, 0)), "second-zero")
    eq(__LOC__, cmpPair((5, 5)), "equal")
    eq(__LOC__, cmpPair((5, 6)), "distinct")
  })
})
