# Enemy pools for Sky Tower floors, read by eye from research/videos/tower_rooms (one frame per room).
# Safe to re-run: python tools/patch_tower_rooms.py
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATH = os.path.join(ROOT, "data", "tower_floors.json")
ENEMIES = {
    1: ["shivairy", "burn_bonk", "fimia", "shivellia"],
    2: ["nightspook", "smunk", "minohawk"],
    3: ["terahopper", "thorni", "urscout_g"],
    4: ["frost_bot", "sir_drip", "freez"],
    5: ["tramix", "tramacron"],
    7: ["greenspook", "minothrush", "smullock"],
    8: ["stormgull", "urscout_b"],
    9: ["burn_bot", "sir_flame", "lavan"],
    10: ["cetrop", "ceratops", "glinthide"],
    11: ["grumelle", "grumairy", "bud_bonk", "kayn"],
    12: ["seaspook", "minogull", "soosoo"],
    16: ["wamia", "flutsplash", "chilelle"],
    17: ["dawnspook", "minoeagle", "smishee", "damage_dog"],
    14: ["stonn", "jag_bot", "sir_spiky"],
    18: ["sap_bot", "goliem", "sir_clip", "growth"],
    19: ["sap_bot", "goliem", "sir_clip"],
    20: ["derakon", "torizo"],
    21: ["fimia", "balro", "burn_bonk", "shivairy"],
    22: ["minohawk", "smunk", "unacorn"],
    23: ["thorni", "terahopper", "humbark"],
    24: ["freeze_bot", "sir_drip", "beetort", "freez"],
    25: ["tramacron", "picore", "pheona"],
    27: ["minothrush", "smullock"],
    29: ["burn_bot", "sir_flame", "lavan"],
    30: ["ceratops", "karos"],
    31: ["yakkadin", "goliem"],
    32: ["skeldrip", "taran"],
    33: ["flarell", "spinecap"],
    34: ["ghouldig", "ghoulsmash", "smunk"],
    35: ["moss_bat", "popochy"],
    36: ["toomba", "auqus", "freez"],
    37: ["magicrell", "derpcap", "skelfire", "redmula"],
    38: ["magicrell", "derpcap"],
    39: ["ghoulseed", "ghoulbloom", "smull", "smullock"],
    40: ["aqua_bat", "aquabella"],
    41: ["ferdog", "flamus", "lavan"],
    42: ["skeleme", "tramula"],
    43: ["naturell", "bloomcap"],
    44: ["ghouldrop", "ghoulfrost", "smoovie"],
    45: ["fire_bat", "flarepaw"],
    48: ["aquarell", "frostcap"],
}

# Floor pages seen in J5VBY2BmEHg (16), M5mNONC9InE (21) and WQml7mTbvCU (38).
BOSSES = {16: "jelliton", 21: "balrog", 38: "astral_eldragon"}
DROPS = {
    16: [["blessed", "A", 2], ["clarity", "A", 3], ["blessed", "B", 3]],
    21: [["blessed", "A", 3], ["clarity", "A", 1], ["blessed", "B", 2]],
}

raw = open(PATH, encoding="utf-8", newline="").read()
data = json.loads(raw)
known = json.load(open(os.path.join(ROOT, "data", "monsters.json"), encoding="utf-8"))
changed = 0
for floor, ids in ENEMIES.items():
    missing = [i for i in ids if i not in known]
    assert not missing, (floor, missing)
    entry = data[str(floor)]
    if entry.get("enemies") != ids:
        entry["enemies"] = ids
        changed += 1
for floor, boss in BOSSES.items():
    assert boss in known, boss
    if data[str(floor)].get("boss") != boss:
        data[str(floor)] = {"boss": boss, **data[str(floor)]}
        changed += 1
for floor, drops in DROPS.items():
    if data[str(floor)].get("drops") != drops:
        data[str(floor)]["drops"] = drops
        changed += 1
lines = ["\t%s: %s" % (json.dumps(k), json.dumps(v, ensure_ascii=False)) for k, v in data.items()]
out = "{\n" + ",\n".join(lines) + "\n}"
if "\r\n" in raw:
    out = out.replace("\n", "\r\n")
open(PATH, "w", encoding="utf-8", newline="").write(out + ("\r\n" if raw.endswith("\r\n") else "\n" if raw.endswith("\n") else ""))
print("floors changed:", changed)
