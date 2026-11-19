import glob
import json
import os
import sys
from concurrent.futures import ProcessPoolExecutor

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scan_attack_styles as A

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VIDEOS = os.path.join(ROOT, "research", "videos")
OUT = os.path.join(VIDEOS, "attack_styles", "duels")
H = 360


def duel_bars(f):
    w = f.shape[1]
    bs = [b for b in A.bars(f) if b[2] >= 4]
    left = [b for b in bs if b[0] < w * 0.42]
    right = [b for b in bs if b[0] > w * 0.58]
    if len(left) == 1 and len(right) == 1 and abs(left[0][1] - right[0][1]) <= 6 and len(bs) <= 3:
        return left[0], right[0]
    return None


def scan(path):
    cap = cv2.VideoCapture(path)
    dur = cap.get(7) / max(1.0, cap.get(5))
    hits = []
    t = 0.0
    while t < dur:
        cap.set(cv2.CAP_PROP_POS_MSEC, t * 1000)
        ok, f = cap.read()
        if not ok:
            break
        f = cv2.resize(f, (round(f.shape[1] * H / f.shape[0]), H), interpolation=cv2.INTER_AREA)
        if duel_bars(f):
            hits.append(t)
        t += 2.0
    runs = []
    for t in hits:
        if runs and t - runs[-1][1] <= 6:
            runs[-1][1] = t
        else:
            runs.append([t, t])
    runs = [r for r in runs if r[1] - r[0] >= 2]
    events = []
    for a, b in runs:
        cap.set(cv2.CAP_PROP_POS_MSEC, max(0.0, a - 4) * 1000)
        home = None
        prev = None
        while True:
            ok, f = cap.read()
            if not ok:
                break
            t = cap.get(cv2.CAP_PROP_POS_MSEC) / 1000
            if t > b + 6:
                break
            s = cv2.resize(f, (round(f.shape[1] * H / f.shape[0]), H), interpolation=cv2.INTER_AREA)
            d = duel_bars(s)
            if d is None:
                continue
            if home is None:
                home = [d[0][0], d[1][0]]
            for side in (0, 1):
                x = d[side][0]
                sign = 1 if side == 0 else -1
                off = (x - home[side]) * sign
                if prev is not None and off >= 25 and prev[side] < 16:
                    events.append({"file": path, "seg": [a, b], "side": "left" if side == 0 else "right", "t": round(t, 2), "home": home[side], "y": d[side][1]})
            prev = [(d[0][0] - home[0]), (home[1] - d[1][0])]
            if abs(prev[0]) < 3:
                home[0] = d[0][0]
            if abs(prev[1]) < 3:
                home[1] = d[1][0]
    return events


def main():
    os.makedirs(OUT, exist_ok=True)
    files = sorted(p for p in glob.glob(os.path.join(VIDEOS, "video*", "*")) if p.endswith((".mp4", ".webm", ".mkv")))
    files = [p for p in files if "league" in p or "badges" in p or "video_hd" in p or "video_new" in p]
    print(len(files), "videos", flush=True)
    events = []
    with ProcessPoolExecutor(8) as ex:
        for k, ev in enumerate(ex.map(scan, files)):
            events += ev
            if k % 20 == 0:
                print(k, len(events), flush=True)
    json.dump(events, open(os.path.join(OUT, "darts.json"), "w"), indent=1)
    print(len(events), "darts in", len({(e["file"], tuple(e["seg"])) for e in events}), "duels")


if __name__ == "__main__":
    main()
