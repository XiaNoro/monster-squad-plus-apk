# Curated corrections to data/islands.json from footage and wiki location notes.
# build_db.gd regenerates islands.json from the wiki dump, so re-run this afterwards.
# Usage: python tools/patch_islands.py
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (island, difficulty, stage number) -> fields. "boss" pins the boss (footage boss lines no longer override it),
# "add" appends enemies, "drops" limits what can drop (default: every enemy).
P = {}


ALL = "normal,hard,hell"


def fix(island, diffs, stages, **kw):
    for d in diffs.split(","):
        for s in (stages if isinstance(stages, (list, range)) else [stages]):
            cur = P.setdefault((island, d, s), {})
            for k, v in kw.items():
                if k == "add":
                    cur["add"] = cur.get("add", []) + [e for e in v if e not in cur.get("add", [])]
                else:
                    cur[k] = v


fix("sprout_island", ALL, range(4, 7), add=["smelly"])
fix("sprout_island", "hard,hell", 3, add=["prisbal"])
BALS = ["flambal", "flobal", "brambal", "prisbal"]
fix("sprout_island", "hell", 1, enemies=BALS, boss="flambal", waves=2)
fix("sprout_island", "hell", 2, enemies=BALS + ["cinderpeep", "o_fruit"], boss="emberpeep", waves=3)
fix("sprout_island", "hell", 3, enemies=BALS + ["mini", "b_fruit"], boss="wini", waves=3)
fix("lake_island", ALL, range(9, 13), add=["bloomion", "earthion"])
fix("lake_island", ALL, range(9, 13), waves=4)
fix("desert_isle", ALL, range(1, 3), waves=3)
fix("desert_isle", ALL, range(11, 13), waves=5)
fix("desert_isle", ALL, range(9, 13), add=["memew"])
fix("desert_isle", ALL, 12, add=["pinkey"])
fix("desert_isle", ALL, 3, boss="hibisquid", add=["hibisq"])
fix("lake_island", ALL, 12, boss="stoneskin")
fix("moonlight_desert", ALL, 7, add=["memew"])
fix("moonlight_desert", "hard", 11, boss="moonstar")
fix("moonlight_desert", "hell", 11, boss="moonlight")
fix("boneyard_island", "hard,hell", 12, boss="krokodar", add=["kroko"])
fix("boneyard_island", "hard,hell", 13, boss="manticlaw")
fix("boneyard_island", "hard,hell", 14, boss="goldverin", add=["wolverin"])
fix("lake_island", "hard,hell", 4, add=["donni"])
fix("boneyard_island", ALL, 3, add=["red_antlad"])
fix("boneyard_island", ALL, 12, add=["ullie"])


for n, (base, six) in enumerate([("picore", "precore"), ("toriz", "torizor"), ("hark", "heroks"), ("karos", "kepros")]):
    fix("robo_island", "normal", 11 + n, boss=six, add=[base], boss_drop=0.05)
for n, (base, six) in enumerate([("megabomba", "megasavage"), ("megablow", "megacrush"), ("megabeat", "megabrute"), ("megapuncha", "megabuster")]):
    fix("robo_island", "hell", 11 + n, boss=six, add=[base], boss_drop=0.05)


def main():
    path = os.path.join(ROOT, "data/islands.json")
    islands = json.load(open(path, encoding="utf-8"))
    mons = json.load(open(os.path.join(ROOT, "data/monsters.json"), encoding="utf-8"))
    count = 0
    for isl in islands:
        for diff, info in isl["difficulties"].items():
            for k, st in enumerate(info["stages"]):
                kw = P.get((isl["id"], diff, k + 1))
                if kw is None:
                    continue
                orig = st.setdefault("orig", {"boss": st["boss"], "enemies": list(st["enemies"]), "drops": list(st.get("drops", []))})
                st["boss"] = orig["boss"]
                st["enemies"] = list(orig["enemies"])
                if orig["drops"]:
                    st["drops"] = list(orig["drops"])
                else:
                    st.pop("drops", None)
                st.pop("boss_fixed", None)
                st.pop("boss_drop", None)
                st.pop("level", None)
                st.pop("waves", None)
                if "waves" in kw:
                    st["waves"] = kw["waves"]
                if "boss_drop" in kw:
                    st["boss_drop"] = kw["boss_drop"]
                if "enemies" in kw:
                    st["enemies"] = list(kw["enemies"])
                for e in kw.get("add", []):
                    if e not in st["enemies"]:
                        st["enemies"].append(e)
                if "boss" in kw:
                    st["boss"] = kw["boss"]
                    st["boss_fixed"] = True
                    if kw.get("drops_from_enemies"):
                        st["drops"] = [e for e in st["enemies"] if e != kw["boss"]]
                    if st["boss"] not in st["enemies"]:
                        st["enemies"].insert(0, st["boss"])
                if "drops" in kw:
                    st["drops"] = list(kw["drops"])
                if "level" in kw:
                    st["level"] = kw["level"]
                for e in st["enemies"] + st.get("drops", []) + [st["boss"]]:
                    if e not in mons:
                        print("UNKNOWN", isl["id"], diff, k + 1, e)
                count += 1
    json.dump(islands, open(path, "w", encoding="utf-8"), indent="\t", ensure_ascii=False)
    print("patched", count, "stages")


main()
