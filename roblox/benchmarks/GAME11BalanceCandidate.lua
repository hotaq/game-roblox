-- Candidate 1: still reaches level 4 before one minute; not selected.
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
        "kills": 1,
        "alive": 25,
        "seconds": 10.013882400000512,
        "level": 1,
        "gems": 1,
        "damage": 48
      },
      {
        "kills": 22,
        "alive": 31,
        "seconds": 20.01476790000015,
        "level": 2,
        "gems": 12,
        "damage": 120
      },
      {
        "kills": 24,
        "alive": 37,
        "seconds": 30.04686749999928,
        "level": 2,
        "gems": 24,
        "damage": 186
      },
      {
        "kills": 35,
        "alive": 42,
        "seconds": 40.04562369999985,
        "level": 3,
        "gems": 29,
        "damage": 264
      },
      {
        "kills": 66,
        "alive": 47,
        "seconds": 50.047116100000494,
        "level": 4,
        "gems": 57,
        "damage": 330
      },
      {
        "kills": 90,
        "alive": 53,
        "seconds": 60.01264439999977,
        "level": 5,
        "gems": 83,
        "damage": 408
      },
      {
        "kills": 107,
        "alive": 58,
        "seconds": 70.04496540000036,
        "level": 5,
        "gems": 100,
        "damage": 492
      },
      {
        "kills": 130,
        "alive": 64,
        "seconds": 80.01249649999954,
        "level": 6,
        "gems": 124,
        "damage": 564
      },
      {
        "kills": 186,
        "alive": 69,
        "seconds": 90.02886639999997,
        "level": 7,
        "gems": 178,
        "damage": 624
      },
      {
        "kills": 227,
        "alive": 75,
        "seconds": 100.04436200000055,
        "level": 7,
        "gems": 219,
        "damage": 714
      },
      {
        "kills": 270,
        "alive": 80,
        "seconds": 110.04451180000069,
        "level": 8,
        "gems": 253,
        "damage": 794
      }
    ],
    "final": {
      "kills": 327,
      "alive": 86,
      "level": 8,
      "gems": 307,
      "damage": 880
    },
    "levels": [
      {
        "wall": 19.74749469999915,
        "kills": 22,
        "level": 2,
        "active": 19.74792504310608
      },
      {
        "wall": 36.945906599999944,
        "kills": 32,
        "level": 3,
        "active": 36.06385517120361
      },
      {
        "wall": 47.37917480000033,
        "kills": 59,
        "level": 4,
        "active": 45.57921504974365
      },
      {
        "wall": 59.61319189999995,
        "kills": 90,
        "level": 5,
        "active": 56.89604997634888
      },
      {
        "wall": 79.77871720000076,
        "kills": 130,
        "level": 6,
        "active": 76.14603996276855
      },
      {
        "wall": 89.47723699999915,
        "kills": 186,
        "level": 7,
        "active": 84.92938804626465
      },
      {
        "wall": 108.1288941999992,
        "kills": 260,
        "level": 8,
        "active": 102.66386008262634
      }
    ],
    "mode": "balance",
    "tuning": {
      "contact": 6,
      "alive": 20,
      "hpGrowth": 0.3,
      "xp": 12,
      "perMinute": 35,
      "growth": 1.3,
      "bone": 8
    },
    "errors": []
  }
}
]====]
