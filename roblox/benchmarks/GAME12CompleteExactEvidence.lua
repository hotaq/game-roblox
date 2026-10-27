-- Exact production spans:50 checks including ordinary new-item reachability and slot caps.
return [====[
{
  "visual": {
    "1": "totem Lv1 bounded cosmetic geometry",
    "2": "totem Lv1 ground pivot",
    "3": "totem Lv1 distinct evolved seal",
    "4": "totem Lv3 bounded cosmetic geometry",
    "5": "totem Lv3 ground pivot",
    "6": "totem Lv3 distinct evolved seal",
    "7": "totem Lv5 bounded cosmetic geometry",
    "8": "totem Lv5 ground pivot",
    "9": "totem Lv5 distinct evolved seal",
    "10": "totem Lv6 bounded cosmetic geometry",
    "11": "totem Lv6 ground pivot",
    "12": "totem Lv6 distinct evolved seal",
    "13": "steady totem snapshots reuse model",
    "14": "replacement snapshot retires old generation",
    "15": "empty snapshot clears all models",
    "16": "100 requested bolts bound to16 bolts and48 segments",
    "17": "same-frame extra strikes cannot exceed visual cap",
    "18": "transient lightning releases parts and counter"
  },
  "rarity": {
    "before": {
      "1": 700,
      "2": 250,
      "3": 50
    },
    "after": {
      "1": 519,
      "2": 370,
      "3": 111
    }
  },
  "checks": {
    "1": "Luck raises Rare and Epic probability and lowers Common",
    "2": "Luck probability clamps at both bounds",
    "3": "all new items are reachable through ordinary card pool",
    "4": "maxed new passives do not overflow five passive slots or level5",
    "5": "sword needs its exact passive",
    "6": "sword evolution reserved in normal card pool",
    "7": "sword evolved weapon has no repeat card",
    "8": "sword shared level6 stats strengthen base weapon",
    "9": "fire needs its exact passive",
    "10": "fire evolution reserved in normal card pool",
    "11": "fire evolved weapon has no repeat card",
    "12": "fire shared level6 stats strengthen base weapon",
    "13": "ring needs its exact passive",
    "14": "ring evolution reserved in normal card pool",
    "15": "ring evolved weapon has no repeat card",
    "16": "ring shared level6 stats strengthen base weapon",
    "17": "axe needs its exact passive",
    "18": "axe evolution reserved in normal card pool",
    "19": "axe evolved weapon has no repeat card",
    "20": "axe shared level6 stats strengthen base weapon",
    "21": "rocks needs its exact passive",
    "22": "rocks evolution reserved in normal card pool",
    "23": "rocks evolved weapon has no repeat card",
    "24": "rocks shared level6 stats strengthen base weapon",
    "25": "totem needs its exact passive",
    "26": "totem evolution reserved in normal card pool",
    "27": "totem evolved weapon has no repeat card",
    "28": "totem shared level6 stats strengthen base weapon",
    "29": "full slots still permit evolution and exclude new acquisitions",
    "30": "fully maxed and evolved loadout falls back to heal",
    "31": "engine float value restores original speed",
    "32": "speed cleanup preserves another system's later change"
  },
  "count": 50,
  "ok": true
}
]====]
