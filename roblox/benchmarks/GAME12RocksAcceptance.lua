-- Real two-client acceptance on bf63ad9 runtime, owner changes preserved through2848283.
-- Source equality checked on all five runtime files. Actual client capture during60s review.
return [====[
{
  "callOK": true,
  "result": {
    "ok": true,
    "clients": 2,
    "checks": [
      "real rocks card icon visible for Player1",
      "real card selection acquires rocks for Player1",
      "real rocks card icon visible for Player2",
      "real card selection acquires rocks for Player2",
      "both real clients see both owners' two stones",
      "server gives contact damage only to the correct owner",
      "rocks do not permanently stun enemies",
      "same-frame overlaps do not duplicate damage",
      "reused slot receives a fresh contact",
      "level 1 stone count replicated to both clients",
      "level 3 stone count replicated to both clients",
      "level 5 stone count replicated to both clients",
      "all stones are anchored and non-colliding/non-queryable",
      "rocks art appears in both HUDs",
      "global card pause freezes both authoritative orbits",
      "teleport cleanup runs during card pause and preserves peer",
      "lethal rock contact awards exactly one kill",
      "real pickup awards exactly one gem after rock kill",
      "ending one run removes only its stones",
      "new character/run creates one fresh orbit",
      "real departure releases peer orbit and preserves survivor",
      "death clears final server/client orbit",
      "zero captured Goblin errors"
    ],
    "review": {
      "a": {
        "nonCosmetic": 0,
        "rocks": 6,
        "icons": 1,
        "errors": []
      },
      "b": {
        "nonCosmetic": 0,
        "rocks": 6,
        "icons": 2,
        "errors": []
      }
    },
    "mode": "real card/replication/ownership/lifecycle",
    "map1Instances": 5288,
    "errors": []
  }
}
]====]
