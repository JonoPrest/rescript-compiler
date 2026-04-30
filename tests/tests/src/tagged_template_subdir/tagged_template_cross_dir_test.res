open Mocha
open Test_utils

let q = Tagged_template_relative_lib.taggedTemplateLiteralAssert`hello ${"world"}`

describe("cross-directory consumer of relative @taggedTemplate", () => {
  test(
    "consumer in a subdirectory uses the @taggedTemplate external from a sibling-directory module",
    () => eq(__LOC__, q, "hello 'world'"),
  )
})
