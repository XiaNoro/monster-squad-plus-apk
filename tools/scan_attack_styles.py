import collections
import glob
import json
import os
import re
import sys
from concurrent.futures import ProcessPoolExecutor

import cv2
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VIDEOS = os.path.join(ROOT, "research", "videos")
OUT = os.path.join(VIDEOS, "attack_styles")
H = 360
FPS = 10.0
TIMER_RE = re.compile(r"\b0[0-4] ?[:;.] ?\d\d\b")
MIN_SEGMENT = 14
MAX_SEGMENT = 40
SEGMENTS_PER_VIDEO = 3


def segments():
    out = []
    for ocr in glob.glob(os.path.join(VIDEOS, "frames*", "*", "ocr.tsv")):
        folder = os.path.dirname(ocr)
        name = os.path.basename(folder)
        vid = re.sub(r"^\d\d_", "", name)
        files = [p for p in glob.glob(os.path.join(VIDEOS, "video*", "*" + vid + ".*")) if p.endswith((".mp4", ".webm", ".mkv"))]
        if not files:
            continue
        times = []
        for line in open(ocr, encoding="utf8", errors="replace"):
            parts = line.rstrip("\n").split("\t", 1)
            if len(parts) != 2:
                continue
            m = re.match(r"﻿?(\d+)\.jpg", parts[0])
            if m and TIMER_RE.search(parts[1]) and "Select" not in parts[1]:
                times.append(int(m.group(1)))
        times.sort()
        runs = []
        for t in times:
            if runs and t - runs[-1][1] <= 4:
                runs[-1][1] = t
            else:
                runs.append([t, t])
        runs = [r for r in runs if r[1] - r[0] >= MIN_SEGMENT]
        runs.sort(key=lambda r: r[0] - r[1])
        for a, b in runs[:SEGMENTS_PER_VIDEO]:
            out.append({"vid": vid, "file": files[0], "t0": a + 1.0, "t1": min(b, a + MAX_SEGMENT)})
    return out


def bars(img):
    w = img.shape[1]
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    green = ((hsv[..., 0] > 40) & (hsv[..., 0] < 80) & (hsv[..., 1] > 140) & (hsv[..., 2] > 140)).astype(np.uint8)
    green[: int(H * 0.12)] = 0
    green[int(H * 0.84):] = 0
    n, _, st, _ = cv2.connectedComponentsWithStats(green)
    out = []
    for i in range(1, n):
        x, y, bw, bh, area = st[i]
        if 4 <= bw <= 90 and 2 <= bh <= 8 and area > bw * bh * 0.6:
            out.append((int(x), int(y), int(bw), int(bh)))
    return out


def anchor(img, bar):
    x, y, bw, bh = bar
    probe = img[max(0, y - 3):y + bh + 3, max(0, x - 14):x]
    if probe.size == 0:
        return None
    hsv = cv2.cvtColor(probe, cv2.COLOR_BGR2HSV)
    return x


def track(seg):
    cap = cv2.VideoCapture(seg["file"])
    cap.set(cv2.CAP_PROP_POS_MSEC, seg["t0"] * 1000)
    frames = []
    nxt = seg["t0"]
    while True:
        ok, f = cap.read()
        if not ok:
            break
        t = cap.get(cv2.CAP_PROP_POS_MSEC) / 1000
        if t > seg["t1"]:
            break
        if t + 1e-3 >= nxt:
            f = cv2.resize(f, (round(f.shape[1] * H / f.shape[0]), H), interpolation=cv2.INTER_AREA)
            frames.append((t, f))
            nxt += 1.0 / FPS
    if len(frames) < FPS * 8:
        return None
    width = frames[0][1].shape[1]
    per = [(t, f, bars(f)) for t, f in frames]
    grid = collections.Counter()
    for _, _, bs in per:
        seen = set()
        for x, y, bw, bh in bs:
            seen.add((round(x / 3), round(y / 3)))
        grid.update(seen)
    homes = []
    for (gx, gy), n in grid.most_common():
        if n < len(per) * 0.45:
            break
        if all(abs(gx * 3 - hx) > 9 or abs(gy * 3 - hy) > 9 for hx, hy in homes):
            homes.append((gx * 3, gy * 3))
    out = []
    for hx, hy in homes:
        side = "ally" if hx < width * 0.5 else "enemy"
        sign = 1.0 if side == "ally" else -1.0
        state = []
        for t, f, bs in per:
            at_home = any(abs(x - hx) <= 4 and abs(y - hy) <= 4 for x, y, bw, bh in bs)
            moved = any(15 <= (x - hx) * sign <= 90 and abs(y - hy) <= 10 for x, y, bw, bh in bs)
            state.append((t, at_home, moved))
        dashes = []
        i = 0
        while i < len(state):
            if not state[i][1]:
                j = i
                while j < len(state) and not state[j][1]:
                    j += 1
                span = (state[j - 1][0] - state[i][0]) + 1.0 / FPS
                if 0.15 <= span <= 0.9 and j < len(state) and i > 0 and any(state[k][2] for k in range(i, j)):
                    dashes.append(round(state[i][0], 2))
                i = j
            else:
                i += 1
        present = [s[0] for s in state if s[1]]
        dur = present[-1] - present[0] if present else 0.0
        gone = sum(1 for s in state if not s[1]) / len(state)
        t_pick = present[len(present) // 2] if present else per[0][0]
        fr = min(per, key=lambda p: abs(p[0] - t_pick))[1]
        cx = hx + 14
        box = (max(0, cx - 75), hy + 2, min(width, cx + 75), min(H, hy + 120))
        crop_name = "%s_%d_%d_%d.jpg" % (seg["vid"], int(seg["t0"]), hx, hy)
        cv2.imwrite(os.path.join(OUT, "crops", crop_name), fr[box[1]:box[3], box[0]:box[2]])
        out.append({"side": side, "home": hx, "y": hy, "dur": round(dur, 1), "gone": round(gone, 2), "dashes": dashes, "drift": 0.0, "crop": crop_name, "t": round(t_pick, 2)})
    return {"seg": seg, "width": width, "tracks": out}


def main():
    os.makedirs(os.path.join(OUT, "crops"), exist_ok=True)
    segs = segments()
    only = sys.argv[1:]
    if only:
        segs = [s for s in segs if s["vid"] in only]
    print(len(segs), "segments", flush=True)
    res = []
    with ProcessPoolExecutor(8) as ex:
        for k, r in enumerate(ex.map(track, segs)):
            if r:
                res.append(r)
            if k % 25 == 0:
                print(k, flush=True)
    json.dump(res, open(os.path.join(OUT, "tracks%s.json" % ("_test" if only else "")), "w"), indent=1)
    n = sum(len(r["tracks"]) for r in res)
    m = sum(1 for r in res for t in r["tracks"] if t["dashes"])
    print(len(res), "segments", n, "tracks", m, "with dashes")


if __name__ == "__main__":
    main()
