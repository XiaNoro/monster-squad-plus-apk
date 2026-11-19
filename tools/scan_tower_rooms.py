import collections
import glob
import json
import os
import re
import sys

import cv2
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VIDEOS = os.path.join(ROOT, "research", "videos")
CUT = os.path.join(ROOT, "assets", "monsters_cut")
OUT = os.path.join(VIDEOS, "tower_rooms")
H = 720
VIDEOS_PER_FLOOR = 2
FLOOR_RE = re.compile(r"Floor (\d{1,2}) \| Drop List")
STAGE_RE = re.compile(r"\bSta[gq]e ([123Il])\b")
TIMER_RE = re.compile(r"\b0([01]) ?[:;.•] ?(\d)(\d)\b")
ELEMENTS = {"fire": (0, 12), "water": (95, 125), "nature": (35, 85), "normal": (130, 165)}


def battles():
    out = collections.defaultdict(lambda: collections.defaultdict(list))
    for ocr in glob.glob(os.path.join(VIDEOS, "frames*", "*", "ocr.tsv")):
        vid = os.path.relpath(os.path.dirname(ocr), VIDEOS)
        cur = None
        for line in open(ocr, encoding="utf8", errors="replace"):
            parts = line.rstrip("\n").split("\t", 1)
            if len(parts) != 2:
                continue
            fn, txt = parts
            m = FLOOR_RE.search(txt)
            if m:
                cur = int(m.group(1))
                continue
            s = STAGE_RE.search(txt)
            t = TIMER_RE.search(txt)
            if cur and s and t and "/" not in txt[s.end():s.end() + 3]:
                stage = {"1": 1, "I": 1, "l": 1, "2": 2, "3": 3}[s.group(1)]
                secs = int(t.group(1)) * 60 + int(t.group(2)) * 10 + int(t.group(3))
                out[(vid, cur)][stage].append((fn, secs))
    return out


def norm(img):
    return cv2.resize(img, (round(img.shape[1] * H / img.shape[0]), H), interpolation=cv2.INTER_AREA)


def hp_bars(img):
    w = img.shape[1]
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    green = ((hsv[..., 0] > 40) & (hsv[..., 0] < 75) & (hsv[..., 1] > 150) & (hsv[..., 2] > 150)).astype(np.uint8)
    green[:, :int(w * 0.55)] = 0
    green[int(H * 0.82):] = 0
    n, _, stats, _ = cv2.connectedComponentsWithStats(green)
    bars = []
    for i in range(1, n):
        x, y, bw, bh, area = stats[i]
        if 30 <= bw <= 160 and 4 <= bh <= 16 and area > bw * bh * 0.5:
            bars.append((int(x), int(y), int(bw), int(bh)))
    return bars


def element_of(img, bar):
    x, y, bw, bh = bar
    c = img[max(0, y - 14):y + bh + 14, max(0, x - 34):x - 4]
    if c.size == 0:
        return ""
    hsv = cv2.cvtColor(c, cv2.COLOR_BGR2HSV)
    sel = (hsv[..., 1] > 110) & (hsv[..., 2] > 90)
    if sel.sum() < 15:
        return ""
    hue = float(np.median(hsv[..., 0][sel]))
    for el, (a, b) in ELEMENTS.items():
        if a <= hue <= b:
            return el
    return "fire" if hue > 165 else ""


def sprite_box(img, bar):
    x, y, bw, bh = bar
    cx = x + bw // 2
    return max(0, cx - 150), y + bh + 2, min(img.shape[1], cx + 150), min(H, y + 250)


_lib = {}


