open Mocha
open Test_utils

/* Exercises the or-pattern compilation paths in compiler/ml/matching.ml
   (`split_or`, `explode_or_pat`, `precompile_or`):
     - or-pattern of constant constructors
     - or-pattern binding a shared variable across both branches
     - or-patterns inside tuple columns (forces explosion) */

type token = Plus | Minus | Times | Div | Num(int)

let isOp = t =>
  switch t {
  | Plus | Minus | Times | Div => true
  | Num(_) => false
  }

type rec tree = Leaf(int) | Node(int, tree, tree)

/* `v` is bound in both arms of the or-pattern */
let rootVal = t =>
  switch t {
  | Leaf(v) | Node(v, _, _) => v
  }

let classify = x =>
  switch x {
  | (1 | 2 | 3, "a" | "b") => "match"
  | (_, _) => "no"
  }

describe(__MODULE__, () => {
  test("or-pattern of constant constructors", () => {
    eq(__LOC__, isOp(Plus), true)
    eq(__LOC__, isOp(Div), true)
    eq(__LOC__, isOp(Num(1)), false)
  })

  test("or-pattern binding shared variable", () => {
    eq(__LOC__, rootVal(Leaf(5)), 5)
    eq(__LOC__, rootVal(Node(9, Leaf(1), Leaf(2))), 9)
  })

  test("or-patterns inside tuple columns", () => {
    eq(__LOC__, classify((1, "a")), "match")
    eq(__LOC__, classify((3, "b")), "match")
    eq(__LOC__, classify((4, "a")), "no")
    eq(__LOC__, classify((1, "c")), "no")
  })
})
