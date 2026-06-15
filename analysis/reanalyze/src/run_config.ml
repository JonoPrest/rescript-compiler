type t = {
  mutable bsb_project_root: string;
  mutable dce: bool;
  mutable exception_: bool;
  mutable project_root: string;
  mutable suppress: string list;
  mutable termination: bool;
  mutable transitive: bool;
  mutable unsuppress: string list;
}

let run_config =
  {
    bsb_project_root = "";
    dce = false;
    exception_ = false;
    project_root = "";
    suppress = [];
    termination = false;
    transitive = false;
    unsuppress = [];
  }

let reset () =
  run_config.dce <- false;
  run_config.exception_ <- false;
  run_config.suppress <- [];
  run_config.termination <- false;
  run_config.transitive <- false;
  run_config.unsuppress <- []

let all () =
  run_config.dce <- true;
  run_config.exception_ <- true;
  run_config.termination <- true

let dce () = run_config.dce <- true
let exception_ () = run_config.exception_ <- true
let termination () = run_config.termination <- true

let transitive b = run_config.transitive <- b

type snapshot = bool * bool * string list * bool * bool * string list

let snapshot () =
  ( run_config.dce,
    run_config.exception_,
    run_config.suppress,
    run_config.termination,
    run_config.transitive,
    run_config.unsuppress )

let equal_snapshot (a : snapshot) (b : snapshot) = a = b
