# Measures how big each monster is drawn in the original game. In battle footage (frames with a "Stage x/y" label or a
# battle clock, which also covers Arena duels where both teams are player monsters) every HP bar is found (the green
# of a full normal bar shows 81 px in the game's own layout, as the type frame covers the first 17 px of Hp.png; it is
# 0.076 of the game width on every device), the monster under it is named with
# scan_stage_enemies' matcher, then its art from assets/monsters_cut is fitted over the footage at 56 heights to find
# the drawn height. Heights are in normal-HP-bar widths, corrected per video by the median width of full bars, so any
# screen size works.
# Per video results go to research/videos/size_scan/ (a rerun only scans frames not done yet); the summary is written
# to data/monster_sizes.json as the full texture height of each monster (in bar widths), plus how much bosses and
# leaders are scaled compared to the rest.
# Usage: python tools/scan_monster_sizes.py [--force] [--jobs N] [--every N] [frames dir or frames dir/video ...]
#        python tools/scan_monster_sizes.py --summary
import functools, glob, json, os, re, statistics, sys
from collections import defaultdict
from multiprocessing import Pool
import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scan_stage_enemies as S
import guess_monster_sizes as G

OUT = os.path.join(S.VIDEOS, "size_scan")
DATA = os.path.join(S.ROOT, "data", "monster_sizes.json")
CUT = os.path.join(S.ROOT, "assets", "monsters_cut")
ACCEPT_Z = 5.0
SURE_Z = 6.5
MIN_FIT = 0.45
MIN_H = 0.7
WORK = 36.0
FIT = np.exp(np.linspace(np.log(0.45), np.log(4.0), 56))
PER_VIDEO = 100
ROLES = ("enemy", "ally", "boss", "leader")
CLOCK = re.compile(r"(?<![\d:])0[0-3]\s?[:;•.,]\s?[0-5oOSs][\doOSs](?![\d:])")


