-- Failed pilot: immediate assertion preceded the deferred PlayerRemoving event.
-- Retained for audit; final acceptance must verify eventual cleanup independently.
return [====[
{
  "callOK": true,
  "result": {
    "ok": false,
    "checks": [
      "four active weapons before pause",
      "chooser anchored with owned shield and pause attribute",
      "engine shield protects damage while choosing",
      "only chooser projectiles and lifetime stop",
      "teammate weapons keep dealing damage",
      "chooser excluded from melee bone and spawn target list",
      "paused damage cannot award a kill",
      "chooser does not collect gems",
      "reroll keeps same pause and deadline",
      "stale click cannot close replacement offer",
      "manual pick restores only chooser movement and protection",
      "pause time excluded only from chooser clock",
      "own projectiles resume after choice",
      "UI explains safety and automatic first card",
      "timeout consumes exactly one pending offer",
      "queued level keeps protection with fresh deadline",
      "late timeout reply does not consume next card",
      "client pause attribute clears",
      "both choosing excludes both from gameplay targets",
      "one resumes without waiting for teammate",
      "death removes own shield and attributes",
      "end run restores original anchored state",
      "end run clears card deadline and HUD state",
      "client has no Goblin errors",
      "client has no Goblin errors"
    ],
    "samples": [],
    "clientBeforeReroll": {
      "attributeOfferId": 1,
      "paused": true,
      "errors": [],
      "safeText": true,
      "offerId": 1
    },
    "disconnectCall": {
      "ok": false,
      "result": "Player Player2 disconnected during remote call to ReplicatedStorage.Goblin.GAME11Test"
    },
    "levels": [],
    "errors": [],
    "mode": "acceptance",
    "error": "ServerScriptService.GoblinHorde:2439: disconnect during choice releases run and shield\nServerScriptService.GoblinHorde:2439\nServerScriptService.GoblinHorde:2463\n",
    "reroll": {
      "attribute": 1,
      "sent": 1
    }
  }
}
]====]
