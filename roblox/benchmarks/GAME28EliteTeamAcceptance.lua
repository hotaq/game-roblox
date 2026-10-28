-- Raw integrated two-client acceptance,49fdf52,2026-10-28.
return [====[{
  "callOK": true,
  "result": {
    "ok": true,
    "fight": {
      "phase": "defeated",
      "seconds": 26.068649100001494,
      "health": 100,
      "awarded": 2
    },
    "clients": 2,
    "checks": [
      "single elite scales HP only to spawn roster",
      "separate target does not inflate horde slots",
      "side step after lock dodges real HeavyAttack",
      "heavy exposes recovery opening",
      "standing in telegraph takes one authoritative hit",
      "stunning weapon interrupts windup",
      "stun recovers at bounded duration",
      "repeat hits cannot stun lock elite",
      "interrupted swing cannot land later",
      "non-stunning ring preserves heavy attack",
      "chooser neither attacks nor receives elite damage",
      "teammate can fight while chooser is protected",
      "sword real weapon damages elite",
      "fire real weapon damages elite",
      "ring real weapon damages elite",
      "axe real weapon damages elite",
      "rocks real weapon damages elite",
      "totem real weapon damages elite",
      "negative target never enters u16 hit packets",
      "completion gives each eligible original member one ordinary card",
      "reward queues behind chooser's current card",
      "duplicate completion cannot replay reward",
      "reward creates card offer for Player2",
      "reward creates card offer for Player1",
      "death model and weapon proxy retired",
      "old run projectile cannot damage elite",
      "replacement run receives no old encounter reward",
      "ignored elite expires without reward or ending run",
      "expiry preserves main run",
      "arena change cancels elite",
      "late entrant receives no retroactive reward",
      "death at reward boundary excludes dead original member",
      "natural elite AI defeated through ordinary auto weapons",
      "fixed population performance phase 1",
      "fixed population performance phase 2",
      "fixed population performance phase 3",
      "fixed population performance phase 4",
      "client no Goblin errors Player2",
      "client no Goblin errors Player1",
      "disconnect clears encounter and proxy",
      "server no Goblin errors"
    ],
    "performance": [
      {
        "elite": false,
        "eliteInstances": 0,
        "alive": 200,
        "heartbeatMs": {
          "p50": 0.29657185077667236,
          "p95": 0.49311113357543945,
          "n": 190
        },
        "stepMs": {
          "p50": 0.6075000019336585,
          "p95": 1.1579999991226941,
          "n": 190
        },
        "round": 1,
        "spawnWallMs": 0,
        "physicsMs": {
          "p50": 0.01431204006075859,
          "p95": 0.0746644139289856,
          "n": 190
        }
      },
      {
        "elite": true,
        "eliteInstances": 217,
        "alive": 200,
        "heartbeatMs": {
          "p50": 0.3577185869216919,
          "p95": 0.5333006381988525,
          "n": 191
        },
        "stepMs": {
          "p50": 0.635200001852354,
          "p95": 1.1215999984415248,
          "n": 191
        },
        "round": 2,
        "spawnWallMs": 5.6955999971251,
        "physicsMs": {
          "p50": 0.03129603713750839,
          "p95": 0.12073704600334167,
          "n": 191
        }
      },
      {
        "elite": false,
        "eliteInstances": 0,
        "alive": 200,
        "heartbeatMs": {
          "p50": 0.3159571886062622,
          "p95": 0.42777219414711,
          "n": 188
        },
        "stepMs": {
          "p50": 0.6913999968674034,
          "p95": 1.2580000002344605,
          "n": 188
        },
        "round": 3,
        "spawnWallMs": 0,
        "physicsMs": {
          "p50": 0.017974747344851494,
          "p95": 0.09737427532672882,
          "n": 188
        }
      },
      {
        "elite": true,
        "eliteInstances": 217,
        "alive": 200,
        "heartbeatMs": {
          "p50": 0.3301630914211273,
          "p95": 0.4923194646835327,
          "n": 186
        },
        "stepMs": {
          "p50": 0.6618000006710645,
          "p95": 1.1984000011580065,
          "n": 186
        },
        "round": 4,
        "spawnWallMs": 4.956500000844244,
        "physicsMs": {
          "p50": 0.1340453177690506,
          "p95": 0.23721763491630554,
          "n": 186
        }
      }
    ],
    "errors": []
  }
}]====]

