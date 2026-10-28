-- Selected candidate 2. Real client, seeded scripted 120-second route.
-- Final production-config repeat recorded separately; this run uses test overrides.
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
        "alive": 25,
        "seconds": 10.01725500000066,
        "level": 1,
        "gems": 0,
        "damage": 30
      },
      {
        "kills": 9,
        "alive": 31,
        "seconds": 20.000051099999837,
        "level": 1,
        "gems": 8,
        "damage": 90
      },
      {
        "kills": 21,
        "alive": 36,
        "seconds": 30.001209899999594,
        "level": 2,
        "gems": 16,
        "damage": 150
      },
      {
        "kills": 33,
        "alive": 42,
        "seconds": 40.05009119999886,
        "level": 2,
        "gems": 32,
        "damage": 220
      },
      {
        "kills": 56,
        "alive": 48,
        "seconds": 50.01551719999952,
        "level": 3,
        "gems": 45,
        "damage": 275
      },
      {
        "kills": 69,
        "alive": 53,
        "seconds": 60.04888829999982,
        "level": 3,
        "gems": 65,
        "damage": 360
      },
      {
        "kills": 98,
        "alive": 59,
        "seconds": 70.03177010000036,
        "level": 4,
        "gems": 83,
        "damage": 425
      },
      {
        "kills": 140,
        "alive": 64,
        "seconds": 80.01490439999907,
        "level": 5,
        "gems": 119,
        "damage": 488
      },
      {
        "kills": 186,
        "alive": 70,
        "seconds": 90.01318309999988,
        "level": 5,
        "gems": 161,
        "damage": 558
      },
      {
        "kills": 226,
        "alive": 75,
        "seconds": 100.04731019999963,
        "level": 6,
        "gems": 203,
        "damage": 618
      },
      {
        "kills": 291,
        "alive": 81,
        "seconds": 110.01396989999921,
        "level": 6,
        "gems": 251,
        "damage": 691
      }
    ],
    "final": {
      "kills": 348,
      "alive": 86,
      "level": 7,
      "gems": 310,
      "damage": 751
    },
    "levels": [
      {
        "wall": 27.416802699999607,
        "kills": 21,
        "level": 2,
        "active": 27.417037963867188
      },
      {
        "wall": 44.64808570000059,
        "kills": 53,
        "level": 3,
        "active": 43.782132148742676
      },
      {
        "wall": 65.28157699999974,
        "kills": 80,
        "level": 4,
        "active": 63.498759269714355
      },
      {
        "wall": 79.23101189999943,
        "kills": 140,
        "level": 5,
        "active": 76.5656270980835
      },
      {
        "wall": 94.77943880000021,
        "kills": 216,
        "level": 6,
        "active": 91.21396589279175
      },
      {
        "wall": 114.0958486999989,
        "kills": 315,
        "level": 7,
        "active": 109.6630048751831
      }
    ],
    "mode": "balance",
    "tuning": {
      "contact": 5,
      "alive": 20,
      "hpGrowth": 0.3,
      "xp": 16,
      "perMinute": 35,
      "growth": 1.4,
      "bone": 8
    },
    "errors": []
  }
}
]====]
