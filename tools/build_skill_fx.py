import glob
import json
import os
import re

import cv2
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, "assets", "apk", "sprites")
OUT = os.path.join(ROOT, "data", "skill_fx.json")
LETTERS = "fwnk"

FOOTAGE = {
    "Flaming Claws": {"aura": "p_f_circle_2", "cast": "c_f_launch", "travel": "c_f_ball", "hit": "h_f_explosion_1", "hit2": "h_f_explosion_3"},
    "Dark Orb": {"cast": "c_b_launch2", "travel": "c_k_ball", "hit": "h_k_explosion_1"},
    "Frozen Punisher": {"charge": "p_w_Sconcentrate_1", "sweep": "c_w_laser", "hit": "h_w_explosion_1", "hit2": "h_w_base_4", "delay": 0.5},
    "Basic Total Heal": {"aura": "p_w_circle_2", "land": "c_heal_1"},
    "Emergency Heal": {"aura": "p_w_light_2", "land": "c_heal2"},
    "Advanced Total Barrier": {"aura": "p_w_magiccircle_2", "land": "t_shield_1"},
    "Iron Shield": {"aura": "p_w_magiccircle_2", "land": "t_shield_1"},
    "Basic Total ATK Up": {"aura": "p_b_circle_1", "land": "c_buff_1", "icon": "c_bufficon_attack"},
    "Hunter's Trick": {"cast": "c_f_launch", "land": "c_debuff_1", "icon": "c_debufficon_defense"},
    "Lightning Strike": {"aura": "c_b_fall", "hit": "h_b_fall", "hit2": "h_w_explosion_1", "delay": 0.45},
    "Iron Laser": {"aura": "p_w_circle_1", "sweep": "c_w_laser", "hit": "h_w_base_4", "delay": 0.4},
    "Panda Stun Punch": {"hit": "c_cut_2", "hit2": "h_n_base_2"},
    "Falling Darkness": {"aura": "p_k_circle_2", "hit": "c_magma_2", "tint": "#b04cff", "hit2": "h_k_explosion_1", "delay": 0.45},
    "Meteor Kick": {"aura": "p_k_circle_2", "hit": "c_magma_2", "tint": "#b04cff", "hit2": "h_k_explosion_1", "delay": 0.45},
    "Fireball": {"cast": "c_f_launch", "travel": "c_f_ball", "hit": "h_f_explosion_3"},
    "Fire Breath": {"aura": "c_b_whirlwave_1", "charge": "p_f_concentrate1_2", "sweep": "c_f_laser", "hit": "h_f_explosion_1", "delay": 0.45},
    "Charge": {"lunge": True, "hit": "c_cut_2", "hit2": "h_diagonalcut_1", "delay": 0.2},
    "Blade of Light": {"hit": "c_cut_2", "hit2": "c_magma_2", "tint2": "#fff2a0"},
    "Claw of Darkness": {"aura": "p_k_circle_2", "charge": "p_k_Sconcentrate_1", "hit": "h_k_explosion_1", "delay": 0.45},
}

SIGNATURES = [
    (r"\bbreath\b|\bflame(thrower)?\b|\binferno\b|\bblaze\b", {"sweep": "c_{e}_breath", "hit": "h_{e}_explosion_1"}),
    (r"laser|beam|cannon|\bray\b|blaster", {"aura": "p_{e}_circle_1", "sweep": "c_{e}_laser", "hit": "h_{e}_base_4", "delay": 0.4}),
    (r"quake|earth|crush|rage|eruption|crystal|sprout|thorn", {"sweep": "c_{e}_quake_2", "hit": "h_{e}_explosion_1", "delay": 0.45}),
    (r"lightning|thunder|electric|shock|volt|spark|storm", {"aura": "c_b_fall", "hit": "h_b_fall", "hit2": "h_{e}_explosion_1", "delay": 0.45}),
    (r"magma|volcano|meteor|pillar", {"hit": "c_magma_2", "hit2": "h_f_explosion_3", "delay": 0.4}),
    (r"snake|vine|serpent", {"sweep": "c_n_snake_1", "hit": "h_n_explosion_1", "delay": 0.45}),
    (r"darkness|shadow|void|black|curse|grudge|cursed", {"aura": "p_k_circle_2", "charge": "p_k_Sconcentrate_1", "hit": "h_k_explosion_1", "delay": 0.45}),
    (r"slash|blade|edge|cut|sword|claw|scythe|chop", {"hit": "c_cut_2", "hit2": "h_diagonalcut_1"}),
    (r"spear|needle|arrow|shot|pierce|sting|bullet|harpoon|lance", {"cast": "c_{e}_launch", "travel": "c_pierceprojectile_1", "hit": "c_pierce_2", "hit2": "h_pierce_1", "fly": 0.18}),
    (r"bite|fang|jaw|drain|blood|vampir", {"hit": "c_bite_1", "hit2": "h_{e}_base_1"}),
    (r"punch|fist|kick|uppercut|smash|hammer|slam|knuckle", {"hit": "c_punch_3", "hit2": "h_{e}_base_2"}),
    (r"\bice\b|frost|frozen|freeze|blizzard|snow", {"cast": "c_w_launch", "travel": "c_iceball_1", "hit": "h_w_explosion_1"}),
    (r"wind|tornado|whirl|tempest|cyclone|gust|wing", {"sweep": "c_b_whirlwave_1", "hit": "h_{e}_base_4", "delay": 0.4}),
    (r"web|spider", {"hit": "h_web_1"}),
    (r"dash|charge|ram\b|rush|tackle|comet", {"cast": "c_charge_1", "hit": "h_{e}_explosion_1"}),
    (r"star|light|holy|shower", {"aura": "p_b_circle_1", "hit": "h_b_explosion_1"}),
    (r"ball|orb|bomb|fireball|bubble", {"cast": "c_{e}_launch", "travel": "c_{e}_ball", "hit": "h_{e}_explosion_1"}),
]

