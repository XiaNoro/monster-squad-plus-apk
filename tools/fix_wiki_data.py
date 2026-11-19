# Fixes wiki mistakes in data/monsters.json that the importer can't catch.
# Run after tools/build_db.gd (safe to re-run): python tools/fix_wiki_data.py [--write]
import copy
import json
import math
from collections import Counter
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
ESTIMATE_MAX_GAP = 0.5


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


def icon_for(effects):
    kinds = {e["type"]: e for e in effects}
    group = any(e.get("target") in ("all_enemies", "all_allies") for e in effects)
    suffix = " All.png" if group else ".png"
    if "dot" in kinds:
        return kinds["dot"]["kind"].capitalize() + suffix
    if "stun" in kinds:
        return "Stun + Attack All.png" if group and "damage" in kinds else "Stun.png"
    if "heal" in kinds:
        return "Attack + Heal.png" if "damage" in kinds else "Heal" + suffix
    if "debuff" in kinds:
        stat = STAT_TEXT.get(kinds["debuff"]["stat"], "ATK")
        return "Attack + DEF Down.png" if "damage" in kinds and stat == "DEF" else "%s Down%s" % (stat, suffix)
    if "buff" in kinds:
        return "%s Up%s" % (STAT_TEXT.get(kinds["buff"]["stat"], "ATK"), suffix)
    if "shield" in kinds:
        return "Shield" + suffix
    return "Attack_All.png" if group else "Attack.png"


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
    if not s.get("icon") and s.get("effects"):
        s["icon"] = icon_for(s["effects"])
        note(mid, "%s %r: icon picked from its effects: %s" % (label, s.get("name"), s["icon"]))
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
            if i + 1 < len(t) and t[i]["material"] in M:
                set_field(mid, "evolve_material", t[i]["material"])
                set_field(mid, "evolve_quantity", t[i]["quantity"])
            elif i + 1 == len(t) and not m.get("evolves_into"):
                set_field(mid, "evolve_material", "")
                set_field(mid, "evolve_quantity", 1)


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


def sk(name, icon, mp, effects, desc=""):
    return {"name": name, "icon": icon, "mp": mp, "effects": effects, "description": desc or describe(effects)}


def sup(name, icon, effects, desc=""):
    return {"name": name, "icon": icon, "cooldown": 12.0, "effects": effects, "description": desc or describe(effects)}


# Icons read off monster cards in footage (research/videos/findings.md, "Skill pass"); names in quotes on the card
# tooltips are real, the rest are placeholders in the game's own naming style.
FOOTAGE_SKILLS = {
    "elit_centaur": ([
        sk("Stun Strike", "Stun.png", 60, [dmg("enemy", 1.5), stun("enemy", 3.0)]),
        sk("Centaur Rush", "Attack All.png", 100, [dmg("all_enemies", 1.2)]),
        sk("Piercing poison", "Poison All.png", 100, [dot("poison", 2, "all_enemies"), debuff("def", "all_enemies", 0.3, 10.0)], "Inflicts Poison 2stage, DEF Down"),
        sk("Basic Speed Down", "Speed Down.png", 40, [debuff("speed", "enemy", 0.25, 20.0)]),
    ], sup("Poison Arrow", "Poison All.png", [dmg("enemy", 1.0), dot("poison", 1, "all_enemies")])),
    "lightning_spirit": ([
        sk("Volt Charge", "ATK Up.png", 40, [buff("atk", "leader", 0.5, 20.0)]),
        sk("Thunder Storm", "Stun + Attack All.png", 150, [dmg("all_enemies", 1.5), stun("all_enemies", 2.0, 0.3)]),
        sk("Spirit Heal", "Heal.png", 60, [heal("most_hurt", 2.0)]),
        sk("Call Lightning", "Bleed.png", 100, [dmg("enemy", 3.0), dot("bleed", 2, "enemy")], "Attack with 300% ATK; inflicts Stage 2 Bleed"),
    ], sup("Lightning Bite", "Bleed.png", [dmg("enemy", 1.5), dot("bleed", 1, "enemy")])),
    "void_genie": ([
        sk("Basic Speed Down", "Speed Down.png", 40, [debuff("speed", "enemy", 0.25, 20.0)]),
        sk("Genie Storm", "Attack All.png", 100, [dmg("all_enemies", 1.2)]),
        sk("Basic Total ATK Down", "ATK Down All.png", 100, [debuff("atk", "all_enemies", 0.25, 20.0)]),
        sk("Void Punch", "Attack.png", 60, [dmg("enemy", 2.5)]),
    ], sup("Void Punch", "Attack.png", [dmg("enemy", 1.5)])),
    "blue_dragongod": ([
        sk("Dragon Blessing", "Heal All.png", 60, [heal("all_allies", 1.5)]),
        sk("Dragon Roar", "ATK Up All.png", 100, [buff("atk", "all_allies", 0.5, 20.0)]),
        sk("Dragon Scale Barrier", "Shield All.png", 100, [shield("all_allies", 3, 15.0)]),
        sk("Frozen Storm", "Freeze All.png", 150, [dmg("all_enemies", 1.8), dot("freeze", 2, "all_enemies")]),
    ], sup("Dragon Scale Barrier", "Shield All.png", [shield("all_allies", 1, 10.0)])),
    "skulme": ([
        sk("Quick Heal", "Heal.png", 40, [heal("most_hurt", 1.5)]),
        sk("Bone Toss", "Attack.png", 40, [dmg("enemy", 2.0)]),
    ], sup("Bone Toss", "Attack.png", [dmg("enemy", 1.5)])),
}


