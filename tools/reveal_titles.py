import cv2
import numpy as np

RARITIES = ["common", "uncommon", "rare", "superrare", "epic", "legendary"]
TH = 0.8


def load():
    out = {}
    for r in RARITIES:
        img = cv2.imread("assets/apk/sprites/betaGacha00/%s.png" % r, cv2.IMREAD_UNCHANGED)
        gray = cv2.cvtColor(img[:, :, :3], cv2.COLOR_BGR2GRAY)
        mask = (img[:, :, 3] > 140).astype(np.uint8) * 255
        out[r] = (gray, mask)
    return out


def _peaks(res, tw, th, limit=12):
    res = res.copy()
    res[~np.isfinite(res)] = -1
    out = []
    for _ in range(limit):
        _, v, _, loc = cv2.minMaxLoc(res)
        if v < TH - 0.08:
            break
        out.append((float(v), loc))
        x, y = loc
        res[max(0, y - th // 2):y + th // 2 + 1, max(0, x - tw // 2):x + tw // 2 + 1] = -1
    return out


def _iou(a, b):
    ax0, ay0, ax1, ay1 = a
    bx0, by0, bx1, by1 = b
    ix = max(0, min(ax1, bx1) - max(ax0, bx0))
    iy = max(0, min(ay1, by1) - max(ay0, by0))
    inter = ix * iy
    return inter / float((ax1 - ax0) * (ay1 - ay0) + (bx1 - bx0) * (by1 - by0) - inter + 1e-6)


def score_at(gray, tmpl, s, loc):
    g, m = tmpl
    t = cv2.resize(g, None, fx=s, fy=s, interpolation=cv2.INTER_AREA)
    mk = cv2.resize(m, (t.shape[1], t.shape[0]), interpolation=cv2.INTER_NEAREST)
    x, y = loc
    pad = 6
    x0, y0 = max(0, x - pad), max(0, y - pad)
    roi = gray[y0:y + t.shape[0] + pad, x0:x + t.shape[1] + pad]
    if roi.shape[0] < t.shape[0] or roi.shape[1] < t.shape[1] or mk.max() == 0:
        return 0.0, loc
    r = cv2.matchTemplate(roi, t, cv2.TM_CCOEFF_NORMED, mask=mk)
    r[~np.isfinite(r)] = -1
    _, v, _, l = cv2.minMaxLoc(r)
    return float(v), (x0 + l[0], y0 + l[1])


def find(gray, tmpls, scales):
    f = 0.25 if gray.shape[0] >= 900 else 0.5
    half = cv2.resize(gray, None, fx=f, fy=f, interpolation=cv2.INTER_AREA)
    cands = []
    for name, (g, m) in tmpls.items():
        for s in scales:
            hs = s * f
            t = cv2.resize(g, None, fx=hs, fy=hs, interpolation=cv2.INTER_AREA)
            if t.shape[1] < 24 or t.shape[0] < 8 or t.shape[1] >= half.shape[1] or t.shape[0] >= half.shape[0]:
                continue
            mk = cv2.resize(m, (t.shape[1], t.shape[0]), interpolation=cv2.INTER_NEAREST)
            r = cv2.matchTemplate(half, t, cv2.TM_CCOEFF_NORMED, mask=mk)
            for v, (x, y) in _peaks(r, t.shape[1], t.shape[0]):
                cands.append((v, name, s, (int(x / f), int(y / f))))
    cands.sort(key=lambda c: -c[0])
    kept = []
    for v, name, s, loc in cands:
        g = tmpls[name][0]
        box = (loc[0], loc[1], loc[0] + g.shape[1] * s, loc[1] + g.shape[0] * s)
        if any(_iou(box, k[4]) > 0.25 for k in kept):
            continue
        fv, floc = score_at(gray, tmpls[name], s, loc)
        if name == "common" and fv >= TH:
            ux = int(floc[0] - (tmpls["uncommon"][0].shape[1] - g.shape[1]) * s)
            uv, uloc = score_at(gray, tmpls["uncommon"], s, (max(0, ux), floc[1]))
            if uv >= fv - 0.03:
                name, fv, floc, g = "uncommon", uv, uloc, tmpls["uncommon"][0]
        if fv >= TH:
            kept.append((fv, name, s, floc, (floc[0], floc[1], floc[0] + g.shape[1] * s, floc[1] + g.shape[0] * s)))
    return kept


def scales_for(h):
    return [h / 1080.0 * k for k in np.geomspace(0.45, 2.4, 24)]


def near(known, h):
    out = []
    for k in known:
        out += [k * f for f in (0.93, 0.965, 1.0, 1.035, 1.07)]
    return out or scales_for(h)
