open Mocha
open Test_utils

let table = "users"
let id = "5"

let queryAcrossFile = Tagged_template_relative_lib.taggedTemplateLiteralAssert`SELECT * FROM ${table} WHERE id = ${id}`

describe("tagged template across modules", () => {
  test(
    "relative @module path tagged template called from another file emits a real tagged template invocation",
    () => eq(__LOC__, queryAcrossFile, "SELECT * FROM 'users' WHERE id = '5'"),
  )
})
