# Finds special-island battles in OCR'd footage (research/videos/frames_hd or frames_new/<id>/ocr.tsv) and identifies the enemies of
# each wave with the detector from scan_stage_enemies.py. A battle is a run of "Stage x/y" frames; its field is the last
# special-island field name (data/special_islands.json, fuzzy-matched) seen on screen within 150 s before it starts.
# Writes research/videos/special_scan/<id>.json and prints one line per battle.
# Usage: python tools/scan_special_battles.py [--jobs N] <video id> ...
import difflib, json, os, re, sys
from collections import defaultdict
from multiprocessing import Pool

import cv2

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scan_stage_enemies as sse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ACCEPT_Z = 4.5
VIDEOS = os.path.join(ROOT, "research", "videos")


def frame_dir(vid):
    return next((d for d in (os.path.join(VIDEOS, c, vid) for c in ("frames_hd", "frames_new", "frames_skipped")) if os.path.isdir(d)), os.path.join(VIDEOS, "frames_hd", vid))
OUT = os.path.join(ROOT, "research", "videos", "special_scan")
LOOKBACK = 150
PER_WAVE = 5


def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower().replace("★", "").replace("*", ""))


def field_names():
    data = json.load(open(os.path.join(ROOT, "data", "special_islands.json"), encoding="utf-8"))
    out = {}
    for isl in data if isinstance(data, list) else data["islands"]:
        for q in isl["quests"]:
            for key in (norm(q["name"]), norm(re.sub(r"\(.*?\)", "", q["name"]))):
                if len(key) >= 5:
                    out.setdefault(key, (isl["id"], q["name"]))
    return out


def find_field(text, fields):
    best = None
    pieces = [p.strip() for p in text.split("|")]
    for raw in pieces + [a + " " + b for a, b in zip(pieces, pieces[1:])]:
        diff = re.search(r"\((EASY|NORMAL|HARD|HELL|EXTREME|VERY HARD)\)", raw, re.I)
        n = norm(re.sub(r"\(.*?\)", "", raw))
        if len(n) < 5:
            continue
        m = difflib.get_close_matches(norm(raw), fields.keys(), n=1, cutoff=0.88) or difflib.get_close_matches(n, fields.keys(), n=1, cutoff=0.82)
        if m:
            best = (fields[m[0]], diff.group(1).lower() if diff else "")
    return best


def battles_of(vid, fields):
    rows = []
    for line in open(os.path.join(frame_dir(vid), "ocr.tsv"), encoding="utf-8-sig"):
        f, _, text = line.rstrip("\n").partition("\t")
        rows.append((int(re.sub(r"\D", "", f) or 0), f, text))
    battles, cur, last_t, seen = [], None, -999, []
    for t, f, text in rows:
        hit = find_field(text, fields)
        if hit:
            seen.append((t, hit))
        w = sse.WAVE.search(text)
        if not w:
            continue
        x, y = int(w.group(1)), int(w.group(2).upper().replace("S", "5"))
        if x < 1 or y < 1 or y > 9 or x > y:
            continue
        if cur is None or t - last_t > 60 or (x == 1 and cur["wave"] > 1):
            prev_end = battles[-1]["end_t"] if battles else -999
            near = [h for s, h in seen if t - LOOKBACK <= s <= t and s >= prev_end]
            cur = {"start": f, "start_t": t, "field": near[-1] if near else None, "wave": x, "waves": defaultdict(int), "frames": defaultdict(list)}
            battles.append(cur)
        cur["wave"] = max(cur["wave"], x)
        cur["waves"][y] += 1
        cur["frames"][x].append(f)
        cur["end_t"] = t
        last_t = t
    return battles


def detect(job):
    vid, b = job
    per_wave = {}
    for wave, frames in sorted(b["frames"].items()):
        step = max(1, len(frames) // PER_WAVE)
        best = {}
        for f in frames[::step][:PER_WAVE]:
            img = cv2.imread(os.path.join(frame_dir(vid), f))
            if img is None:
                continue
            for el, win, unit in sse.enemies_in(img):
                top = sse.identify(el, win, unit)
                if top and top[0][0] >= ACCEPT_Z:
                    z, _s, mid = top[0]
                    if z > best.get(mid, (0, ""))[0]:
                        best[mid] = (round(z, 2), f)
        per_wave[wave] = best
    return per_wave


def main(args):
    jobs = 6
    if "--jobs" in args:
        k = args.index("--jobs")
        jobs = int(args[k + 1])
        args = args[:k] + args[k + 2:]
    fields = field_names()
    os.makedirs(OUT, exist_ok=True)
    for vid in [a for a in args if a != "--"]:
        battles = battles_of(vid, fields)
        with Pool(jobs, initializer=sse.load_refs) as pool:
            found = pool.map(detect, [(vid, b) for b in battles])
        out = []
        for b, per_wave in zip(battles, found):
            waves = max(b["waves"], key=b["waves"].get)
            field = b["field"]
            row = {"start": b["start"], "end_t": b["end_t"], "island": field[0][0] if field else "", "field": field[0][1] if field else "",
                   "difficulty": field[1] if field else "", "waves_shown": waves, "reached": b["wave"],
                   "enemies": {str(w): {m: v for m, v in sorted(e.items(), key=lambda kv: -kv[1][0])} for w, e in per_wave.items()}}
            out.append(row)
            ens = "  ".join("w%s:%s" % (w, ",".join(e.keys())) for w, e in row["enemies"].items())
            print("%s %s %-28s %-6s %d/%d  %s" % (vid, b["start"][:-4], (row["field"] or "?")[:28], row["difficulty"], row["reached"], waves, ens), flush=True)
        json.dump({"video": vid, "battles": out}, open(os.path.join(OUT, vid + ".json"), "w", encoding="utf-8"), indent=1)


if __name__ == "__main__":
    main(sys.argv[1:])