def library(mons):
    if not _lib:
        for p in glob.glob(os.path.join(CUT, "*.png")):
            k = os.path.basename(p)[:-4]
            if k not in mons:
                continue
            t = cv2.imread(p, cv2.IMREAD_UNCHANGED)
            if t is None or t.shape[2] != 4:
                continue
            ys, xs = np.nonzero(t[..., 3] > 40)
            if len(xs) == 0:
                continue
            t = t[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
            variants = []
            for height in (60, 75, 90, 105, 120):
                tt = cv2.resize(t, (max(4, round(t.shape[1] * height / t.shape[0])), height), interpolation=cv2.INTER_AREA)
                for u in (tt, cv2.flip(tt, 1)):
                    m = (u[..., 3] > 128).astype(np.uint8)
                    variants.append((np.ascontiguousarray(u[..., :3]), m))
            _lib[k] = variants
    return _lib


def match(crop, keys, lib):
    small = cv2.resize(crop, (crop.shape[1] // 2, crop.shape[0] // 2), interpolation=cv2.INTER_AREA)
    scores = []
    for k in keys:
        best = -1.0
        for u, m in lib[k]:
            if u.shape[1] >= small.shape[1] or u.shape[0] >= small.shape[0]:
                continue
            r = cv2.matchTemplate(small, u, cv2.TM_CCOEFF_NORMED, mask=m)
            r = r[np.isfinite(r)]
            if r.size:
                best = max(best, float(r.max()))
        scores.append((best, k))
    scores.sort(reverse=True)
    return scores[:6]


def pick_frame(frames):
    frames = sorted(frames, key=lambda f: -f[1])
    early = [f for f in frames if f[1] >= 80] or frames[:1]
    return early


_mons = None


def room(job):
    global _mons
    vid, floor, stage, frames = job
    if _mons is None:
        _mons = json.load(open(os.path.join(ROOT, "data", "monsters.json"), encoding="utf8"))
    lib = library(_mons)
    best = None
    for fn, secs in pick_frame(frames):
        img = norm(cv2.imread(os.path.join(VIDEOS, vid, fn)))
        bars = hp_bars(img)
        if best is None or len(bars) > len(best[2]):
            best = (fn, img, bars)
    fn, img, bars = best
    name = "F%02d_R%d_%s_%s" % (floor, stage, vid.replace(os.sep, "_"), fn[:-4])
    cv2.imwrite(os.path.join(OUT, name + ".jpg"), img[:, int(img.shape[1] * 0.5):])
    enemies = []
    for bar in sorted(bars, key=lambda b: (b[0], b[1])):
        el = element_of(img, bar)
        x0, y0, x1, y1 = sprite_box(img, bar)
        keys = [k for k in lib if _mons[k].get("element") == el] or list(lib)
        enemies.append({"bar": bar, "element": el, "top": [(k, round(v, 3)) for v, k in match(img[y0:y1, x0:x1], keys, lib)]})
    return {"floor": floor, "room": stage, "video": vid, "frame": fn, "image": name + ".jpg", "enemies": enemies}


def main():
    from concurrent.futures import ProcessPoolExecutor
    os.makedirs(OUT, exist_ok=True)
    only = {int(a) for a in sys.argv[1:]}
    per_floor = collections.defaultdict(list)
    for (vid, floor), stages in battles().items():
        if floor <= 50 and (not only or floor in only):
            per_floor[floor].append((not vid.startswith("frames_hd"), -len(stages), -sum(len(v) for v in stages.values()), vid, stages))
    jobs = []
    for floor in sorted(per_floor):
        for _, _, _, vid, stages in sorted(per_floor[floor])[:VIDEOS_PER_FLOOR]:
            for stage in sorted(stages):
                jobs.append((vid, floor, stage, stages[stage]))
    print(len(jobs), "rooms", flush=True)
    report = []
    with ProcessPoolExecutor(max_workers=6) as ex:
        for r in ex.map(room, jobs):
            report.append(r)
            print(r["floor"], r["room"], r["video"], r["frame"], [(e["element"], e["top"][0][0]) for e in r["enemies"]], flush=True)
    json.dump(report, open(os.path.join(OUT, "rooms.json"), "w", encoding="utf8"), indent=1)


if __name__ == "__main__":
    main()
