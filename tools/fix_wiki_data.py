# Fixes wiki mistakes in data/monsters.json that the importer can't catch.
# Run after tools/build_db.gd (safe to re-run): python tools/fix_wiki_data.py [--write]
import copy
import json
import os
import re
import statistics
import sys

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATH = os.path.join(ROOT, "data", "monsters.json")
raw = open(PATH, encoding="utf-8").read()
M = json.loads(raw)
log = []


def note(mid, what):
    log.append("%s: %s" % (mid, what))


def dmg(t, m):
    return {"type": "damage", "target": t, "mult": m}


def heal(t, m):
    return {"type": "heal", "target": t, "mult": m}


def buff(stat, t, pct, dur):
    return {"type": "buff", "stat": stat, "target": t, "pct": pct, "duration": dur}


def debuff(stat, t, pct, dur):
    return {"type": "debuff", "stat": stat, "target": t, "pct": pct, "duration": dur}


def dot(kind, stage, t, dur=10.0):
    return {"type": "dot", "kind": kind, "stage": stage, "target": t, "duration": dur}


def stun(t, dur, chance=1.0):
    return {"type": "stun", "target": t, "duration": dur, "chance": chance}


def shield(t, stage, dur):
    return {"type": "shield", "target": t, "stage": stage, "duration": dur}


def pct(m, g):
    return int(m.group(g)) / 100.0


LIFESTEAL = {"type": "lifesteal", "pct": 0.3, "duration": 20.0}
SKILL_RULES = [
    (r"shield all allies \+ (\d+)% hp recovery", lambda m: [shield("all_allies", 1, 15.0), heal("all_allies", pct(m, 1))]),
    (r"heal all (\d+)% \+ (\d+)% attack bonus to all allies", lambda m: [heal("all_allies", pct(m, 1)), buff("atk", "all_allies", pct(m, 2), 20.0)]),
    (r"^(\d+)% (?:atk|attack) bonus to (?:lead|leader) monster$", lambda m: [buff("atk", "leader", pct(m, 1), 20.0)]),
    (r"attack with (\d+)%, disincreases all atk (\d+)%(?: \((\d+)s)?", lambda m: [dmg("enemy", pct(m, 1)), debuff("atk", "all_enemies", pct(m, 2), float(m.group(3) or 3))]),
    (r"(\d+)% attack bonus to all allies \+ (\d+)% defense bonus", lambda m: [buff("atk", "all_allies", pct(m, 1), 20.0), buff("def", "all_allies", pct(m, 2), 20.0)]),
    (r"level (\d) shields? to all allies, speed up", lambda m: [shield("all_allies", int(m.group(1)), 15.0), buff("speed", "all_allies", 0.2, 20.0)]),
    (r"^(\d+)% attack bonus to all allies$", lambda m: [buff("atk", "all_allies", pct(m, 1), 20.0)]),
    (r"increases atk by (\d+)%; attacks with (\d+)% atk", lambda m: [buff("atk", "self", pct(m, 1), 10.0), dmg("enemy", pct(m, 2))]),
    (r"shield (\d) to all allies \[for (\d+)s\]\s*\+ armor bonus \[\+(\d+)% def for (\d+)s\]", lambda m: [shield("all_allies", int(m.group(1)), float(m.group(2))), buff("def", "all_allies", pct(m, 3), float(m.group(4)))]),
    (r"defends against all bad statuses from enemies for (\d+)s", lambda m: [{"type": "immune", "target": "all_allies", "duration": float(m.group(1))}]),
    (r"attacks with (\d+)% atk, reduce (\d+)% attack damage", lambda m: [dmg("enemy", pct(m, 1)), debuff("atk", "enemy", pct(m, 2), 10.0)]),
    (r"armor break with (\d+)% atk \+ \(def down (\d+)s\)", lambda m: [dmg("enemy", pct(m, 1)), debuff("def", "enemy", 0.3, float(m.group(2)))]),
    (r"^removes 1 stat boost from all enemies$", lambda m: [{"type": "dispel", "target": "all_enemies"}]),
    (r"attacks with (\d+)% atk, level (\d) ppowerful frezze", lambda m: [dmg("enemy", pct(m, 1)), dot("freeze", int(m.group(2)), "enemy")]),
    (r"all damage attack (\d+)%; severe burn (\d)", lambda m: [dmg("all_enemies", pct(m, 1)), dot("burn", int(m.group(2)), "all_enemies")]),
    (r"(\d+)% damage to all, level (\d) sever burn", lambda m: [dmg("all_enemies", pct(m, 1)), dot("burn", int(m.group(2)), "all_enemies")]),
    (r"attacks with (\d+)% atk; inflicts bleed (\d)", lambda m: [dmg("enemy", pct(m, 1)), dot("bleed", int(m.group(2)), "enemy")]),
    (r"recover hp hile attacking|recovers hp \[\d+% rec\] while attacking", lambda m: [dict(LIFESTEAL)]),
    (r"^provoke all, self shield$", lambda m: [{"type": "provoke", "duration": 10.0}, shield("self", 2, 15.0)]),
    (r"attacks with (\d+)% atk, stunned for (\d+)s", lambda m: [dmg("enemy", pct(m, 1)), stun("enemy", float(m.group(2)))]),
    (r"(\d+)% to single target \+ (\d+)% stun", lambda m: [dmg("enemy", pct(m, 1)), stun("enemy", 2.0, pct(m, 2))]),
    (r"attacks with (\d+)% atk and stuns fir (\d+)s", lambda m: [dmg("enemy", pct(m, 1)), stun("enemy", float(m.group(2)))]),
    (r"returns (\d+)% dmg per 1 team; atk \+(\d+)%", lambda m: [{"type": "reflect", "pct": pct(m, 1), "duration": 15.0}, buff("atk", "self", pct(m, 2), 15.0)]),
    (r"(?:resurrect|revives?) (?:single|one fallen) (?:ally|enemy) with (\d+)% hp", lambda m: [{"type": "revive", "target": "fallen_ally", "pct": pct(m, 1)}]),
    (r"decreased def by (\d+)% and attacks all with (\d+)% atk", lambda m: [debuff("def", "all_enemies", pct(m, 1), 10.0), dmg("all_enemies", pct(m, 2))]),
    (r"set up the trap inflicting (\d+) dmg in (\d+) sec", lambda m: [{"type": "time_bomb", "target": "enemy", "damage": int(m.group(1)), "delay": float(m.group(2))}]),
    (r"attacks all \(atk (\d+)%\) stage (\d) bleed.*heal hp \((?:(\d+)% rec|rec (\d+)%)\)", lambda m: [dmg("all_enemies", pct(m, 1)), dot("bleed", int(m.group(2)), "all_enemies"), heal("self", int(m.group(3) or m.group(4)) / 100.0)]),
]
ICON_FIXES = {"ATK and DEF Up All.png": "ATK Up All.png"}
TARGET_TEXT = {"enemy": "1 enemy", "all_enemies": "all enemies", "all_allies": "all allies", "leader": "the leader",
               "most_hurt": "the most hurt ally", "random_ally": "a random ally", "self": "self", "fallen_ally": "a fallen ally"}