def footage_skills():
    for mid, (skills, support) in FOOTAGE_SKILLS.items():
        if mid in M and not M[mid].get("skills"):
            M[mid]["skills"] = copy.deepcopy(skills)
            M[mid]["support_skill"] = copy.deepcopy(support)
            note(mid, "skills from footage card: %s" % ", ".join(s["name"] for s in skills))
    for s in M["e_zakum"]["skills"] + [M["e_zakum"]["support_skill"]]:
        if s["name"] == "Zakum Leech" and s["effects"][0]["mult"] != 2.0:
            s["effects"][0]["mult"] = 2.0
            s["description"] = "Attacks with 200% ATK; Heal HP (REC 100%)"
            note("e_zakum", "Zakum Leech 200% from footage card (RYKrWYyQHx4 0126)")
    for s in M["flame_knight"]["skills"]:
        if s["name"] == "Piercing fire" and not s.get("icon"):
            s["icon"] = "Attack + DEF Down.png"
            note("flame_knight", "Piercing fire icon from footage card")
    if int(M["blue_dragongod"]["stats"].get("hp", 0)) == 0:
        set_field("blue_dragongod", "stats", {"hp": 4079, "atk": 565, "def": 187, "rec": 658, "mp": 240})
    set_field("blue_dragongod", "passive", "All Monsters' ATK + 50%")
    set_field("blue_dragongod", "passive_effect", {"element": "all", "pct": 0.5, "stat": "atk"})
    if not M["blue_dragongod"].get("location"):
        set_field("blue_dragongod", "location", "Mystery Box")
    set_field("caocao", "location", "Temple of Four Elements (hell)")
    set_field("flame_knight", "passive", "Increases Fire Monsters' ATK by 50%")
    set_field("flame_knight", "passive_effect", {"element": "fire", "pct": 0.5, "stat": "atk"})
    for mid, p in (("aqua_spirit", 40), ("undine", 45)):
        set_field(mid, "passive", "Increases Water Monsters' ATK by %d%%" % p)
        set_field(mid, "passive_effect", {"element": "water", "pct": p / 100, "stat": "atk"})


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