MELEE_FAMILIES = ("eldrake", "eldragon", "rookie", "lucky")
ATTACK_BY = {"rookie": "tarang_attack01", "lucky": "tarang_attack01"}
MELEE = {"c_cut_2", "c_punch_3", "c_bite_1", "h_web_1"}
BUFF_ICON = {"atk": "c_bufficon_attack", "crit": "c_bufficon_critical", "speed": "c_bufficon_speed"}
DEBUFF_ICON = {"def": "c_debufficon_defense", "speed": "c_debufficon_speed"}

ALIAS = {
    "c_k_launch": "c_b_launch2",
    "c_w_breath": "c_w_quake_2",
    "c_n_breath": "c_n_quake_2",
    "c_k_breath": "c_k_laser",
    "c_k_quake_2": "c_n_quake_2",
    "p_n_circle_1": "p_b_circle_1",
    "p_n_circle_2": "p_b_circle_1",
    "h_w_explosion_3": "h_w_explosion_1",
    "h_n_explosion_3": "h_n_explosion_1",
    "h_k_explosion_3": "h_k_explosion_1",
    "h_k_base_2": "h_k_base_1",
    "h_k_base_4": "h_k_explosion_1",
    "h_n_base_4": "h_n_explosion_1",
    "p_n_Sconcentrate_1": "p_n_Sconcentrate_1",
}


NAMED = {
    "Statue Guard": {"aura": "p_w_magiccircle_2", "land": "k_zakumbarrier_1"},
}
ULTIMATE_CHARGE = {
    ("water", "single"): "p_w_concentrate2_1",
    ("water", "aoe"): "p_w_concentrate2_2",
    ("nature", "single"): "p_n_Sconcentrate_2",
    ("nature", "aoe"): "p_n_Sconcentrate_2",
}


def offsets(have):
    out = {}
    for d in sorted(have):
        if d[:2] not in ("c_", "h_", "k_", "p_", "t_"):
            continue
        mask = None
        for f in sorted(glob.glob(os.path.join(SPRITES, d, d + "_*.png"))):
            im = cv2.imread(f, cv2.IMREAD_UNCHANGED)
            if im is None or im.ndim < 3 or im.shape[2] < 4:
                continue
            a = im[..., 3] > 24
            mask = a if mask is None else (mask | a if mask.shape == a.shape else mask)
        if mask is None or not mask.any():
            continue
        ys, xs = np.nonzero(mask)
        h, w = mask.shape
        dx = round((xs.min() + xs.max()) / 2 - w / 2)
        dy = round((ys.min() + ys.max()) / 2 - h / 2)
        if abs(dx) > 2 or abs(dy) > 2:
            out[d] = [dx, dy]
    return out


def sheets():
    return {d for d in os.listdir(SPRITES) if os.path.isdir(os.path.join(SPRITES, d))}


def kind(skill):
    types = [e["type"] for e in skill["effects"]]
    targets = [e.get("target") for e in skill["effects"]]
    first = types[0] if types else ""
    if "damage" in types:
        return "aoe" if "all_enemies" in targets else "single"
    if first in ("heal",):
        return "heal_all" if "all_allies" in targets else "heal"
    return first


