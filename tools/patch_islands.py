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
fix("moonlight_desert", "hard", 10, boss="dratula")
fix("boneyard_island", "normal", 13, boss="trean")
fix("dino_gorge", "normal", 12, boss="jadefang")
fix("dino_gorge", "normal", 14, boss="rubyfang")
fix("sky_island", "hell", 4, boss="unacorn")
fix("dino_gorge", "normal", 2, waves=4)
fix("robo_island", "hard", [13, 14], waves=4)
fix("sprout_island", "hell", 1, add=["firbal"])
fix("lake_island", "normal", 5, add=["o_fruit"])
fix("lake_island", "normal", 6, add=["g_fruit"])
fix("lake_island", "normal", 8, add=["friby", "o_drank", "seaspec", "dawnspec", "p_fruit", "glacion", "nightspec"])
fix("lake_island", "normal", 9, add=["dawnspook", "nightspec"])
fix("lake_island", "normal", 10, add=["nightspec"])
fix("lake_island", "hard", 5, add=["sliming"])
fix("lake_island", "hard", 6, add=["g_fruit"])
fix("lake_island", "hard", 7, add=["p_fruit", "bloomasher", "rokk"])
fix("lake_island", "hard", 9, add=["dawnspec", "spike_bonk", "friby", "nightspec"])
fix("lake_island", "hard", 11, add=["nightspec", "seaspook", "sliby"])
fix("lake_island", "hard", 12, add=["nightspec", "sliby", "seaspec", "lavion", "friby", "dawnspook", "p_fruit"])
fix("desert_isle", "normal", 3, add=["blu_antlar"])
fix("desert_isle", "hard", 1, add=["craboth"])
fix("desert_isle", "hard", 2, add=["camhil"])
fix("desert_isle", "hard", 3, add=["crabay", "crablaze", "craboth"])
fix("desert_isle", "hard", 5, add=["craboth", "red_antlid"])
fix("desert_isle", "hard", 6, add=["crabay", "bud_antlid", "craboth", "red_antlar"])
fix("desert_isle", "hard", 8, add=["red_antlar", "antlid", "bud_antlid", "bud_antlar"])
fix("desert_isle", "hard", 9, add=["camhil", "seaspook"])
fix("desert_isle", "hard", 10, add=["seaspook"])
fix("moonlight_desert", "normal", 5, add=["red_bonk"])
fix("boneyard_island", "normal", 7, add=["reditula"])
fix("boneyard_island", "normal", 9, add=["bloomasher"])
fix("boneyard_island", "normal", 12, add=["pragon"])
fix("boneyard_island", "normal", 13, add=["ibismash"])
fix("boneyard_island", "normal", 14, add=["red_antlar"])
fix("dino_gorge", "normal", 2, add=["smoo"])
fix("dino_gorge", "normal", 12, add=["ibi", "yakkadin", "pragon"])
fix("dino_gorge", "normal", 13, add=["dera", "gremula"])
fix("dino_gorge", "normal", 14, add=["ferdog"])
fix("robo_island", "hard", 13, add=["spooking", "king_drip", "king_spiky"])
fix("sky_island", "normal", 7, add=["redmula"])
fix("sky_island", "hell", 4, add=["king_spiky"])
fix("sprout_island", "normal", 3, add=["octo", "smoo", "prisbal", "flobal"])
fix("sprout_island", "normal", 4, add=["octo", "prisbal", "smish"])
fix("lake_island", "normal", 10, add=["seaspec", "greenspec", "friby", "glacion"])
fix("lake_island", "normal", 11, add=["friby"])
fix("lake_island", "hard", 11, add=["dawnspec", "dawnspook", "friby"])
fix("lake_island", "hard", 7, add=["b_fruit"])
fix("desert_isle", "normal", 3, add=["crabay"])
fix("desert_isle", "normal", 12, add=["screechey"])
fix("moonlight_desert", "normal", 3, add=["flambal", "bonk_pyro"])
fix("moonlight_desert", "hard", 7, add=["shivairy", "dawnspook"])
fix("moonlight_desert", "hard", 10, add=["smee"])
fix("boneyard_island", "normal", 9, add=["crabay", "red_antlar"])
fix("boneyard_island", "normal", [11, 14], add=["tramix"])
fix("boneyard_island", "hell", 14, add=["fino", "red_antlar"])
fix("dino_gorge", "normal", 2, add=["smee", "smull"])
fix("dino_gorge", "normal", 10, add=["grand_bang", "surak"])
fix("dino_gorge", "hard", 14, add=["trama", "ibi", "ferdog"])
fix("sky_island", "hard", 8, add=["ici"])
fix("sprout_island", "normal", 4, add=["brambal", "b_fruit", "flambal"])
fix("sprout_island", "normal", 5, add=["flambal", "prisbal", "flobal", "grumelle"])
fix("sprout_island", "normal", 6, add=["raingull", "conelle"])
fix("sprout_island", "hard", 5, add=["brambal", "flobal", "prisbal"])
fix("lake_island", "normal", 11, add=["nightspec", "glacion", "dawnspec", "lavion"])
fix("desert_isle", "hard", 1, add=["crabay"])
fix("desert_isle", "normal,hard", 3, add=["crabterror"])
fix("desert_isle", "hard", 5, add=["crabay", "blu_antlid"])
fix("desert_isle", "normal", 7, add=["blu_antlid", "blu_antlar"])
fix("moonlight_desert", "normal", 2, add=["nightspook", "armor_bonk"])
fix("moonlight_desert", "normal", [3, 4], add=["ferdog"])
fix("moonlight_desert", "normal", 5, add=["flambal"])
fix("moonlight_desert", "hard", 2, add=["greenspec", "conairy", "antlar", "armor_bonk"])
fix("moonlight_desert", "hard", 3, add=["ferdog", "crabshade", "flambal"])
fix("boneyard_island", "normal", 14, add=["cero"])
fix("dino_gorge", "hard", 13, add=["derakon", "dera"])
fix("dino_gorge", "hell", 3, add=["smulling", "smoo", "smull", "smish"])
fix("dino_gorge", "normal", 14, add=["trama", "yakka", "redmula", "ibi", "grand_bang", "doomba", "gremula", "yakkadin"])
fix("sky_island", "normal", 2, add=["pinkey", "amethoid", "ami"])
fix("sky_island", "hard", 6, add=["oceanik"])
fix("dino_gorge", "normal", 14, add=["dratula", "pretula", "tramix"])