FOOTAGE_STATS = {
    "ceratoking": {"stats_max": {"hp": 4725, "atk": 665}},
    "darkrake": {"stats_max": {"hp": 3014, "atk": 1033}},
    "flame_eldragon": {"stats_max": {"hp": 4833, "atk": 733}},
    "glacial_eldragon": {"stats_max": {"hp": 3407, "atk": 477}},
    "native_eldragon": {"stats_max": {"hp": 3614, "atk": 473}},
    "voidina": {"stats_max": {"hp": 2284, "atk": 753}},
    "e_pink_bean": {"stats_max": {"hp": 2838, "atk": 595}},
    "ceres": {"stats_max": {"hp": 1370, "atk": 615, "def": 46, "rec": 341}},
    "burdon": {"stats_max": {"hp": 2286, "atk": 318, "def": 99, "rec": 556}},
    "e_zakum": {"stats": {"hp": 1798, "atk": 290, "def": 122, "rec": 364}, "stats_max": {"hp": 2581, "atk": 348, "def": 122, "rec": 625}},
    "gusdon": {"stats": {"hp": 2432}},
    "kangard": {"stats_max": {"hp": 2733, "atk": 871, "def": 52, "rec": 519}},
    "jackolantern": {"stats_max": {"atk": 840}},
    "flame_sprite": {"stats_max": {"rec": 643}},
    "twinblaze": {"stats": {"atk": 498}},
    "zayn": {"stats_max": {"atk": 290}},
    "charmew": {"stats_max": {"hp": 3128, "atk": 447, "rec": 686}},
    "stoneheart": {"stats_max": {"hp": 2849, "atk": 423, "rec": 602}},
    "drakoon": {"stats_max": {"hp": 3575, "atk": 550, "def": 165, "rec": 633}},
}


def footage_stats():
    for mid, fields in FOOTAGE_STATS.items():
        for key, vals in fields.items():
            M[mid][key].update(vals)
        note(mid, "stats from footage cards: %s" % fields)


# Loading-screen lines read off footage (research/videos/frames*/*/ocr.tsv).
FOOTAGE_QUOTES = {
    "ant_queen": "I am the queen of ant army.",
    "aqua_bat": "You are not welcome here!",
    "aquacron": "I am colder than ice baby!",
    "aquahopper": "Beyond the power of Lv. 30!",
    "aquarell": "Don't be surprised if I disappear.",
    "aqusa": "Prepare for mummification.",
    "banana_dragon": "This is my true form!",
    "banasnake": "Do not eat the banana peel.",
    "beblaze": "Less yapping, more slapping!",
    "beetortle": "I may be small, but I dream big.",
    "blossom_knight": "Feel the wrath of my blossoming sword",
    "bluebella": "Enough drops of water'll make a hole in a stone.",
    "bud_knight": "Careful! The flowers haven't bloomed yet",
    "centaur": "All heroes are born from me",
    "ceratoking": "An ancient power is slowly rising!",
    "chilla": "You'll never win if you don't try hard.",
    "cumulo": "I'll blow you out like a candle if you come near me!",
    "damage_dog": "If you can punch, you can be punched.",
    "dark_ena": "There's no escaping my icy gaze!",
    "dark_knight": "I dwell in the darkest place",
    "darkrake": "When I stare into the abyss, the abyss stares back at me",
    "deramax": "A new ice age begins!",
    "derastorm": "A new ice age begins!",
    "drakan": "I am the hardest shield ever.",
    "drakoon": "Are you looking for stronger power?",
    "elit_centaur": "I am the master of all heroes",
    "evil_ena": "There's no escaping my icy gaze!",
    "evil_hy": "The fire in my eyes is enough to burn you!",
    "expert_joun": "I am the mighty spear master!",
    "fire_genie": "I'm Fire genie",
    "fire_sprite": "I am the flame of ancient.",
    "flame_eldragon": "I will burn everything with the ancient fire!",
    "flame_sprite": "My fire is everlasting!",
    "flamell": "Want to see a magic trick?",
    "forinas": "Enchanting, aren't I?",
    "frivolaze": "What can you sacrifice for your dreams?",
    "frivolycan": "What can you sacrifice for your dreams?",
    "gateau": "What is your favorite sweet?",
    "ghouldrop": "Brrrrrrrrr...",
    "ghoulflame": "Buuuuurns...",
    "ghoulfrost": "Brrrrrrrrr...",
    "glacial_eldragon": "I live beneath the deep blue",
    "goliath": "With patience, the thirsty root breaks stone.",
    "granubis": "Let me guide you after death.",
    "granuka": "Let me guide you after death.",
    "grochiss": "We're in this together, no matter what!",
    "gusdon": "If ya don't got brains, use brawn instead!",
    "humbath": "You think I can't beat you?",
    "iron_bear": "These claws of mine? Might want to avoid them.",
    "kaios": "We are chained by fate, you and I.",
    "kalper": "You could wait, but when will chance come again?",
    "leaf_genie": "I'm Leaf genie",
    "leaf_spirit": "Listen to the whispers of life",
    "lightning_spirit": "Lightning is the most powerful weapon to illuminate the darkness",
    "luxhopper": "Beyond the power of Lv. 30!",
    "magroon": "Punch! Punch! Punch with the fire in my heart!",
    "mandrake": "Feel the power of the great nature!",
    "megacrush": "The terror begins.",
    "megania": "I will protect nature with my iron antlers.",
    "megaslamma": "I. Will. Destroy. You.",
    "minohawk": "Chaos! Destruction! Oblivion!",
    "minothrush": "Face oblivion!",
    "moss_bat": "Silence, intruder!",
    "native_eldragon": "Finally... I've awaken from the unknown jungle.",
    "naturia_eldragon": "Beware! The Deep forest is very dangerous.",
    "noxhopper": "Beyond the power of Lv. 30!",
    "patrox": "You'll pay for abusing Mother Nature!",
    "roklam": "The earth will be here long after you're gone.",
    "rudolph": "We give presents to good kids!",
    "slime_king": "One must eat to become strong.",
    "stabeak": "Try me. I dare ya.",
    "stellar_eldragon": "My power will send everything to the next dimension!",
    "stoneheart": "When you look into darkness, it often looks back.",
    "thornton": "Stand on your own two legs!",
    "torizo": "Ride the winds with me.",
    "tramacron": "Do you feel that? It's the heat of my breath!",
    "tundra_eldragon": "Beware! The deep sea is very cold.",
    "turto_kaiser": "Life begins at one hundred years old.",
    "ultrang": "I'm not the giving tree.",
    "ultraroost": "Eat chicken not me!",
    "undine": "I'm beautiful and dangerous as a deep lake",
    "uranger_g": "You can take on the world with a friend.",
    "void_genie": "I'm Void genie",
    "void_knight": "Darkness is my strength",
    "voidina": "I come from a deep space",
    "volt_spirit": "I'm a spirit that controls lightning.",
    "water_genie": "I'm Water genie",
    "wetnia": "I am cold blooded.",
}


