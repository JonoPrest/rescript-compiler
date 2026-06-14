open Mocha
open Test_utils

/* Exercises `combine_constant` in compiler/ml/matching.ml across every constant
   kind, each routed to a different compilation strategy:
     - Const_int    -> call_switcher / interval logic (edges, holes, negatives)
     - Const_char   -> call_switcher (0..max)
     - Const_float  -> make_test_sequence with Pfloatcomp
     - Const_bigint -> make_test_sequence with Pbigintcomp
   All matches are exhaustive (trailing `_`) to stay warning-clean under
   -warn-error A. */

let classifyInt = x =>
  switch x {
  | -5 => "neg5"
  | 0 => "zero"
  | 1 | 2 | 3 => "small"
  | 100 => "hundred"
  | _ => "other"
  }

let classifyChar = c =>
  switch c {
  | 'a' => 1
  | 'e' => 2
  | 'm' => 3
  | 'q' => 4
  | 'z' => 5
  | _ => 0
  }

/* >= 4 cases so make_test_sequence performs the dichotomic split
 (split_sequence / cut) rather than a flat comparison chain. */
let classifyFloat = x =>
  switch x {
  | 0.0 => "zero"
  | 1.5 => "onehalf"
  | 2.5 => "twohalf"
  | 3.5 => "threehalf"
  | 4.5 => "fourhalf"
  | _ => "other"
  }

let classifyBig = b =>
  switch b {
  | 0n => "zero"
  | 1n => "one"
  | 10n => "ten"
  | 50n => "fifty"
  | 100n => "hundred"
  | _ => "other"
  }

describe(__MODULE__, () => {
  test("int switch with negatives, or-pattern and holes", () => {
    eq(__LOC__, classifyInt(-5), "neg5")
    eq(__LOC__, classifyInt(0), "zero")
    eq(__LOC__, classifyInt(1), "small")
    eq(__LOC__, classifyInt(2), "small")
    eq(__LOC__, classifyInt(3), "small")
    eq(__LOC__, classifyInt(100), "hundred")
    eq(__LOC__, classifyInt(4), "other")
    eq(__LOC__, classifyInt(-1), "other")
  })

  test("char switch", () => {
    eq(__LOC__, classifyChar('a'), 1)
    eq(__LOC__, classifyChar('e'), 2)
    eq(__LOC__, classifyChar('m'), 3)
    eq(__LOC__, classifyChar('q'), 4)
    eq(__LOC__, classifyChar('z'), 5)
    eq(__LOC__, classifyChar('x'), 0)
  })

  test("float switch (dichotomic comparison split)", () => {
    eq(__LOC__, classifyFloat(0.0), "zero")
    eq(__LOC__, classifyFloat(1.5), "onehalf")
    eq(__LOC__, classifyFloat(2.5), "twohalf")
    eq(__LOC__, classifyFloat(3.5), "threehalf")
    eq(__LOC__, classifyFloat(4.5), "fourhalf")
    eq(__LOC__, classifyFloat(9.9), "other")
  })

  test("bigint switch (dichotomic comparison split)", () => {
    eq(__LOC__, classifyBig(0n), "zero")
    eq(__LOC__, classifyBig(1n), "one")
    eq(__LOC__, classifyBig(10n), "ten")
    eq(__LOC__, classifyBig(50n), "fifty")
    eq(__LOC__, classifyBig(100n), "hundred")
    eq(__LOC__, classifyBig(7n), "other")
  })
})
