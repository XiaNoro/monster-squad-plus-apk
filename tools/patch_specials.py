# Footage/wiki corrections for data/special_islands.json (hand-maintained file; safe to re-run).
# Usage: python tools/patch_specials.py
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATH = os.path.join(ROOT, "data/special_islands.json")

ELEMENTAL_POOL = ["fortina", "pentacorn", "slayergal", "pandabond", "whalduke", "ant_queen", "pheona", "torch_eldragon",
                  "frozen_eldragon", "neo_eldragon", "void_eldragon", "pyro_eldragon", "polar_eldragon", "nurture_eldragon",
                  "meteor_eldragon", "fire_eldrake"]
ELEMENTAL_GEMS = [1, 3, 4, 6, 7]
ELEMENTAL_ENEMIES = [
    ["fire_eldrake", "nurture_eldragon", "polar_eldragon", "spriby", "craboth"],
    ["polar_eldragon", "frozen_eldragon", "meteor_eldragon", "crablu", "water_kong"],
    ["pyro_eldragon", "torch_eldragon", "pheona", "crablaze", "flame_kong"],
    ["void_eldragon", "neo_eldragon", "meteor_eldragon", "crabshade", "no_kong"],
    ["pandabond", "whalduke", "ant_queen", "torch_eldragon", "void_eldragon"],
]
ELEMENTAL_RARE = [0.004, 0.006, 0.008, 0.01, 0.015]


HW_NAMES = ["1 Jack's carnival", "2 Masquerade", "3 Wolf's howling", "4 City of zombi", "5 Mummy's curse", "6 Walpurgisnacht"]
HW_BG = ["halloween_carnival", "halloween_masquerade", "halloween_graveyard", "halloween_zombi", "halloween_castle", "halloween_pumpkin"]
HW_ENERGY = {"normal": [10, 20, 30, 40, 50, 0], "hard": [15, 25, 35, 50, 60, 0], "hell": [25, 35, 45, 60, 70, 0]}
HW_FP = {"normal": 100, "hard": 200, "hell": 300}
HW_RARE = {"normal": "jack", "hard": "necro_kid", "hell": "jiangshi"}
GHOULS = ["ghoulflame", "ghoulseed", "ghouldrop", "ghouldig"]
GHOULS6 = ["ghoulflash", "ghoulbloom", "ghoulfrost", "ghoulsmash"]
HW_FIELDS = {
    "normal": [("jack_o_paw", ["firepaw"]), ("kora", ["shade"]), ("guardwolf", ["guardhunt"]),
               ("ghouldig", GHOULS), ("jackolantern", ["tutankha", "jack"])],
    "hard": [("jack_o_paw", ["firepaw", "flarepaw"]), ("camilla", ["shade", "shadow"]), ("kaowolf", ["guardhunt", "guardwolf"]),
             ("ghoulflash", GHOULS), ("jackolantern", ["tutankha", "jackoblack"])],
    "hell": [("jack_o_paw", ["infernopaw", "furion"]), ("narkissa", ["midnight", "camilla"]), ("kaolycan", ["guardwolf", "kaowolf"]),
             ("ghoulsmash", GHOULS + GHOULS6[:3]), ("necro_moncer", ["imhotep", "jackoblack", "necro_horn"])],
}
HW_FINAL = {"normal": "jackolantern", "hard": "jackolantern", "hell": "bw_ghosts"}
HW_LAST_WAVE = {"normal": ["jackoblack"], "hard": ["jackoblack", "necro_corn"], "hell": ["jiangshi"]}


