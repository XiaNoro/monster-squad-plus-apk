# Footage corrections for special islands and raids: boss lines, bosses, drop lists, raid texts and raid room lines.
# Safe to re-run; run it after patch_specials.py (which rebuilds parts of special_islands.json).
# Sources: research/videos/audit_2026-11-09 (missing_dialogue.tsv, special_drops.md).
# Usage: python tools/patch_footage_lines.py
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPECIALS = os.path.join(ROOT, "data", "special_islands.json")
RAIDS = os.path.join(ROOT, "data", "raids.json")

SAY = {
    ("spirit_island", "Ici (★4)"): "The spirits of the elements fill me with power!",
    ("magic_island", "Swirell (★4)"): "You think you can use me just because I'm full of\npower? I'll show you!",
    ("training_island", "Training(Hard)"): "There is no end to a challenge.\nOnly the ones you set yourself.",
    ("treasure_island", "Treasure(Hard)"): "No matter how much treasure, it's not enough.\nFunny, right? You have no idea, do you?",
    ("jungle_island", "Jungle(Easy)"): "You think plants are passive?\nShall we see if that's true? Come on!",
    ("icicle_island", "Icicle(Extreme)"): "Blades of ice will leave a mark\nand disappear without a trace.",
    ("volcano_island", "Volcano(Extreme)"): "Did you live an exciting life?\nThen you'll have no regrets!",
    ("deep_ocean_island", "3 Silent Heal"): "A bastard making much noise in the sea will be\nsilenced forever.",
    ("deep_ocean_island", "7 Frozen Sea"): "Quite impressive you bear this coldness.",
    ("deep_ocean_island", "8 Titanic Foot"): "Tsunami in the heart of the sea causes Long Stun. It's\ngoanna be hard for you if your fellow can't be cured.",
    ("elemental_island", "Temple of Great Nature (normal)"): "Face nature's wrath and tremble in fear!",
    ("elemental_island", "Temple of Four Elements (hell)"): "All the fools seeking treasure will be punished!",
    ("hunters_folly", "Lustful Hunter"): "Hell is so much more pleasurable than heaven.",
    ("hunters_folly", "Slothful Hunter"): "Demon hunting is a pain. I'd rather sit back and relax.",
    ("hunters_folly", "Envious Hunter"): "Don't be jealous because I'm better than you.",
    ("hunters_folly", "Prideful Hunter"): "Hmph, as if a demon could outsmart ME!",
    ("k9_kingdom", "Unholy Dog"): "Monsters threw me from the sky. Will you help me?",
    ("k9_kingdom", "Hot Dog"): "All I want is to be surrounded by screams of pain!",
    ("k9_kingdom", "Alpha Dog"): "It's not too late to bow down and become my slave.",
    ("k9_kingdom", "Beta Dog"): "You truly think you can win with those weaklings?",
    ("k9_kingdom", "Sigma Dog"): "You've come far...but this is the end of the line!",
    ("candy_island", "Candy Forest (HELL)"): "Candy festival! Follow me if you want some!",
}

BOSS = {
    ("icicle_island", "Icicle(Extreme)"): "naladdin",
    ("volcano_island", "Volcano(Extreme)"): "nightmare",
    ("deep_ocean_island", "7 Frozen Sea"): "nalino",
    ("deep_ocean_island", "8 Titanic Foot"): "torban",
}

TEMPLE_LIST = ["fortina", "pentacorn", "slayergal", "pandabond", "whalduke", "ant_queen", "pheona", "torch_eldragon",
               "frozen_eldragon", "neo_eldragon", "void_eldragon", "pyro_eldragon", "polar_eldragon", "nurture_eldragon",
               "meteor_eldragon", "fire_eldrake"]
TEMPLE_RARE = {"fortina": 0.01, "pentacorn": 0.01, "slayergal": 0.01, "pandabond": 0.01, "whalduke": 0.01, "ant_queen": 0.01}

DROPS = {
    ("magic_island", "Voxus (★4)"): (["voxus", "voidina", "blacky", "stonn", "rokk"], {"voidina": 0.03, "blacky": 0.05}),
    ("hunters_folly", "Wrathful Hunter"): (["lowe", "grand_bang", "brickett"], {}),
    ("maple_island", "Pink Bean"): (["e_zakum", "e_magnus", "smelly"], {}),
    ("maple_island", "Pink Bean(Chaos)"): (["e_zakum", "e_magnus", "smelly"], {}),
}

