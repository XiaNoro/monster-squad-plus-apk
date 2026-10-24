# Lists monsters whose wiki "location" names a story stage they are missing from in data/islands.json.
# Skips evolution notes ("First Stage ..." refers to the base form).  Usage: python tools/location_check.py
import json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NAMES = {"sprout": "sprout_island", "lake": "lake_island", "desert": "desert_isle", "moonlight": "moonlight_desert",
         "boneyard": "boneyard_island", "bone": "boneyard_island", "robo": "robo_island", "dino": "dino_gorge"}
mons = json.load(open(os.path.join(ROOT, "data/monsters.json"), encoding="utf-8"))
islands = {i["id"]: i for i in json.load(open(os.path.join(ROOT, "data/islands.json"), encoding="utf-8"))}


def stages(text):
    out = []
    for m in re.finditer(r"(Sprout|Lake|Desert|Moonlight|Boneyard|Bone|Robo|Dino)[^0-9()]{0,12}[(\s-]*((?:\d{1,2}\s*(?:~|-|,|and)?\s*)+)\)?\s*(\((?:Normal|Hard|Hell)[^)]*\))?", text, re.I):
        isl = NAMES[m.group(1).lower()]
        nums = []
        for a, b in re.findall(r"(\d{1,2})\s*(?:[~-]\s*(\d{1,2}))?", m.group(2)):
            a = int(a)
            b = int(b) if b else a
            nums += list(range(a, b + 1))
        diffs = re.findall(r"normal|hard|hell", m.group(3) or "", re.I)
        out.append((isl, [n for n in nums if n < 20], [d.lower() for d in diffs] or ["normal"]))
    return out


for mid, m in sorted(mons.items()):
    loc = str(m.get("location", ""))
    if not loc or re.search(r"evolution|first stage|1st stage|first form|second stage", loc, re.I):
        continue
    for isl, nums, diffs in stages(loc):
        if isl not in islands:
            continue
        for d in diffs:
            st = islands[isl]["difficulties"][d]["stages"]
            for n in nums:
                if n - 1 < len(st) and mid not in st[n - 1]["enemies"]:
                    print("%-14s %-16s %-6s stage %-2d  (%s)" % (mid, isl, d, n, loc[:70]))