def patch_halloween(hw):
    hw["promo"] = "You'll be invited to a special monster's party when you clear Fields 1~5."
    hw["_source"] = ("Fields 1-6, energy (Normal 10-50, Hard 15/25/35, Hell 25-70), Walpurgisnacht FP 100/300, waves, backgrounds and enemies: "
                     "OMYpt_g8c38, L8MkmNw8srI, 3vEP5Z0ly2Q. Hard 4/5 energy, Hard Walpurgisnacht FP, gold/exp and some bosses estimated. "
                     "Hell Mummy's curse also shows three bull-like monsters missing from the DB.")
    quests = []
    for tab, base_lv, step, gold0, exp0 in (("normal", 15, 3, 1000, 200), ("hard", 22, 3, 2200, 350), ("hell", 30, 3, 3400, 500)):
        for f in range(6):
            q = {"name": HW_NAMES[f], "tab": tab, "energy": HW_ENERGY[tab][f], "level": base_lv + step * f,
                 "exp": exp0 + 100 * f, "gold": gold0 + 800 * f, "drop_level": [1, 1], "bg": HW_BG[f],
                 "rare": [{"id": HW_RARE[tab], "chance": 0.05}]}
            if f < 5:
                boss, enemies = HW_FIELDS[tab][f]
                q.update({"boss": boss, "enemies": enemies, "stages": 3})
            else:
                pools = [e for _, e in HW_FIELDS[tab]] + [HW_LAST_WAVE[tab]]
                q.update({"boss": HW_FINAL[tab], "enemies": sorted({m for p in pools for m in p}), "wave_pools": pools,
                          "stages": 6, "fp": HW_FP[tab]})
            quests.append(q)
    hw["quests"] = quests


K9_FIELDS = [
    ("Unholy Dog", 5, "saint_bern", ["grumie", "bern"], "bern"),
    ("Feral Dog", 10, "kaolycan", ["guardwolf", "kaowolf"], "chilie"),
    ("Fierce Dog", 15, "harm_hound", ["shivvie", "shivairy"], "shivvie"),
    ("Hot Dog", 20, "twinblaze", ["ferdog", "shivairy"], "shivvie"),
    ("Alpha Dog", 25, "firukis", ["shivelle", "shivairy"], "shivairy"),
    ("Beta Dog", 30, "aquavis", ["chilelle", "ghoulflash"], "chilairy"),
    ("Sigma Dog", 35, "granubis", ["grumelle", "grumairy"], "grumairy"),
    ("Omega Dog", 40, "anubis", ["conelle", "conairy"], "conairy"),
]
K9_DOGFATHER = [["harm_hound"], ["twinblaze"], ["kaolycan"], ["aquavis"], ["granubis"], ["firukis"], ["anubis"], ["saint_bern"], ["big_bern"]]


def patch_k9(k9):
    k9["desc"] = "This holy garden was once a paradise for dogs, but now it's being occupied by selfish monsters. Help Arch Bern restore peace to this land."
    k9["promo"] = "Help Arch Bern restore peace to Doggy Heaven!"
    k9["_source"] = "Field names, energy 5-40, Dogfather 300 FP and 9 waves, bosses, enemies and backgrounds: ElOm4vFzGyc. Levels and Dogfather waves 1-8 bosses partly estimated."
    k9.pop("est_energy", None)
    quests = []
    for n, (name, energy, boss, enemies, drop) in enumerate(K9_FIELDS):
        quests.append({"name": name, "energy": energy, "level": 8 + 3 * n, "exp": 100 + 100 * n, "gold": 500 + 500 * n,
                       "drop_level": [1, 1], "boss": boss, "enemies": enemies, "stages": 3, "drops": [drop] + enemies,
                       "bg": "k9_cliffs" if n < 4 else "k9_garden"})
    quests.append({"name": "Dogfather", "energy": 0, "fp": 300, "level": 30, "exp": 1000, "gold": 3900, "drop_level": [1, 1],
                   "boss": "arch_bern", "enemies": sorted({m for p in K9_DOGFATHER for m in p}), "wave_pools": K9_DOGFATHER,
                   "wave_sizes": [1] * 8 + [0], "stages": 9, "bg": "k9_garden", "rare": [{"id": "bern", "chance": 0.1}]})
    k9["quests"] = quests


