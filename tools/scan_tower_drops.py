import collections
import glob
import json
import os
import re
import sys

import cv2
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PANELS = os.path.join(ROOT, "research", "videos", "frames_hd", "panels", "new")
ICONS = os.path.join(ROOT, "assets", "stone_icons")
FLOORS = os.path.join(ROOT, "data", "tower_floors.json")
OUT = os.path.join(ROOT, "research", "videos", "tower_drops")
REF = "0ZxQZlMOHkQ_F19_0856.png"
H = 612
SLOT_X = [64, 181, 298]
SLOT_Y = 372
SLOT = 109
FIT_MIN = 0.45


def lavender(img):
    b, g, r = [img[..., i].astype(int) for i in range(3)]
    return ((r > 150) & (b > 160) & (b - g > 5) & (abs(r - b) < 45)).astype(np.float32)


def norm(img):
    return cv2.resize(img, (round(img.shape[1] * H / img.shape[0]), H), interpolation=cv2.INTER_AREA)


_ref_mask = None


def ref_mask():
    global _ref_mask
    if _ref_mask is None:
        img = norm(cv2.imread(os.path.join(PANELS, REF)))
        _ref_mask = lavender(img[SLOT_Y - 6:SLOT_Y + SLOT + 6, SLOT_X[0] - 6:SLOT_X[2] + SLOT + 6])
    return _ref_mask


def locate(img):
    m = lavender(img)
    best = (-1.0, 0, 0, 1.0)
    for s in np.arange(0.9, 1.11, 0.02):
        t = cv2.resize(ref_mask(), None, fx=s, fy=s, interpolation=cv2.INTER_NEAREST)
        if t.shape[0] >= m.shape[0] or t.shape[1] >= m.shape[1]:
            continue
        r = cv2.matchTemplate(m, t, cv2.TM_CCORR_NORMED)
        _, v, _, loc = cv2.minMaxLoc(r)
        if v > best[0]:
            best = (v, loc[0], loc[1], s)
    v, x, y, s = best
    return v, [(x + (sx - SLOT_X[0] + 6) * s, y + 6 * s, SLOT * s) for sx in SLOT_X]


def icon_templates():
    out = []
    for p in sorted(glob.glob(os.path.join(ICONS, "*.png"))):
        t = cv2.imread(p, cv2.IMREAD_UNCHANGED)
        kind = os.path.basename(p)[:-4].split("_")[0]
        out.append((kind, t))
    return out


def slot_icon(img, box):
    x, y, size = box
    c = img[int(y + size * 0.16):int(y + size * 0.92), int(x + size * 0.1):int(x + size * 0.9)]
    return cv2.resize(c, (40, 38), interpolation=cv2.INTER_AREA)


