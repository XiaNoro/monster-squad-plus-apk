# Checks special-island drop lists against footage. Two sources:
#  popups   - the stage "Monster" drop-list popup (title = quest name, 3-column card grid, green OK button). The grid is
#             placed relative to the OK button and fitted by icon score, each card is named with match_icons' library.
#             The title bar is cut out and read with tools/ocr_frames.ps1, since the stage list behind the popup also
#             shows quest names.
#  captures - monsters caught after special-island wins found by scan_special_battles.py (research/videos/special_scan),
#             read from the capture screen with scan_drops' card finder.
# Writes research/videos/special_drops.tsv and special_drops.md (per quest: footage vs data/special_islands.json drops).
# Usage: python -I tools/scan_special_drops.py [--jobs 8]
import difflib, glob, json, os, re, shutil, subprocess, sys
from collections import defaultdict
from multiprocessing import Pool
import cv2
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import match_icons as MI

ROOT = MI.ROOT
VIDEOS = os.path.join(ROOT, "research", "videos")
TITLE_DIR = os.path.join(VIDEOS, "special_drops_titles")
OK = re.compile(r"^[0O]K$")
ACCEPT = 0.55
SURE = 0.65
MARGIN = 0.04
POOL_MIN = 0.45
POOL_SLACK = 0.03
CAPTURE_MIN = 0.5
STEP = 1.09
ROW_D2 = 0.78
PANEL_GAP = 0.28
FIT_FLOOR = 0.35
SMALL = 24
GROUP_GAP = 8
CAPTURE_WINDOW = 150

islands = json.load(open(os.path.join(ROOT, "data", "special_islands.json"), encoding="utf-8-sig"))["islands"]
monsters = json.load(open(os.path.join(ROOT, "data", "monsters.json"), encoding="utf-8"))
keys, mat, small = [], None, None


def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower().replace("★", "").replace("*", ""))


def quest_titles():
    out = {}
    for short in (False, True):
        fulls = set(out)
        for isl in islands:
            for q in isl["quests"]:
                t = norm(re.sub(r"\s*\(.*?\)", "", q["name"])) if short else norm(q["name"])
                if len(t) >= 3 and (isl["id"], q["name"]) not in out.get(t, []) and not (short and t in fulls):
                    out.setdefault(t, []).append((isl["id"], q["name"]))
    return out


TITLES = quest_titles()


def title_of(parts, cutoff=0.86):
    best = (0.0, None)
    for p in parts:
        n = norm(p)
        if len(n) < 3:
            continue
        for t, qs in TITLES.items():
            r = 1.0 if n == t else difflib.SequenceMatcher(None, n, t).ratio()
            if r > best[0]:
                best = (r, qs)
    return best[1] if best[0] >= cutoff else None


def small_prep(img):
    img = cv2.resize(img, (SMALL, SMALL), interpolation=cv2.INTER_AREA)[4:18, 3:21]
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB).astype(np.float32)
    lab -= lab.mean(axis=(0, 1))
    return (lab / (np.linalg.norm(lab) + 1e-6)).reshape(-1)


def init():
    global keys, mat, small
    lib = MI.library()
    keys, mat = MI.stack(lib)
    rows = []
    for k in keys:
        img = cv2.imread(os.path.join(ROOT, "assets", "icons", k + ".webp"), cv2.IMREAD_UNCHANGED)
        if img.shape[2] == 4:
            a = img[..., 3:4] / 255.0
            img = (img[..., :3] * a + 128 * (1 - a)).astype(np.uint8)
        rows.append(small_prep(img))
    small = np.stack(rows)


def ok_button(img):
    H, W = img.shape[:2]
    g = cv2.inRange(cv2.cvtColor(img, cv2.COLOR_BGR2HSV), (35, 120, 120), (75, 255, 255))
    n, _lab, st, _c = cv2.connectedComponentsWithStats(g)
    for k in sorted(range(1, n), key=lambda k: -st[k][4]):
        x, y, w, h, a = st[k]
        if 0.15 * W < w < 0.4 * W and 3.0 < w / h < 5.0 and 0.5 * H < y < 0.85 * H and 0.35 * W < x + w / 2 < 0.65 * W:
            return x, y, w, h
        break
    return None


