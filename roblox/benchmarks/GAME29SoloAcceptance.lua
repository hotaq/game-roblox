-- Actual background StudioTestService result on 7e0c992, 2026-10-27 UTC.
-- Behavioral trial, not human playtesting; see GAME29Protocol for limits.
return [====[
{
  "callOK": true,
  "result": {
    "ok": true,
    "clients": 1,
    "checks": [
      "prototype remains disabled in repository config",
      "disabled prototype creates no marker/reward",
      "real client receives optional marker",
      "ignore expires without ending run or taking reward",
      "leaving to dodge decays real objective progress",
      "global pause freezes trial clocks",
      "one server reward arrives through ordinary card UI",
      "duplicate completion cannot repeat reward",
      "real card selection consumes one pending reward",
      "restart cannot farm terminal attempt while batch remains",
      "reward commit excludes departed run",
      "death on completion tick cannot add another reward",
      "all runs ended releases marker and attempt state",
      "no captured Goblin script errors"
    ],
    "map1Instances": 5288,
    "kind": "scripted behavioral trials; not a human fun survey",
    "trials": [
      {
        "distanceStuds": 0,
        "progress": 7.999999999999981,
        "strategy": "hold",
        "damageTaken": 63.785728454589844,
        "rewards": 1,
        "wallSeconds": 10.74927419999949,
        "health": 36.214271545410156,
        "seed": 29,
        "status": "success",
        "hordeTarget": 40,
        "activeSeconds": 7.999999999999981,
        "dead": false
      },
      {
        "distanceStuds": 117.50522461533546,
        "progress": 7.999999999999981,
        "strategy": "inside-circle",
        "damageTaken": 69.91654205322266,
        "rewards": 1,
        "wallSeconds": 10.616700499998842,
        "health": 30.083457946777344,
        "seed": 29,
        "status": "success",
        "hordeTarget": 40,
        "activeSeconds": 7.999999999999981,
        "dead": false
      },
      {
        "distanceStuds": 183.99404001235962,
        "progress": 0,
        "strategy": "wide-kite",
        "damageTaken": 93.88401365280151,
        "rewards": 0,
        "wallSeconds": 16.132676099998207,
        "health": 6.115986347198486,
        "seed": 29,
        "status": "active",
        "hordeTarget": 40,
        "activeSeconds": 12.033333333333301,
        "dead": false
      }
    ],
    "errors": []
  }
}
]====]
