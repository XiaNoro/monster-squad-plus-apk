# Rips monster sprites from cube-opening footage (the single-monster reveal screen: dark-green stage,
# star row and LEGENDARY/EPIC/SUPER RARE title). Finds each reveal, picks its cleanest frame (no speech
# bubble), builds a background plate as the per-pixel median of all reveal frames, cuts each monster out
# against that plate, then drops duplicates. Output: research/sprites_rip/<video id>/ (PNGs + contact sheet).
# Frames of any size are scaled to 1080 high and centred in 1920 wide. Gold (EPIC/LEGENDARY) and blue
# (RARE/SUPER RARE) titles both count, on a dark stage only (bright battle cut-ins with gold stars are skipped).
# Videos with too few reveals borrow the best-fitting plate from another ripped video. Reveals the plate
# doesn't fit exactly (moving/zoomed stage) are cut out with GrabCut seeded by the plate difference.
# Usage: python tools/rip_reveals.py <video id> [--scan]
import sys, os, json
import numpy as np
import cv2

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VID = sys.argv[1]
SRC = os.path.join(ROOT, "research", "videos", "video_hd", VID + ".mp4")
OUT = os.path.join(ROOT, "research", "sprites_rip", VID)
FPS = cv2.VideoCapture(SRC).get(cv2.CAP_PROP_FPS) or 30.0
STEP = max(1, round(FPS / 8))
DUP = 0.09
MIN_OWN_PLATE = 8

STARS = (slice(140, 255), slice(570, 1340))
TITLE = (slice(255, 365), slice(600, 1300))
BADGE = (slice(120, 265), slice(400, 570))
CROP = (slice(365, 900), slice(420, 1500))


def gold(a):
    b, g, r = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    return ((r > 200) & (g > 150) & (b < 90) & (r - b > 120)).mean()


def pink(a):
    b, g, r = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    return ((r > 200) & (b > 120) & (g < 120)).mean()


def blue(a):
    b, g, r = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    return ((b > 180) & (r < 130) & (b - r > 100)).mean()


def stage(f):
    s = np.concatenate([f[450:800, 60:330].reshape(-1, 3), f[450:800, 1590:1860].reshape(-1, 3)]).mean(0)
    return bool(s.mean() < 110)


def mint(a):
    b, g, r = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    return ((g > 215) & (r > 175) & (b > 175) & (g >= r) & (g - b < 60)).mean()


def norm(f):
    h, w = f.shape[:2]
    if (h, w) == (1080, 1920):
        return f
    nw = round(w * 1080 / h)
    f = cv2.resize(f, (nw, 1080), interpolation=cv2.INTER_AREA if h > 1080 else cv2.INTER_CUBIC)
    if nw >= 1920:
        x = (nw - 1920) // 2
        return f[:, x:x + 1920]
    x = (1920 - nw) // 2
    return cv2.copyMakeBorder(f, 0, 0, x, 1920 - nw - x, cv2.BORDER_REPLICATE)


def scan():
    cap = cv2.VideoCapture(SRC)
    rows = []
    i = 0
    while True:
        ok = cap.grab()
        if not ok:
            break
        if i % STEP == 0:
            f = norm(cap.retrieve()[1])
            corner = f[700:760, 60:200].reshape(-1, 3).mean(0)
            rows.append({"i": i, "t": round(i / FPS, 2), "stars": round(gold(f[STARS]), 3), "title": round(max(gold(f[TITLE]), blue(f[TITLE])), 3), "stage": stage(f),
                         "new": round(pink(f[BADGE]), 3), "mint": round(mint(f[CROP]), 4), "bright": round(float((f[CROP].min(2) > 230).mean()), 4), "bg": [round(x) for x in corner]})
        i += 1
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "scan.json"), "w") as fh:
        json.dump(rows, fh)
    return rows


