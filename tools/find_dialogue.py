# Lists in-battle dialogue candidates from a video's OCR: sentence-like text seen on frames that also show
# "Stage x/y", grouped by the field name last seen.  Usage: python tools/find_dialogue.py <video id> [...]
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIELD = re.compile(r"\b(Sprout|Lake|Desert|Moonlight|Boneyard|Robo)\s?-\s?(\d{1,2})\b", re.I)
SKIP = re.compile(r"Monsters'|leader's|Critical|Shield|Barrier|Claws|Heal|Orb|Touch|Order|Stage|Lv\.|Rank|Loading|Tip", re.I)

for vid in sys.argv[1:]:
    field = "?"
    seen = set()
    print("##", vid)
    for line in open(os.path.join(ROOT, "research/videos/frames_hd", vid, "ocr.tsv"), encoding="utf-8-sig"):
        parts = line.rstrip("\n").split("\t", 1)
        if len(parts) < 2:
            continue
        t, text = parts
        f = FIELD.search(text)
        if f and "Stage" not in text:
            field = "%s-%s" % (f.group(1).capitalize(), f.group(2))
        for seg in text.split(" | "):
            seg = seg.strip()
            if len(seg) < 18 or SKIP.search(seg) or not re.search(r"[a-z]{3,} [a-z]{2,}", seg):
                continue
            key = re.sub(r"\W", "", seg.lower())[:30]
            if key in seen:
                continue
            seen.add(key)
            print("%s  %-13s %s" % (t[:4], field, seg))
