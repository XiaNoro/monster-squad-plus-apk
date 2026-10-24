# Matches ripped sprites (research/sprites_rip/<video>/rip_*.png) to monster ids by comparing them with the
# current art in assets/monsters_cut (both straight and mirrored), restricted to monsters of the rip's star
# grade (--any-grade drops that, for footage where the star count isn't reliable). Writes matches.json and a
# review sheet (rip | best | 2nd | 3rd) next to the rips.
# Usage: python tools/match_rips.py <video id> [--any-grade]
import sys, os, json
import numpy as np
import cv2

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "research", "sprites_rip", sys.argv[1])
N = 40
ANY_GRADE = "--any-grade" in sys.argv


def load(path):
    im = cv2.imread(path, cv2.IMREAD_UNCHANGED)
    if im is None:
        return None
    if im.shape[2] == 3:
        im = np.dstack([im, np.full(im.shape[:2], 255, np.uint8)])
    ys, xs = np.where(im[..., 3] > 40)
    return im[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def feats(im):
    h, w = im.shape[:2]
    s = N / max(h, w)
    sm = cv2.resize(im, (max(1, round(w * s)), max(1, round(h * s))), interpolation=cv2.INTER_AREA)
    pad = np.zeros((N, N, 4), np.uint8)
    y0, x0 = (N - sm.shape[0]) // 2, (N - sm.shape[1]) // 2
    pad[y0:y0 + sm.shape[0], x0:x0 + sm.shape[1]] = sm
    a = pad[..., 3:4].astype(np.float32) / 255
    lab = cv2.cvtColor(pad[..., :3], cv2.COLOR_BGR2LAB).astype(np.float32) * a
    hsv = cv2.cvtColor(im[..., :3], cv2.COLOR_BGR2HSV)
    m = (im[..., 3] > 128).astype(np.uint8)
    hist = cv2.calcHist([hsv], [0, 1], m, [18, 8], [0, 180, 0, 256]).reshape(-1)
    hist /= max(1e-6, hist.sum())
    return {"lab": lab, "a": a, "hist": hist, "aspect": w / h}


def score(f, g):
    spatial = np.abs(f["lab"] - g["lab"]).mean() / 60 + np.abs(f["a"] - g["a"]).mean()
    colour = 1 - np.minimum(f["hist"], g["hist"]).sum()
    return 0.45 * spatial + 0.55 * colour + 0.2 * abs(np.log(f["aspect"] / g["aspect"]))


def main():
    mons = json.load(open(os.path.join(ROOT, "data", "monsters.json"), encoding="utf-8"))
    lst = mons["monsters"] if isinstance(mons, dict) and "monsters" in mons else (list(mons.values()) if isinstance(mons, dict) else mons)
    index = json.load(open(os.path.join(DIR, "index.json")))
    cands = {}
    for m in lst:
        p = os.path.join(ROOT, "assets", "monsters_cut", m["id"] + ".png")
        if m.get("material") or not os.path.exists(p):
            continue
        im = load(p)
        cands[m["id"]] = {"stars": int(m.get("stars", 0)), "f": [feats(im), feats(im[:, ::-1])], "img": im, "name": m.get("name", m["id"])}
    out = []
    rows = []
    for r in index:
        im = load(os.path.join(DIR, r["file"]))
        f = feats(im)
        pool = [(min(score(f, g) for g in c["f"]), k) for k, c in cands.items() if ANY_GRADE or c["stars"] == r["stars"]]
        if len(pool) < 3:
            pool = [(min(score(f, g) for g in c["f"]), k) for k, c in cands.items()]
        pool.sort()
        best = pool[:3]
        out.append({"file": r["file"], "id": best[0][1], "score": round(float(best[0][0]), 3), "margin": round(float(best[1][0] - best[0][0]), 3), "alts": [b[1] for b in best[1:]]})
        rows.append((im, [cands[b[1]]["img"] for b in best], [cands[b[1]]["name"] for b in best], best[0][0]))
    json.dump(out, open(os.path.join(DIR, "matches.json"), "w"), indent=1)
    sheet(rows)


def tile(im, size):
    s = min(size / im.shape[1], size / im.shape[0])
    im = cv2.resize(im, (max(1, int(im.shape[1] * s)), max(1, int(im.shape[0] * s))), interpolation=cv2.INTER_AREA)
    c = np.full((size, size, 3), 70, np.uint8)
    y0, x0 = (size - im.shape[0]) // 2, (size - im.shape[1]) // 2
    a = im[..., 3:4].astype(np.float32) / 255
    c[y0:y0 + im.shape[0], x0:x0 + im.shape[1]] = (im[..., :3] * a + c[y0:y0 + im.shape[0], x0:x0 + im.shape[1]] * (1 - a)).astype(np.uint8)
    return c


def sheet(rows):
    size, lab = 110, 18
    per = 2
    blocks = []
    for n, (rip, best, names, sc) in enumerate(rows):
        cells = [tile(rip, size)] + [tile(b, size) for b in best]
        strip = np.hstack(cells)
        bar = np.full((lab, strip.shape[1], 3), 255, np.uint8)
        cv2.putText(bar, "%d  %s  (%.2f) | %s | %s" % (n + 1, names[0], sc, names[1], names[2]), (3, 13), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (0, 0, 0), 1)
        blocks.append(np.vstack([strip, bar]))
    while len(blocks) % per:
        blocks.append(np.zeros_like(blocks[0]))
    pairs = [np.hstack([blocks[i], np.full((blocks[0].shape[0], 8, 3), 255, np.uint8), blocks[i + 1]]) for i in range(0, len(blocks), per)]
    for p in range(0, len(pairs), 13):
        cv2.imwrite(os.path.join(DIR, "match_%d.jpg" % (p // 13 + 1)), np.vstack(pairs[p:p + 13]), [cv2.IMWRITE_JPEG_QUALITY, 85])


if __name__ == "__main__":
    main()
