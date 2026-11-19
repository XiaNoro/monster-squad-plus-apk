# Measures how big each monster is drawn in the original lobby (the home screen; the friend lobby uses the same layout).
# Lobby frames are the ones whose OCR has "Team Rank". Each frame is OCR'd with line positions (tools/ocr_boxes.ps1,
# small frames upscaled 2x first); a line ending in a monster name is that monster's tag, a crown above it marks the
# leader, and the monster's art is fitted from just above the tag (tall heads reach behind it) down, with
# scan_monster_sizes.fit. Heights are in normal HP bar
# widths like the battle sizes; the screen scale comes from the same video's battle bars (size_scan) or the game width.
# Results are added to data/monster_sizes.json as "lobby" sizes, a leader scale, and the lobby/battle ratio used for
# monsters only measured in battle.
# Usage: python tools/scan_lobby_sizes.py [--force] [--jobs N]
#        python tools/scan_lobby_sizes.py --summary
import difflib, functools, glob, json, os, re, shutil, statistics, subprocess, sys, tempfile
from collections import defaultdict
from multiprocessing import Pool
import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scan_stage_enemies as S
import scan_monster_sizes as Z

OUT = os.path.join(S.VIDEOS, "lobby_scan")
BOXES = os.path.join(OUT, "ocr_boxes.jsonl")
PER_VIDEO = 30
UPSCALE_BELOW = 1500
BAR = 98.0
LIFT = 1.0
OCR_JOBS = 8
LEVEL = re.compile(r"^\W*[LlI1][\W_]?[vV][\W_]*[\d]{0,2}\W*")


