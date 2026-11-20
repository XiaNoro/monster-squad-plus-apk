import argparse
import csv
import os
import shutil
import sys

import cv2

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scan_loops as sl
import scrape_evo_idle as evo
import video_inventory as vi
from idle_namer import Namer


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=sl.OUT)
    ap.add_argument("--kinds", default="reveal,pet")
    args = ap.parse_args()
    out = args.out
    index = os.path.join(out, "index.tsv")
    rows = list(csv.DictReader(open(index, encoding="utf8"), delimiter="\t"))
    done = set(open(os.path.join(out, "done.txt"), encoding="utf8").read().split("\n"))
    finished = {v["yid"] or v["base"] for v in vi.videos() if v["old"] in done}
    by_clip = {}
    for r in rows:
        if r["video"] not in finished:
            shutil.rmtree(os.path.join(out, r["folder"]), ignore_errors=True)
            continue
        by_clip[r["clip"]] = r
    rows = list(by_clip.values())
    kinds = set(args.kinds.split(","))
    namer = Namer()
    changed = 0
    for r in rows:
        if r["kind"] not in kinds:
            continue
        src = os.path.join(out, r["folder"])
        if not os.path.isdir(src):
            continue
        fs = sorted(p for p in os.listdir(src) if p.endswith(".png"))
        if not fs:
            continue
        frames = [cv2.imread(os.path.join(src, fs[len(fs) // 3])), cv2.imread(os.path.join(src, fs[2 * len(fs) // 3]))]
        kind = "reveal"
        mid, score, nxt, second = sl.name_clip(namer, kind, frames)
        if mid.startswith("pet_"):
            kind = "pet"
        clip = kind + r["clip"][r["clip"].index("_"):]
        rel = os.path.join("" if r["loop_found"] == "yes" else "no_loop", mid or "unknown", clip).replace(os.sep, "/")
        if rel != r["folder"]:
            dst = os.path.join(out, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.rmtree(dst, ignore_errors=True)
            shutil.move(src, dst)
            changed += 1
            print("%s -> %s" % (r["folder"], rel), flush=True)
        r.update({"clip": clip, "kind": kind, "id": mid, "name": namer.names.get(mid, ""), "match": score, "runner_up": nxt, "runner_up_match": second, "folder": rel})
    for base in (out, os.path.join(out, "no_loop")):
        for x in os.listdir(base) if os.path.isdir(base) else []:
            d = os.path.join(base, x)
            if os.path.isdir(d) and not os.listdir(d):
                os.rmdir(d)
    with open(index, "w", encoding="utf8") as f:
        f.write("\t".join(sl.FIELDS) + "\n")
        for r in rows:
            f.write("\t".join(str(r.get(k, "")) for k in sl.FIELDS) + "\n")
    loops = sorted((r for r in rows if r["loop_found"] == "yes"), key=lambda r: (r["id"] == "", r["name"], r["kind"], r["clip"]))
    evo.sheet([(r["folder"], "%s %s" % (r["kind"], r["name"] or "?")) for r in loops], out)
    print("renamed", changed, "rows", len(rows), "loops", len(loops), "named loops", sum(1 for r in loops if r["id"]), "monsters", len({r["id"] for r in loops if r["id"]}), flush=True)


if __name__ == "__main__":
    main()