def rule(skill, element):
    k = kind(skill)
    effects = skill["effects"]
    stats = [e.get("stat") for e in effects if e["type"] == "buff"]
    dstats = [e.get("stat") for e in effects if e["type"] == "debuff"]
    s = {}
    if k == "single":
        s = {"aura": "p_{e}_circle_1", "charge": "p_{e}_concentrate1_1", "cast": "c_{e}_launch", "travel": "c_{e}_ball", "hit": "h_{e}_explosion_1"}
    elif k == "aoe":
        s = {"aura": "p_{e}_circle_2", "charge": "p_{e}_Sconcentrate_1", "cast": "c_{e}_launch", "hit": "h_{e}_explosion_1", "hit2": "h_{e}_base_4", "delay": 0.45}
    elif k == "heal":
        s = {"aura": "p_w_light_2", "land": "c_heal2"}
    elif k == "heal_all":
        s = {"aura": "p_w_circle_2", "land": "c_heal_1"}
    elif k == "buff":
        s = {"aura": "p_b_circle_1", "land": "c_buff_1"}
        if stats and stats[0] in BUFF_ICON:
            s["icon"] = BUFF_ICON[stats[0]]
    elif k == "shield":
        s = {"aura": "p_w_magiccircle_2", "charge": "c_shield_1", "land": "t_shield_1"}
    elif k in ("debuff", "dispel", "stun", "silence", "dot", "time_bomb", "shield_break"):
        s = {"aura": "p_{e}_circle_1", "cast": "c_{e}_launch", "hit": "h_{e}_base_2"}
    elif k == "cleanse":
        s = {"aura": "p_w_circle_1", "land": "t_extraglow_b_1"}
    elif k == "reflect":
        s = {"aura": "p_b_circle_1", "charge": "c_thorn_1"}
    elif k in ("provoke", "immune", "lifesteal", "revive"):
        s = {"aura": "p_b_circle_1"}
    if "heal" in [e["type"] for e in effects] and k in ("single", "aoe"):
        s["land"] = "c_heal2"
    if dstats and dstats[0] in DEBUFF_ICON:
        s["icon"] = DEBUFF_ICON[dstats[0]]
    if k in ("single", "aoe"):
        name = skill["name"].lower()
        for pat, extra in SIGNATURES:
            if re.search(pat, name):
                if "sweep" in extra or "travel" in extra or extra.get("hit") in MELEE:
                    s.pop("travel", None)
                    if "sweep" in extra or extra.get("hit") in MELEE:
                        s.pop("cast", None)
                s.update(extra)
                break
        ult = ULTIMATE_CHARGE.get((element, k))
        if ult and float(skill.get("mp", 0)) >= 150 and s.get("charge", "").startswith("p_{e}_"):
            s["charge"] = ult
    return s


def valid(spec, have):
    out = {}
    for key, v in spec.items():
        if not isinstance(v, str) or key.startswith("tint"):
            out[key] = v
            continue
        names = [v.replace("{e}", c) for c in LETTERS] if "{e}" in v else [v]
        if all(ALIAS.get(n, n) in have for n in names):
            out[key] = v
    return out


def main():
    have = sheets()
    bad = [k for k, v in ALIAS.items() if v not in have]
    assert not bad, bad
    monsters = json.load(open(os.path.join(ROOT, "data", "monsters.json"), encoding="utf8"))
    skills = {}
    sources = {"footage": 0, "rule": 0}
    for m in monsters.values():
        for sk in m.get("skills", []):
            name = sk["name"].strip().rstrip(":")
            if name in skills:
                continue
            spec = FOOTAGE.get(name) or NAMED.get(name) or rule(sk, m.get("element", ""))
            spec = valid(spec, have)
            if spec:
                skills[name] = spec
    for name in skills:
        sources["footage" if name in FOOTAGE else "rule"] += 1
    data = {
        "alias": ALIAS,
        "offsets": offsets(have),
        "default_style": "ranged",
        "styles": {k: "melee" for k in sorted(monsters) if k.endswith(MELEE_FAMILIES)},
        "attack": {
            "fire": ["c_scratch_1", "c_bite_1", "h_f_base_1", "c_punch_2"],
            "water": ["c_punch_3", "h_w_base_1", "c_cut_1", "c_punch_2"],
            "nature": ["c_scratch_1", "c_cut_2", "h_n_base_1", "c_punch_2"],
            "normal": ["c_punch_1", "c_bite_2", "h_k_base_1", "c_punch_2", "h_base_1"],
        },
        "attack_by": ATTACK_BY,
        "tick": {"burn": "h_f_tick", "poison": "h_n_tick", "freeze": "h_w_tick", "bleed": "h_b_tick", "time_bomb": "h_b_explosion_1"},
        "apply": {
            "stun": "", "silence": "t_silence_1", "provoke": "t_provoke_1", "reflect": "t_thorn_1",
            "immune": "c_immune_1", "shield": "", "debuff_def": "c_debufficon_defense", "debuff_speed": "c_debufficon_speed",
        },
        "loops": {
            "stun": "k_stun", "silence": "k_silence_1", "provoke": "k_provoke_1", "reflect": "k_thorn_1",
            "immune": "k_immune_1", "time_bomb": "k_bomb_1", "shield": "k_shield",
            "dot_burn": "k_burn", "dot_poison": "k_poison", "dot_freeze": "k_frost", "dot_bleed": "k_bleed",
        },
        "skills": dict(sorted(skills.items())),
    }
    for section in ("tick", "apply", "loops"):
        for k, v in data[section].items():
            assert v == "" or v in have, (section, k, v)
    for lst in data["attack"].values():
        assert all(v in have for v in lst), lst
    assert all(v in have for v in ATTACK_BY.values()), ATTACK_BY
    with open(OUT, "w", encoding="utf8") as f:
        json.dump(data, f, indent="\t", ensure_ascii=False)
        f.write("\n")
    print(len(skills), "skills", sources)


if __name__ == "__main__":
    main()
