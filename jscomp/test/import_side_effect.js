// Generated by ReScript, PLEASE EDIT WITH CARE
'use strict';


var a = import("./side_effect2.js").then(function (m) {
      return m.a;
    });

var M = await import("./side_effect.js");

exports.a = a;
exports.M = M;
/* M Not a pure module */