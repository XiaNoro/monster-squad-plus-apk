# Pulls skill tooltips ("<skill name> | <description>") out of the frame OCR files and lists the ones that are
# missing from data/monsters.json for the monster whose card is on screen.
# Usage: python -I tools/harvest_tooltips.py [out.tsv]
import difflib, glob, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
mons = json.load(open(os.path.join(ROOT, "data/monsters.json"), encoding="utf-8"))
by_name = {m["name"].lower(): mid for mid, m in mons.items()}
names = sorted(by_name, key=len, reverse=True)
DESC = re.compile(r"^(attacks?|inflicts?|increases?|decreases?|heals?|recovers?|absorbs?|cures?|poison|stun|reduces?|deals?|revives?|reflects?|provokes?|silences?|freezes?|burns?|bleeds?|armor|all |team|leader)", re.I)
SKIP = re.compile(r"^(hp|atk|def|rec|pet|exp|ok|select|rank|boost|fusion|evolve|magic|stone|awaken|class|evolution|lv[\.:]|mana|party|use|level|store|event|team|tearn|from|by |cube|index|mission|arena|continue|sure|none|remove)", re.I)


def norm(s):
	return re.sub(r"[^a-z0-9 ]", "", s.lower()).strip()


def known(mid, skill):
	m = mons[mid]
	have = [norm(s["name"]) for s in m.get("skills") or []] + [norm((m.get("support_skill") or {}).get("name", ""))]
	return max((difflib.SequenceMatcher(None, norm(skill), h).ratio() for h in have if h), default=0.0)


def card_monster(parts):
	for p in parts[:6]:
		q = re.sub(r"^[\(c9\s]+", "", p).strip().lower()
		for n in names:
			if q == n or (len(n) > 4 and q.startswith(n)):
				return by_name[n]
	return None


found = {}
for f in glob.glob(os.path.join(ROOT, "research/videos/**/ocr*.tsv"), recursive=True):
	video = os.path.basename(os.path.dirname(f))
	for line in open(f, encoding="utf-8", errors="replace"):
		if "\t" not in line:
			continue
		frame, text = line.rstrip("\n").split("\t", 1)
		parts = [p.strip() for p in text.split("|")]
		mid = card_monster(parts)
		if not mid:
			continue
		for i in range(len(parts) - 1):
			name, desc = parts[i], parts[i + 1]
			if not DESC.match(desc) or not re.search(r"\d+ ?%|stage|level \d|ATK", desc, re.I) or len(desc) < 14 or SKIP.match(name) or len(name) < 4 or len(name) > 28 or DESC.match(name):
				continue
			if not re.match(r"^[A-Za-z'][A-Za-z' \-!]+$", name) or norm(name) in by_name:
				continue
			key = (mid, norm(name))
			score = known(mid, name)
			if key not in found or len(desc) > len(found[key][1]):
				found[key] = (name, desc, score, "%s/%s" % (video, frame))

out = open(sys.argv[1], "w", encoding="utf-8") if len(sys.argv) > 1 else None
rows = sorted(found.items(), key=lambda kv: (kv[1][2], kv[0][0]))
for (mid, _), (name, desc, score, where) in rows:
	line = "%s\t%s\t%s\t%.2f\t%s" % (mid, name, desc, score, where)
	if out:
		out.write(line + "\n")
	if score < 0.8:
		print(line.encode("ascii", "replace").decode())
print("tooltips: %d, new (score < 0.8): %d" % (len(rows), sum(1 for r in rows if r[1][2] < 0.8)))
