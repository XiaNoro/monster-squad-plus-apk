import argparse
import os
import re
import sys
import time

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import reveal_titles as rt
import scrape_evo_idle as evo
import video_inventory as vi
from idle_namer import Namer

OUT = "research/videos/idle_loops"
MIN_H = 720
CATCH = re.compile(r"Next Field|Leave", re.I)
FIELDS = ["clip", "kind", "id", "name", "match", "runner_up", "runner_up_match", "video", "height", "start_s", "length_s", "fps", "loop_frames", "loop_score", "loop_found", "saved_frames", "folder"]


def slot_box(hit, n_slots, shape):
    _, _, s, _, (x0, y0, x1, y1) = hit
    u = 72.0 * s
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    h, w = shape[:2]
    if n_slots == 1 and u / h > 0.105:
        box = (cx - 3.4 * u, cy - 0.6 * u, cx + 3.4 * u, cy + 4.1 * u)
    else:
        box = (cx - 2.45 * u, cy + 0.35 * u, cx + 2.45 * u, cy + 3.75 * u)
    return tuple(int(v) for v in (max(0, box[0]), max(0, box[1]), min(w, box[2]), min(h, box[3])))


def scan_reveal(cap, fps, win, tmpls, known):
    cap.set(cv2.CAP_PROP_POS_MSEC, win[0] * 1000.0)
    idx, last = int(win[0] * fps), int(win[1] * fps)
    slots, runs, cur = [], [], {}
    next_search = idx
    while idx <= last:
        ok, frame = cap.read()
        if not ok:
            break
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        alive = []
        for sl in slots:
            v, _ = rt.score_at(gray, tmpls[sl["hit"][1]], sl["hit"][2], sl["hit"][3])
            sl["miss"] = 0 if v >= rt.TH - 0.1 else sl["miss"] + 1
            alive.append(sl["miss"] < 8)
        if (not any(alive) or idx >= next_search) and idx >= next_search - int(fps * 1.5):
            next_search = idx + int(fps * 2)
            hits = rt.find(gray, tmpls, rt.near(known, gray.shape[0]) if known else rt.scales_for(gray.shape[0]))
            if not hits and known:
                hits = rt.find(gray, tmpls, rt.scales_for(gray.shape[0]))
            for h in hits:
                if not any(abs(h[2] - k) / k < 0.05 for k in known):
                    known.append(h[2])
            new_keys = {(round((h[4][0] + h[4][2]) / 20), round(h[4][1] / 10)) for h in hits}
            for key in list(cur):
                if key not in new_keys:
                    runs.append(cur.pop(key))
            hits.sort(key=lambda h: (round(h[4][1] / (72.0 * h[2])), h[4][0]))
            old = {sl["key"]: sl for sl in slots}
            slots = []
            for h in hits:
                key = (round((h[4][0] + h[4][2]) / 20), round(h[4][1] / 10))
                slots.append(old[key] if key in old else {"hit": h, "key": key, "box": slot_box(h, len(hits), frame.shape), "n": len(hits), "miss": 0, "slot": len(slots)})
            alive = [True] * len(slots)
        for sl, ok_ in zip(slots, alive):
            key = sl["key"]
            if not ok_:
                if key in cur:
                    runs.append(cur.pop(key))
                continue
            if sl["miss"]:
                continue
            x0, y0, x1, y1 = sl["box"]
            crop = frame[y0:y1, x0:x1].copy()
            run = cur.get(key)
            if run and (run["crops"][-1].shape != crop.shape or evo._diff(run["crops"][-1], crop) > evo.SPLIT):
                runs.append(cur.pop(key))
                run = None
            if run is None:
                run = cur[key] = {"t0": idx / fps, "crops": [], "n": sl["n"], "rarity": sl["hit"][1], "slot": sl["slot"]}
            run["crops"].append(crop)
        slots = [sl for sl, ok_ in zip(slots, alive) if ok_]
        idx += 1
    runs.extend(cur.values())
    return runs


def ocr_text(v, k):
    out = {}
    p = os.path.join(v["frames"], "ocr.tsv") if v["frames"] else ""
    if p and os.path.exists(p):
        for line in open(p, encoding="utf-8-sig", errors="ignore"):
            name, _, text = line.partition("\t")
            stem = os.path.splitext(name)[0]
            if stem.isdigit():
                out[int(stem) * k] = text
    return out


def final_path(v, wait):
    if v["dup"] or not v["yid"]:
        return v["path"]
    start = time.time()
    while True:
        row = vi.manifest().get(v["old"])
        if row:
            if row["status"] == "done" and os.path.exists(row["new"]):
                return row["new"]
            old = os.path.join(vi.ROOT, v["old"])
            return old if os.path.exists(old) else ""
        if time.time() - start > wait:
            return v["path"] if os.path.exists(v["path"]) else ""
        time.sleep(30)


def append(row):
    path = os.path.join(OUT, "index.tsv")
    new = not os.path.exists(path)
    with open(path, "a", encoding="utf8") as f:
        if new:
            f.write("\t".join(FIELDS) + "\n")
        f.write("\t".join(str(row.get(k, "")) for k in FIELDS) + "\n")


def reveal_area(img):
    h, w = img.shape[:2]
    return img[int(h * 0.3):int(h * 0.92), int(w * 0.25):int(w * 0.75)]