def footage_quotes():
    for mid, q in FOOTAGE_QUOTES.items():
        if mid in M and not M[mid].get("quote"):
            M[mid]["quote"] = q
            note(mid, "quote from loading screen")


def fill_stats_from_recolours():
    keys = ("hp", "atk", "def", "rec")
    groups = {}
    for mid, m in M.items():
        if m.get("material") or int(m["stats"].get("hp", 0)) <= 0:
            continue
        groups.setdefault((m["stars"],) + tuple(int(m["stats"][k]) for k in keys), []).append(mid)
    for ids in groups.values():
        votes = Counter(tuple(int(M[x]["stats_max"][k]) for k in keys) for x in ids if int(M[x]["stats_max"].get("hp", 0)) > 0)
        if not votes:
            continue
        top, n = votes.most_common(1)[0]
        if len(votes) > 1 and (n < 3 or n < 0.75 * sum(votes.values())):
            continue
        src = next(x for x in ids if tuple(int(M[x]["stats_max"][k]) for k in keys) == top)
        for mid in ids:
            cur = tuple(int(M[mid]["stats_max"].get(k, 0)) for k in keys)
            if cur == top or "stats_max" in FOOTAGE_STATS.get(mid, {}):
                continue
            M[mid]["stats_max"].update(dict(zip(keys, top)))
            note(mid, "Lv30 stats %s -> %s, as most of its recolours (%s)" % (cur, top, src) if cur[0] > 0 else "had no Lv30 stats; copied from %s (same Lv1 stats)" % src)


def reset_estimates():
    for m in M.values():
        if m.pop("stats_estimated", None):
            for part in m.pop("stats_estimated_parts"):
                for k in ("hp", "atk", "rec"):
                    m[part][k] = 0


