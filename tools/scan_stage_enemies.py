# Reads quest footage (research/videos/<frames dir>/<video>/*.jpg + ocr.tsv) and records, per battle, which story stage
# it is (field name on the Select Friend / boss intro screens), the difficulty (highlighted tab on the stage list),
# the boss named on the boss intro, the wave count ("Stage x/y") and every enemy detection. Enemies are found by their
# HP bar (right half, element orb on its left, no "Lv." label above), then matched against assets/monsters_cut of that
# element with masked template matching. Scores are z-scores against each monster's typical score on random enemy
# windows (--calibrate builds that table first), so art that resembles everything does not win by default.
# One result per video goes to research/videos/stage_scan/, with the best window per monster per battle in crops/.
# Cached videos keep their detections; the OCR-derived fields (stage, difficulty, boss, waves) are refreshed each run.
# Usage: python tools/scan_stage_enemies.py --calibrate
#        python tools/scan_stage_enemies.py [--force] [--every N] [--jobs N] [frames dir or frames dir/video ...]
import difflib, json, os, random, re, sys
from collections import Counter
from multiprocessing import Pool
import cv2
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VIDEOS = os.path.join(ROOT, "research", "videos")
OUT = os.path.join(VIDEOS, "stage_scan")
CALIB = os.path.join(OUT, "calib.json")
FIELDS = {"sprout": "sprout_island", "lake": "lake_island", "desert": "desert_isle", "moonlight": "moonlight_desert",
          "boneyard": "boneyard_island", "bone": "boneyard_island", "dino": "dino_gorge", "robo": "robo_island", "sky": "sky_island"}
FIELD = re.compile(r"\b(Sprout|Lake|Desert|Moonlight|Boneyard|Bone|Dino|Robo|Sky)\s{0,2}[-~—]\s{0,2}([\dI](?:\s?[\dIO])?)(?![\w])", re.I)
LEVEL_TAG = re.compile(r"^\W*L[vV][\W_]", re.I)
WAVE = re.compile(r"Stage\s*([1-9])\s*(?:/\s*|[1lI])([1-9S])\b", re.I)
LIST_WORDS = re.compile(r"\b(Rank|Monster|No Record)\b", re.I)
DEFAULT_DIRS = ["frames", "frames_hd"]
BW = 40
SCALES = (0.9, 1.08, 1.3, 1.55, 1.85, 2.2)
COARSE = 16
COARSE_SCALES = (0.95, 1.25, 1.6, 2.05)
SHORTLIST = 12
KEEP_Z = 1.5
FIELD_FRESH = 75

monsters = json.load(open(os.path.join(ROOT, "data", "monsters.json"), encoding="utf-8"))
names = {}
for _mid, _m in monsters.items():
    names.setdefault(re.sub(r"[^a-z0-9]", "", _m.get("name", _mid).lower()), _mid)
refs = {}
calib = {}


def load_refs():
    cv2.setNumThreads(1)
    d = os.path.join(ROOT, "assets", "monsters_cut")
    for f in sorted(os.listdir(d)):
        mid = f[:-4]
        if not f.endswith(".png") or mid not in monsters:
            continue
        im = cv2.imread(os.path.join(d, f), cv2.IMREAD_UNCHANGED)
        if im is None or im.ndim < 3 or im.shape[2] < 4:
            continue
        ys, xs = np.where(im[:, :, 3] > 128)
        if len(ys) == 0:
            continue
        im = im[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        refs.setdefault(monsters[mid].get("element", ""), []).append((mid, templates(im, COARSE, COARSE_SCALES), templates(im, BW, SCALES)))
    if os.path.exists(CALIB):
        calib.update(json.load(open(CALIB, encoding="utf-8")))


def templates(im, bw, scales):
    out = []
    for k in scales:
        th = int(bw * k)
        tw = max(4, int(im.shape[1] * th / im.shape[0]))
        r = cv2.resize(im, (tw, th), interpolation=cv2.INTER_AREA)
        for flip in (False, True):
            rr = cv2.flip(r, 1) if flip else r
            m = (rr[:, :, 3] > 128).astype(np.uint8)
            if m.sum() < 12:
                continue
            out.append((cv2.cvtColor(rr[:, :, :3], cv2.COLOR_BGR2LAB), cv2.merge([m, m, m])))
    return out


def game_rect(img):
    g = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY).astype(np.float32)
    rows = np.where(g.std(axis=1) > 12)[0]
    cols = np.where(g.std(axis=0) > 12)[0]
    if len(rows) == 0 or len(cols) == 0:
        return 0, 0, img.shape[1], img.shape[0]
    return int(cols[0]), int(rows[0]), int(cols[-1]) + 1, int(rows[-1]) + 1