STAT_TEXT = {"atk": "ATK", "def": "DEF", "rec": "REC", "speed": "Speed", "crit": "Critical Hit", "crit_dmg": "Critical Damage"}


def describe(effects):
    out = []
    for e in effects:
        t = TARGET_TEXT.get(e.get("target", "enemy"), "")
        k = e["type"]
        if k == "damage":
            out.append("Attacks %s with %d%% ATK" % (t, round(e["mult"] * 100)))
        elif k == "heal":
            out.append("Heals %s (%d%% REC)" % (t, round(e["mult"] * 100)))
        elif k == "shield":
            out.append("Stage %d shield to %s for %ds" % (e["stage"], t, e["duration"]))
        elif k in ("buff", "debuff"):
            out.append("%s %s %s%d%% for %ds" % (t[0].upper() + t[1:], STAT_TEXT.get(e["stat"], e["stat"]), "+" if k == "buff" else "-", round(e["pct"] * 100), e["duration"]))
        elif k == "dot":
            out.append("Stage %d %s on %s" % (e["stage"], e["kind"].capitalize(), t))
        elif k == "stun":
            out.append("Stuns %s for %ds" % (t, e["duration"]))
    return "; ".join(out)


def fix_skill(mid, s, label):
    tag = re.search(r"\s*\[(\d+)\]$", s.get("name", ""))
    if tag:
        note(mid, "%s name %r: bracket is its MP cost" % (label, s["name"]))
        s["name"] = s["name"][:tag.start()]
        if "mp" in s:
            s["mp"] = int(tag.group(1))
    d = (s.get("description") or "").strip().lower()
    for rx, build in SKILL_RULES:
        m = re.search(rx, d)
        if m:
            new = build(m)
            if new != s.get("effects"):
                note(mid, "%s %r: %s -> %s" % (label, s.get("name"), sorted({e["type"] for e in s.get("effects", [])}), [e["type"] for e in new]))
                s["effects"] = new
            break
    if s.get("icon") in ICON_FIXES:
        s["icon"] = ICON_FIXES[s["icon"]]
        note(mid, "%s icon -> %s" % (label, s["icon"]))
    if not d and s.get("effects"):
        s["description"] = describe(s["effects"])
        note(mid, "%s %r: described as %r" % (label, s.get("name"), s["description"]))