def panel(btn, c):
    bottom = btn[1] - PANEL_GAP * c
    return bottom - 2 * STEP * c - 0.12 * c, bottom + 0.05 * c


def cells(img, btn, c, d2, dx):
    x, y, w, _h = btn
    step = c * STEP
    cx = x + w / 2 + dx
    top, bottom = panel(btn, c)
    out = []
    for row in range(3):
        cy = y - d2 - row * step
        for col in (-1, 0, 1):
            bx, by = int(cx + col * step - c / 2), int(cy - c / 2)
            if bx >= 0 and by >= max(0, top) and by + c <= bottom:
                out.append((row, col, (bx, by, int(c), int(c))))
    return out


def fit_score(img, btn, geo):
    sc = []
    for _r, _c, (bx, by, bw, bh) in cells(img, btn, *geo):
        crop = img[by:by + bh, bx:bx + bw]
        if crop.shape[0] == bh and crop.shape[1] == bw:
            sc.append(float((small @ small_prep(crop)).max()))
    return sum(max(0.0, v - FIT_FLOOR) for v in sc) if len(sc) >= 3 else -1.0


def fit(img, btn):
    w = btn[2]
    coarse = [(c, d2 * c, dx) for c in np.linspace(0.30, 0.42, 7) * w
              for d2 in np.linspace(ROW_D2, ROW_D2 + STEP, 9) for dx in np.linspace(-0.04, 0.04, 5) * w]
    best = max(coarse, key=lambda g: fit_score(img, btn, g))
    c, d2, dx = best
    fine = [(c * k, d2 + e * c, dx + f * w) for k in (0.98, 1.0, 1.02) for e in np.linspace(-0.07, 0.07, 5) for f in (-0.01, 0, 0.01)]
    best = max(fine + [best], key=lambda g: fit_score(img, btn, g))
    return best if fit_score(img, btn, best) >= 0 else None


def scan_popup(img):
    btn = ok_button(img)
    if btn is None:
        return None
    geo = fit(img, btn)
    if geo is None:
        return None
    c = geo[0]
    cx = btn[0] + btn[2] / 2
    top, _bottom = panel(btn, c)
    y0, y1 = int(max(0, top - 1.25 * c)), int(max(0, top - 0.1 * c))
    x0, x1 = int(max(0, cx - 2.0 * c)), int(cx + 2.0 * c)
    title = img[y0:y1, x0:x1]
    tops = [MI.best(img, box, keys, mat, 12) for _r, _c, box in cells(img, btn, *geo)]
    return tops, title


def decide(tops, pool):
    out = []
    for top in tops:
        if top[0][1] >= ACCEPT and (top[0][1] >= SURE or top[0][1] - top[1][1] >= MARGIN):
            out.append((top[0][0], round(top[0][1], 3), round(top[0][1] - top[1][1], 3), "icon"))
            continue
        near = [(m, sc) for m, sc in top if m in pool and sc >= POOL_MIN and sc >= top[0][1] - POOL_SLACK]
        if near:
            out.append((near[0][0], round(near[0][1], 3), round(near[0][1] - top[0][1], 3), "pool"))
    return out


def quest_pool(qs):
    out = set()
    for isl in islands:
        for q in isl["quests"]:
            if (isl["id"], q["name"]) in qs:
                out |= set(q.get("drops", [])) | set(q.get("enemies", [])) | {q.get("boss", "")} | {r["id"] for r in q.get("rare", [])}
    return out


def popup_job(job):
    d, frames = job
    vid = os.path.basename(d)
    coll = os.path.basename(os.path.dirname(d))
    res = []
    for f, qs in frames:
        img = cv2.imread(os.path.join(d, f))
        if img is None:
            continue
        got = scan_popup(img)
        if got is None:
            continue
        tops, title = got
        tname = "%s__%s__%s.png" % (coll, vid, f[:-4])
        if title.size:
            cv2.imwrite(os.path.join(TITLE_DIR, tname), cv2.resize(title, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC))
        res.append({"video": vid, "coll": coll, "frame": f, "ocr_quests": qs, "tops": tops, "title_file": tname})
    return res


