-- Corrected cumulative HealthChanged damage; hidden real-client 120-second baseline.
-- Report GAME11_05c6b0ba-e1aa-4c17-9464-c68dd82bf33b. Scripted route, not human difficulty.
return [====[
{
  "callOK": true,
  "result": {
    "ok": true,
    "note": "Scripted circle, anchored route, 10000HP measurement dummy; damage recorded; not human survival/fun evidence",
    "checks": [
      "balance no server errors",
      "balance no client errors"
    ],
    "samples": [
      {
        "kills": 0,
        "alive": 32,
        "seconds": 10.045386600000711,
        "level": 1,
        "gems": 0,
        "damage": 48
      },
      {
        "kills": 17,
        "alive": 38,
        "seconds": 20.04283369999939,
        "level": 3,
        "gems": 12,
        "damage": 102
      },
      {
        "kills": 37,
        "alive": 45,
        "seconds": 30.04307300000073,
        "level": 4,
        "gems": 25,
        "damage": 168
      },
      {
        "kills": 60,
        "alive": 52,
        "seconds": 40.04315189999943,
        "level": 5,
        "gems": 44,
        "damage": 234
      },
      {
        "kills": 84,
        "alive": 59,
        "seconds": 50.00867939999989,
        "level": 6,
        "gems": 68,
        "damage": 318
      },
      {
        "kills": 127,
        "alive": 65,
        "seconds": 60.025211399999534,
        "level": 8,
        "gems": 111,
        "damage": 378
      },
      {
        "kills": 164,
        "alive": 72,
        "seconds": 70.02499440000065,
        "level": 9,
        "gems": 137,
        "damage": 462
      },
      {
        "kills": 219,
        "alive": 79,
        "seconds": 80.04093880000073,
        "level": 10,
        "gems": 184,
        "damage": 546
      },
      {
        "kills": 285,
        "alive": 85,
        "seconds": 90.02491220000047,
        "level": 11,
        "gems": 236,
        "damage": 612
      },
      {
        "kills": 342,
        "alive": 93,
        "seconds": 100.02503550000074,
        "level": 12,
        "gems": 304,
        "damage": 690
      },
      {
        "kills": 421,
        "alive": 100,
        "seconds": 110.03923050000049,
        "level": 12,
        "gems": 369,
        "damage": 774
      }
    ],
    "final": {
      "kills": 504,
      "alive": 107,
      "level": 13,
      "gems": 451,
      "damage": 840
    },
    "levels": [
      {
        "wall": 14.911213400000634,
        "kills": 6,
        "level": 2,
        "active": 14.91153597831726
      },
      {
        "wall": 18.94391159999941,
        "kills": 17,
        "level": 3,
        "active": 18.061697959899902
      },
      {
        "wall": 26.777631299999484,
        "kills": 33,
        "level": 4,
        "active": 24.996698141098022
      },
      {
        "wall": 34.675849900000685,
        "kills": 46,
        "level": 5,
        "active": 31.997008085250854
      },
      {
        "wall": 42.626844399999754,
        "kills": 66,
        "level": 6,
        "active": 39.047039270401
      },
      {
        "wall": 51.676859299999705,
        "kills": 96,
        "level": 7,
        "active": 47.21532416343689
      },
      {
        "wall": 57.50875719999931,
        "kills": 123,
        "level": 8,
        "active": 52.14929223060608
      },
      {
        "wall": 68.39216959999976,
        "kills": 158,
        "level": 9,
        "active": 62.1662323474884
      },
      {
        "wall": 78.72382619999917,
        "kills": 216,
        "level": 10,
        "active": 71.61595845222473
      },
      {
        "wall": 89.25734039999952,
        "kills": 285,
        "level": 11,
        "active": 81.2825014591217
      },
      {
        "wall": 99.9078382000007,
        "kills": 342,
        "level": 12,
        "active": 91.04995846748352
      },
      {
        "wall": 111.70670190000055,
        "kills": 439,
        "level": 13,
        "active": 101.94953560829163
      }
    ],
    "mode": "balance",
    "tuning": {
      "contact": 6,
      "alive": 25,
      "hpGrowth": 0.4,
      "xp": 5,
      "perMinute": 45,
      "growth": 1.22,
      "bone": 8
    },
    "errors": []
  }
}
]====]
