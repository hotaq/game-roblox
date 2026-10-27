-- Actual background StudioTestService result on 7e0c992, 2026-10-27 UTC.
-- Behavioral trial, not human playtesting; see GAME29Protocol for limits.
return [====[
{
  "callOK": true,
  "result": {
    "ok": true,
    "clients": 2,
    "checks": [
      "prototype remains disabled in repository config",
      "disabled prototype creates no marker/reward",
      "real client receives optional marker",
      "ignore expires without ending run or taking reward",
      "leaving to dodge decays real objective progress",
      "global pause freezes trial clocks",
      "one server reward arrives through ordinary card UI",
      "distant eligible teammate gets one offer",
      "duplicate completion cannot repeat reward",
      "real card selection consumes one pending reward",
      "restart cannot farm terminal attempt while batch remains",
      "peer has no captured Goblin errors before departure",
      "actual disconnect removes eligibility during pause",
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
        "hordeTarget": 40,
        "progress": 7.999999999999981,
        "strategy": "hold",
        "damageTaken": 57.86783981323242,
        "peerHealth": 100,
        "rewards": 1,
        "wallSeconds": 10.882889499996963,
        "health": 42.13216018676758,
        "seed": 29,
        "status": "success",
        "peerRewards": 1,
        "activeSeconds": 7.999999999999981,
        "dead": false
      },
      {
        "distanceStuds": 117.50522461533546,
        "hordeTarget": 40,
        "progress": 7.999999999999981,
        "strategy": "inside-circle",
        "damageTaken": 87.91997909545898,
        "peerHealth": 100,
        "rewards": 1,
        "wallSeconds": 10.800200600002427,
        "health": 12.080020904541016,
        "seed": 29,
        "status": "success",
        "peerRewards": 1,
        "activeSeconds": 7.999999999999981,
        "dead": false
      },
      {
        "distanceStuds": 183.99404001235962,
        "hordeTarget": 40,
        "progress": 0,
        "strategy": "wide-kite",
        "damageTaken": 87.88582801818848,
        "peerHealth": 100,
        "rewards": 0,
        "wallSeconds": 16.098573100000067,
        "health": 12.114171981811523,
        "seed": 29,
        "status": "active",
        "peerRewards": 0,
        "activeSeconds": 12.033333333333301,
        "dead": false
      }
    ],
    "errors": []
  }
}
]====]