def popup_candidates():
    jobs = []
    for ocr in glob.glob(os.path.join(VIDEOS, "frames*", "*", "ocr.tsv")):
        frames = []
        for line in open(ocr, encoding="utf-8-sig", errors="replace"):
            if "\t" not in line:
                continue
            f, text = line.rstrip("\n").split("\t", 1)
            parts = [p.strip() for p in text.split("|")]
            if not any(OK.match(p) for p in parts):
                continue
            qs = title_of(parts[:6])
            if qs:
                frames.append((f, qs))
        if frames:
            jobs.append((os.path.dirname(ocr), frames))
    return jobs


def read_titles():
    subprocess.run(["powershell", "-NoProfile", "-File", os.path.join(ROOT, "tools", "ocr_frames.ps1"), TITLE_DIR],
                   check=True, stdout=subprocess.DEVNULL)
    out = {}
    for line in open(os.path.join(TITLE_DIR, "ocr.tsv"), encoding="utf-8-sig", errors="replace"):
        if "\t" in line:
            f, text = line.rstrip("\n").split("\t", 1)
            out[f] = text
    return out


def capture_job(path):
    import scan_drops as SD
    import scan_stage_enemies as SSE
    if not SD.flat:
        SD.init()
    data = json.load(open(path, encoding="utf-8"))
    vid = data["video"]
    d = next((x for x in glob.glob(os.path.join(VIDEOS, "frames*", vid)) if os.path.exists(os.path.join(x, "ocr.tsv"))), None)
    if d is None:
        return []
    rows = [(SD.secs(f), f, t) for f, t in SSE.read_ocr(d)]
    battles = sorted(data["battles"], key=lambda b: int(b["end_t"]))
    out = []
    for i, b in enumerate(battles):
        lo = int(b["end_t"])
        hi = min(lo + CAPTURE_WINDOW, SD.secs(battles[i + 1]["start"]) if i + 1 < len(battles) else 10 ** 9)
        hits = [(f, text) for t, f, text in rows if lo < t < hi and SD.CAPTURE.search(text)]
        if not hits or not b.get("island"):
            continue
        qs = [(b["island"], q["name"]) for isl in islands if isl["id"] == b["island"] for q in isl["quests"] if q["name"] == b["field"]]
        f = hits[len(hits) // 2][0]
        img = cv2.imread(os.path.join(d, f))
        if img is None:
            continue
        pool = quest_pool(qs)
        for w in b["enemies"].values():
            pool |= set(w)
        for win, unit, stars, _sx in SD.slots(img):
            graded = {m for m, mm in SSE.monsters.items() if int(mm.get("stars", 0)) == stars}
            p = SD.rank(win, unit, pool & graded) or SD.rank(win, unit, pool)
            if p and p[0][0] >= CAPTURE_MIN:
                out.append({"video": vid, "frame": f, "island": b["island"], "quest": b["field"], "stars": stars,
                            "monster": p[0][1], "score": round(p[0][0], 3)})
    return out


def group(rows):
    rows.sort(key=lambda r: (r["video"], r["frame"]))
    out, last = [], None
    for r in rows:
        t = int(re.sub(r"\D", "", r["frame"]) or 0)
        key = (r["video"], tuple(r["quests"]))
        if last and last[0] == key and t - last[1] <= GROUP_GAP:
            g = out[-1]
            g["frames"].append(r["frame"])
        else:
            g = {"video": r["video"], "quests": r["quests"], "title": r["title"], "frames": [r["frame"]], "ids": {}}
            out.append(g)
        for mid, sc, mg, how in r["ids"]:
            old = g["ids"].get(mid)
            if old is None or (how == "icon", sc) > (old[2] == "icon", old[0]):
                g["ids"][mid] = (sc, mg, how)
        last = (key, t)
    return [g for g in out if g["ids"]]


def name(mid):
    return monsters.get(mid, {}).get("name", mid)


def main(args):
    jobs = int(args[args.index("--jobs") + 1]) if "--jobs" in args else max(1, (os.cpu_count() or 2) - 2)
    shutil.rmtree(TITLE_DIR, ignore_errors=True)
    os.makedirs(TITLE_DIR)
    cands = popup_candidates()
    print("popup candidates: %d frames in %d videos" % (sum(len(f) for _d, f in cands), len(cands)), flush=True)
    with Pool(jobs, initializer=init) as pool:
        raw = [r for res in pool.imap_unordered(popup_job, cands) for r in res]
    titles = read_titles()
    rows = []
    for r in raw:
        text = titles.get(r["title_file"], "")
        qs = title_of([p.strip() for p in text.split("|")] + [text], 0.8)
        if not qs:
            continue
        r.update({"quests": qs, "title": text, "ids": decide(r["tops"], quest_pool(qs))})
        rows.append(r)
    popups = group(rows)
    print("%d popup frames, %d with a readable title" % (len(raw), len(rows)), flush=True)
    paths = sorted(glob.glob(os.path.join(VIDEOS, "special_scan", "*.json")))
    with Pool(jobs) as pool:
        caps = [r for res in pool.imap_unordered(capture_job, paths) for r in res]
    print("%d popups, %d captures" % (len(popups), len(caps)), flush=True)

    per = defaultdict(lambda: {"popup": defaultdict(list), "capture": defaultdict(list)})
    for g in popups:
        for isl, qn in g["quests"]:
            for mid, (sc, _mg, how) in g["ids"].items():
                per[(isl, qn)]["popup"][mid].append("%s/%s %.2f%s" % (g["video"], g["frames"][0], sc, "" if how == "icon" else " pool"))
    for c in caps:
        per[(c["island"], c["quest"])]["capture"][c["monster"]].append("%s/%s %.2f" % (c["video"], c["frame"], c["score"]))

    with open(os.path.join(VIDEOS, "special_drops.tsv"), "w", encoding="utf-8") as fh:
        fh.write("source\tvideo\tframe\tisland\tquest\tmonster\tscore\tmargin\thow\n")
        for g in popups:
            for isl, qn in g["quests"]:
                for mid, (sc, mg, how) in sorted(g["ids"].items()):
                    fh.write("popup\t%s\t%s\t%s\t%s\t%s\t%.3f\t%.3f\t%s\n" % (g["video"], g["frames"][0], isl, qn, mid, sc, mg, how))
        for c in caps:
            fh.write("capture\t%s\t%s\t%s\t%s\t%s\t%.3f\t\tsprite\n" % (c["video"], c["frame"], c["island"], c["quest"], c["monster"], c["score"]))

    lines = ["# Special-island drops: footage vs data/special_islands.json", "",
             "Made by tools/scan_special_drops.py. Popup = the stage's drop-list popup; capture = monster caught after a win. "
             "'pool' = only named because it is on that quest's own list (low-resolution card). "
             "Popups only show the rows on screen, so 'ours, not in footage' is only a hint.", ""]
    summary, done = [], set()
    for isl in islands:
        for q in isl["quests"]:
            key = (isl["id"], q["name"])
            ev = per.get(key)
            if not ev or key in done:
                continue
            done.add(key)
            ours = []
            for qq in isl["quests"]:
                if qq["name"] == q["name"]:
                    ours += [m for m in (qq.get("drops") or qq.get("enemies", []) + [qq.get("boss", "")]) + [r["id"] for r in qq.get("rare", [])]
                             if m and m not in ours]
            seen = set(ev["popup"]) | set(ev["capture"])
            extra = [m for m in seen if m not in ours]
            lines.append("### %s / %s" % (isl["name"], q["name"]))
            lines.append("- ours: %s" % (", ".join(name(m) for m in ours) or "(none)"))
            for src in ("popup", "capture"):
                for mid, where in sorted(ev[src].items()):
                    tag = "ok" if mid in ours else "**NOT IN OUR LIST**"
                    lines.append("- %s: %s %s (%s)" % (src, name(mid), tag, "; ".join(where[:3])))
            unseen = [m for m in ours if m not in seen]
            if unseen and ev["popup"]:
                lines.append("- ours, not in footage: %s" % ", ".join(name(m) for m in unseen))
            lines.append("")
            summary.append("| %s | %s | %d | %d | %s |" % (isl["name"], q["name"], len(ev["popup"]), len(ev["capture"]),
                                                       ", ".join(name(m) for m in extra) or "-"))
    head = ["| island | quest | popup ids | capture ids | not in our list |", "|---|---|---|---|---|"]
    md = lines[:4] + head + summary + [""] + lines[4:]
    open(os.path.join(VIDEOS, "special_drops.md"), "w", encoding="utf-8").write("\n".join(md) + "\n")
    print("\n".join(head + summary))
    print("->", os.path.join(VIDEOS, "special_drops.md"))


if __name__ == "__main__":
    main(sys.argv[1:])
