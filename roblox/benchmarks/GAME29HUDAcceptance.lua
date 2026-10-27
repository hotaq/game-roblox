-- Exact objective span from65aa634, real background two-client PlayerGui replication.
-- Main place still earlier source; no Script.Source writes. Ordinary reward is mocked here.
-- Initial diagnostic had a previously dead run; reloaded both characters after stopping
-- only the disposable helper's ordinary horde Script, then repeated every check below.
-- Screenshot: renders/game29_objective_hud.jpg. Final DisplayOrder=-1 keeps card overlays above HUD.
return [====[
{
  "callOK": true,
  "result": {
    "ok": true,
    "mode": "exact65aa634 objective span, real two PlayerGui replicas, mocked reward delivery",
    "checks": [
      "HUD appears for both eligible participants",
      "both clients replicate progress3 and remaining32",
      "first run removal clears only first HUD during pause",
      "survivor success removes all HUDs",
      "survivor pending reward is one",
      "reset clears fresh HUDs"
    ],
    "sourceWrites": false
  }
}
]====]
