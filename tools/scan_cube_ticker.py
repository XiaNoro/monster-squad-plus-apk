# Reads the hub ticker ("<player> Obtained <monster> ★N from Cube / by Fusion / by Evolving") out of every OCR file in
# research/videos/frames*/ and compares the monsters seen coming out of cubes with the pools cubes_screen.gd builds
# (non-material, base form or 5★+, by star count). One sighting per monster and source per video.
# Writes research/videos/cube_ticker.tsv and cube_ticker.md.
# Usage: python -I tools/scan_cube_ticker.py
import difflib, glob, json, os, re
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VIDEOS = os.path.join(ROOT, "research", "videos")
SOURCES = [("cube", re.compile(r"^(?:from|frorn|frMn|frtxn|fr\w{1,3})\s*(?:Cube|Qbe|Cub)\b", re.I)),
           ("fusion", re.compile(r"^by\s*Fusi", re.I)),
           ("evolving", re.compile(r"^by\s*Evo", re.I))]
monsters = json.load(open(os.path.join(ROOT, "data", "monsters.json"), encoding="utf-8"))


def norm(s):
    return re.sub(r"[^a-z]", "", s.lower())


NAMES = {norm(m["name"]): mid for mid, m in monsters.items() if len(norm(m["name"])) >= 3}


def monster_in(part):
    p = re.sub(r"(?i)\bobtain\S*", "", part)
    p = re.sub(r"[•★*]\s*\d.*$|\s\d.*$", "", p).strip()
    n = norm(p)
    if len(n) < 3:
        return None
    if n in NAMES:
        return NAMES[n]
    hit = difflib.get_close_matches(n, NAMES.keys(), 1, 0.88) if len(n) >= 5 else []
    return NAMES[hit[0]] if hit else None


def upload_dates():
    out = {}
    for f in glob.glob(os.path.join(VIDEOS, "video*", "*.info.json")):
        try:
            j = json.load(open(f, encoding="utf-8"))
        except (OSError, ValueError):
            continue
        out[j.get("id", "")] = j.get("upload_date", "")
    return out


def cube_pool_ok(mid):
    m = monsters[mid]
    return mid == "goldbat" or (not m.get("material") and (not m.get("evolves_from") or int(m.get("stars", 0)) >= 3))


def main():
    dates = upload_dates()
    seen = defaultdict(lambda: defaultdict(set))
    rows = []
    for ocr in glob.glob(os.path.join(VIDEOS, "frames*", "*", "ocr.tsv")):
        folder = os.path.basename(os.path.dirname(ocr))
        vid = folder.split("_", 1)[1] if re.match(r"^\d{8}_", folder) else folder
        date = dates.get(vid, folder[:8] if re.match(r"^\d{8}_", folder) else "")
        for line in open(ocr, encoding="utf-8-sig", errors="replace"):
            if "\t" not in line:
                continue
            frame, text = line.rstrip("\n").split("\t", 1)
            parts = [p.strip() for p in text.split("|")]
            for i, p in enumerate(parts):
                src = next((s for s, rx in SOURCES if rx.match(p)), None)
                if not src:
                    continue
                for j in range(i - 1, max(-1, i - 4), -1):
                    mid = monster_in(parts[j])
                    if mid:
                        if vid not in seen[mid][src]:
                            rows.append((mid, src, vid, frame, date))
                        seen[mid][src].add(vid)
                        break
    with open(os.path.join(VIDEOS, "cube_ticker.tsv"), "w", encoding="utf-8") as fh:
        fh.write("monster\tstars\tsource\tvideo\tframe\tdate\n")
        for mid, src, vid, frame, date in sorted(rows):
            fh.write("%s\t%s\t%s\t%s\t%s\t%s\n" % (mid, monsters[mid].get("stars"), src, vid, frame, date))

    def dates_of(mid, src):
        ds = sorted(d for m, s, _v, _f, d in rows if m == mid and s == src and d)
        return "%s..%s" % (ds[0], ds[-1]) if ds else ""

    cube = sorted((m for m in seen if seen[m]["cube"]), key=lambda m: (-int(monsters[m].get("stars", 0)), m))
    lines = ["# Hub ticker: where 5★/6★ monsters came from", "",
             "Made by tools/scan_cube_ticker.py from the OCR of all footage. Count = videos with a ticker line.", "",
             "## Seen from Cube", "", "| monster | ★ | videos | dates | in our cube pool | wiki location |", "|---|---|---|---|---|---|"]
    for m in cube:
        lines.append("| %s | %s | %d | %s | %s | %s |" % (monsters[m]["name"], monsters[m].get("stars"), len(seen[m]["cube"]),
                                                   dates_of(m, "cube"), "yes" if cube_pool_ok(m) else "**NO**", monsters[m].get("location", "")[:60]))
    lines += ["", "## Seen only by Fusion / Evolving", "", "| monster | ★ | fusion | evolving | in our cube pool |", "|---|---|---|---|---|"]
    for m in sorted((m for m in seen if not seen[m]["cube"]), key=lambda m: (-int(monsters[m].get("stars", 0)), m)):
        lines.append("| %s | %s | %d | %d | %s |" % (monsters[m]["name"], monsters[m].get("stars"), len(seen[m]["fusion"]),
                                               len(seen[m]["evolving"]), "**yes**" if cube_pool_ok(m) else "no"))
    open(os.path.join(VIDEOS, "cube_ticker.md"), "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("%d sightings, %d monsters (%d from cube) -> %s" % (len(rows), len(seen), len(cube), os.path.join(VIDEOS, "cube_ticker.md")))


if __name__ == "__main__":
    main()
