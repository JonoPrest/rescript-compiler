open Mocha
open Test_utils

/* Exercises `combine_constructor` in compiler/ml/matching.ml:
     - regular variant, mixed arities, exhaustive -> Lswitch, sig_complete (no fail)
     - extension constructors (exceptions) -> Pextension_slot_eq chain
     - unboxed single constructor -> direct projection */

type shape =
  | Point
  | Circle(float)
  | Square(float)
  | Rect(float, float)

let area = s =>
  switch s {
  | Point => 0.0
  | Circle(r) => 3.0 *. r *. r
  | Square(side) => side *. side
  | Rect(w, h) => w *. h
  }

exception NotFound
exception Code(int)

let describeExn = e =>
  switch e {
  | NotFound => "not-found"
  | Code(n) => "code:" ++ string_of_int(n)
  | _ => "other"
  }

@unboxed type meters = Meters(float)

let unwrap = m =>
  switch m {
  | Meters(f) => f
  }

describe(__MODULE__, () => {
  test("exhaustive variant switch, mixed arities", () => {
    eq(__LOC__, area(Point), 0.0)
    eq(__LOC__, area(Circle(2.0)), 12.0)
    eq(__LOC__, area(Square(3.0)), 9.0)
    eq(__LOC__, area(Rect(2.0, 5.0)), 10.0)
  })

  test("extension/exception constructor match", () => {
    eq(__LOC__, describeExn(NotFound), "not-found")
    eq(__LOC__, describeExn(Code(5)), "code:5")
    eq(__LOC__, describeExn(Failure("x")), "other")
  })

  test("unboxed single constructor", () => {
    eq(__LOC__, unwrap(Meters(4.5)), 4.5)
  })
})