def estimate_missing_stats():
    keys = ("hp", "atk", "rec")
    def has(m, part):
        return int((m.get(part) or {}).get("hp", 0)) > 0

    real = [m for m in M.values() if not m.get("material") and all(int((m.get(p) or {}).get(k, 0)) > 0 for p in ("stats", "stats_max") for k in keys)]
    variants = json.load(open(os.path.join(ROOT, "data", "monster_variants.json"), encoding="utf-8"))["groups"]

    def nearest(m, part, n=3):
        def gap(x):
            return sum(math.log(m[part][k] / x[part][k]) ** 2 for k in keys if int(m[part].get(k, 0)) > 0)
        pool = sorted((x for x in real if x["stars"] == m["stars"]), key=gap)[:n]
        return pool, gap(pool[0])

    def mark(mid, part, how):
        m = M[mid]
        m["stats_estimated"] = True
        m.setdefault("stats_estimated_parts", []).append(part)
        note(mid, "%s estimated (%s): %s" % ("Lv1" if part == "stats" else "Lv30", how, [m[part][k] for k in keys]))

    def step(a, b):
        out = {}
        for k in keys + ("def",):
            r = [M[x["evolves_into"]]["stats"][k] / x["stats"][k] for x in real
                 if x["stars"] == a and x.get("evolves_into") in M and M[x["evolves_into"]]["stars"] == b
                 and has(M[x["evolves_into"]], "stats") and x["stats"][k] > 0]
            out[k] = statistics.median(r)
        return out

    for mid, m in sorted(M.items()):
        if has(m, "stats") or m.get("material"):
            continue
        group = next((g for g in variants if mid in g), {})
        same = [M[x] for x in group if x != mid and x in M and has(M[x], "stats") and M[x]["stars"] == m["stars"]]
        up, down = M.get(m.get("evolves_into") or ""), M.get(m.get("evolves_from") or "")
        if all(int(m["stats_max"].get(k, 0)) > 0 for k in keys):
            pool, _ = nearest(m, "stats_max")
            for k in keys:
                m["stats"][k] = round(m["stats_max"][k] / statistics.median(x["stats_max"][k] / x["stats"][k] for x in pool))
            how = "Lv30 stats worked back through %s" % ", ".join(x["id"] for x in pool)
        elif same:
            for k in keys + ("def",):
                m["stats"][k] = round(statistics.median(x["stats"][k] for x in same))
            how = "median of its recolours %s" % ", ".join(x["id"] for x in same)
        elif up and down and has(up, "stats") and has(down, "stats"):
            for k in keys + ("def",):
                m["stats"][k] = round(math.sqrt(up["stats"][k] * down["stats"][k]))
            how = "midpoint of %s and %s" % (down["id"], up["id"])
        elif up and has(up, "stats"):
            r = step(m["stars"], up["stars"])
            for k in keys + ("def",):
                m["stats"][k] = round(up["stats"][k] / r[k])
            how = "%s divided by the usual %d-to-%d-star evolution gain" % (up["id"], m["stars"], up["stars"])
        else:
            continue
        if int(m["stats"].get("def", 0)) <= 0:
            m["stats"]["def"] = round(statistics.median(x["stats"]["def"] for x in real if x["stars"] == m["stars"]))
        mark(mid, "stats", how)

    for mid, m in sorted(M.items()):
        todo = [k for k in keys if int(m["stats_max"].get(k, 0)) <= 0]
        if not has(m, "stats") or not todo or m.get("material"):
            continue
        pool, gap = nearest(m, "stats")
        if gap > ESTIMATE_MAX_GAP:
            continue
        for k in todo:
            m["stats_max"][k] = round(m["stats"][k] * statistics.median(x["stats_max"][k] / x["stats"][k] for x in pool))
        if int(m["stats_max"].get("def", 0)) <= 0:
            m["stats_max"]["def"] = m["stats"]["def"]
        mark(mid, "stats_max", "growth of the closest %d-star profiles %s" % (m["stars"], ", ".join(x["id"] for x in pool)))


fix_material_flags()
for mid, m in M.items():
    if m.get("material"):
        continue
    fix_passive(mid, m)
fix_evolutions()
reset_estimates()
fix_stats()
footage_stats()
fill_stats_from_recolours()
estimate_missing_stats()
footage_quotes()
footage_skills()
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
