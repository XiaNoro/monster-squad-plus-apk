import argparse
import glob
import os
import shutil
import sys

import cv2

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from idle_namer import Namer
import numpy as np
from PIL import Image

REF_FRAME = "frames_hd/gDadMfmvPRg/0138.jpg"
TITLE = (255, 158, 955, 238)
BOX = (1195, 420, 1775, 945)
NAME_BOX = (1265, 515, 1692, 915)
SCALES = np.arange(0.22, 1.16, 0.02)
FOUND = 0.72
KEEP = 0.62
SPLIT = 22.0
DIM = 0.5


def load_title(root):
    ref = cv2.imread(os.path.join(root, REF_FRAME))
    x0, y0, x1, y1 = TITLE
    return cv2.cvtColor(ref[y0:y1, x0:x1], cv2.COLOR_BGR2GRAY)


def seeds(root, vid):
    path = os.path.join(root, "frames_hd", vid, "ocr.tsv")
    out = []
    for line in open(path, encoding="utf-8-sig", errors="ignore"):
        name, _, text = line.partition("\t")
        if "Evolution Tre" in text or "Evolution Tr" in text:
            out.append(int(os.path.splitext(name)[0]))
    return sorted(out)


def windows(times, pad):
    out = []
    for t in times:
        if out and t - pad <= out[-1][1]:
            out[-1][1] = t + pad
        else:
            out.append([max(0.0, t - pad), t + pad])
    return out


def find_popup(gray, title):
    best = (0.0, None, None)
    h, w = gray.shape
    for s in SCALES:
        tw, th = int(title.shape[1] * s), int(title.shape[0] * s)
        if tw < 40 or tw >= w or th >= h:
            continue
        t = cv2.resize(title, (tw, th), interpolation=cv2.INTER_AREA)
        r = cv2.matchTemplate(gray, t, cv2.TM_CCOEFF_NORMED)
        _, v, _, loc = cv2.minMaxLoc(r)
        if v > best[0]:
            best = (v, s, loc)
    return best


def still_open(gray, tmpl, loc):
    x, y = loc
    m = 6
    th, tw = tmpl.shape
    x0, y0 = max(0, x - m), max(0, y - m)
    roi = gray[y0:y + th + m, x0:x + tw + m]
    if roi.shape[0] < th or roi.shape[1] < tw:
        return 0.0
    if float(gray[y:y + th, x:x + tw].mean()) < float(tmpl.mean()) * DIM:
        return 0.0
    return float(cv2.matchTemplate(roi, tmpl, cv2.TM_CCOEFF_NORMED).max())


def box_for(s, loc, shape):
    x, y = loc
    bx0 = x + (BOX[0] - TITLE[0]) * s
    by0 = y + (BOX[1] - TITLE[1]) * s
    bx1 = x + (BOX[2] - TITLE[0]) * s
    by1 = y + (BOX[3] - TITLE[1]) * s
    h, w = shape[:2]
    return int(max(0, bx0)), int(max(0, by0)), int(min(w, bx1)), int(min(h, by1))


def scan(cap, fps, win, title):
    cap.set(cv2.CAP_PROP_POS_MSEC, win[0] * 1000.0)
    last = int(win[1] * fps)
    idx = int(win[0] * fps)
    tmpl = loc = box = None
    runs, cur = [], []
    next_search = idx
    while idx <= last:
        ok, frame = cap.read()
        if not ok:
            break
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        score = 0.0
        if tmpl is not None:
            score = still_open(gray, tmpl, loc)
        if score < KEEP and idx >= next_search:
            next_search = idx + int(fps / 2)
            v, s, l = find_popup(cv2.resize(gray, None, fx=0.5, fy=0.5, interpolation=cv2.INTER_AREA), cv2.resize(title, None, fx=0.5, fy=0.5, interpolation=cv2.INTER_AREA))
            if v >= FOUND - 0.05:
                l = (l[0] * 2, l[1] * 2)
                v = still_open(gray, cv2.resize(title, (int(title.shape[1] * s), int(title.shape[0] * s)), interpolation=cv2.INTER_AREA), l)
            if v >= FOUND:
                tmpl = cv2.resize(title, (int(title.shape[1] * s), int(title.shape[0] * s)), interpolation=cv2.INTER_AREA)
                loc = l
                box = box_for(s, l, frame.shape)
                score = v
        if score >= KEEP and box is not None:
            x0, y0, x1, y1 = box
            crop = frame[y0:y1, x0:x1].copy()
            if cur and (cur[-1][1].shape != crop.shape or _diff(cur[-1][1], crop) > SPLIT):
                runs.append(cur)
                cur = []
            cur.append((idx / fps, crop))
        elif cur:
            runs.append(cur)
            cur = []
        idx += 1
    if cur:
        runs.append(cur)
    return runs


def _small(img):
    return cv2.resize(img, (96, int(96 * img.shape[0] / img.shape[1])), interpolation=cv2.INTER_AREA).astype(np.float32)


def _diff(a, b):
    return float(np.abs(_small(a) - _small(b)).mean())