PASSIVE_JUNK = r"^(none|only made by|found on)"
PASSIVE_TEXT_FIXES = [(r"\bIncre(?:se|ae)s\b", "Increases"), (r"^Increase\b", "Increases"), (r"\bDFE\b", "DEF"), (r"Moonsters", "Monsters"),
                      (r"Normals Monsters", "Normal Monsters"), (r"NormalMonsters", "Normal Monsters"), (r"Monsters;", "Monsters'"),
                      (r"Critical Chances", "Critical Chance"), (r"’", "'"), (r"\bwith (\d+)$", r"by \1")]
PASSIVE_RX = re.compile(r"(?:increases? )?(?:(fire|water|nature|normal|all) (?:type )?monsters?'?s?|(leader)'?s?|(team)'?s?) ?"
                        r"(hp|atk|def|rec|critical hit|critical damage|mp recovery|speed|mp)(?: by| \+| increases by)? ?\+?(\d+)(%?)")
PASSIVE_STATS = {"atk": "atk", "speed": "speed", "critical hit": "crit", "def": "def", "rec": "rec", "hp": "hp",
                 "critical damage": "crit_dmg", "mp recovery": "mp_regen", "mp": "mp"}


def fix_passive(mid, m):
    text = (m.get("passive") or "").strip().lstrip("-").strip()
    if re.match(PASSIVE_JUNK, text.lower()):
        note(mid, "passive %r is not a passive; cleared" % text)
        m["passive"], m["passive_effect"] = "", {}
        return
    for rx, rep in PASSIVE_TEXT_FIXES:
        text = re.sub(rx, rep, text)
    if text != m.get("passive"):
        m["passive"] = text
    if m.get("passive_effect") or not text:
        return
    t = text.lower().replace("critical chance", "critical hit").replace("attack", "atk").replace("monster's", "monsters'")
    t = re.sub(r"\bcritical by", "critical hit by", t)
    r = PASSIVE_RX.search(t)
    if r is None:
        note(mid, "passive still not understood: %r" % text)
        return
    scope = r.group(1) or ("leader" if r.group(2) else "all")
    eff = {"element": scope, "stat": PASSIVE_STATS[r.group(4)]}
    if r.group(6):
        eff["pct"] = int(r.group(5)) / 100.0
    else:
        eff["flat"] = float(r.group(5))
    m["passive_effect"] = eff
    note(mid, "passive %r -> %s" % (text, eff))


def tree(mid):
    return copy.deepcopy(M[mid]["evolution_tree"])


def set_field(mid, key, value):
    if M[mid].get(key) != value:
        note(mid, "%s %r -> %r" % (key, M[mid].get(key), value if key != "evolution_tree" else " > ".join(t["monster"] for t in value)))
        M[mid][key] = value


def fix_evolutions():
    set_field("dark_kong", "evolution_tree", tree("dark_monk"))
    set_field("king_drip", "evolution_tree", tree("sir_drip"))
    set_field("minoeagler", "evolution_tree", tree("minoeaglet"))
    set_field("greenspec", "evolves_from", "")
    set_field("native_eldragon", "evolves_from", "neo_eldragon")
    set_field("owlder", "evolves_from", "marshowl")
    set_field("sir_swoosh", "evolves_from", "lil_swoosh")
    set_field("sir_swoosh", "evolution_tree", tree("lil_swoosh"))
    set_field("darkteim", "evolves_from", "darkra")
    set_field("darkteim", "evolution_tree", tree("darkra"))
    aliases = {"li_l_splish": "lil_splish", "icicel": "icikel"}
    for mid, m in M.items():
        t = m.get("evolution_tree", [])
        for i, step in enumerate(t):
            mat = step.get("material", "")
            q = re.match(r"^(.+?)_x_?(\d+)$", mat)
            if mat == "1" or (i == len(t) - 1 and mat and mat not in M):
                mat = ""
            elif mat in aliases:
                mat = aliases[mat]
            elif q and q.group(1) in M:
                mat = q.group(1)
                step["quantity"] = int(q.group(2))
            if mat != step.get("material", ""):
                note(mid, "tree material %r -> %r" % (step.get("material"), mat))
                step["material"] = mat
        ids = [s["monster"] for s in t]
        if mid in ids:
            i = ids.index(mid)
            if i + 1 < len(t) and t[i]["material"] in M and m.get("evolve_material", "") not in M:
                set_field(mid, "evolve_material", t[i]["material"])
                set_field(mid, "evolve_quantity", t[i]["quantity"])


