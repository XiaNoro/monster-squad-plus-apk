# Finds monster captures ("Next Field / Again / Leave" screens) after each won battle that tools/scan_stage_enemies.py
# found, and identifies the captured monster by sprite. Output: research/videos/drops.tsv
# Usage: python -I tools/scan_drops.py [--jobs 8]
import glob, json, os, re, sys
from collections import Counter, defaultdict
from multiprocessing import Pool
import cv2
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scan_stage_enemies as S

CAPTURE = re.compile(r"Next\s*Field|Again.*Leave|Leave.*Again", re.I)
RARITY = re.compile(r"\b(UNCOMMON|COMMON|RARE|EPIC|LEGEND\w*)\b", re.I)
WINDOW = 150
CROPS = os.path.join(S.VIDEOS, "drops_crops")
islands = json.load(open(os.path.join(S.ROOT, "data", "islands.json"), encoding="utf-8"))
flat = []


def init():
    S.load_refs()
    for el in S.refs.values():
        flat.extend(el)


def secs(f):
    return int(re.sub(r"\D", "", f) or 0)


def slots(img):
    H, W = img.shape[:2]
    hsv = cv2.cvtColor(img[:int(H * 0.45)], cv2.COLOR_BGR2HSV)
    yellow = cv2.inRange(hsv, (18, 140, 200), (34, 255, 255))
    n, _lab, st, cen = cv2.connectedComponentsWithStats(yellow)
    stars = sorted((cen[k][0], cen[k][1]) for k in range(1, n)
                   if H * 0.04 < st[k][3] < H * 0.1 and 0.75 < st[k][2] / st[k][3] < 1.3 and st[k][4] > 0.4 * st[k][2] * st[k][3])
    groups = []
    for x, y in stars:
        if groups and x - groups[-1][-1][0] < H * 0.1 and abs(y - groups[-1][-1][1]) < H * 0.04:
            groups[-1].append((x, y))
        else:
            groups.append([(x, y)])
    out = []
    for grp in groups:
        cx = sum(x for x, _ in grp) / len(grp)
        sy = sum(y for _, y in grp) / len(grp)
        win = img[int(sy + H * 0.17):int(min(H, sy + H * 0.52)), int(max(0, cx - H * 0.17)):int(min(W, cx + H * 0.17))]
        if win.shape[0] > 20 and win.shape[1] > 20:
            out.append((win, H * 0.105, len(grp), cx / W))
    return out


def rank(win, unit, pool):
    coarse = S.scaled(win, unit, S.COARSE)
    cands = [r for r in flat if r[0] in pool]
    short = sorted(((S.best_score(coarse, c), mid, f) for mid, c, f in cands), key=lambda r: -r[0])[:S.SHORTLIST]
    fine = S.scaled(win, unit, S.BW)
    return sorted(((S.best_score(fine, f), mid) for _s, mid, f in short), reverse=True)[:2]


def stage_pool(island, diff, stage):
    out = set()
    for isl in islands:
        if isl["id"] != island:
            continue
        for d, info in isl["difficulties"].items():
            if diff in (d, "?") and 0 < stage <= len(info["stages"]):
                st = info["stages"][stage - 1]
                out |= set(st["enemies"]) | {st["boss"]}
    return out


def scan(path):
    data = json.load(open(path, encoding="utf-8"))
    d = os.path.join(S.VIDEOS, data["frames"], data["video"])
    if not os.path.exists(os.path.join(d, "ocr.tsv")):
        return []
    rows = [(secs(f), f, t) for f, t in S.read_ocr(d)]
    battles = sorted(data["battles"], key=lambda b: secs(b["start"]))
    out = []
    for i, b in enumerate(battles):
        if b.get("result") != "win":
            continue
        lo = secs(b["end"])
        hi = min(lo + WINDOW, secs(battles[i + 1]["start"]) if i + 1 < len(battles) else 10 ** 9)
        events, last = [], -99
        for t, f, text in rows:
            if lo < t < hi and CAPTURE.search(text):
                if t - last > 4:
                    events.append([])
                events[-1].append((f, text))
                last = t
        seen = {m for h in b["hits"] for m in [h[3]] if h[5] >= 4.5}
        for ev in events:
            rar = next((RARITY.search(t).group(1).upper() for _f, t in ev if RARITY.search(t)), "")
            f = ev[len(ev) // 2][0]
            img = cv2.imread(os.path.join(d, f))
            if img is None:
                continue
            pool = seen | stage_pool(b["island"], b["difficulty"], b["stage"]) | {b.get("boss_intro", "")}
            for k, (win, unit, stars, sx) in enumerate(slots(img)):
                graded = {m for m, mm in S.monsters.items() if int(mm.get("stars", 0)) == stars}
                g = rank(win, unit, graded)
                p = rank(win, unit, pool & graded) or rank(win, unit, pool)
                name = "%s_%s_%d.jpg" % (data["video"], f[:-4], k)
                cv2.imwrite(os.path.join(CROPS, name), win)
                out.append({"video": data["video"], "frames": data["frames"], "frame": f, "island": b["island"], "stage": b["stage"],
                            "difficulty": b["difficulty"], "boss_intro": b.get("boss_intro", ""), "rarity": rar, "stars": stars,
                            "global": g, "pool": p, "battle": b["start"], "crop": name, "in_pool": sorted(pool)})
    return out


def main(args):
    jobs = int(args[args.index("--jobs") + 1]) if "--jobs" in args else 8
    paths = [p for p in sorted(glob.glob(os.path.join(S.OUT, "*.json"))) if not p.endswith("calib.json")]
    os.makedirs(CROPS, exist_ok=True)
    for old in glob.glob(os.path.join(CROPS, "*.jpg")):
        os.remove(old)
    rows = []
    with Pool(jobs, initializer=init) as pool:
        for r in pool.imap_unordered(scan, paths):
            rows += r
    tsv = os.path.join(S.VIDEOS, "drops.tsv")
    with open(tsv, "w", encoding="utf-8") as fh:
        fh.write("\t".join(["video", "frame", "island", "difficulty", "stage", "boss_intro", "rarity", "stars", "global", "g_score",
                            "g_margin", "pool", "p_score", "battle", "crop"]) + "\n")
        for r in sorted(rows, key=lambda r: (r["island"], r["difficulty"], r["stage"], r["video"], r["frame"])):
            g, p = r["global"], r["pool"]
            fh.write("\t".join(map(str, [r["video"], r["frame"], r["island"], r["difficulty"], r["stage"], r["boss_intro"], r["rarity"], r["stars"],
                                         g[0][1] if g else "", round(g[0][0], 3) if g else "", round(g[0][0] - g[1][0], 3) if len(g) > 1 else "",
                                         p[0][1] if p else "", round(p[0][0], 3) if p else "", r["battle"], r["crop"]])) + "\n")
    print(len(rows), "captures ->", tsv)


if __name__ == "__main__":
    main(sys.argv[1:])
