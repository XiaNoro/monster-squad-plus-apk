import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGES = {"sprout_island": "Sprout Island", "lake_island": "Lake Island", "desert_isle": "Desert Isle",
         "moonlight_desert": "Moonlight Desert", "boneyard_island": "Boneyard Island", "robo_island": "Robo Island"}
norm = lambda s: re.sub(r"[^a-z0-9]", "", s.lower())


def load():
    mons = json.load(open(os.path.join(ROOT, "data/monsters.json"), encoding="utf-8"))
    by = {}
    for mid, m in mons.items():
        by[norm(m["name"])] = mid
    return mons, by


def parse(text, by):
    out = {}
    tabs = re.split(r"\|-\|\s*(\w+)\s*=", text)
    for i in range(1, len(tabs), 2):
        diff = tabs[i].lower()
        stages = []
        for block in re.split(r"\n\*\s*", tabs[i + 1])[1:]:
            name = block.split("\n", 1)[0].strip()
            ids = [by.get(norm(n), "?" + n) for n in re.findall(r"\{\{Monster Icon\|([^}|]+)", block)]
            stages.append({"name": name, "ids": ids})
        out[diff] = stages
    return out


def main():
    mons, by = load()
    islands = json.load(open(os.path.join(ROOT, "data/islands.json"), encoding="utf-8"))
    wiki = {}
    for iid, page in PAGES.items():
        p = os.path.join(ROOT, "research/wiki_islands", page + ".txt")
        if not os.path.exists(p):
            continue
        wiki[iid] = parse(open(p, encoding="utf-8").read(), by)
    for isl in islands:
        if isl["id"] not in wiki:
            continue
        for diff, info in isl["difficulties"].items():
            ws = wiki[isl["id"]].get(diff, [])
            for k, st in enumerate(info["stages"]):
                w = ws[k]["ids"] if k < len(ws) else None
                have = st.get("enemies", [])
                drops = st.get("drops", [])
                flag = "" if w is None or sorted(w) == sorted(have) else "  <> wiki " + ",".join(w)
                print("%s %s %-14s boss=%-12s en=%s%s%s" % (isl["id"], diff, st["name"], st["boss"], ",".join(have), (" drops=" + ",".join(drops)) if drops else "", flag))
    json.dump(wiki, open(os.path.join(ROOT, "research/wiki_islands/parsed.json"), "w"), indent=1)


main()
