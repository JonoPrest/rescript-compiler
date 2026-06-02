open Mocha
open Test_utils

/* Exercises `divide_variant` / `split_variant_cases` and the variant
   switchers in compiler/ml/matching.ml. A closed polymorphic variant with
   both constant tags (#Red ...) and block tags (#Rgb(..), #Named(..)) forces
   the `Pis_poly_var_block` split plus both the constant and block switch
   paths. Exhaustive, so it stays warning-clean. */

type color = [#Red | #Green | #Blue | #Rgb(int, int, int) | #Named(string)]

let name = (c: color) =>
  switch c {
  | #Red => "red"
  | #Green => "green"
  | #Blue => "blue"
  | #Rgb(r, g, b) => string_of_int(r + g + b)
  | #Named(s) => s
  }

describe(__MODULE__, () => {
  test("polymorphic variant: constant tags", () => {
    eq(__LOC__, name(#Red), "red")
    eq(__LOC__, name(#Green), "green")
    eq(__LOC__, name(#Blue), "blue")
  })

  test("polymorphic variant: block tags", () => {
    eq(__LOC__, name(#Rgb(1, 2, 3)), "6")
    eq(__LOC__, name(#Named("teal")), "teal")
  })
})
