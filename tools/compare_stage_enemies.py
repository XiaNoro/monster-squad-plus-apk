# Compares research/videos/stage_scan/*.json (from scan_stage_enemies.py) with data/islands.json the way the game reads
# it (StageBuilder.story_quest: boss_lines override unless boss_fixed, waves default per island). Battles without a
# readable difficulty tab are assigned the difficulty whose boss matches the boss intro, when exactly one does.
# Writes research/videos/stage_compare.md, plus stage_compare_review_N.jpg sheets pairing each flagged footage crop
# with our art for the monster it was matched to, and prints the summary.
# Usage: python tools/compare_stage_enemies.py [--z 4.5]
import glob, json, os, sys
from collections import Counter, defaultdict
import cv2
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCAN = os.path.join(ROOT, "research", "videos", "stage_scan")
STAGES_PER_QUEST = [2, 3, 4, 4, 4, 5, 5, 4]
SURE_Z = 6.5

monsters = json.load(open(os.path.join(ROOT, "data", "monsters.json"), encoding="utf-8"))
islands = {i["id"]: i for i in json.load(open(os.path.join(ROOT, "data", "islands.json"), encoding="utf-8"))}
boss_lines = json.load(open(os.path.join(ROOT, "data", "tutorial.json"), encoding="utf-8")).get("boss_lines", {})


def family(mid):
    seen = set()
    while monsters.get(mid, {}).get("evolves_from") and mid not in seen:
        seen.add(mid)
        mid = monsters[mid]["evolves_from"]
    return mid


def name(mid):
    return monsters.get(mid, {}).get("name", mid)


def stage_count(order, idx):
    if order == 0:
        return 2 if idx == 0 else (4 if idx >= 5 else 3)
    return STAGES_PER_QUEST[min(max(order, 0), len(STAGES_PER_QUEST) - 1)]


def ours(island_id, diff, idx):
    isl = islands.get(island_id)
    if not isl or diff not in isl["difficulties"] or idx >= len(isl["difficulties"][diff]["stages"]):
        return None
    st = isl["difficulties"][diff]["stages"][idx]
    boss = st["boss"]
    line = boss_lines.get("%s:%s:%d" % (island_id, diff, idx), boss_lines.get("%s:normal:%d" % (island_id, idx), {}))
    say = line.get("say", "")
    if say and say != boss and say in monsters and not st.get("boss_fixed"):
        boss = say
    return {"boss": boss, "enemies": set(st["enemies"]) | {boss}, "waves": int(st.get("waves", stage_count(int(isl.get("order", 0)), idx)))}