def find_loop(frames, fps):
    smalls = [_small(f) for f in frames]
    n = len(smalls)
    kmin = max(2, int(round(0.4 * fps)))
    kmax = min(n // 2, int(round(6.0 * fps)))
    if kmax <= kmin:
        return None, 1.0
    d = {}
    for k in range(1, kmax + 1):
        d[k] = float(np.mean([np.abs(smalls[i] - smalls[i + k]).mean() for i in range(0, n - k)]))
    cand = range(kmin, kmax + 1)
    best = min(cand, key=lambda k: d[k])
    for div in (4, 3, 2):
        k = int(round(best / div))
        if k >= kmin and d[k] <= d[best] * 1.15:
            best = k
            break
    spread = float(np.median([d[k] for k in cand])) or 1.0
    return best, d[best] / spread


def save(run, fps, period, outdir):
    os.makedirs(outdir, exist_ok=True)
    frames = [c for _, c in run]
    start = min(3, len(frames) - 1)
    loop = frames[start:start + period] if period else frames
    for i, f in enumerate(loop):
        cv2.imwrite(os.path.join(outdir, "f%03d.png" % i), f)
    pil = [Image.fromarray(cv2.cvtColor(f, cv2.COLOR_BGR2RGB)) for f in loop]
    pil[0].save(os.path.join(outdir, "loop.webp"), save_all=True, append_images=pil[1:], duration=int(1000 / fps), loop=0, lossless=False, quality=92)
    h, w = loop[0].shape[:2]
    vw = cv2.VideoWriter(os.path.join(outdir, "loop.mp4"), cv2.VideoWriter_fourcc(*"mp4v"), fps, (w, h))
    reps = max(1, int(np.ceil(4.0 * fps / max(1, len(loop)))))
    for _ in range(reps):
        for f in loop:
            vw.write(f)
    vw.release()
    return len(loop)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default="research/videos")
    ap.add_argument("--out", default="research/videos/idle_evo")
    ap.add_argument("--only", default="")
    ap.add_argument("--min-sec", type=float, default=1.0)
    args = ap.parse_args()
    root = args.root
    title = load_title(root)
    vids = [p.replace("\\", "/").split("/")[-2] for p in glob.glob(os.path.join(root, "frames_hd", "*", "ocr.tsv"))]
    if args.only:
        vids = [v for v in vids if v in args.only.split(",")]
    if os.path.isdir(args.out):
        shutil.rmtree(args.out)
    os.makedirs(args.out, exist_ok=True)
    print("building monster index...", flush=True)
    namer = Namer()
    rows = []
    for vid in sorted(vids):
        times = seeds(root, vid)
        mp4 = os.path.join(root, "video_hd", vid + ".mp4")
        if not times or not os.path.exists(mp4):
            continue
        cap = cv2.VideoCapture(mp4)
        fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
        kept = 0
        for win in windows(times, 3.0):
            for run in scan(cap, fps, win, title):
                if len(run) < args.min_sec * fps:
                    continue
                period, ratio = find_loop([c for _, c in run], fps)
                t0 = run[0][0]
                name = "%s_%04d_%02d" % (vid, int(t0), int((t0 % 1) * 100))
                looped = ratio < 0.6
                crops = [c for _, c in run]
                mid, score, nxt, second = namer.name([_name_area(crops[0]), _name_area(crops[len(crops) // 2])])
                rel = os.path.join("" if looped else "no_loop", mid or "unknown", name)
                n = save(run, fps, period if looped else None, os.path.join(args.out, rel))
                rows.append((name, mid, namer.names.get(mid, ""), str(score), nxt, str(second), vid, "%.2f" % t0, "%.2f" % (len(run) / fps), "%.2f" % fps, str(period or ""), "%.2f" % ratio, "yes" if looped else "no", str(n), rel.replace(os.sep, "/")))
                kept += 1
                print("  %s -> %s (%d, next %s %d)%s" % (name, mid or "unknown", score, nxt, second, "" if looped else "  [no loop]"), flush=True)
        cap.release()
        print("%s: %d clips" % (vid, kept), flush=True)
    with open(os.path.join(args.out, "index.tsv"), "w", encoding="utf-8") as f:
        f.write("clip\tid\tname\tmatch\trunner_up\trunner_up_match\tvideo\tstart_s\tlength_s\tfps\tloop_frames\tloop_score\tloop_found\tsaved_frames\tfolder\n")
        for r in rows:
            f.write("\t".join(r) + "\n")
    loops = sorted((r for r in rows if r[12] == "yes"), key=lambda r: (r[1] == "", r[2], r[0]))
    sheet([(r[14], r[2] or "?") for r in loops], args.out)
    print("clips:", len(rows), "loops found:", len(loops), "named:", sum(1 for r in rows if r[1]), "monsters with a loop:", len({r[1] for r in loops if r[1]}))


def _name_area(crop):
    h, w = crop.shape[:2]
    fx = lambda v: (v - BOX[0]) / (BOX[2] - BOX[0])
    fy = lambda v: (v - BOX[1]) / (BOX[3] - BOX[1])
    return crop[int(fy(NAME_BOX[1]) * h):int(fy(NAME_BOX[3]) * h), int(fx(NAME_BOX[0]) * w):int(fx(NAME_BOX[2]) * w)]


def sheet(names, out):
    if not names:
        return
    cols, cw, ch = 8, 200, 190
    img = np.full((((len(names) + cols - 1) // cols) * ch, cols * cw, 3), 255, np.uint8)
    for i, (name, label) in enumerate(names):
        f = cv2.imread(os.path.join(out, name, "f000.png"))
        k = min((cw - 6) / f.shape[1], (ch - 24) / f.shape[0])
        f = cv2.resize(f, (int(f.shape[1] * k), int(f.shape[0] * k)), interpolation=cv2.INTER_AREA)
        x, y = (i % cols) * cw, (i // cols) * ch
        img[y + 3:y + 3 + f.shape[0], x + 3:x + 3 + f.shape[1]] = f
        cv2.putText(img, label[:24], (x + 4, y + ch - 7), cv2.FONT_HERSHEY_SIMPLEX, 0.38, (0, 0, 0), 1, cv2.LINE_AA)
    cv2.imwrite(os.path.join(out, "sheet.jpg"), img, [cv2.IMWRITE_JPEG_QUALITY, 88])


if __name__ == "__main__":
    sys.exit(main())