for n, (base, six) in enumerate([("picore", "precore"), ("toriz", "torizor"), ("hark", "heroks"), ("karos", "kepros")]):
    fix("robo_island", "normal", 11 + n, boss=six, add=[base], boss_drop=0.05)
for n, (base, six) in enumerate([("megabomba", "megasavage"), ("megablow", "megacrush"), ("megabeat", "megabrute"), ("megapuncha", "megabuster")]):
    fix("robo_island", "hell", 11 + n, boss=six, add=[base], boss_drop=0.05)

# 2026-11-10 audit (research/videos/audit_2026-11-09): bosses read from boss intros, waves and enemies from stage_compare.md.
# Sprout-4 Hell (tab misread), Sprout-6 Megabuster (mis-ID), Dino-9 Normal (monthly King CaoCao quest) and
# Dino-14 Tramula (= Dratula) are left out.
fix("robo_island", "hard", 12, boss="torizor")
fix("moonlight_desert", "hell", 6, boss="cupion")
fix("dino_gorge", "hell", 9, boss="kangard")
fix("dino_gorge", "normal", 10, boss="shelltor")
fix("dino_gorge", "hell", 1, waves=4)
# 2026-11-11: LMJmca8FWEg 0163 / 0410 / 0480 (Dino-1/2/3, Normal by their 4- and 5-wave counts; the tab read as Hard).
fix("dino_gorge", "normal", 1, add=["smoo", "smee", "smish", "smull", "smelly"])
fix("dino_gorge", "normal", 2, add=["dumbird", "smella"])
fix("dino_gorge", "normal", 3, add=["smoovie", "smulling", "smish", "smelly", "smella"])
fix("robo_island", "hard", [1, 12], waves=4)
fix("robo_island", "hell", [11, 12], waves=4)
for (island, diff, stage), adds in {
    ("boneyard_island", "hell", 1): ["smishee"], ("boneyard_island", "hell", 2): ["mossmasher"],
    ("boneyard_island", "hell", 9): ["bloomasher"], ("boneyard_island", "hell", 10): ["crabay"],
    ("desert_isle", "hard", 1): ["crabterror"], ("desert_isle", "hard", 2): ["craboth"],
    ("desert_isle", "hell", 6): ["bud_antlid"], ("desert_isle", "normal", 2): ["mayn"],
    ("dino_gorge", "hard", 10): ["pretula", "gremula", "ferdog"], ("dino_gorge", "hard", 11): ["ferdog", "ibismash"],
    ("dino_gorge", "hard", 14): ["redmula"], ("dino_gorge", "hell", 3): ["dera", "smoovie", "derakon", "nadri"],
    ("dino_gorge", "hell", 4): ["twirly", "smoo", "smoovie"], ("dino_gorge", "hell", 6): ["beetort"],
    ("dino_gorge", "hell", 7): ["pragon", "cetrop"], ("dino_gorge", "hell", 9): ["yakkadin"],
    ("dino_gorge", "normal", 1): ["smoovie", "smella"], ("dino_gorge", "normal", 3): ["smoo"],
    ("dino_gorge", "normal", 4): ["smee", "smoo", "smoovie", "smelly", "smull", "smella", "smish"],
    ("dino_gorge", "normal", 10): ["ferdog"], ("dino_gorge", "normal", 11): ["marshowl", "ibismash"],
    ("dino_gorge", "normal", 14): ["surakan", "toriz", "ibismash"],
    ("moonlight_desert", "hard", 8): ["spike_bonk"], ("moonlight_desert", "hard", 9): ["dawnspook"],
    ("moonlight_desert", "hell", 6): ["antlar", "greenspook"], ("moonlight_desert", "normal", 4): ["crabterror"],
    ("robo_island", "hard", 1): ["li_l_drip"], ("robo_island", "hard", 14): ["king_flame"],
    ("robo_island", "hell", 12): ["picore"], ("sky_island", "hard", 3): ["glacion", "soosoo"],
    ("sky_island", "hard", 6): ["stoneheart", "wamia"], ("sky_island", "hard", 7): ["doorbot_v2"],
    ("sky_island", "hard", 8): ["icikel"],
}.items():
    fix(island, diff, stage, add=adds)


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
                    if st["boss"] in st["enemies"]:
                        st["enemies"].remove(st["boss"])
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