def main(args):
    accept = float(args[args.index("--z") + 1]) if "--z" in args else 4.5
    groups = defaultdict(list)
    for path in sorted(glob.glob(os.path.join(SCAN, "*.json"))):
        if path.endswith("calib.json"):
            continue
        data = json.load(open(path, encoding="utf-8"))
        for b in data["battles"]:
            b["video"] = data["video"]
            diff, how = b["difficulty"], "tab"
            if diff == "?":
                fits = [d for d in ("normal", "hard", "hell") if b["boss_intro"] and (ours(b["island"], d, b["stage"] - 1) or {}).get("boss") == b["boss_intro"]]
                diff, how = (fits[0], "boss") if len(fits) == 1 else ("?", "")
            b["diff_from"] = how
            groups[(b["island"], diff, b["stage"])].append(b)

    order = {k: i for i, k in enumerate(islands)}
    lines, summary = [], Counter()
    rows_out, review = [], []
    for key in sorted(groups, key=lambda k: (order.get(k[0], 99), ["normal", "hard", "hell", "?"].index(k[1]), k[2])):
        island_id, diff, stage = key
        bs = groups[key]
        hits = Counter()
        battles_with = defaultdict(set)
        best = {}
        for b in bs:
            for wave, f, el, mid, raw, zz, _m2, _z2 in b["hits"]:
                if zz < accept:
                    continue
                hits[mid] += 1
                battles_with[mid].add((b["video"], b["start"]))
                if zz > best.get(mid, (0, ""))[0]:
                    best[mid] = (zz, b["crops"].get(mid, ""))
        seen = {m for m, n in hits.items() if n >= 2 or best[m][0] >= SURE_Z}
        intros = Counter(b["boss_intro"] for b in bs if b["boss_intro"])
        waves = Counter(b["waves"] for b in bs)
        ref = ours(island_id, diff, stage - 1) if diff != "?" else None
        title = "%s-%d %s" % (islands.get(island_id, {}).get("name", island_id), stage, diff.capitalize())
        lines.append("### %s" % title)
        vids = sorted({b["video"] for b in bs})
        lines.append("%d battle(s) in %s; difficulty from %s; %d enemy sightings" % (
            len(bs), ", ".join(vids), "/".join(sorted({b["diff_from"] or "?" for b in bs})), sum(hits.values())))
        if ref is None:
            lines.append("- (no matching stage in islands.json to compare)")
            lines.append("- seen: " + ", ".join("%s x%d" % (name(m), hits[m]) for m in sorted(seen, key=lambda m: -hits[m])))
            lines.append("")
            continue
        summary["stages"] += 1
        if intros:
            ib = intros.most_common(1)[0][0]
            ok = ib == ref["boss"]
            summary["boss_ok" if ok else "boss_diff"] += 1
            lines.append("- boss: footage **%s**, ours **%s** %s" % (name(ib), name(ref["boss"]), "OK" if ok else "<- DIFFERENT"))
            if not ok:
                rows_out.append((title, "boss", "footage %s, ours %s" % (name(ib), name(ref["boss"]))))
        fw = waves.most_common(1)[0][0]
        if fw != ref["waves"]:
            summary["waves_diff"] += 1
            lines.append("- waves: footage %d, ours %d <- DIFFERENT" % (fw, ref["waves"]))
            rows_out.append((title, "waves", "footage %d, ours %d" % (fw, ref["waves"])))
        fams = defaultdict(set)
        for m in ref["enemies"]:
            fams[family(m)].add(m)
        confirmed = sorted(seen & ref["enemies"])
        missing = sorted(seen - ref["enemies"], key=lambda m: -hits[m])
        if confirmed:
            lines.append("- confirmed: " + ", ".join("%s x%d" % (name(m), hits[m]) for m in confirmed))
            summary["confirmed"] += len(confirmed)
        for m in missing:
            near = fams.get(family(m))
            tag = "same family as our %s" % "/".join(name(x) for x in sorted(near)) if near else "NOT IN OUR LIST"
            lines.append("- footage has **%s** x%d in %d battle(s), best z %.1f, %s  `%s`" % (
                name(m), hits[m], len(battles_with[m]), best[m][0], tag, best[m][1]))
            summary["family" if near else "missing"] += 1
            rows_out.append((title, "family" if near else "missing", "%s x%d (%s)" % (name(m), hits[m], tag)))
            review.append(("%s: %s" % (title.replace(" Island", "").replace(" Isle", ""), name(m)), best[m][1], m))
        unseen = sorted(ref["enemies"] - seen - {fm for m in seen for fm in fams.get(family(m), set())})
        if unseen and sum(hits.values()) >= 12:
            lines.append("- ours but never seen: " + ", ".join(name(m) for m in unseen))
            summary["unseen"] += len(unseen)
        lines.append("")

    head = ["# Stage enemies: footage vs data/islands.json", "",
            "Generated by tools/compare_stage_enemies.py (accept z >= %.1f; a monster counts as seen with 2+ sightings or one at z >= %.1f)." % (accept, SURE_Z),
            "Crops of the best sighting are in research/videos/stage_scan/crops/.", "",
            "| | count |", "|---|---|"]
    for k in ["stages", "boss_ok", "boss_diff", "waves_diff", "confirmed", "missing", "family", "unseen"]:
        head.append("| %s | %d |" % (k, summary[k]))
    head += ["", "## Differences", "", "| stage | kind | detail |", "|---|---|---|"]
    head += ["| %s | %s | %s |" % r for r in rows_out]
    head += ["", "## By stage", ""]
    out = os.path.join(ROOT, "research", "videos", "stage_compare.md")
    open(out, "w", encoding="utf-8").write("\n".join(head + lines) + "\n")
    print(dict(summary))
    print("->", out)
    for page, path in enumerate(review_sheets(review)):
        print("-> review sheet", path)


def tile(im, label, w=150, h=170):
    if im is None:
        im = np.full((10, 10, 3), 128, np.uint8)
    if im.ndim == 3 and im.shape[2] == 4:
        a = im[:, :, 3:] / 255.0
        im = (im[:, :, :3] * a + 210 * (1 - a)).astype(np.uint8)
    s = (h - 24) / max(im.shape[0], im.shape[1] * (h - 24) / w)
    im = cv2.resize(im, (max(1, int(im.shape[1] * s)), max(1, int(im.shape[0] * s))))
    t = np.full((h, w, 3), 210, np.uint8)
    t[:im.shape[0], :im.shape[1]] = im
    cv2.putText(t, label[:24], (3, h - 7), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (0, 0, 0), 1)
    return t


def review_sheets(review, per_page=24):
    paths = []
    for old in glob.glob(os.path.join(ROOT, "research", "videos", "stage_compare_review_*.jpg")):
        os.remove(old)
    cut = os.path.join(ROOT, "assets", "monsters_cut")
    for page in range(0, len(review), per_page):
        pairs = []
        for label, crop, mid in review[page:page + per_page]:
            footage = cv2.imread(os.path.join(SCAN, "crops", crop)) if crop else None
            art = cv2.imread(os.path.join(cut, mid + ".png"), cv2.IMREAD_UNCHANGED)
            pairs.append(np.hstack([tile(footage, label.split(":")[0]), tile(art, label.split(": ", 1)[-1]), np.full((170, 12, 3), 255, np.uint8)]))
        while len(pairs) % 4:
            pairs.append(np.full_like(pairs[0], 255))
        sheet = np.vstack([np.hstack(pairs[i:i + 4]) for i in range(0, len(pairs), 4)])
        path = os.path.join(ROOT, "research", "videos", "stage_compare_review_%d.jpg" % (page // per_page + 1))
        cv2.imwrite(path, sheet)
        paths.append(path)
    return paths


main(sys.argv[1:])
