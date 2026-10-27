-- Verified real two-client acceptance. Compact report omits per-phase slot maps only.
-- Full evidence in Studio ServerStorage.GAME24_102b97c5-eb60-49f9-9a29-fcb0da0e2b92.RawReport.
return [====[
{
  "callOK": true,
  "result": {
    "initial": {
      "top": 2,
      "count": 2,
      "b": {
        "models": 1000,
        "events": {
          "swings": 36765,
          "deaths": 0,
          "pickups": 0,
          "hits": 0
        },
        "errors": [],
        "gems": [],
        "slots": {
          "2": {
            "incarnation": 17,
            "x": 1120,
            "z": 0
          }
        },
        "count": 1
      },
      "bPosition": "1120, 4, 0",
      "aPosition": "880, 4, 0",
      "a": {
        "models": 1000,
        "events": {
          "swings": 36796,
          "deaths": 0,
          "pickups": 0,
          "hits": 0
        },
        "errors": [],
        "gems": [],
        "slots": {
          "1": {
            "incarnation": 17,
            "x": 880,
            "z": 0
          }
        },
        "count": 1
      },
      "center": "1000, 0, 0"
    },
    "baseline": "original dense broadcast sender; same simulation and frozen test scene",
    "checks": [
      "phase visible count broadcast/clustered/100/1",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count broadcast/clustered/100/2",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count nearby/clustered/100/1",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count nearby/clustered/100/2",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count broadcast/separated/100/1",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count broadcast/separated/100/2",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count nearby/separated/100/1",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count nearby/separated/100/2",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count broadcast/clustered/1000/1",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count broadcast/clustered/1000/2",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count nearby/clustered/1000/1",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count nearby/clustered/1000/2",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count broadcast/separated/1000/1",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count broadcast/separated/1000/2",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count nearby/separated/1000/1",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count nearby/separated/1000/2",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count nearby/clustered/100/1",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count nearby/clustered/100/2",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count broadcast/clustered/100/1",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count broadcast/clustered/100/2",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count nearby/separated/100/1",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count nearby/separated/100/2",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count broadcast/separated/100/1",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count broadcast/separated/100/2",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count nearby/clustered/1000/1",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count nearby/clustered/1000/2",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count broadcast/clustered/1000/1",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count broadcast/clustered/1000/2",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count nearby/separated/1000/1",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count nearby/separated/1000/2",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count broadcast/separated/1000/1",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "phase visible count broadcast/separated/1000/2",
      "phase client error free",
      "client/server payload agrees within ten percent",
      "two separated clients receive their own nearby enemy",
      "outside enter radius hidden",
      "entry appears",
      "hysteresis retained",
      "exit removed",
      "twenty visibility cycles leave no stale model or growing pool",
      "silent slot reuse has fresh identity and position",
      "stale death/hit/swing cannot affect reused slot",
      "current-incarnation hit and swing each render once",
      "each client animates only the incarnation it actually saw",
      "both kills retain distinct authoritative gems and credit",
      "hidden death has no stale observer corpse/gem",
      "teleport/entry recovers an existing gem without replaying death",
      "arriving player collects hidden-death gem exactly once",
      "same-interval kill/pickup renders once and leaves no gem",
      "receiver resync restores existing enemy and gem",
      "disconnect releases per-player view and run state",
      "fresh connection 1 gets existing enemy and gem",
      "fresh connection error free",
      "late join state released before next connection",
      "fresh connection 2 gets existing enemy and gem",
      "fresh connection error free",
      "no departed player view reference",
      "no departed player view reference",
      "final snapshot clears enemies and gems on both clients",
      "no Goblin script errors"
    ],
    "phases": [
      {
        "population": 100,
        "seconds": 15.016570800002228,
        "clients": [
          {
            "bytes": 56516,
            "seconds": 15.083300999998755,
            "errors": [],
            "packets": 137,
            "serverBytes": 56512,
            "visual": {
              "models": 100,
              "events": {
                "swings": 932,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 100
            }
          },
          {
            "bytes": 56520,
            "seconds": 15.084075799997663,
            "errors": [],
            "packets": 137,
            "serverBytes": 56512,
            "visual": {
              "models": 100,
              "events": {
                "swings": 934,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 100
            }
          }
        ],
        "repeatIndex": 1,
        "stepMs": {
          "max": 1.537699998152675,
          "p50": 0.38380000114557333,
          "p95": 0.8745000013732351,
          "n": 450
        },
        "layout": "clustered",
        "mode": "broadcast",
        "sendMs": {
          "max": 0.4165999998804182,
          "p50": 0.04499999704421498,
          "p95": 0.0943000013648998,
          "n": 137
        }
      },
      {
        "population": 100,
        "seconds": 15.016354500003217,
        "clients": [
          {
            "bytes": 60330,
            "seconds": 15.099790799999028,
            "errors": [],
            "packets": 139,
            "serverBytes": 59916,
            "visual": {
              "models": 100,
              "events": {
                "swings": 1890,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 100
            }
          },
          {
            "bytes": 59916,
            "seconds": 15.066842400003225,
            "errors": [],
            "packets": 138,
            "serverBytes": 59916,
            "visual": {
              "models": 100,
              "events": {
                "swings": 1890,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 100
            }
          }
        ],
        "repeatIndex": 1,
        "stepMs": {
          "max": 0.6987999986449722,
          "p50": 0.30810000316705555,
          "p95": 0.5654999986290932,
          "n": 451
        },
        "layout": "clustered",
        "mode": "nearby",
        "sendMs": {
          "max": 0.3556000010576099,
          "p50": 0.07580000237794593,
          "p95": 0.14340000052470714,
          "n": 138
        }
      },
      {
        "population": 100,
        "seconds": 15.000103200000012,
        "clients": [
          {
            "bytes": 56878,
            "seconds": 15.083027699998638,
            "errors": [],
            "packets": 138,
            "serverBytes": 56462,
            "visual": {
              "models": 100,
              "events": {
                "swings": 2777,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 100
            }
          },
          {
            "bytes": 56866,
            "seconds": 15.066840499999671,
            "errors": [],
            "packets": 138,
            "serverBytes": 56462,
            "visual": {
              "models": 100,
              "events": {
                "swings": 2777,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 100
            }
          }
        ],
        "repeatIndex": 1,
        "stepMs": {
          "max": 0.5715000006603077,
          "p50": 0.2789999998640269,
          "p95": 0.43139999979757704,
          "n": 450
        },
        "layout": "separated",
        "mode": "broadcast",
        "sendMs": {
          "max": 0.19160000010742806,
          "p50": 0.03470000228844583,
          "p95": 0.06850000136182643,
          "n": 137
        }
      },
      {
        "population": 100,
        "seconds": 15.000138899999001,
        "clients": [
          {
            "bytes": 31680,
            "seconds": 15.048288599999069,
            "errors": [],
            "packets": 138,
            "serverBytes": 31662,
            "visual": {
              "models": 100,
              "events": {
                "swings": 3213,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 50
            }
          },
          {
            "bytes": 31782,
            "seconds": 15.050704000001133,
            "errors": [],
            "packets": 138,
            "serverBytes": 31752,
            "visual": {
              "models": 100,
              "events": {
                "swings": 3230,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 50
            }
          }
        ],
        "repeatIndex": 1,
        "stepMs": {
          "max": 1.1506999981065746,
          "p50": 0.28469999961089343,
          "p95": 0.5335999994713347,
          "n": 450
        },
        "layout": "separated",
        "mode": "nearby",
        "sendMs": {
          "max": 0.3901999989466276,
          "p50": 0.08789999992586672,
          "p95": 0.1756999990902841,
          "n": 138
        }
      },
      {
        "population": 1000,
        "seconds": 15.000335500000801,
        "clients": [
          {
            "bytes": 555042,
            "seconds": 15.064893900002062,
            "errors": [],
            "packets": 137,
            "serverBytes": 555010,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 7694,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 1000
            }
          },
          {
            "bytes": 559038,
            "seconds": 15.100994899999932,
            "errors": [],
            "packets": 138,
            "serverBytes": 555010,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 7715,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 1000
            }
          }
        ],
        "repeatIndex": 1,
        "stepMs": {
          "max": 9.41650000095251,
          "p50": 5.696299998817267,
          "p95": 7.944799999677343,
          "n": 450
        },
        "layout": "clustered",
        "mode": "broadcast",
        "sendMs": {
          "max": 0.2553000012994744,
          "p50": 0.09520000094198622,
          "p95": 0.16250000044237822,
          "n": 137
        }
      },
      {
        "population": 1000,
        "seconds": 15.015514699996857,
        "clients": [
          {
            "bytes": 568230,
            "seconds": 15.100077499999315,
            "errors": [],
            "packets": 137,
            "serverBytes": 568140,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 12132,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 1000
            }
          },
          {
            "bytes": 572274,
            "seconds": 15.115306300001976,
            "errors": [],
            "packets": 138,
            "serverBytes": 568140,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 12162,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 1000
            }
          }
        ],
        "repeatIndex": 1,
        "stepMs": {
          "max": 10.082999997393927,
          "p50": 5.527100001927465,
          "p95": 8.28919999912614,
          "n": 451
        },
        "layout": "clustered",
        "mode": "nearby",
        "sendMs": {
          "max": 0.7289999994100071,
          "p50": 0.3505000022414606,
          "p95": 0.6291999998211395,
          "n": 137
        }
      },
      {
        "population": 1000,
        "seconds": 15.000148899998749,
        "clients": [
          {
            "bytes": 558552,
            "seconds": 15.067062100002659,
            "errors": [],
            "packets": 138,
            "serverBytes": 558516,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 16299,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 1000
            }
          },
          {
            "bytes": 562556,
            "seconds": 15.09964509999918,
            "errors": [],
            "packets": 139,
            "serverBytes": 558516,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 16322,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 1000
            }
          }
        ],
        "repeatIndex": 1,
        "stepMs": {
          "max": 8.512600001267856,
          "p50": 4.824299998290371,
          "p95": 6.896499999129446,
          "n": 450
        },
        "layout": "separated",
        "mode": "broadcast",
        "sendMs": {
          "max": 0.2889000024879351,
          "p50": 0.10099999781232327,
          "p95": 0.1731000011204742,
          "n": 138
        }
      },
      {
        "population": 1000,
        "seconds": 15.01698000000033,
        "clients": [
          {
            "bytes": 302748,
            "seconds": 15.099454600000172,
            "errors": [],
            "packets": 138,
            "serverBytes": 302694,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 18354,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 500
            }
          },
          {
            "bytes": 305133,
            "seconds": 15.099825499997678,
            "errors": [],
            "packets": 139,
            "serverBytes": 302970,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 18409,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 500
            }
          }
        ],
        "repeatIndex": 1,
        "stepMs": {
          "max": 10.35279999996419,
          "p50": 5.269200002658181,
          "p95": 8.214900000893977,
          "n": 450
        },
        "layout": "separated",
        "mode": "nearby",
        "sendMs": {
          "max": 1.0389000017312355,
          "p50": 0.40779999835649505,
          "p95": 0.7198000021162443,
          "n": 138
        }
      },
      {
        "population": 100,
        "seconds": 15.000364400002582,
        "clients": [
          {
            "bytes": 59436,
            "seconds": 15.050124199999118,
            "errors": [],
            "packets": 137,
            "serverBytes": 59448,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 19318,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 100
            }
          },
          {
            "bytes": 59460,
            "seconds": 15.067315000000235,
            "errors": [],
            "packets": 137,
            "serverBytes": 59448,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 19363,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 100
            }
          }
        ],
        "repeatIndex": 2,
        "stepMs": {
          "max": 1.326000001427019,
          "p50": 0.49190000208909623,
          "p95": 0.972999998339219,
          "n": 450
        },
        "layout": "clustered",
        "mode": "nearby",
        "sendMs": {
          "max": 0.6157000025268644,
          "p50": 0.12180000339867547,
          "p95": 0.26059999800054356,
          "n": 137
        }
      },
      {
        "population": 100,
        "seconds": 15.000554499998543,
        "clients": [
          {
            "bytes": 56962,
            "seconds": 15.099147000000812,
            "errors": [],
            "packets": 138,
            "serverBytes": 56956,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 20277,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 100
            }
          },
          {
            "bytes": 57372,
            "seconds": 15.099763900001562,
            "errors": [],
            "packets": 139,
            "serverBytes": 56956,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 20324,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 100
            }
          }
        ],
        "repeatIndex": 2,
        "stepMs": {
          "max": 1.4040999994904269,
          "p50": 0.36390000241226517,
          "p95": 0.8493999994243495,
          "n": 450
        },
        "layout": "clustered",
        "mode": "broadcast",
        "sendMs": {
          "max": 0.26709999656304717,
          "p50": 0.04400000034365803,
          "p95": 0.1143000008596573,
          "n": 138
        }
      },
      {
        "population": 100,
        "seconds": 15.015800199998921,
        "clients": [
          {
            "bytes": 31872,
            "seconds": 15.084044300001551,
            "errors": [],
            "packets": 138,
            "serverBytes": 31645,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 20745,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 50
            }
          },
          {
            "bytes": 31854,
            "seconds": 15.097710099998949,
            "errors": [],
            "packets": 138,
            "serverBytes": 31609,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 20782,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 50
            }
          }
        ],
        "repeatIndex": 2,
        "stepMs": {
          "max": 1.207799999974668,
          "p50": 0.3566999985196162,
          "p95": 0.8336999999301042,
          "n": 450
        },
        "layout": "separated",
        "mode": "nearby",
        "sendMs": {
          "max": 0.4626000009011477,
          "p50": 0.11499999891384505,
          "p95": 0.25459999960730784,
          "n": 137
        }
      },
      {
        "population": 100,
        "seconds": 15.01647800000137,
        "clients": [
          {
            "bytes": 56484,
            "seconds": 15.098998999998003,
            "errors": [],
            "packets": 137,
            "serverBytes": 56468,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 21640,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 100
            }
          },
          {
            "bytes": 56890,
            "seconds": 15.099818700000469,
            "errors": [],
            "packets": 138,
            "serverBytes": 56468,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 21682,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 100
            }
          }
        ],
        "repeatIndex": 2,
        "stepMs": {
          "max": 1.5577000012854114,
          "p50": 0.4183000019111205,
          "p95": 0.898300000699237,
          "n": 450
        },
        "layout": "separated",
        "mode": "broadcast",
        "sendMs": {
          "max": 0.40219999937107787,
          "p50": 0.050499998906161636,
          "p95": 0.09929999941959977,
          "n": 137
        }
      },
      {
        "population": 1000,
        "seconds": 15.000130699998408,
        "clients": [
          {
            "bytes": 572538,
            "seconds": 15.100316300002305,
            "errors": [],
            "packets": 138,
            "serverBytes": 568416,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 26116,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 1000
            }
          },
          {
            "bytes": 576594,
            "seconds": 15.115465800001402,
            "errors": [],
            "packets": 139,
            "serverBytes": 568416,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 26174,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 1000
            }
          }
        ],
        "repeatIndex": 2,
        "stepMs": {
          "max": 11.697400001139613,
          "p50": 5.559799999900861,
          "p95": 8.084400000370806,
          "n": 450
        },
        "layout": "clustered",
        "mode": "nearby",
        "sendMs": {
          "max": 1.1308000030112453,
          "p50": 0.3238000026613008,
          "p95": 0.6528000012622215,
          "n": 137
        }
      },
      {
        "population": 1000,
        "seconds": 15.01700069999788,
        "clients": [
          {
            "bytes": 558932,
            "seconds": 15.098732599999494,
            "errors": [],
            "packets": 138,
            "serverBytes": 558894,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 30569,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 1000
            }
          },
          {
            "bytes": 558944,
            "seconds": 15.098362700002326,
            "errors": [],
            "packets": 138,
            "serverBytes": 558894,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 30615,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 1000
            }
          }
        ],
        "repeatIndex": 2,
        "stepMs": {
          "max": 8.919899999455083,
          "p50": 5.4062999988673255,
          "p95": 7.6188999992155,
          "n": 450
        },
        "layout": "clustered",
        "mode": "broadcast",
        "sendMs": {
          "max": 0.17020000086631626,
          "p50": 0.08740000339457765,
          "p95": 0.1350999991700519,
          "n": 138
        }
      },
      {
        "population": 1000,
        "seconds": 15.015399699997943,
        "clients": [
          {
            "bytes": 305133,
            "seconds": 15.097845100000995,
            "errors": [],
            "packets": 139,
            "serverBytes": 302958,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 32677,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 500
            }
          },
          {
            "bytes": 304815,
            "seconds": 15.098315300001559,
            "errors": [],
            "packets": 139,
            "serverBytes": 302604,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 32649,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 500
            }
          }
        ],
        "repeatIndex": 2,
        "stepMs": {
          "max": 11.108700000477256,
          "p50": 4.920300001685973,
          "p95": 7.450299999618437,
          "n": 450
        },
        "layout": "separated",
        "mode": "nearby",
        "sendMs": {
          "max": 1.4327999997476581,
          "p50": 0.39459999970858917,
          "p95": 0.7434000035573263,
          "n": 138
        }
      },
      {
        "population": 1000,
        "seconds": 15.00031730000046,
        "clients": [
          {
            "bytes": 562488,
            "seconds": 15.084172300001228,
            "errors": [],
            "packets": 139,
            "serverBytes": 558470,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 36766,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 1000
            }
          },
          {
            "bytes": 558486,
            "seconds": 15.099268900001334,
            "errors": [],
            "packets": 138,
            "serverBytes": 558470,
            "visual": {
              "models": 1000,
              "events": {
                "swings": 36751,
                "deaths": 0,
                "pickups": 0,
                "hits": 0
              },
              "count": 1000
            }
          }
        ],
        "repeatIndex": 2,
        "stepMs": {
          "max": 10.6554000012693,
          "p50": 4.811499999050284,
          "p95": 6.630099996982608,
          "n": 451
        },
        "layout": "separated",
        "mode": "broadcast",
        "sendMs": {
          "max": 0.35430000207270496,
          "p50": 0.09700000009615906,
          "p95": 0.15270000221789815,
          "n": 138
        }
      }
    ],
    "quick": false,
    "enter": 192,
    "map1Instances": 5288,
    "renderContext": "background; not device FPS",
    "ok": true,
    "leave": 224,
    "errors": []
  }
}
]====]