def element_of(hsv, x, y, h):
    reg = hsv[max(0, y - h):y + 2 * h, max(0, x - 3 * h):max(0, x - 1)]
    if reg.size == 0:
        return ""
    px = reg.reshape(-1, 3)
    sat = px[(px[:, 1] > 110) & (px[:, 2] > 110)]
    if len(sat) < 0.15 * len(px):
        return ""
    hue = sat[:, 0]
    votes = {"fire": int(((hue < 14) | (hue > 168)).sum()), "water": int(((hue >= 92) & (hue < 128)).sum()),
             "nature": int(((hue >= 35) & (hue < 85)).sum()), "normal": int(((hue >= 128) & (hue <= 168)).sum())}
    best = max(votes, key=votes.get)
    return best if votes[best] > 0.35 * len(sat) else ""


def bars(img, left=0.3):
    x0, y0, x1, y1 = game_rect(img)
    W, H = x1 - x0, y1 - y0
    unit = W * 0.076
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    green = cv2.inRange(hsv, (35, 120, 120), (80, 255, 255))
    green[:, :x0 + int(W * left)] = 0
    green[:y0 + int(H * 0.05)] = 0
    green[y0 + int(H * 0.85):] = 0
    n, lab, st, _ = cv2.connectedComponentsWithStats(green)
    thick = max(3, int(W * 0.012))
    out = []
    for i in range(1, n):
        x, y, w, h, _a = st[i]
        if w < W * 0.015:
            continue
        m = lab[y:y + h, x:x + w] == i
        ok = (m.sum(axis=0) > 0) & (m.sum(axis=0) <= thick)
        best, run, start = (0, 0), 0, 0
        for c, v in enumerate(ok):
            run = run + 1 if v else 0
            if run == 1:
                start = c
            if run > best[1] - best[0]:
                best = (start, start + run)
        bw = best[1] - best[0]
        if bw < W * 0.015:
            continue
        rows = np.where(m[:, best[0]:best[1]].any(axis=1))[0]
        bx, by, bh = x + best[0], y + int(rows[0]), int(rows[-1] - rows[0] + 1)
        if bw <= 2 * bh or bh < W * 0.0055 or bh > W * 0.012 or bw > 1.7 * unit:
            continue
        mid_rows = hsv[by + bh // 4:by + bh - bh // 4].astype(np.int16)
        lost = (mid_rows[:, :, 2] < 120) | ((mid_rows[:, :, 1] > 100) & ((mid_rows[:, :, 0] < 30) | (mid_rows[:, :, 0] > 125)))
        if bw < 0.9 * unit:
            track = lost[:, bx + bw + 2:int(bx + 0.95 * unit)]
            if track.size and track.mean() < 0.6:
                continue
        dark = lost[:, bx + bw:int(bx + 1.75 * unit)].mean(axis=0) > 0.6
        run = len(dark) if dark.all() else int(np.argmin(dark))
        span = (bw + run) / unit
        el = element_of(hsv, bx, by, bh)
        if not el:
            continue
        above = hsv[max(0, int(by - 2.2 * bh)):max(0, by - 1), bx:int(bx + unit)].reshape(-1, 3)
        player = len(above) > 0 and ((above[:, 1] < 60) & (above[:, 2] > 215)).mean() > 0.04 and (above[:, 2] < 70).mean() > 0.04
        out.append({"x": bx, "y": by, "h": bh, "w": bw, "el": el, "player": player or bx < x0 + W * 0.5,
                    "long": bw > 1.15 * unit or (bw < 0.9 * unit and 1.35 < span < 1.72)})
    return (x0, y0, x1, y1), unit, out


def enemies_in(img):
    (x0, y0, x1, y1), unit, found = bars(img)
    W = x1 - x0
    out = []
    for b in found:
        if b["player"]:
            continue
        wx0, wx1 = int(max(x0 + W * 0.45, b["x"] - unit)), int(min(x1, b["x"] + 2.0 * unit))
        bottom = b["y"] + 2.7 * unit
        for o in found:
            if o is not b and o["y"] > b["y"] + 0.6 * unit and abs(o["x"] - b["x"]) < 1.2 * unit:
                bottom = min(bottom, o["y"] + o["h"])
        wy0, wy1 = int(b["y"] + b["h"] / 2), int(min(y1, bottom))
        if wx1 - wx0 < unit or wy1 - wy0 < unit:
            continue
        out.append((b["el"], img[wy0:wy1, wx0:wx1], unit))
    return out


def best_score(lab, sizes):
    best = -1.0
    for t, m in sizes:
        if t.shape[0] > lab.shape[0] or t.shape[1] > lab.shape[1]:
            continue
        r = cv2.matchTemplate(lab, t, cv2.TM_CCOEFF_NORMED, mask=m)
        r[~np.isfinite(r)] = -1
        best = max(best, float(r.max()))
    return best


def scaled(win, unit, bw):
    s = bw / unit
    win = cv2.resize(win, (max(8, int(win.shape[1] * s)), max(8, int(win.shape[0] * s))), interpolation=cv2.INTER_AREA)
    return cv2.cvtColor(win, cv2.COLOR_BGR2LAB)


def z(mid, s, k):
    c = calib.get(mid)
    if not c:
        return (s - 0.45) / 0.06
    return (s - c[k]) / max(c[k + 1], 0.02)


def identify(el, win, unit):
    coarse = scaled(win, unit, COARSE)
    pool = sorted(((z(mid, best_score(coarse, c), 0), mid, f) for mid, c, f in refs.get(el, [])), key=lambda r: -r[0])[:SHORTLIST]
    fine = scaled(win, unit, BW)
    scores = []
    for _z, mid, f in pool:
        s = best_score(fine, f)
        scores.append((z(mid, s, 2), s, mid))
    scores.sort(reverse=True)
    return scores[:2]


def boss_name(pieces, at):
    for p in pieces[at:at + 7]:
        key = re.sub(r"[^a-z0-9]", "", p.lower())
        if len(key) < 3 or LEVEL_TAG.match(p) or key in FIELDS:
            continue
        hit = difflib.get_close_matches(key, names.keys(), n=1, cutoff=0.85)
        if hit:
            return names[hit[0]]
    return ""


def difficulty(img):
    x0, y0, x1, y1 = game_rect(img)
    W, H = x1 - x0, y1 - y0
    band = img[y0 + int(H * 0.12):y0 + int(H * 0.26), x0 + int(W * 0.38):x0 + int(W * 0.9)]
    hsv = cv2.cvtColor(band, cv2.COLOR_BGR2HSV)
    gold = cv2.inRange(hsv, (14, 140, 190), (34, 255, 255))
    if gold.sum() / 255 < band.shape[0] * band.shape[1] * 0.06:
        return ""
    cx = (np.where(gold)[1].mean() + W * 0.38) / W
    return "normal" if cx < 0.555 else ("hard" if cx < 0.71 else "hell")


def read_ocr(d):
    rows = []
    for line in open(os.path.join(d, "ocr.tsv"), encoding="utf-8-sig"):
        parts = line.rstrip("\n").split("\t", 1)
        if len(parts) == 2 and parts[0][:1].isdigit():
            rows.append((parts[0], parts[1]))
    rows.sort(key=lambda r: int(re.sub(r"\D", "", r[0]) or 0))
    return rows


def battles_of(d):
    battles, cur, field, diff = [], None, None, ""
    last_t, field_t = -999, -999
    for f, text in read_ocr(d):
        t = int(re.sub(r"\D", "", f) or 0)
        w = WAVE.search(text)
        fields = list(FIELD.finditer(text))
        if "Normal" in text and ("Hard" in text or LIST_WORDS.search(text)) and not w:
            got = difficulty(cv2.imread(os.path.join(d, f)))
            if got:
                diff = got
        if len(fields) == 1 and not LIST_WORDS.search(text):
            field, field_t = fields[0], t
            pieces = [p.strip() for p in text.split("|")]
            at = next((k for k, p in enumerate(pieces) if FIELD.search(p)), 0)
            boss = boss_name(pieces, at + 1) if not w and not re.search(r"Obtained|by Evolving|from Cube|by Fusion", text, re.I) else ""
            if boss and cur is not None and t - last_t < 40:
                cur["boss_intro"] = boss
                cur["field_m"] = field
        if re.search(r"Quest Success|Failed", text, re.I):
            if cur:
                cur["result"] = "win" if re.search("Success", text, re.I) else "lose"
                battles.append(cur)
                cur = None
            field_t = -999
            continue
        if not w:
            continue
        x, y = int(w.group(1)), int(w.group(2).upper().replace("S", "5"))
        if x < 1 or y < 1 or y > 9 or x > y:
            continue
        if cur is None or (x < cur["wave"] and x == 1) or t - last_t > 90:
            if cur:
                battles.append(cur)
            cur = {"field_m": field if t - field_t <= FIELD_FRESH else None, "difficulty": diff or "?", "start": f, "waves": y, "wave": x, "frames": {}, "boss_intro": "", "result": "?", "ys": Counter()}
        cur["wave"] = max(cur["wave"], x)
        cur["ys"][y] += 1
        cur["waves"] = cur["ys"].most_common(1)[0][0]
        cur["end"] = f
        cur["frames"].setdefault(x, []).append(f)
        last_t = t
    if cur:
        battles.append(cur)
    out = []
    for b in battles:
        fm = b.pop("field_m")
        b.pop("ys")
        if fm is None:
            continue
        b["island"] = FIELDS[fm.group(1).lower()]
        b["stage"] = int(re.sub(r"\s", "", fm.group(2)).upper().replace("I", "1").replace("O", "0"))
        out.append(b)
    return out


def scan_video(job):
    coll, d, every, force = job
    vid = os.path.basename(d)
    dest = os.path.join(OUT, "%s__%s.json" % (coll, vid))
    battles = battles_of(d)
    if os.path.exists(dest) and not force:
        old = {b["start"]: b for b in json.load(open(dest, encoding="utf-8"))["battles"]}
        if not {b["start"] for b in battles} <= set(old):
            return "%s/%s: battles changed, rerun with --force" % (coll, vid)
        for b in battles:
            b.pop("frames")
            b["hits"], b["crops"] = old[b["start"]]["hits"], old[b["start"]]["crops"]
        json.dump({"video": vid, "frames": coll, "battles": battles}, open(dest, "w", encoding="utf-8"), indent=1)
        return None
    crops = os.path.join(OUT, "crops")
    for b in battles:
        hits, best = [], {}
        for wave, frames in sorted(b.pop("frames").items()):
            step = max(1, len(frames) // every)
            for f in frames[::step][:every]:
                img = cv2.imread(os.path.join(d, f))
                if img is None:
                    continue
                for el, win, unit in enemies_in(img):
                    top = identify(el, win, unit)
                    if not top or top[0][0] < KEEP_Z:
                        continue
                    (z1, s1, m1), second = top[0], (top[1] if len(top) > 1 else (0.0, 0.0, ""))
                    hits.append([wave, f, el, m1, round(s1, 3), round(z1, 2), second[2], round(second[0], 2)])
                    if z1 > best.get(m1, (-99, None))[0]:
                        best[m1] = (z1, win)
        b["hits"] = hits
        b["crops"] = {}
        for mid, (_z, win) in best.items():
            name = "%s__%s__%s__%s.jpg" % (coll, vid, b["start"][:-4], mid)
            cv2.imwrite(os.path.join(crops, name), win)
            b["crops"][mid] = name
    json.dump({"video": vid, "frames": coll, "battles": battles}, open(dest, "w", encoding="utf-8"), indent=1)
    return "%s/%s: %d battles, %d detections" % (coll, vid, len(battles), sum(len(b["hits"]) for b in battles))


def calib_window(job):
    d, f = job
    img = cv2.imread(os.path.join(d, f))
    out = []
    if img is None:
        return out
    for el, win, unit in enemies_in(img):
        coarse, fine = scaled(win, unit, COARSE), scaled(win, unit, BW)
        out.append({mid: (best_score(coarse, c), best_score(fine, fi)) for mid, c, fi in refs.get(el, [])})
    return out


def calibrate(dirs, jobs):
    picks = []
    rng = random.Random(7)
    for _coll, d in dirs:
        frames = [f for f, text in read_ocr(d) if WAVE.search(text)]
        picks += [(d, f) for f in rng.sample(frames, min(6, len(frames)))]
    rng.shuffle(picks)
    picks = picks[:420]
    seen = {}
    with Pool(jobs, initializer=load_refs) as pool:
        for windows in pool.imap_unordered(calib_window, picks):
            for scores in windows:
                for mid, cf in scores.items():
                    seen.setdefault(mid, []).append(cf)
    table = {}
    for mid, v in seen.items():
        a = np.array(v)
        table[mid] = [round(float(a[:, 0].mean()), 4), round(float(a[:, 0].std()), 4), round(float(a[:, 1].mean()), 4), round(float(a[:, 1].std()), 4)]
    json.dump(table, open(CALIB, "w", encoding="utf-8"), indent=0)
    print("calibrated %d monsters on %d frames" % (len(table), len(picks)))


def main(args):
    force = "--force" in args
    opts = {"--every": 3, "--jobs": max(1, (os.cpu_count() or 2) - 2)}
    targets = []
    i = 0
    while i < len(args):
        if args[i] in opts:
            opts[args[i]] = int(args[i + 1])
            i += 1
        elif not args[i].startswith("--"):
            targets.append(args[i])
        i += 1
    dirs = []
    for t in targets or DEFAULT_DIRS:
        p = os.path.join(VIDEOS, t)
        if os.path.exists(os.path.join(p, "ocr.tsv")):
            dirs.append((os.path.basename(os.path.dirname(p)), p))
        elif os.path.isdir(p):
            dirs += [(t, os.path.join(p, v)) for v in sorted(os.listdir(p)) if os.path.exists(os.path.join(p, v, "ocr.tsv"))]
    os.makedirs(os.path.join(OUT, "crops"), exist_ok=True)
    if "--calibrate" in args:
        calibrate(dirs, opts["--jobs"])
        return
    jobs = [(coll, d, opts["--every"], force) for coll, d in dirs]
    with Pool(opts["--jobs"], initializer=load_refs) as pool:
        for msg in pool.imap_unordered(scan_video, jobs):
            if msg:
                print(msg, flush=True)


if __name__ == "__main__":
    main(sys.argv[1:])