@functools.lru_cache(maxsize=48)
def art(mid):
    im = cv2.imread(os.path.join(CUT, mid + ".png"), cv2.IMREAD_UNCHANGED)
    ys, xs = np.where(im[:, :, 3] > 128)
    crop = im[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    s = 4.2 * WORK / crop.shape[0]
    if s < 1.0:
        crop = cv2.resize(crop, (max(4, int(crop.shape[1] * s)), int(crop.shape[0] * s)), interpolation=cv2.INTER_AREA)
    return crop


def stars(mid):
    return int(S.monsters.get(mid, {}).get("stars", 0))


def off_star(drawn):
    by_star = defaultdict(list)
    for mid, h in drawn.items():
        by_star[stars(mid)].append(h)
    med = {k: statistics.median(v) for k, v in by_star.items()}
    return [mid for mid, h in drawn.items() if not 0.4 < h / med[stars(mid)] < 2.5]


def alpha_frac(mid):
    im = cv2.imread(os.path.join(CUT, mid + ".png"), cv2.IMREAD_UNCHANGED)
    ys = np.where((im[:, :, 3] > 128).any(axis=1))[0]
    return (ys.max() - ys.min() + 1) / im.shape[0]


def fit(win, unit, mid):
    s = WORK / unit
    lab = cv2.cvtColor(cv2.resize(win, (max(8, int(win.shape[1] * s)), max(8, int(win.shape[0] * s))), interpolation=cv2.INTER_AREA), cv2.COLOR_BGR2LAB)
    a = art(mid)
    scores = []
    for k in FIT:
        th = int(round(k * WORK))
        tw = max(4, int(round(a.shape[1] * th / a.shape[0])))
        if th < 12 or th >= lab.shape[0] or tw >= lab.shape[1]:
            scores.append((-1.0, None))
            continue
        r = cv2.resize(a, (tw, th), interpolation=cv2.INTER_AREA)
        best = (-1.0, None)
        for flip in (False, True):
            rr = cv2.flip(r, 1) if flip else r
            m = (rr[:, :, 3] > 128).astype(np.uint8)
            res = cv2.matchTemplate(lab, cv2.cvtColor(rr[:, :, :3], cv2.COLOR_BGR2LAB), cv2.TM_CCOEFF_NORMED, mask=cv2.merge([m, m, m]))
            res[~np.isfinite(res)] = -1
            _, v, _, loc = cv2.minMaxLoc(res)
            if v > best[0]:
                best = (v, (loc[0], loc[1], tw, th))
        scores.append(best)
    i = int(np.argmax([v for v, _ in scores]))
    v, rect = scores[i]
    if v < MIN_FIT or rect is None or i == 0 or i == len(FIT) - 1 or scores[i + 1][0] < 0:
        return None
    x, y, tw, th = rect
    if x <= 1 or y + th >= lab.shape[0] - 1 or x + tw >= lab.shape[1] - 1:
        return None
    a0, a1, a2 = scores[i - 1][0], v, scores[i + 1][0]
    den = a0 - 2 * a1 + a2
    off = 0.5 * (a0 - a2) / den if den < 0 else 0.0
    h = float(np.exp(np.log(FIT[i]) + off * (np.log(FIT[1]) - np.log(FIT[0]))))
    if h < MIN_H:
        return None
    return h, v, (x / s, y / s, tw / s, th / s)


def measure(img):
    (x0, y0, x1, y1), unit, found = S.bars(img, left=0.0)
    full = [b["w"] / unit for b in found if not b["long"] and 0.92 < b["w"] / unit < 1.1]
    out = []
    for b in found:
        role = ("leader" if b["long"] else "ally") if b["player"] else ("boss" if b["long"] else "enemy")
        span = 1.55 if b["long"] else 1.0
        bottom = b["y"] + 2.8 * unit
        for o in found:
            if o is not b and o["y"] > b["y"] + 0.6 * unit and abs(o["x"] - b["x"]) < 1.3 * unit:
                bottom = min(bottom, o["y"] + o["h"])
        wy0, iy1 = int(b["y"] + b["h"] / 2), int(min(y1, bottom))
        if iy1 - wy0 < unit:
            continue
        top = []
        for pad in (1.0, 0.75):
            tx0, tx1 = int(max(x0, b["x"] - pad * unit)), int(min(x1, b["x"] + (span + pad) * unit))
            if tx1 - tx0 >= 1.5 * unit:
                top = S.identify(b["el"], img[wy0:iy1, tx0:tx1], unit)
            if top and top[0][0] >= ACCEPT_Z:
                break
        if not top or top[0][0] < ACCEPT_Z:
            continue
        z1, _s, mid = top[0]
        wx0, wx1 = int(max(x0, b["x"] - 1.7 * unit)), int(min(x1, b["x"] + (span + 1.7) * unit))
        wy1 = int(min(y1, b["y"] + (4.3 if b["long"] else 3.6) * unit))
        got = fit(img[wy0:wy1, wx0:wx1], unit, mid)
        if got:
            out.append([mid, role, round(got[0], 4), round(z1, 2), round(got[1], 3), [wx0, wy0] + [round(v) for v in got[2]]])
    return full, out


def scan_video(job):
    coll, d, every, force = job
    vid = os.path.basename(d)
    dest = os.path.join(OUT, "%s__%s.json" % (coll, vid))
    ocr = S.read_ocr(d)
    frames = [f for f, text in ocr if S.WAVE.search(text)][::every][:PER_VIDEO]
    frames += [f for f, text in ocr if CLOCK.search(text) and not S.WAVE.search(text)][::every][:PER_VIDEO]
    old = json.load(open(dest, encoding="utf-8")) if os.path.exists(dest) and not force else {}
    done = set(old.get("done", []))
    todo = [f for f in frames if f not in done]
    if old and not todo:
        return None
    fulls, meas = old.get("fulls", []), old.get("meas", [])
    for f in todo:
        img = cv2.imread(os.path.join(d, f))
        if img is None:
            continue
        full, out = measure(img)
        fulls += full
        meas += [m + [f] for m in out]
    ratio = statistics.median(fulls) if len(fulls) >= 5 else 1.0
    json.dump({"video": vid, "frames": coll, "bar_ratio": round(ratio, 4), "full_bars": len(fulls), "fulls": [round(v, 4) for v in fulls],
               "done": sorted(done | set(todo)), "meas": meas}, open(dest, "w", encoding="utf-8"))
    return "%s/%s: %d new frames, %d sizes" % (coll, vid, len(todo), len(meas))


def summary():
    by = defaultdict(lambda: defaultdict(list))
    for p in glob.glob(os.path.join(OUT, "*.json")):
        d = json.load(open(p, encoding="utf-8"))
        r = float(d.get("bar_ratio", 1.0))
        for mid, role, h, z, v, *_ in d["meas"]:
            if h >= MIN_H:
                by[mid][role].append((h / r, z))
    med = {m: {role: statistics.median(h for h, _ in v) for role, v in roles.items() if len(v) >= 2} for m, roles in by.items()}
    scale = {"enemy": 1.0}
    for role in ("ally", "boss", "leader"):
        pairs = [rs[role] / rs["enemy"] for rs in med.values() if role in rs and "enemy" in rs]
        if role != "ally":
            pairs += [rs[role] / rs["ally"] * scale.get("ally", 1.0) for rs in med.values() if role in rs and "ally" in rs and "enemy" not in rs]
        scale[role] = round(statistics.median(pairs), 3) if len(pairs) >= 3 else 1.0
        print("%-6s scale %.3f from %d monsters" % (role, scale[role], len(pairs)))
    sizes = {}
    for mid, roles in sorted(by.items()):
        hz = [(h / scale[role], z) for role, v in roles.items() for h, z in v]
        for min_z in (0.0, SURE_Z):
            hs = [h for h, z in hz if z >= min_z]
            if len(hs) < 3:
                break
            m = statistics.median(hs)
            q = np.percentile(hs, [25, 75])
            spread = (q[1] - q[0]) / m
            if spread <= 0.25:
                break
        if len(hs) < 3 or spread > 0.25:
            continue
        sizes[mid] = {"h": round(m / alpha_frac(mid), 3), "n": len(hs), "spread": round(float(spread), 3), "drawn": m}
    odd = off_star({mid: s["drawn"] for mid, s in sizes.items()})
    for mid in odd:
        del sizes[mid]
    for s in sizes.values():
        del s["drawn"]
    if odd:
        print("dropped %d far from their star rating's usual size: %s" % (len(odd), ", ".join(odd)))
    data = json.load(open(DATA, encoding="utf-8")) if os.path.exists(DATA) else {}
    data["_about"] = ("Sprite sizes measured from footage. sizes (battle, tools/scan_monster_sizes.py) and lobby "
                      "(tools/scan_lobby_sizes.py) give the full height of assets/monsters_cut/<id>.png in widths of the normal "
                      "HP bar's visible green as filmed on 16:9 screens, where the game stretches its 1066-wide layout 1.0675x wider "
                      "(so one unit is 81 x 1.0675 layout px tall, BattleUnitView.SIZE_PX). role_scale and lobby_scale.leader multiply it for bosses and leaders; "
                      "lobby_scale.from_battle turns a battle size into a lobby size. guess (tools/guess_monster_sizes.py) estimates "
                      "the rest from their evolution line and star rating; shared gives recolours of one creature "
                      "(data/monster_variants.json) one body size and overrides the rest.")
    data["role_scale"] = {k: v for k, v in scale.items() if k != "enemy"}
    data["sizes"] = sizes
    G.fill(data)
    open(DATA, "w", encoding="utf-8").write(json.dumps(data, indent="\t"))
    print("%d monsters measured (%d seen) -> %s" % (len(sizes), len(by), DATA))


def main(args):
    if "--summary" in args:
        summary()
        return
    force = "--force" in args
    opts = {"--every": 2, "--jobs": max(1, (os.cpu_count() or 2) - 2)}
    targets, i = [], 0
    while i < len(args):
        if args[i] in opts:
            opts[args[i]] = int(args[i + 1])
            i += 1
        elif not args[i].startswith("--"):
            targets.append(args[i])
        i += 1
    dirs = []
    for t in targets or S.DEFAULT_DIRS:
        p = os.path.join(S.VIDEOS, t)
        if os.path.exists(os.path.join(p, "ocr.tsv")):
            dirs.append((os.path.basename(os.path.dirname(p)), p))
        elif os.path.isdir(p):
            dirs += [(t, os.path.join(p, v)) for v in sorted(os.listdir(p)) if os.path.exists(os.path.join(p, v, "ocr.tsv"))]
    os.makedirs(OUT, exist_ok=True)
    jobs = [(coll, d, opts["--every"], force) for coll, d in dirs]
    with Pool(opts["--jobs"], initializer=S.load_refs) as pool:
        for msg in pool.imap_unordered(scan_video, jobs):
            if msg:
                print(msg, flush=True)
    summary()


if __name__ == "__main__":
    main(sys.argv[1:])
