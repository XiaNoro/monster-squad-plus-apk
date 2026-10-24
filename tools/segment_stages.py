# Splits a walkthrough's OCR (research/videos/frames_hd/<id>/ocr.tsv) into stages: field names seen on the
# Select Friend / stage list screens, and each battle's "Stage x/y" wave counter.
# Prints one line per battle: start..end seconds, field name, waves, last-wave frame.
# Usage: python tools/segment_stages.py <video id>
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIELD = re.compile(r"\b(Sprout|Lake|Desert|Moonlight|Boneyard|Bone|Dino|Robo|Sky|Robo)\s?-\s?(\d{1,2})\b", re.I)
WAVE = re.compile(r"Stage\s*(\d)\s*/\s*(\d)", re.I)


def main(vid):
    rows = []
    for line in open(os.path.join(ROOT, "research/videos/frames_hd", vid, "ocr.tsv"), encoding="utf-8-sig"):
        parts = line.rstrip("\n").split("\t", 1)
        if len(parts) < 2 or not parts[0][:4].isdigit():
            continue
        rows.append((int(parts[0][:4]), parts[1]))
    field = "?"
    battles = []
    cur = None
    for t, text in rows:
        f = FIELD.search(text)
        w = WAVE.search(text)
        if f and not w:
            field = "%s-%s" % (f.group(1).capitalize(), f.group(2))
        if "Quest Successful" in text or "Failed" in text:
            if cur:
                cur["end"] = t
                cur["result"] = "win" if "Successful" in text else "lose"
                battles.append(cur)
                cur = None
            continue
        if w:
            x, y = int(w.group(1)), int(w.group(2))
            if cur is None or (x < cur["wave"] and x == 1):
                if cur:
                    battles.append(cur)
                cur = {"field": field, "start": t, "end": t, "waves": y, "wave": x, "last": None, "result": "?"}
            cur["wave"] = max(cur["wave"], x)
            cur["end"] = t
            if x == y and cur["last"] is None:
                cur["last"] = t
    if cur:
        battles.append(cur)
    for b in battles:
        print("%5d-%5d  %-12s waves=%d last=%s %s" % (b["start"], b["end"], b["field"], b["waves"], b["last"], b["result"]))


main(sys.argv[1])
