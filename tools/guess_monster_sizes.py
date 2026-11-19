# Estimates a battle size for every monster that footage never measured (data/monster_sizes.json "guess").
# A monster with a measured relative in its evolution line takes the nearest one's size, scaled by the median growth
# per evolution stage, blended (FAMILY_WEIGHT, in log space) with the usual size for its star rating; the rest take the
# usual size for their star rating (material monsters form their own group). Leave-one-out over the measured monsters:
# family guesses are within 6% at the median and 19% at the 90th percentile, star-only ones 8% and 26%.
# Recolours of one creature (data/monster_variants.json, tools/find_monster_variants.py) share one body size
# ("shared"): the median over the measured ones (or their guesses when none was measured) of size / height factor,
# times each member's factor. It overrides their own measurements.
# Usage: python tools/guess_monster_sizes.py   (the size scanners also run it when they write their summaries)
import json, math, os, statistics, sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data", "monster_sizes.json")
MONSTERS = os.path.join(ROOT, "data", "monsters.json")
VARIANTS = os.path.join(ROOT, "data", "monster_variants.json")
FAMILY_WEIGHT = 0.7


def chain(mons, mid):
    line = [mid]
    a = mid
    while mons[a].get("evolves_from") in mons and mons[a]["evolves_from"] not in line:
        a = mons[a]["evolves_from"]
        line.insert(0, a)
    b = mid
    while mons[b].get("evolves_into") in mons and mons[b]["evolves_into"] not in line:
        b = mons[b]["evolves_into"]
        line.append(b)
    return line


def fill(data):
    mons = json.load(open(MONSTERS, encoding="utf-8"))
    from_battle = float(data.get("lobby_scale", {}).get("from_battle", 1.0))
    known = {m: s["h"] for m, s in data.get("lobby", {}).items() if m in mons}
    known = {m: h / from_battle for m, h in known.items()}
    known.update({m: s["h"] for m, s in data.get("sizes", {}).items() if m in mons})
    group = lambda m: "material" if mons[m].get("material") else int(mons[m].get("stars", 1))
    by = defaultdict(list)
    for m, h in known.items():
        by[group(m)].append(h)
    usual = {g: statistics.median(v) for g, v in by.items()}
    step = statistics.median([known[mons[m]["evolves_into"]] / h for m, h in known.items() if mons[m].get("evolves_into") in known])
    groups = json.load(open(VARIANTS, encoding="utf-8"))["groups"] if os.path.exists(VARIANTS) else []
    groups = [{m: f for m, f in g.items() if m in mons} for g in groups]
    shared = {}
    for g in groups:
        seen = [known[m] / f for m, f in g.items() if m in known]
        if seen:
            body = statistics.median(seen)
            shared.update({m: body * f for m, f in g.items()})
    measured = known
    known = dict(known)
    known.update(shared)
    guess = {}
    for mid in sorted(mons):
        if mid in known:
            continue
        base = usual.get(group(mid), usual.get(int(mons[mid].get("stars", 1)), statistics.median(usual.values())))
        line = chain(mons, mid)
        i = line.index(mid)
        rel = [(abs(j - i), known[o] * step ** (i - j)) for j, o in enumerate(line) if o in known]
        h = base
        if rel:
            near = min(d for d, _ in rel)
            fam = statistics.geometric_mean([v for d, v in rel if d == near])
            h = math.exp(FAMILY_WEIGHT * math.log(fam) + (1.0 - FAMILY_WEIGHT) * math.log(base))
        guess[mid] = round(h, 3)
    for g in groups:
        if g and next(iter(g)) not in shared:
            body = statistics.median([guess[m] / f for m, f in g.items()])
            shared.update({m: body * f for m, f in g.items()})
    data["guess"] = guess
    data["shared"] = {m: round(h, 3) for m, h in sorted(shared.items())}
    data["guess_rule"] = {"evolution_step": round(step, 3), "family_weight": FAMILY_WEIGHT,
                          "usual": {str(g): round(v, 3) for g, v in sorted(usual.items(), key=lambda kv: str(kv[0]))}}
    return len(guess), sum(1 for m in guess if any(o in measured for o in chain(mons, m))), len(shared)


if __name__ == "__main__":
    data = json.load(open(DATA, encoding="utf-8"))
    n, fam, same = fill(data)
    open(DATA, "w", encoding="utf-8").write(json.dumps(data, indent="\t"))
    print("%d monsters guessed (%d from a measured relative), %d share a recolour group's size -> %s" % (n, fam, same, DATA))