def segments(rows):
    segs, cur = [], []
    for r in rows:
        if r["stars"] > 0.1 and r["title"] > 0.06 and r.get("stage", True):
            cur.append(r)
        elif cur:
            segs.append(cur)
            cur = []
    if cur:
        segs.append(cur)
    out = []
    for s in segs:
        pool = [r for r in s if r["mint"] <= 0.002] or s
        low = min(r.get("bright", 0) for r in pool)
        pool = [r for r in pool if r.get("bright", 0) <= low + 0.002]
        best = pool[len(pool) // 2]
        out.append({"i": best["i"], "t": best["t"], "stars": round(s[len(s) // 2]["stars"] / 0.0515), "new": bool(max(r["new"] for r in s) > 0.08), "bubble": best["mint"]})
    return out


def frames(idx):
    want = set(idx)
    got = {}
    cap = cv2.VideoCapture(SRC)
    i = 0
    last = max(want)
    while i <= last:
        if not cap.grab():
            break
        if i in want:
            got[i] = norm(cap.retrieve()[1])
        i += 1
    return got


def build_plate(crops):
    stack = np.stack(crops).astype(np.float32)
    b, g, r = stack[..., 0], stack[..., 1], stack[..., 2]
    hsv = np.stack([cv2.cvtColor(c, cv2.COLOR_BGR2HSV) for c in crops])
    hue = hsv[..., 0].astype(np.float32)
    bg = (hue > 60) & (hue < 95) & (g >= r + 8) & (np.abs(b - g) < 70)
    masked = np.where(bg[..., None], stack, np.nan)
    plate = np.nanmedian(masked, axis=0)
    count = bg.sum(0)
    hole = (count < 6) | np.isnan(plate).any(2)
    plain = np.median(stack, axis=0)
    h, w = hole.shape
    yy, xx = np.mgrid[0:h, 0:w]
    centre = ((xx - w * 0.48) / (w * 0.2)) ** 2 + ((yy - h * 0.5) / (h * 0.45)) ** 2 < 1.0
    plate = np.where((hole & ~centre)[..., None], plain, np.nan_to_num(plate)).astype(np.uint8)
    plate = cv2.inpaint(plate, (hole & centre).astype(np.uint8) * 255, 9, cv2.INPAINT_TELEA)
    return cv2.GaussianBlur(plate, (5, 5), 0)


def cutout(img, plate):
    p = img.astype(np.float32)
    q = plate.astype(np.float32) + 1.0
    k = (p * q).sum(2) / (q * q).sum(2)
    perp = np.linalg.norm(p - k[..., None] * q, axis=2)
    d = np.abs(p - q).max(2)
    shade = (k > 0.55) & (k < 2.2)
    d = np.where(shade, np.minimum(d, perp * 1.6), d)
    a = np.clip((d - 20.0) / 22.0, 0, 1)
    m = (a > 0.5).astype(np.uint8)
    m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    n, lab, stats, _ = cv2.connectedComponentsWithStats(m, 8)
    if n > 1:
        big = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        bx, by, bw, bh = stats[big, :4]
        keep = np.zeros(n, bool)
        for k in range(1, n):
            x, y, w, h, area = stats[k]
            near = x < bx + bw + 30 and x + w > bx - 30 and y < by + bh + 30 and y + h > by - 30
            keep[k] = near and area >= 30
        m = keep[lab].astype(np.uint8)
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8))
    filled = m.copy()
    h, w = m.shape
    flood = np.zeros((h + 2, w + 2), np.uint8)
    cv2.floodFill(filled, flood, (0, 0), 1)
    m = m | (1 - filled)
    a = np.maximum(a * cv2.dilate(m, np.ones((5, 5), np.uint8)), m.astype(np.float32))
    a = cv2.GaussianBlur(a, (3, 3), 0)
    rgba = np.dstack([img, (a * 255).astype(np.uint8)])
    ys, xs = np.where(a > 0.05)
    if len(xs) == 0:
        return None
    return rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def border_diff(img, plate):
    d = np.abs(img.astype(int) - plate.astype(int)).max(2)
    return float(np.median(np.concatenate([d[:40].ravel(), d[-40:].ravel(), d[:, :60].ravel(), d[:, -60:].ravel()])))


def fits(img, plate):
    return border_diff(img, plate) <= 1.5


def borrow_plate(crops):
    best, score = None, 8.0
    base = os.path.dirname(OUT)
    for v in os.listdir(base):
        p = os.path.join(base, v, "plate.png")
        if v == VID or not os.path.exists(p):
            continue
        plate = cv2.imread(p)
        s = float(np.median([border_diff(c, plate) for c in crops]))
        if s < score:
            best, score = plate, s
    return best


def count_stars(f):
    a = f[STARS]
    b, g, r = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    m = ((r > 200) & (g > 150) & (b < 90) & (r - b > 120)).astype(np.uint8)
    n, _, stats, _ = cv2.connectedComponentsWithStats(cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8)), 8)
    areas = stats[1:, cv2.CC_STAT_AREA]
    if not len(areas):
        return 0
    return int((areas > areas.max() * 0.4).sum())


def grabcut(img, plate=None):
    x0, x1 = 220, img.shape[1] - 220
    m = np.zeros(img.shape[:2], np.uint8)
    bg, fg = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    rect = (x0, 20, x1 - x0, img.shape[0] - 70)
    if plate is None:
        cv2.grabCut(img, m, rect, bg, fg, 8, cv2.GC_INIT_WITH_RECT)
    else:
        d = np.abs(img.astype(int) - plate.astype(int)).max(2)
        inside = np.zeros(m.shape, bool)
        inside[rect[1]:rect[1] + rect[3], rect[0]:rect[0] + rect[2]] = True
        m[:] = cv2.GC_BGD
        m[inside] = np.where(d[inside] > 45, cv2.GC_PR_FGD, cv2.GC_PR_BGD)
        cv2.grabCut(img, m, None, bg, fg, 8, cv2.GC_INIT_WITH_MASK)
    m = ((m == 1) | (m == 3)).astype(np.uint8)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(m, 8)
    if n < 2:
        return None
    big = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    bx, by, bw, bh = stats[big, :4]
    keep = np.zeros(n, bool)
    for k in range(1, n):
        x, y, w, h, area = stats[k]
        keep[k] = area >= 40 and x < bx + bw + 20 and x + w > bx - 20 and y < by + bh + 20 and y + h > by - 20
    a = cv2.GaussianBlur(keep[lab].astype(np.float32), (3, 3), 0)
    rgba = np.dstack([img, (a * 255).astype(np.uint8)])
    ys, xs = np.where(a > 0.05)
    return rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def signature(rgba):
    a = rgba[..., 3:4].astype(np.float32) / 255.0
    rgb = rgba[..., :3].astype(np.float32) * a
    small = cv2.resize(np.dstack([rgb, a[..., 0] * 255]), (24, 24), interpolation=cv2.INTER_AREA)
    return small.reshape(-1) / 255.0, rgba.shape[1] / max(1, rgba.shape[0])


def main():
    path = os.path.join(OUT, "scan.json")
    rows = json.load(open(path)) if os.path.exists(path) and "--scan" not in sys.argv else scan()
    segs = segments(rows)
    print(len(segs), "reveals")
    if not segs:
        return
    got = frames([s["i"] for s in segs])
    crops = [got[s["i"]][CROP] for s in segs if s["i"] in got]
    plate = build_plate(crops) if len(crops) >= MIN_OWN_PLATE else borrow_plate(crops)
    if plate is not None and len(crops) >= MIN_OWN_PLATE:
        cv2.imwrite(os.path.join(OUT, "plate.png"), plate)
    kept = []
    for s, c in zip(segs, crops):
        s["stars"] = count_stars(got[s["i"]]) or s["stars"]
        if s["stars"] <= 1:
            continue
        r = cutout(c, plate) if plate is not None and fits(c, plate) else grabcut(c, plate)
        if r is None or r.shape[0] < 60:
            continue
        sig, aspect = signature(r)
        dup = None
        for k in kept:
            if abs(k["aspect"] - aspect) < 0.35 and np.abs(k["sig"] - sig).mean() < DUP:
                dup = k
                break
        if dup:
            dup["seen"].append(s["t"])
            if s["bubble"] < dup["bubble"]:
                dup.update({"img": r, "bubble": s["bubble"], "t": s["t"]})
            continue
        kept.append({"img": r, "sig": sig, "aspect": aspect, "stars": s["stars"], "new": s["new"], "t": s["t"], "bubble": s["bubble"], "seen": [s["t"]]})
    for f in os.listdir(OUT):
        if f.startswith("rip_"):
            os.remove(os.path.join(OUT, f))
    index = []
    for n, k in enumerate(kept):
        name = "rip_%02d_%ds_%dstar.png" % (n + 1, int(k["t"]), k["stars"])
        cv2.imwrite(os.path.join(OUT, name), k["img"])
        index.append({"file": name, "t": k["t"], "stars": k["stars"], "new": k["new"], "seen_at": k["seen"]})
    json.dump(index, open(os.path.join(OUT, "index.json"), "w"), indent=1)
    sheet(kept)
    print(len(kept), "unique sprites")


def sheet(kept):
    if not kept:
        return
    cell = 220
    cols = 8
    rows_n = (len(kept) + cols - 1) // cols
    canvas = np.full((rows_n * (cell + 24), cols * cell, 3), (255, 0, 255), np.uint8)
    for n, k in enumerate(kept):
        im = k["img"]
        s = min((cell - 10) / im.shape[1], (cell - 10) / im.shape[0])
        im = cv2.resize(im, (max(1, int(im.shape[1] * s)), max(1, int(im.shape[0] * s))), interpolation=cv2.INTER_AREA)
        y0 = (n // cols) * (cell + 24) + (cell - im.shape[0]) // 2
        x0 = (n % cols) * cell + (cell - im.shape[1]) // 2
        a = im[..., 3:4].astype(np.float32) / 255.0
        roi = canvas[y0:y0 + im.shape[0], x0:x0 + im.shape[1]].astype(np.float32)
        canvas[y0:y0 + im.shape[0], x0:x0 + im.shape[1]] = (im[..., :3] * a + roi * (1 - a)).astype(np.uint8)
        cv2.putText(canvas, "%d  %d*" % (n + 1, k["stars"]), ((n % cols) * cell + 6, (n // cols) * (cell + 24) + cell + 18), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 0), 2)
    cv2.imwrite(os.path.join(OUT, "sheet.jpg"), canvas, [cv2.IMWRITE_JPEG_QUALITY, 88])


if __name__ == "__main__":
    main()
