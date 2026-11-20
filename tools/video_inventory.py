import csv
import glob
import json
import os
import re

import cv2

ROOT = "research/videos"
HQ_ROOT = "F:/monster-squad+/research/videos_hq"
MANIFEST = os.path.join(ROOT, "hq_manifest.tsv")
EXTS = (".mp4", ".webm", ".mkv")
YID = re.compile(r"([A-Za-z0-9_-]{11})$")
EVO = re.compile(r"Evolution Tr", re.I)
REVEAL = re.compile(r"\b(UNCOMMON|COMMON|RARE|EPIC|LEGENDARY|LECENDA\w*|LEGENDA\w*|SUPER ?RARE)\b|Hello Master|Yes Sir", re.I)


def probe(path):
    cap = cv2.VideoCapture(path)
    w, h, fps, n = cap.get(3), cap.get(4), cap.get(5) or 30.0, cap.get(7)
    cap.release()
    return int(w), int(h), float(fps), (n / fps if fps else 0.0)


def manifest():
    out = {}
    if os.path.exists(MANIFEST):
        for r in csv.DictReader(open(MANIFEST, encoding="utf8"), delimiter="\t"):
            out[r["old"]] = r
    return out


_BY_ID = None


def _frames_index():
    global _BY_ID
    if _BY_ID is None:
        _BY_ID = {}
        for d in glob.glob(os.path.join(ROOT, "frames*", "*")):
            if not os.path.isdir(d):
                continue
            m = YID.search(os.path.basename(d))
            if m:
                has_ocr = os.path.exists(os.path.join(d, "ocr.tsv"))
                prev = _BY_ID.get(m.group(1))
                if prev is None or (has_ocr and not prev[1]):
                    _BY_ID[m.group(1)] = (d, has_ocr)
    return _BY_ID


def _frames_dir(folder, base, yid):
    suffix = folder[len("video"):]
    d = os.path.join(ROOT, "frames" + suffix, base)
    if os.path.isdir(d) and os.path.exists(os.path.join(d, "ocr.tsv")):
        return d
    hit = _frames_index().get(yid)
    if hit and (hit[1] or not os.path.isdir(d)):
        return hit[0]
    return d if os.path.isdir(d) else None


def _seconds_per_name(fdir, duration):
    nums = sorted(int(os.path.splitext(f)[0]) for f in os.listdir(fdir) if re.fullmatch(r"\d+\.jpg", f))
    if len(nums) < 2:
        return 2.0
    if nums[1] - nums[0] >= 2 or duration <= 0:
        return 1.0
    return max(1.0, round(duration / max(1, nums[-1])))


def seeds(fdir, k, pattern):
    path = os.path.join(fdir, "ocr.tsv")
    if not os.path.exists(path):
        return []
    out = []
    for line in open(path, encoding="utf-8-sig", errors="ignore"):
        name, _, text = line.partition("\t")
        stem = os.path.splitext(name)[0]
        if stem.isdigit() and pattern.search(text):
            out.append(int(stem) * k)
    return sorted(out)


def videos():
    man = manifest()
    out = []
    olds = set()
    for folder in sorted(d for d in os.listdir(ROOT) if d.startswith("video") and os.path.isdir(os.path.join(ROOT, d))):
        for f in os.listdir(os.path.join(ROOT, folder)):
            if os.path.splitext(f)[1] in EXTS:
                olds.add("%s/%s" % (folder, f))
    olds.update(o for o, r in man.items() if r.get("status") == "done")
    for old in sorted(olds):
        folder, f = old.split("/", 1)
        base, ext = os.path.splitext(f)
        info_path = os.path.join(ROOT, folder, base + ".info.json")
        m = YID.search(base)
        yid = m.group(1) if m else ""
        if os.path.exists(info_path):
            try:
                yid = json.load(open(info_path, encoding="utf8")).get("id", yid)
            except ValueError:
                pass
        out.append({"folder": folder, "file": f, "base": base, "old": old, "yid": yid, "info": info_path if os.path.exists(info_path) else "", "hq": man.get(old, {})})
    seen = {}
    for v in out:
        path = os.path.join(ROOT, v["old"])
        if v["hq"].get("status") == "done" and os.path.exists(v["hq"]["new"]):
            v["path"] = v["hq"]["new"]
        elif os.path.exists(path):
            v["path"] = path
        else:
            v["path"] = ""
        v["frames"] = _frames_dir(v["folder"], v["base"], v["yid"])
        v["dup"] = v["yid"] in seen
        seen.setdefault(v["yid"], v)
    return out


def attach_seeds(v):
    v["evo"], v["reveal"] = [], []
    if not v["frames"] or not v["path"]:
        return v
    _, _, _, dur = probe(v["path"])
    k = _seconds_per_name(v["frames"], dur)
    v["evo"] = seeds(v["frames"], k, EVO)
    v["reveal"] = seeds(v["frames"], k, REVEAL)
    return v
