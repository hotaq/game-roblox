-- Exact production spans on f1754b1:48 checks; complements live tests.
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
    "3": "sword needs its exact passive",
    "4": "sword evolution reserved in normal card pool",
    "5": "sword evolved weapon has no repeat card",
    "6": "sword shared level6 stats strengthen base weapon",
    "7": "fire needs its exact passive",
    "8": "fire evolution reserved in normal card pool",
    "9": "fire evolved weapon has no repeat card",
    "10": "fire shared level6 stats strengthen base weapon",
    "11": "ring needs its exact passive",
    "12": "ring evolution reserved in normal card pool",
    "13": "ring evolved weapon has no repeat card",
    "14": "ring shared level6 stats strengthen base weapon",
    "15": "axe needs its exact passive",
    "16": "axe evolution reserved in normal card pool",
    "17": "axe evolved weapon has no repeat card",
    "18": "axe shared level6 stats strengthen base weapon",
    "19": "rocks needs its exact passive",
    "20": "rocks evolution reserved in normal card pool",
    "21": "rocks evolved weapon has no repeat card",
    "22": "rocks shared level6 stats strengthen base weapon",
    "23": "totem needs its exact passive",
    "24": "totem evolution reserved in normal card pool",
    "25": "totem evolved weapon has no repeat card",
    "26": "totem shared level6 stats strengthen base weapon",
    "27": "full slots still permit evolution and exclude new acquisitions",
    "28": "fully maxed and evolved loadout falls back to heal",
    "29": "engine float value restores original speed",
    "30": "speed cleanup preserves another system's later change"
  },
  "count": 48,
  "ok": true
}
]====]
