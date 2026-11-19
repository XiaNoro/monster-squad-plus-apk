# Lists monsters with missing/odd skill data and skill icons that have no image in assets/skill_icons.
# Usage: python -I tools/skill_audit.py
import json, os, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
mons = json.load(open(os.path.join(ROOT, "data/monsters.json"), encoding="utf-8"))
have = {os.path.splitext(f)[0] for f in os.listdir(os.path.join(ROOT, "assets/skill_icons")) if not f.endswith(".import")}


def icon_ok(icon):
	k = os.path.splitext(icon)[0].replace(" ", "_").lower()
	return any(c in have for c in [k, k.replace("_and_", "_+_"), k.replace("heal_+_cure", "cure"), k.split("_+_")[0]])


counts = collections.Counter()
no_skills, few_skills, no_support, no_icon_name, empty_effects = [], [], [], [], []
missing_icons = collections.defaultdict(list)
for mid, m in mons.items():
	if m.get("material"):
		continue
	sk = m.get("skills") or []
	counts[len(sk)] += 1
	if not sk:
		no_skills.append(mid)
	elif len(sk) < 4 and int(m.get("stars", 1)) >= 3:
		few_skills.append("%s(%d*,%d)" % (mid, m.get("stars", 0), len(sk)))
	sup = m.get("support_skill") or {}
	if not sup.get("name"):
		no_support.append(mid)
	for s in sk + ([sup] if sup.get("name") else []):
		if not s.get("icon"):
			no_icon_name.append("%s:%s" % (mid, s.get("name")))
		elif not icon_ok(s["icon"]):
			missing_icons[s["icon"]].append(mid)
		if s in sk and not s.get("effects"):
			empty_effects.append("%s:%s" % (mid, s.get("name")))

print("non-material monsters by skill count:", dict(sorted(counts.items())))
print("\nno skills (%d):" % len(no_skills), " ".join(sorted(no_skills)))
print("\n3*+ with fewer than 4 skills (%d):" % len(few_skills), " ".join(sorted(few_skills)))
print("\nno support skill (%d):" % len(no_support), " ".join(sorted(no_support)))
print("\nskills without an icon name (%d):" % len(no_icon_name), " ".join(no_icon_name[:80]))
print("\nskills with no parsed effects (%d):" % len(empty_effects), " ".join(empty_effects[:80]))
print("\nicon files referenced but missing (%d):" % len(missing_icons))
for icon, ids in sorted(missing_icons.items(), key=lambda kv: -len(kv[1])):
	print("  %-40s %3d  e.g. %s" % (icon, len(ids), ", ".join(ids[:4])))
