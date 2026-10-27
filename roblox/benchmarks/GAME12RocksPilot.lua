-- Diagnostic pilot:22 gameplay checks passed; fixture omitted pausedAt for forced cards.
-- Fixed in bf63ad9. This failed pilot is not final acceptance.
return [====[
{
  "callOK": true,
  "result": {
    "ok": false,
    "map1Instances": 5288,
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
      "death clears final server/client orbit"
    ],
    "review": {
      "a": {
        "nonCosmetic": 0,
        "rocks": 6,
        "icons": 2,
        "errors": []
      },
      "b": {
        "nonCosmetic": 0,
        "rocks": 6,
        "icons": 1,
        "errors": []
      }
    },
    "mode": "real card/replication/ownership/lifecycle",
    "error": "ServerScriptService.GoblinHorde:1714: zero captured Goblin errors\nServerScriptService.GoblinHorde:1714\nServerScriptService.GoblinHorde:1723\n",
    "errors": [
      "ServerScriptService.GoblinHorde:298: attempt to perform arithmetic (sub) on number and nil",
      "ServerScriptService.GoblinHorde:298: attempt to perform arithmetic (sub) on number and nil"
    ]
  }
}
]====]
