-- Retained unsuccessful fixture runs. Later acceptance must pass independently.
-- Two offer-delivery races, then a disconnected InvokeClient reply; never counted as passes.
return [====[
{
  "GAME11_4a10cddd-9cf4-41ba-bbdc-e9c7cd8e2e4e": {
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
      "errors": [],
      "levels": [],
      "mode": "acceptance",
      "error": "Player Player2 disconnected during remote call to ReplicatedStorage.Goblin.GAME11Test\nServerScriptService.GoblinHorde:2549\nServerScriptService.GoblinHorde:2463\n",
      "reroll": {
        "attribute": 1,
        "sent": 1
      }
    }
  },
  "GAME11_87daa4c1-1a8b-403e-9001-eeadf0721191": {
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
        "both choosing excludes both from gameplay targets"
      ],
      "samples": [],
      "clientBeforeReroll": {
        "attributeOfferId": 1,
        "paused": true,
        "errors": [],
        "safeText": false,
        "offerId": []
      },
      "errors": [],
      "levels": [],
      "mode": "acceptance",
      "error": "ServerScriptService.GoblinHorde:2443: GAME11 timeout first resumes\nServerScriptService.GoblinHorde:2443 function waitFor\nServerScriptService.GoblinHorde:2533\nServerScriptService.GoblinHorde:2457\n",
      "reroll": {
        "attribute": 1,
        "sent": 1
      }
    }
  },
  "GAME11_06a62687-5db1-42d4-a343-332e0c5e0f03": {
    "callOK": true,
    "result": {
      "ok": false,
      "levels": [],
      "checks": [
        "four active weapons before pause",
        "chooser anchored with owned shield and pause attribute",
        "engine shield protects damage while choosing",
        "only chooser projectiles and lifetime stop",
        "teammate weapons keep dealing damage",
        "chooser excluded from melee bone and spawn target list",
        "paused damage cannot award a kill",
        "chooser does not collect gems"
      ],
      "errors": [],
      "mode": "acceptance",
      "error": "ServerScriptService.GoblinHorde:2443: GAME11 timeout reroll\nServerScriptService.GoblinHorde:2443 function waitFor\nServerScriptService.GoblinHorde:2506\nServerScriptService.GoblinHorde:2457\n",
      "samples": []
    }
  }
}
]====]