def maple_island():
    mobs = ["spooki", "octo", "ponee"]
    q = []
    for chaos in (False, True):
        for name, boss, chaos_boss, extra in (("Zakum", "e_zakum", "zakum", ["smish", "smee"]), ("Magnus", "e_magnus", "magnus", []),
                                              ("Pink Bean", "e_pink_bean", "pink_bean", [])):
            q.append({"name": name + ("(Chaos)" if chaos else ""), "energy": 20 if chaos else 4, "level": 30 if chaos else 20,
                      "exp": 600 if chaos else 300, "gold": 1500 if chaos else 520, "drop_level": [1, 1],
                      "boss": chaos_boss if chaos else boss, "enemies": mobs + extra, "stages": 3, "bg": "maple_castle",
                      "drops": ([boss] if not chaos else ["e_zakum", "e_magnus", "e_pink_bean"]) + extra,
                      "drop_mult": 0.5 if chaos else 1.0})
    return {"id": "maple_island", "name": "Maple Island", "kind": "event", "days": [],
            "desc": "A limited-edition island straight out of MapleStory! Find Zakum, Pink Bean, and Magnus here!",
            "promo": "A limited-edition island straight out of MapleStory!",
            "_source": "MapleStory crossover (p5OaHCqSMyw, 360p): fields, energy 4/20, bosses, Zakum box (E Zakum, Smish, Smee), "
                       "Pink Bean (Chaos) box, enemies Spooki/Octo/Ponee, Pink Bean field background. Gold/levels and Magnus "
                       "field enemies estimated.",
            "quests": q}


def main():
    d = json.load(open(PATH, encoding="utf-8-sig"))
    mons = json.load(open(os.path.join(ROOT, "data/monsters.json"), encoding="utf-8"))
    by = {s["id"]: s for s in d["islands"]}

    el = by["elemental_island"]
    el["unlock_gems"] = 15
    el["days"] = [6]
    el["desc"] = "In this island, the divine guard protects a precious treasure where Red Cubes can be found."
    el["est_quests"] = "Temple names, bosses and gem costs 1/3/4/6/7: dRjMGwJWYCg (0:10, 11:05). Drop list from the in-game popup at 10:57 (wiki: list shown in-game is incomplete, drops are very rare). Opens Saturdays, 60 min for 15 gems otherwise (wiki)."
    for k, q in enumerate(el["quests"]):
        q["gems"] = ELEMENTAL_GEMS[k]
        q["stages"] = 4
        q["enemies"] = ELEMENTAL_ENEMIES[k]
        q["drops"] = [e for e in ELEMENTAL_POOL if e in ELEMENTAL_ENEMIES[k] or (k == 4 and e in ("fortina", "pentacorn", "slayergal"))]
        q["drop_mult"] = 0.15
        q["red_cube_chance"] = ELEMENTAL_RARE[k]
        if k == 4:
            q["rare"] = [{"id": i, "chance": 0.01} for i in ("fortina", "pentacorn", "slayergal")]

    tr = by["treasure_island"]
    tr["est_enemies"] = False
    tr["_source"] = "Bosses Prisbal/Mewceleste/Pentacorn, energy 7/10/15, yellow monster cubes, 3 waves on Easy: D9HuvYhKiJQ."
    tq = tr["quests"]
    tq[0].update({"boss": "prisbal", "enemies": ["pufbal", "mewer", "prisbal"], "drops": ["pufbal", "mewer", "prisbal"], "stages": 3})
    tq[1].update({"boss": "mewceleste", "enemies": ["mewer", "mewshine", "prisbal"], "drops": ["mewer", "mewshine", "prisbal"], "stages": 4})
    tq[2].update({"boss": "pentacorn", "enemies": ["mewshine", "mewceleste", "prisbal"], "drops": ["mewshine", "mewceleste"], "stages": 4})

    ju = by["jungle_island"]["quests"][0]
    ju.update({"boss": "greenspook", "enemies": ["craboth", "budding", "spriby", "crabcoon", "greenspec"], "stages": 4,
               "drops": ["greenspook", "greenspec", "craboth", "budding", "spriby", "crabcoon"]})

    for q in by["magic_island"]["quests"]:
        line = q["enemies"]
        q["enemies"] = line[:2]
        q["stages"] = 4
        q["drop_level"] = [15, 30]

    for q in by["material_island"]["quests"]:
        q["stages"] = 3 if "3)" in q["name"] else 4
        q["drop_level"] = [15, 30]

    patch_halloween(by["halloween_island"])
    patch_k9(by["k9_kingdom"])
    d["islands"] = [s for s in d["islands"] if s["id"] != "maple_island"] + [maple_island()]

    for s in d["islands"]:
        for q in s["quests"]:
            for e in [q["boss"]] + q["enemies"] + q.get("drops", []):
                if e not in mons:
                    print("UNKNOWN", s["id"], q["name"].encode("ascii", "replace"), e)
    json.dump(d, open(PATH, "w", encoding="utf-8"), indent=4, ensure_ascii=False)
    print("ok")


main()
