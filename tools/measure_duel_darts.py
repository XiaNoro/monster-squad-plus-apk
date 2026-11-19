import collections
import json
import os
import sys

import cv2

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scan_attack_styles as A

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DARTS = os.path.join(ROOT, "research", "videos", "attack_styles", "duels", "darts.json")


def measure(e, other_home):
    cap = cv2.VideoCapture(e["file"])
    cap.set(cv2.CAP_PROP_POS_MSEC, (e["t"] - 0.05) * 1000)
    x = None
    best = 0.0
    while True:
        ok, f = cap.read()
        if not ok:
            break
        t = cap.get(cv2.CAP_PROP_POS_MSEC) / 1000
        if t > e["t"] + 1.0:
            break
        f = cv2.resize(f, (round(f.shape[1] * 360 / f.shape[0]), 360), interpolation=cv2.INTER_AREA)
        bs = [b for b in A.bars(f) if abs(b[1] - e["y"]) <= 8 and b[2] >= 4]
        if not bs:
            continue
        ref = e["home"] if x is None else x
        b = min(bs, key=lambda b: abs(b[0] - ref))
        if abs(b[0] - ref) > 120:
            continue
        x = b[0]
        best = max(best, abs(x - e["home"]))
    gap = abs(other_home - e["home"])
    return round(best / max(1.0, gap), 2)


def main():
    ev = json.load(open(DARTS))
    duels = collections.defaultdict(list)
    for e in ev:
        duels[(e["file"], tuple(e["seg"]))].append(e)
    out = []
    for i, ((f, seg), xs) in enumerate(duels.items()):
        homes = {}
        for e in xs:
            homes.setdefault(e["side"], e["home"])
        lh = homes.get("left", 169 * 1.0)
        rh = homes.get("right", 473 * 1.0)
        for e in xs:
            other = rh if e["side"] == "left" else lh
            e["reach"] = measure(e, other)
        for side in ("left", "right"):
            r = sorted(e["reach"] for e in xs if e["side"] == side)
            if r:
                out.append({"duel": i, "file": os.path.basename(f), "seg": list(seg), "side": side, "reach": r})
                print(i, os.path.basename(f), seg, side, r, flush=True)
    json.dump(out, open(os.path.join(os.path.dirname(DARTS), "reach.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