RAID_DESC = {
    "pharaohs_curse": "Sealed Pharaoh has awakened after thousands of years. Discover the secret of Pyramid.",
    "beauty_or_the_beast": "This island is home to violent beasts, but if you go into the forest, you might meet the island's beautiful mistress.",
}

RAID_SOURCE = {
    "mansion_of_madness": "All 12 rooms confirmed from Stage popups in nQ32vaLy-Ms and SdhIA5LxZ4c.",
    "ruined_village": "Rooms 1-10 and 12 confirmed from Stage popups in Qp42mJw2Syo.",
    "beauty_or_the_beast": "All 12 rooms confirmed from Stage popups in FxyWvAnt-Wo. Cube drops (Guardhunt, Toomba, Ferdog, Yakkadin, Torban, Ibismash, Ibisking) confirmed in _zWGX1aXmsc.",
    "pharaohs_curse": "Rooms 1 and 3-12 confirmed from Stage popups in X8sy1M0ylBo and syrrRJrXYU8.",
}
RAID_ROOMS = {"pharaohs_curse": {6: ["evil_hy", "evil_hy", "skelefire", "skelefire"]}}
RAID_LINES = {
    "beauty_or_the_beast": {
        "4": "Who dares to challenge me and my razor sharp\nfangs?!",
        "5": "So you want to meet the mistress of the forest? Well,\nit's me! See my pretty hair?!",
        "7": "To be honest, I haven't met the mistress, either. I\nheard she's pretty, though.",
        "8": "Are you the fool who's searching for the mistress?",
        "9": "What, is my forest different from what you\nexpected?",
        "11": "A smart woman knows never to bare her fangs in\npublic.",
        "12": "Just because you're cute doesn't mean I'll show you\nany mercy.",
    },
}


def set_boss(q, boss):
    old = q["boss"]
    if old == boss:
        return
    q["boss"] = boss
    q["enemies"] = [e for e in q["enemies"] if e != boss]
    if old not in q["enemies"]:
        q["enemies"].append(old)


def main():
    d = json.load(open(SPECIALS, encoding="utf-8"))
    mons = json.load(open(os.path.join(ROOT, "data", "monsters.json"), encoding="utf-8"))
    n = 0
    for s in d["islands"]:
        for q in s["quests"]:
            key = (s["id"], q["name"])
            if key in BOSS:
                set_boss(q, BOSS[key])
            if key in SAY:
                q["say"] = SAY[key]
                n += 1
            if key in DROPS:
                drops, rare = DROPS[key]
                q["drops"] = list(drops)
                for e in drops:
                    if e != q["boss"] and e not in q["enemies"] and e not in rare:
                        q["enemies"].append(e)
                if rare:
                    have = {r["id"] for r in q.get("rare", [])}
                    q["rare"] = q.get("rare", []) + [{"id": i, "chance": c} for i, c in rare.items() if i not in have]
            if s["id"] == "elemental_island":
                extra = [e for e in q.get("drops", []) if e not in TEMPLE_LIST]
                q["drops"] = TEMPLE_LIST + extra
                have = {r["id"] for r in q.get("rare", [])}
                q["rare"] = q.get("rare", []) + [{"id": i, "chance": c} for i, c in TEMPLE_RARE.items() if i not in have]
            for e in [q["boss"]] + q["enemies"] + q.get("drops", []) + [r["id"] for r in q.get("rare", [])]:
                if e not in mons:
                    print("UNKNOWN", s["id"], e)
    open(SPECIALS, "w", encoding="utf-8", newline="").write(json.dumps(d, indent=4, ensure_ascii=False).replace("\n", "\r\n"))

    r = json.load(open(RAIDS, encoding="utf-8"))
    for raid in r["raids"]:
        if raid["id"] in RAID_DESC:
            raid["desc"] = RAID_DESC[raid["id"]]
        if raid["id"] in RAID_SOURCE:
            raid["source"] = RAID_SOURCE[raid["id"]]
        for room, ids in RAID_ROOMS.get(raid["id"], {}).items():
            raid["rooms"][room - 1] = ids
        if raid["id"] in RAID_LINES:
            raid["lines"] = RAID_LINES[raid["id"]]
    open(RAIDS, "w", encoding="utf-8", newline="").write(json.dumps(r, indent=4, ensure_ascii=False))
    print("special lines", n, "- raids patched")


main()