def tier_stats():
    growth, lv1, lv30 = {}, {}, {}
    for s in range(1, 7):
        rows = [m for m in M.values() if m["stars"] == s and not m.get("material") and int(m["stats"].get("hp", 0)) > 0 and int(m["stats_max"].get("hp", 0)) > 0]
        growth[s] = {k: statistics.median(float(m["stats_max"][k]) / max(1.0, float(m["stats"][k])) for m in rows) for k in ("hp", "atk", "rec")}
        lv1[s] = {k: statistics.median(float(m["stats"][k]) for m in rows) for k in ("hp", "atk", "def", "rec")}
        lv30[s] = {k: statistics.median(float(m["stats_max"][k]) for m in rows) for k in ("hp", "atk", "def", "rec")}
    return growth, lv1, lv30


def odd(v, median):
    return v > 0 and (v > median * 4 or v < median / 4)


def fix_stats():
    growth, med1, med30 = tier_stats()
    for mid, m in M.items():
        if m.get("material"):
            continue
        s = m["stars"]
        lv1, lv30 = m["stats"], m["stats_max"]
        for k in ("hp", "atk", "def", "rec"):
            a, b = int(lv1.get(k, 0) or 0), int(lv30.get(k, 0) or 0)
            if odd(b, med30[s][k]) or (a > 0 and 0 < b < a * 0.8 and not odd(a, med1[s][k])):
                note(mid, "Lv30 %s %d is impossible (Lv1 %d); left to the game's growth fallback" % (k, b, a))
                lv30[k] = 0
            elif k != "def" and b > 0 and not odd(b, med30[s][k]) and (odd(a, med1[s][k]) or (a > 0 and b / a > growth[s][k] * 2.5 and a / med1[s][k] < b / med30[s][k])):
                fixed = round(b / growth[s][k])
                note(mid, "Lv1 %s %d is impossible (Lv30 %d); set to %d" % (k, a, b, fixed))
                lv1[k] = fixed
        s50 = m.get("stats_50") or {}
        if any(0 < int(s50.get(k, 0) or 0) < int(lv30.get(k, 0) or 0) for k in s50):
            note(mid, "Lv50 stats %s are below Lv30; removed" % s50)
            m["stats_50"] = {}


def fix_material_flags():
    wiki = json.load(open(os.path.join(ROOT, "research", "wiki", "wikitext.json"), encoding="utf-8-sig"))
    by_name = {m["name"]: mid for mid, m in M.items()}
    for title, text in wiki.items():
        mid = by_name.get(title)
        if mid is None or not M[mid].get("material"):
            continue
        r = re.search(r"\|\s*material\s*=\s*([^\n|}]*)", text, re.I)
        value = r.group(1).strip() if r else ""
        if value.lower() != "yes" and not title.endswith("Fruit"):
            note(mid, "wiki says material=%r; no longer a material" % value)
            M[mid]["material"] = False


def fill_missing_skills():
    before = len(log)
    for mid, m in M.items():
        if m.get("material") or m.get("skills"):
            continue
        chain = [s["monster"] for s in m.get("evolution_tree", [])]
        if mid in chain:
            i = chain.index(mid)
            near = sorted((x for x in chain if x != mid and x in M and M[x].get("skills")), key=lambda x: abs(chain.index(x) - i))
        else:
            near = [x for x in (m.get("evolves_into"), m.get("evolves_from")) if x in M and M[x].get("skills")]
        if near:
            m["skills"] = copy.deepcopy(M[near[0]]["skills"])
            if not (m.get("support_skill") or {}).get("name"):
                m["support_skill"] = copy.deepcopy(M[near[0]].get("support_skill", {}))
            note(mid, "had no skills; borrowed %d from %s" % (len(m["skills"]), near[0]))
    if len(log) > before:
        fill_missing_skills()


fix_material_flags()
for mid, m in M.items():
    if m.get("material"):
        continue
    fix_passive(mid, m)
fix_evolutions()
fix_stats()
fill_missing_skills()
for mid, m in M.items():
    for i, s in enumerate(m.get("skills", [])):
        fix_skill(mid, s, "skill %d" % (i + 1))
    if (m.get("support_skill") or {}).get("name"):
        fix_skill(mid, m["support_skill"], "support")

print("\n".join(log))
print(len(log), "changes")
if "--write" in sys.argv:
    out = json.dumps(M, ensure_ascii=False, indent="\t", sort_keys=True)
    open(PATH, "w", encoding="utf-8", newline="\n").write(out + ("\n" if raw.endswith("\n") else ""))
    print("written")
