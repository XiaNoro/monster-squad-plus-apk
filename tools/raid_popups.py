# Reads raid room lineups from footage: finds the "Stage N" enemy popups through the OCR text in
# research/videos/frames_hd/<id>/ocr.tsv (made by tools/ocr_frames.ps1), tries the 4-enemy, 5-enemy and BOSS popup
# layouts and keeps the best-scoring one, then prints each room's monsters (best frame per room, plus runner-ups).
# Slot positions are in 1920x1080 units and scaled to the video. Also writes <id>/rooms.json.
# Usage: python tools/raid_popups.py <video id>
import sys, os, re, json
import cv2
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import match_icons

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAYOUTS = {
    "4": [(655, 497), (864, 497), (1072, 497), (1280, 497)],
    "5": [(596, 499), (780, 499), (964, 499), (1164, 499), (1362, 499)],
    "boss": [(952, 524)],
}
SIZE = 176


def main():
    vid = sys.argv[1]
    d = os.path.join(ROOT, "research", "videos", "frames_hd", vid)
    keys, mat = match_icons.stack(match_icons.library())
    rooms = {}
    for line in open(os.path.join(d, "ocr.tsv"), encoding="utf-8-sig"):
        name, _, text = line.rstrip("\n").partition("\t")
        m = re.search(r"Stage (\d{1,2})\b(?! ?/)", text)
        if not m or not re.search(r"\bG[Oo]\b", text):
            continue
        room = int(m.group(1))
        if room == 111 or room > 12:
            continue
        frame = cv2.imread(os.path.join(d, name))
        k = frame.shape[0] / 1080.0
        boss = re.search(r"B[Oo]SS", text) is not None
        best = None
        for lay, pts in LAYOUTS.items():
            if boss and lay != "boss":
                continue
            got = []
            for x, y in pts:
                s = int(SIZE * k)
                got.append(match_icons.best(frame, (int(x * k - s / 2), int(y * k - s / 2), s, s), keys, mat, 2))
            mean = float(np.mean([g[0][1] for g in got])) - (0.1 if lay == "boss" and not boss else 0.0)
            if best is None or mean > best[0]:
                best = (mean, lay, got)
        if best and (room not in rooms or best[0] > rooms[room]["score"]):
            rooms[room] = {"score": best[0], "frame": name, "ids": [g[0][0] for g in best[2]], "alt": [g[1][0] for g in best[2]], "scores": [round(g[0][1], 3) for g in best[2]]}
    for r in sorted(rooms):
        v = rooms[r]
        print("room %2d  %s  %.3f  %s   (alt %s) %s" % (r, v["frame"], v["score"], ", ".join(v["ids"]), ", ".join(v["alt"]), v["scores"]))
    json.dump(rooms, open(os.path.join(d, "rooms.json"), "w"), indent=1)


main()