def lobby_frames():
    out = []
    for coll in S.DEFAULT_DIRS:
        base = os.path.join(S.VIDEOS, coll)
        for v in sorted(os.listdir(base)):
            d = os.path.join(base, v)
            if not os.path.exists(os.path.join(d, "ocr.tsv")):
                continue
            fr = [f for f, text in S.read_ocr(d) if "Team Rank" in text]
            step = max(1, len(fr) // PER_VIDEO)
            out += [(coll, v, f) for f in fr[::step][:PER_VIDEO]]
    return out


def ocr(frames):
    done = set()
    if os.path.exists(BOXES):
        for line in open(BOXES, encoding="utf-8"):
            done.add(json.loads(line)["file"])
    tmp = tempfile.mkdtemp(prefix="lobby_ocr_")
    todo = []
    for coll, v, f in frames:
        src = os.path.join(S.VIDEOS, coll, v, f)
        dst = os.path.join(tmp, "%s__%s__%s" % (coll, v, f))
        if "%s|%s|%s" % (coll, v, f) in done:
            continue
        img = cv2.imread(src)
        if img is None:
            continue
        if img.shape[1] < UPSCALE_BELOW:
            img = cv2.resize(img, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
        cv2.imwrite(dst, img, [cv2.IMWRITE_JPEG_QUALITY, 93])
        todo.append(dst)
    procs = []
    for k in range(OCR_JOBS):
        part = todo[k::OCR_JOBS]
        if not part:
            continue
        lst = os.path.join(tmp, "list_%d.txt" % k)
        open(lst, "w", encoding="ascii").write("\n".join(part))
        procs.append(subprocess.Popen(["powershell", "-NoProfile", "-File", os.path.join(S.ROOT, "tools", "ocr_boxes.ps1"), lst, os.path.join(tmp, "out_%d.jsonl" % k)], stdout=subprocess.DEVNULL))
    for p in procs:
        p.wait()
    with open(BOXES, "a", encoding="utf-8") as w:
        for part in glob.glob(os.path.join(tmp, "out_*.jsonl")):
            for line in open(part, encoding="utf-8-sig"):
                d = json.loads(line)
                coll, v, f = os.path.basename(d["file"]).split("__")
                w.write(json.dumps({"file": "%s|%s|%s" % (coll, v, f), "lines": d["lines"] or []}) + "\n")
    shutil.rmtree(tmp, ignore_errors=True)
    print("ocr: %d new frames" % len(todo), flush=True)


def name_to_id(text):
    rest = LEVEL.sub("", text.strip())
    for cand in [rest] + rest.split()[-1:]:
        key = re.sub(r"[^a-z0-9]", "", cand.lower())
        if len(key) < 4:
            continue
        hit = difflib.get_close_matches(key, S.names.keys(), n=1, cutoff=0.82)
        if hit:
            return S.names[hit[0]]
        pre = [k for k in S.names if k.startswith(key)] if len(key) >= 5 else []
        if len(pre) == 1:
            return S.names[pre[0]]
    return ""


@functools.lru_cache(maxsize=1)
def crown_art():
    return cv2.imread(os.path.join(S.ROOT, "assets", "apk", "sprites", "betaUI00", "I_leader_01.png"), cv2.IMREAD_UNCHANGED)


def crown_at(img, k, rect):
    x0, y0, x1, y1 = rect
    W, H = x1 - x0, y1 - y0
    a = crown_art()
    best = (0.0, None)
    for s in (0.92, 1.0, 1.08):
        c = cv2.resize(a, (max(6, int(a.shape[1] * k * s)), max(6, int(a.shape[0] * k * s))), interpolation=cv2.INTER_AREA)
        m = (c[:, :, 3] > 128).astype(np.uint8)
        area = img[int(y0 + 0.1 * H):int(y0 + 0.75 * H), x0:int(x0 + 0.8 * W)]
        res = cv2.matchTemplate(area, c[:, :, :3], cv2.TM_CCOEFF_NORMED, mask=cv2.merge([m, m, m]))
        res[~np.isfinite(res)] = -1
        _, v, _, loc = cv2.minMaxLoc(res)
        if v > best[0]:
            best = (v, (x0 + loc[0] + c.shape[1] / 2, y0 + 0.1 * H + loc[1] + c.shape[0]))
    return best[1] if best[0] >= 0.6 else None


def is_leader(crown, k, x, y, w):
    return crown is not None and x - 30 * k <= crown[0] + 160 * k and crown[0] - 40 * k <= x + w and -15 * k <= y - crown[1] <= 45 * k


def scale_of(coll, v, img):
    p = os.path.join(Z.OUT, "%s__%s.json" % (coll, v))
    ratio = 1.0
    if os.path.exists(p):
        d = json.load(open(p, encoding="utf-8"))
        if d.get("full_bars", 0) >= 5:
            ratio = float(d["bar_ratio"])
    x0, y0, x1, y1 = S.game_rect(img)
    return (x1 - x0) * 0.076 * ratio / BAR, (x0, y0, x1, y1)


def measure_video(job):
    coll, v, entries, force = job
    dest = os.path.join(OUT, "%s__%s.json" % (coll, v))
    if os.path.exists(dest) and not force:
        return None
    meas = []
    for f, lines, up in entries:
        img = cv2.imread(os.path.join(S.VIDEOS, coll, v, f))
        if img is None:
            continue
        k, (x0, y0, x1, y1) = scale_of(coll, v, img)
        W, H = x1 - x0, y1 - y0
        crown = crown_at(img, k, (x0, y0, x1, y1))
        unit = BAR * k
        for ln in lines:
            mid = name_to_id(ln["text"])
            if not mid:
                continue
            x, y, w, h = [int(round(ln[c] / up)) for c in ("x", "y", "w", "h")]
            if not (y0 + 0.08 * H < y < y0 + 0.8 * H and x < x0 + 0.8 * W):
                continue
            role = "leader" if is_leader(crown, k, x, y, w) else "member"
            wx0, wx1 = int(max(x0, x - 160 * k)), int(min(x1, x + w + 120 * k))
            wy0, wy1 = int(max(y0, y + h - LIFT * unit)), int(min(y1, y + h + 4.4 * unit))
            if wx1 - wx0 < unit or wy1 - wy0 < 1.5 * unit:
                continue
            got = Z.fit(img[wy0:wy1, wx0:wx1], unit, mid)
            if got:
                meas.append([mid, role, round(got[0], 4), round(got[1], 3), f, [wx0, wy0] + [round(c) for c in got[2]]])
    json.dump({"video": v, "frames": coll, "meas": meas}, open(dest, "w", encoding="utf-8"))
    return "%s/%s: %d sizes" % (coll, v, len(meas))


def summary():
    per = defaultdict(lambda: defaultdict(list))
    for p in glob.glob(os.path.join(OUT, "*__*.json")):
        d = json.load(open(p, encoding="utf-8"))
        for mid, role, h, v, *_ in d["meas"]:
            per[(mid, role)][d["video"]].append(h)
    med = defaultdict(dict)
    for (mid, role), vids in per.items():
        vm = [statistics.median(hs) for hs in vids.values() if len(hs) >= 2]
        if vm:
            med[mid][role] = (statistics.median(vm), sum(len(hs) for hs in vids.values()), len(vm))
    pairs = [r["leader"][0] / r["member"][0] for r in med.values() if "leader" in r and "member" in r]
    leader = round(statistics.median(pairs), 3) if len(pairs) >= 3 else 1.0
    print("leader scale %.3f from %d monsters" % (leader, len(pairs)))
    lobby = {}
    for mid in med:
        hs = [h / (leader if role == "leader" else 1.0) for (m, role), vids in per.items() if m == mid for v in vids.values() for h in v]
        m = statistics.median(hs)
        q = np.percentile(hs, [25, 75])
        if len(hs) >= 3 and (q[1] - q[0]) / m <= 0.25:
            lobby[mid] = {"h": round(m / Z.alpha_frac(mid), 3), "n": len(hs), "drawn": m}
    odd = Z.off_star({mid: s["drawn"] for mid, s in lobby.items()})
    for mid in odd:
        del lobby[mid]
    for s in lobby.values():
        del s["drawn"]
    if odd:
        print("dropped %d far from their star rating's usual size: %s" % (len(odd), ", ".join(odd)))
    data = json.load(open(Z.DATA, encoding="utf-8")) if os.path.exists(Z.DATA) else {"sizes": {}}
    both = [lobby[m]["h"] / data["sizes"][m]["h"] for m in lobby if m in data["sizes"]]
    ratio = round(statistics.median(both), 3) if len(both) >= 3 else 1.0
    off = [m for m in lobby if m in data["sizes"] and abs(lobby[m]["h"] / (data["sizes"][m]["h"] * ratio) - 1.0) > 0.3]
    for m in off:
        del lobby[m]
    print("lobby/battle ratio %.3f from %d monsters; dropped %d that disagree with battle: %s" % (ratio, len(both), len(off), ", ".join(off)))
    data["lobby"] = dict(sorted(lobby.items()))
    data["lobby_scale"] = {"leader": leader, "from_battle": ratio}
    Z.G.fill(data)
    open(Z.DATA, "w", encoding="utf-8").write(json.dumps(data, indent="\t"))
    print("%d monsters measured in the lobby -> %s" % (len(lobby), Z.DATA))


def main(args):
    if "--summary" in args:
        summary()
        return
    jobs = int(args[args.index("--jobs") + 1]) if "--jobs" in args else max(1, (os.cpu_count() or 2) - 2)
    os.makedirs(OUT, exist_ok=True)
    frames = lobby_frames()
    print("lobby frames: %d" % len(frames), flush=True)
    ocr(frames)
    by = defaultdict(list)
    for line in open(BOXES, encoding="utf-8"):
        d = json.loads(line)
        coll, v, f = d["file"].split("|")
        img_w = cv2.imread(os.path.join(S.VIDEOS, coll, v, f)).shape[1] if not by.get((coll, v)) else by[(coll, v)][0][3]
        by[(coll, v)].append((f, d["lines"], 2.0 if img_w < UPSCALE_BELOW else 1.0, img_w))
    work = [(coll, v, [e[:3] for e in entries], "--force" in args) for (coll, v), entries in sorted(by.items())]
    with Pool(jobs, initializer=S.load_refs) as pool:
        for msg in pool.imap_unordered(measure_video, work):
            if msg:
                print(msg, flush=True)
    summary()


if __name__ == "__main__":
    main(sys.argv[1:])