def name_clip(namer, kind, frames):
    if kind == "evo":
        return namer.name(frames)
    if kind in ("reveal", "pet"):
        return namer.name_any([reveal_area(f) for f in frames], min_inliers=8)
    return namer.name_any(frames)


def keep(run_crops, t0, fps, kind, vid, height, namer, name_frames, rows, slot=None):
    period, ratio = evo.find_loop(run_crops, fps)
    looped = ratio < 0.6
    mid, score, nxt, second = name_clip(namer, kind, name_frames)
    if kind == "reveal" and mid.startswith("pet_"):
        kind = "pet"
    clip = "%s_%s_%04d_%02d" % (kind, vid, int(t0), int((t0 % 1) * 100)) + ("_s%d" % (slot + 1) if slot is not None else "")
    rel = os.path.join("" if looped else "no_loop", mid or "unknown", clip)
    n = evo.save([(0, c) for c in run_crops], fps, period if looped else None, os.path.join(OUT, rel))
    row = {"clip": clip, "kind": kind, "id": mid, "name": namer.names.get(mid, ""), "match": score, "runner_up": nxt, "runner_up_match": second, "video": vid, "height": height,
           "start_s": "%.2f" % t0, "length_s": "%.2f" % (len(run_crops) / fps), "fps": "%.2f" % fps, "loop_frames": period or "", "loop_score": "%.2f" % ratio,
           "loop_found": "yes" if looped else "no", "saved_frames": n, "folder": rel.replace(os.sep, "/")}
    append(row)
    rows.append(row)
    print("    %-7s %s -> %s (%d)%s" % (kind, clip, mid or "unknown", score, "" if looped else " [no loop]"), flush=True)


def main():
    global OUT
    ap = argparse.ArgumentParser()
    ap.add_argument("--wait", type=float, default=3 * 3600)
    ap.add_argument("--fresh", action="store_true")
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default=OUT)
    args = ap.parse_args()
    OUT = args.out
    if args.fresh and os.path.isdir(OUT):
        import shutil
        shutil.rmtree(OUT)
    os.makedirs(OUT, exist_ok=True)
    done_path = os.path.join(OUT, "done.txt")
    done = set(open(done_path, encoding="utf8").read().split("\n")) if os.path.exists(done_path) else set()
    print("building monster index...", flush=True)
    namer = Namer()
    title = evo.load_title(vi.ROOT)
    tmpls = rt.load()
    plan = []
    for v in vi.videos():
        if v["old"] in done or v["dup"] or (args.only and v["yid"] not in args.only.split(",")):
            continue
        vi.attach_seeds(v)
        if v["evo"] or v["reveal"]:
            plan.append(v)
    plan.sort(key=lambda v: (-(len(v["evo"]) + len(v["reveal"])), v["old"]))
    print("videos with seeds:", len(plan), flush=True)
    rows = []
    for v in plan:
        path = final_path(v, args.wait)
        if not path:
            continue
        w, h, fps, dur = vi.probe(path)
        vid = v["yid"] or v["base"]
        if h < MIN_H - 20:
            print("skip %s (%dp)" % (v["old"], h), flush=True)
        else:
            print("%s (%dp)" % (v["old"], h), flush=True)
            cap = cv2.VideoCapture(path)
            for win in evo.windows(v["evo"], 3.0):
                for run in evo.scan(cap, fps, win, title):
                    if len(run) < fps:
                        continue
                    crops = [c for _, c in run]
                    keep(crops, run[0][0], fps, "evo", vid, h, namer, [evo._name_area(crops[0]), evo._name_area(crops[len(crops) // 2])], rows)
            k = vi._seconds_per_name(v["frames"], dur) if v["frames"] else 2.0
            texts = ocr_text(v, k)
            known = []
            for win in evo.windows(v["reveal"], 3.0):
                near = " ".join(t for s, t in texts.items() if win[0] - 2 <= s <= win[1] + 2)
                for run in scan_reveal(cap, fps, win, tmpls, known):
                    if len(run["crops"]) < fps:
                        continue
                    kind = "catch" if CATCH.search(near) else ("grid" if run["n"] > 1 else "reveal")
                    crops = run["crops"]
                    keep(crops, run["t0"], fps, kind, vid, h, namer, [crops[len(crops) // 3], crops[2 * len(crops) // 3]], rows, run["slot"] if run["n"] > 1 else None)
            cap.release()
        with open(done_path, "a", encoding="utf8") as f:
            f.write(v["old"] + "\n")
    import csv
    all_rows = list(csv.DictReader(open(os.path.join(OUT, "index.tsv"), encoding="utf8"), delimiter="\t")) if os.path.exists(os.path.join(OUT, "index.tsv")) else []
    loops = sorted((r for r in all_rows if r["loop_found"] == "yes"), key=lambda r: (r["id"] == "", r["name"], r["kind"], r["clip"]))
    evo.sheet([(r["folder"], "%s %s" % (r["kind"], r["name"] or "?")) for r in loops], OUT)
    print("finished. clips:", len(all_rows), "loops:", len(loops), "monsters with a loop:", len({r["id"] for r in loops if r["id"]}), flush=True)


if __name__ == "__main__":
    main()
