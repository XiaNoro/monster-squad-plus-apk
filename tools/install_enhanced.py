import os, re, sys, shutil
import cv2
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sys.argv[1]
BACKUP = os.path.join(ROOT, "research", "replaced_originals")
FIELD = (716, 204)
FOLDERS = {"badges REDO": "badges"}


def trim(img):
    if img.ndim == 3 and img.shape[2] == 4:
        pts = cv2.findNonZero((img[..., 3] > 10).astype("uint8"))
        if pts is not None:
            x, y, w, h = cv2.boundingRect(pts)
            return img[y:y + h, x:x + w]
    return img


def resize(img, w, h):
    k = w / img.shape[1]
    return cv2.resize(img, (w, h), interpolation=cv2.INTER_AREA if k < 1 else cv2.INTER_LANCZOS4)


def fit(img, w, h):
    k = min(w / img.shape[1], h / img.shape[0])
    return resize(img, max(1, round(img.shape[1] * k)), max(1, round(img.shape[0] * k)))


def paste(img, w, h, cy=None):
    out = np.zeros((h, w, 4), np.uint8)
    y = (h - img.shape[0]) // 2 if cy is None else max(0, min(h - img.shape[0], round(cy - img.shape[0] / 2)))
    x = (w - img.shape[1]) // 2
    out[y:y + img.shape[0], x:x + img.shape[1]] = img
    return out


def bbox(img):
    return cv2.boundingRect(cv2.findNonZero((img[..., 3] > 10).astype("uint8")))


def digits(g):
    col = g[..., 3].astype(np.float64).sum(0)
    w = g.shape[1]
    cuts = [0]
    for i in range(1, 10):
        lo, hi = round(w * (i - 0.5) / 10), round(w * (i + 0.5) / 10)
        cuts.append(lo + int(np.argmin(col[lo:hi])))
    cuts.append(w)
    return [trim(despeck(g[:, cuts[i]:cuts[i + 1]].copy())) for i in range(10)]


def despeck(p):
    n, lab, st, _ = cv2.connectedComponentsWithStats((p[..., 3] > 10).astype("uint8"), connectivity=8)
    if n > 2:
        big = st[1:, cv2.CC_STAT_AREA].max()
        for i in range(1, n):
            if st[i, cv2.CC_STAT_AREA] < big * 0.05:
                p[lab == i] = 0
    return p


def font_sheet(img, old, cells=True):
    g = trim(img)
    ox, oy, ow, oh = bbox(old)
    if not cells:
        g = fit(g, ow, 10 ** 6)
        return paste(g, old.shape[1], max(old.shape[0], g.shape[0]), oy + oh / 2)
    cell = old.shape[1] // 10
    parts = digits(g)
    k = min(oh / max(p.shape[0] for p in parts), (cell - 2) / max(p.shape[1] for p in parts))
    out = np.zeros((old.shape[0], old.shape[1], 4), np.uint8)
    tall = round(max(p.shape[0] for p in parts) * k)
    base = oy + (oh + tall) // 2
    for i, p in enumerate(parts):
        p = resize(p, max(1, round(p.shape[1] * k)), max(1, round(p.shape[0] * k)))
        x = i * cell + (cell - p.shape[1]) // 2
        out[base - p.shape[0]:base, x:x + p.shape[1]] = p
    return out


def convert(rel, img, old):
    folder = rel.split("/")[0]
    if folder == "fields":
        h = round(img.shape[1] * FIELD[1] / FIELD[0])
        return resize(img[:h], *FIELD)
    if folder == "battle_bg":
        return img
    if rel.startswith("apk/sprites/damage_font/"):
        return font_sheet(img, old, not rel.endswith("DF_critical.png"))
    if rel.startswith("apk/"):
        return resize(img, old.shape[1], old.shape[0])
    if folder == "badges":
        return resize(img, 256, 256)
    if folder == "icons":
        return fit(trim(img), 256, 256)
    if folder == "monsters_cut":
        return fit(trim(img), 480, 480)
    if folder == "islands":
        return resize(trim(img), old.shape[1], old.shape[0])
    if folder == "ui":
        return resize(img, old.shape[1] * 2, old.shape[0] * 2)
    raise ValueError(rel)


for d, _, files in os.walk(SRC):
    for f in sorted(files):
        if not f.endswith("_marked.png"):
            continue
        rel = os.path.relpath(os.path.join(d, f), SRC).replace("\\", "/")
        for a, b in FOLDERS.items():
            rel = rel.replace(a + "/", b + "/")
        rel = re.sub(r"_marked\.png$", ".png", rel)
        dst = os.path.join(ROOT, "assets", rel)
        if not os.path.exists(dst):
            print("skip (no target)", rel)
            continue
        bak = os.path.join(BACKUP, rel.replace("apk/", "", 1))
        if not os.path.exists(bak):
            os.makedirs(os.path.dirname(bak), exist_ok=True)
            shutil.copy2(dst, bak)
        img = cv2.imread(os.path.join(d, f), cv2.IMREAD_UNCHANGED)
        old = cv2.imread(bak, cv2.IMREAD_UNCHANGED)
        out = convert(rel, img, old)
        cv2.imwrite(dst, out)
        print(rel, f"{old.shape[1]}x{old.shape[0]} -> {out.shape[1]}x{out.shape[0]}")