def feat(bgr, alpha=None):
    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    sat = hsv[..., 1] > 90
    if alpha is not None:
        sat &= alpha > 128
    h = hsv[..., 0][sat]
    hist = np.bincount((h // 6).astype(int), minlength=30).astype(float)
    return hist / max(1.0, hist.sum()), sat.mean()


def classify(crop, templates):
    fh, _ = feat(crop)
    scores = []
    for kind, t in templates:
        th, tw = t.shape[:2]
        k = min(32 / th, 32 / tw)
        t = cv2.resize(t, (max(1, round(tw * k)), max(1, round(th * k))), interpolation=cv2.INTER_AREA)
        canvas = np.full((38, 40, 3), 90, np.uint8)
        alpha = np.zeros((38, 40), np.uint8)
        oy, ox = (38 - t.shape[0]) // 2 + 2, (40 - t.shape[1]) // 2
        a = t[..., 3:4].astype(float) / 255.0
        region = canvas[oy:oy + t.shape[0], ox:ox + t.shape[1]]
        canvas[oy:oy + t.shape[0], ox:ox + t.shape[1]] = (t[..., :3] * a + region * (1 - a)).astype(np.uint8)
        alpha[oy:oy + t.shape[0], ox:ox + t.shape[1]] = t[..., 3]
        th_, _ = feat(canvas, alpha)
        hist = float(np.minimum(fh, th_).sum())
        g1 = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY).astype(np.float32)
        g2 = cv2.cvtColor(canvas, cv2.COLOR_BGR2GRAY).astype(np.float32)
        ncc = float(cv2.matchTemplate(g1, g2[4:-4, 4:-4], cv2.TM_CCOEFF_NORMED).max())
        scores.append((hist + ncc, kind))
    best = {}
    for s, kind in scores:
        best[kind] = max(best.get(kind, -9), s)
    ranked = sorted(best.items(), key=lambda kv: -kv[1])
    return ranked


def badge(img, box):
    x, y, size = box
    r = size * 0.16
    cx, cy = x + size * 0.17, y + size * 0.13
    c = img[max(0, int(cy - r)):int(cy + r), max(0, int(cx - r)):int(cx + r)]
    hsv = cv2.cvtColor(c, cv2.COLOR_BGR2HSV)
    sel = hsv[..., 1] > 80
    if sel.sum() < 5:
        return None
    hue = np.median(hsv[..., 0][sel])
    sat = np.median(hsv[..., 1][sel])
    val = np.median(hsv[..., 2][sel])
    return float(hue), float(sat), float(val), float(sel.mean())


def numeral(img, box):
    x, y, size = box
    c = img[int(y + size * 0.02):int(y + size * 0.28), int(x + size * 0.62):int(x + size * 0.98)]
    hsv = cv2.cvtColor(c, cv2.COLOR_BGR2HSV)
    m = ((hsv[..., 1] > 90) & (hsv[..., 2] > 150) & (hsv[..., 0] > 25) & (hsv[..., 0] < 100)).astype(np.uint8)
    if m.sum() < 6:
        return 0, 0.0
    cols = m.sum(axis=0) > max(2, m.shape[0] * 0.35)
    runs = 0
    prev = False
    for v in cols:
        if v and not prev:
            runs += 1
        prev = v
    hue = float(np.median(hsv[..., 0][m > 0]))
    return runs, hue


def panels():
    out = []
    for p in sorted(glob.glob(os.path.join(PANELS, "*_F*_*.png"))):
        if p.endswith(("_best.png", "_icon.png")):
            continue
        m = re.search(r"_F(\d+)_", os.path.basename(p))
        if m:
            out.append((int(m.group(1)), p))
    return out


def read_panel(path, templates):
    img = norm(cv2.imread(path))
    fit, boxes = locate(img)
    slots = []
    for box in boxes:
        ranked = classify(slot_icon(img, box), templates)
        slots.append({"type": ranked[0][0], "score": round(ranked[0][1], 3),
                      "margin": round(ranked[0][1] - ranked[1][1], 3), "badge": badge(img, box),
                      "numeral": numeral(img, box), "box": [round(v) for v in box]})
    return img, fit, slots


def rank_of(b):
    if b is None:
        return None
    hue, sat, val, _ = b
    if val < 115:
        return "E"
    if hue > 165 or hue < 8:
        return "A"
    if 140 <= hue <= 165:
        return "S"
    if 85 <= hue <= 120:
        return "B"
    if 40 <= hue <= 70:
        return "D"
    if 10 <= hue < 40:
        return "C"
    return None


def stone(s):
    return [s["type"], rank_of(s["badge"]), s["numeral"][0]]


def main():
    os.makedirs(OUT, exist_ok=True)
    known = json.load(open(FLOORS, encoding="utf8"))
    templates = icon_templates()
    rows = []
    votes = collections.defaultdict(collections.Counter)
    for floor, path in panels():
        img, fit, slots = read_panel(path, templates)
        name = os.path.basename(path)[:-4]
        read = [stone(s) for s in slots]
        rows.append({"floor": floor, "panel": name, "fit": round(fit, 3), "read": read, "slots": slots,
                     "known": known.get(str(floor), {}).get("drops")})
        if fit >= FIT_MIN:
            votes[floor][json.dumps(read)] += 1
        x0, y0 = int(slots[0]["box"][0]), int(slots[0]["box"][1])
        x1 = int(slots[2]["box"][0] + slots[2]["box"][2])
        y1 = int(y0 + slots[0]["box"][2])
        cv2.imwrite(os.path.join(OUT, name + "_drops.png"), img[max(0, y0 - 4):y1 + 4, max(0, x0 - 4):x1 + 4])
    json.dump(rows, open(os.path.join(OUT, "raw.json"), "w", encoding="utf8"), indent=1)
    lines = ["# Sky Tower Drop Lists read from footage", "",
             "tools/scan_tower_drops.py; panels with fit < %.2f skipped. Slot = [type, rank, variant]." % FIT_MIN, "",
             "| Floor | Read (votes) | Ours | Status |", "|---|---|---|---|"]
    for floor in range(1, 51):
        ours = known.get(str(floor), {}).get("drops")
        if not votes[floor]:
            lines.append("| %d | — | %s | no footage |" % (floor, json.dumps(ours) if ours else "procedural"))
            continue
        top, n = votes[floor].most_common(1)[0]
        total = sum(votes[floor].values())
        status = "new" if not ours else ("OK" if json.loads(top) == ours else "DIFF")
        lines.append("| %d | %s (%d/%d) | %s | %s |" % (floor, top, n, total, json.dumps(ours) if ours else "procedural", status))
    open(os.path.join(ROOT, "research", "videos", "tower_drops.md"), "w", encoding="utf8").write("\n".join(lines) + "\n")
    print(len(rows), "panels")
    print("\n".join(lines[6:]))


if __name__ == "__main__":
    main()
