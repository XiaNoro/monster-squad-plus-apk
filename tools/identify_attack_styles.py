import collections
import glob
import json
import os
import sys
from concurrent.futures import ProcessPoolExecutor

import cv2
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "research", "videos", "attack_styles")
CUT = os.path.join(ROOT, "assets", "monsters_cut")
HEIGHTS = (30, 38, 46, 54, 62, 72)
ELEMENTS = {"fire": (0, 12), "water": (95, 125), "nature": (35, 85), "normal": (130, 165)}
MELEE_RATE = 1.2
RANGED_MIN = 12.0


def verdict(t):
    rate = len(t["dashes"]) / max(1.0, t["dur"]) * 10.0
    if len(t["dashes"]) >= 2 and rate >= MELEE_RATE:
        return "melee"
    if not t["dashes"] and t["dur"] >= RANGED_MIN and t["drift"] <= 6:
        return "ranged"
    return ""


_lib = {}
_mons = None


def library():
    global _mons
    if _mons is None:
        _mons = json.load(open(os.path.join(ROOT, "data", "monsters.json"), encoding="utf8"))
    if not _lib:
        for p in glob.glob(os.path.join(CUT, "*.png")):
            k = os.path.basename(p)[:-4]
            if k not in _mons or _mons[k].get("material"):
                continue
            t = cv2.imread(p, cv2.IMREAD_UNCHANGED)
            if t is None or t.ndim < 3 or t.shape[2] != 4:
                continue
            ys, xs = np.nonzero(t[..., 3] > 40)
            if len(xs) == 0:
                continue
            t = t[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
            vs = []
            for h in HEIGHTS:
                tt = cv2.resize(t, (max(4, round(t.shape[1] * h / t.shape[0])), h), interpolation=cv2.INTER_AREA)
                for u in (tt, cv2.flip(tt, 1)):
                    vs.append((np.ascontiguousarray(u[..., :3]), (u[..., 3] > 128).astype(np.uint8)))
            _lib[k] = vs
    return _lib, _mons


def match(job):
    crop_path, el = job
    lib, mons = library()
    crop = cv2.imread(os.path.join(OUT, "crops", crop_path))
    if crop is None:
        return crop_path, []
    keys = [k for k in lib if mons[k].get("element") == el] or list(lib)
    scores = []
    for k in keys:
        best = -1.0
        for u, m in lib[k]:
            if u.shape[0] >= crop.shape[0] or u.shape[1] >= crop.shape[1]:
                continue
            r = cv2.matchTemplate(crop, u, cv2.TM_CCOEFF_NORMED, mask=m)
            r = r[np.isfinite(r)]
            if r.size:
                best = max(best, float(r.max()))
        scores.append((round(best, 3), k))
    scores.sort(reverse=True)
    return crop_path, scores[:5]


def element_of_track(seg_file, t, home, y, width):
    cap = cv2.VideoCapture(seg_file)
    cap.set(cv2.CAP_PROP_POS_MSEC, t * 1000)
    ok, f = cap.read()
    if not ok:
        return ""
    f = cv2.resize(f, (round(f.shape[1] * 360 / f.shape[0]), 360), interpolation=cv2.INTER_AREA)
    x = int(home)
    c = f[max(0, y - 8):y + 12, max(0, x - 18):max(1, x - 1)]
    if c.size == 0:
        return ""
    hsv = cv2.cvtColor(c, cv2.COLOR_BGR2HSV)
    sel = (hsv[..., 1] > 110) & (hsv[..., 2] > 90)
    if sel.sum() < 8:
        return ""
    hue = float(np.median(hsv[..., 0][sel]))
    for el, (a, b) in ELEMENTS.items():
        if a <= hue <= b:
            return el
    return "fire" if hue > 165 else ""


def prep(r):
    out = []
    for t in r["tracks"]:
        v = verdict(t)
        if v:
            out.append({"vid": r["seg"]["vid"], "crop": t["crop"], "side": t["side"], "verdict": v, "dashes": len(t["dashes"]), "dur": t["dur"],
                        "element": element_of_track(r["seg"]["file"], t["t"], t["home"], t["y"], r["width"])})
    return out


def main():
    res = json.load(open(os.path.join(OUT, "tracks.json")))
    with ProcessPoolExecutor(8) as ex:
        rows = [x for part in ex.map(prep, res) for x in part]
    print(len(rows), "decisive tracks", collections.Counter(r["verdict"] for r in rows), collections.Counter(r["element"] for r in rows), flush=True)
    with ProcessPoolExecutor(6) as ex:
        found = dict(ex.map(match, [(r["crop"], r["element"]) for r in rows], chunksize=4))
    for r in rows:
        r["top"] = found.get(r["crop"], [])
    json.dump(rows, open(os.path.join(OUT, "identified.json"), "w"), indent=1)
    print("done")


if __name__ == "__main__":
    main()
