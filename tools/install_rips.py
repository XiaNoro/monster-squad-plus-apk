# Installs matched rips (research/sprites_rip/<video>/matches.json, after the OVERRIDES below) as battle
# sprites in assets/monsters_cut/<id>.png, mirrored to face the same way as the art they replace. The old
# sprites are copied to research/monsters_cut_pre_rip/ first (once), so this can be undone or re-run.
# PICKS replaces the matcher entirely for a set (only the listed rips are installed). FLIP lists monsters whose
# old art faced the wrong way, so their rip is turned back round.
# Usage: python tools/install_rips.py <video id>
import sys, os, json, shutil
import numpy as np
import cv2
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from match_rips import load, feats, score, ROOT

VID = sys.argv[1]
DIR = os.path.join(ROOT, "research", "sprites_rip", VID)
CUT = os.path.join(ROOT, "assets", "monsters_cut")
BACKUP = os.path.join(ROOT, "research", "monsters_cut_pre_rip")
OVERRIDES = {
    "Av0_PQeZR7Y": {17: None, 18: None, 19: "krokodin", 26: None, 31: "blue_dragongod", 32: None, 51: None, 70: "chilchilla"},
    "forest_reveals": {1: None, 2: "jelliking", 3: None},
}
FLIP = {"kaios", "darkrake", "patragon", "thundaro", "elit_centaur"}
PICKS = {
    "batch2": {1: "shaaark", 2: "espina", 3: "kanga", 4: "kabash", 8: "twinblaze", 9: "grumairy",
               10: "conellia", 11: "trimi", 12: "fino", 13: "puchy", 17: "sir_fwoosh", 18: "mimi", 19: "swordgal",
               21: "wami", 22: "ferdog", 23: "pari", 24: "naomi", 26: "crown_bear", 33: "greentula", 35: "prism_kong", 37: "plum_bun", 38: "greenspook", 44: "kaowolf",
               45: "finosaurus", 46: "magroon", 47: "grumelle", 48: "trimia", 49: "chilellia", 51: "tramula",
               59: "cammount", 61: "shivairy", 63: "spa_ape", 65: "twinbark", 66: "stabbr",
               70: "parigontix", 71: "octoqueen", 73: "lavatron", 75: "plum_bat"},
    "batch3": {1: "screechey", 3: "beetorking", 6: "kaios", 7: "iron_bear", 8: "zayn", 9: "whimptor", 10: "wamiami",
               12: "whalgent", 13: "doonga", 15: "derakon", 17: "mewshine", 19: "owlder", 21: "nadrian", 22: "ami",
               23: "infernopaw", 25: "grand_bomb", 27: "taran", 29: "torban", 30: "groch", 31: "spooki", 36: "rean",
               37: "gramtula", 38: "spookloak", 39: "becinder", 41: "kroko"},
    "UpdR7VO-Er8": {1: "armorin", 4: "frivolycan", 5: "chilelle", 7: "greengeist", 9: "tallie", 12: "drop_bonk"},
    "qTORNXmk5TA": {1: "ceratops", 2: "cupion", 6: "cetrop", 9: "flarrel"},
    "gjnUbLszOVU": {1: "pheornas", 2: "balro", 6: "finosaur", 9: "unee", 10: "shivellia"},
    "ddfUQq1TQk4": {2: "flarepaw", 6: "lucky", 8: "forin", 10: "reditula", 12: "trapula"},
    "uoE11JwIN8w": {1: "dragomi", 3: "water_kong", 5: "sharpbeak", 10: "humbark", 14: "beetort"},
    "fsVxvMZltBc": {1: "xenocutter", 2: "ici", 4: "pandonin", 5: "ruburak", 8: "azurehide"},
    "C7zO1aLP51U": {1: "maglavan"},
    "iM13xmwUkps": {7: "pompabear", 16: "mayn"},
    "ulNikfQabA4": {1: "stoneskin", 5: "firepaw", 8: "wolverin"},
    "n5dnu2B1vPw": {1: "esper", 6: "cutiepong", 9: "octovia"},
    "34D1MNCpEew": {2: "wamia", 4: "dawnspook", 5: "xenolancer", 7: "feroah"},
    "p3bubCiqwx0": {1: "doorbot_v2", 7: "sea_geist", 8: "urscout_g", 9: "fortina", 10: "balrog", 12: "thorni", 14: "jelliton"},
    "-iOgBeFYYpc": {4: "nightspook", 8: "pinkey", 12: "tramix", 14: "ice_crush"},
    "tjgPYUoHSw4": {8: "banana_dragon", 9: "pentacorn", 11: "narkissa", 22: "dumbird", 34: "dark_hawk", 35: "plossom", 51: "jackolantern"},
    "qgPn3IRLnzA": {2: "glintscale", 3: "jadehide", 4: "mantiroar", 10: "femme_fatale_chosun", 12: "antlid", 33: "volcanic_ape"},
    "Q9GME4fRoCM": {2: "tramarex", 3: "stellar_eldragon", 10: "moon_king", 20: "titan_foot", 23: "darkrake", 25: "kepros", 28: "stabking"},
}


def main():
    matches = json.load(open(os.path.join(DIR, "matches.json")))
    over = OVERRIDES.get(VID, {})
    os.makedirs(BACKUP, exist_ok=True)
    done = {}
    for n, m in enumerate(matches, 1):
        mid = PICKS[VID].get(n) if VID in PICKS else over.get(n, m["id"])
        if mid is None or mid in done:
            continue
        rip = cv2.imread(os.path.join(DIR, m["file"]), cv2.IMREAD_UNCHANGED)
        dst = os.path.join(CUT, mid + ".png")
        if os.path.exists(dst):
            back = os.path.join(BACKUP, mid + ".png")
            if not os.path.exists(back):
                shutil.copy2(dst, back)
            old = load(back)
            f = feats(load(os.path.join(DIR, m["file"])))
            if score(f, feats(old[:, ::-1])) < score(f, feats(old)):
                rip = rip[:, ::-1]
        if mid in FLIP:
            rip = rip[:, ::-1]
        cv2.imwrite(dst, np.ascontiguousarray(rip))
        done[mid] = m["file"]
    json.dump(done, open(os.path.join(DIR, "installed.json"), "w"), indent=1)
    print(len(done), "sprites installed")


if __name__ == "__main__":
    main()
