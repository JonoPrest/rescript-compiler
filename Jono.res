
let construct: (( unit, unit) => option<int>) => unit = fn => Js.log(fn( (), ()))

construct(Some(1))
