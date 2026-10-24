class_name BattleUnit
extends RefCounted

const PLAYER := 0
const ENEMY := 1
const BASE_ATTACK_INTERVAL := 1.6
const BASE_CRIT := 0.05
const BASE_CRIT_DMG := 0.5
const HP_SCALE := 3.0

var side: int
var slot: int
var monster_id: String
var name: String
var element: String
var level: int
var is_leader := false
var is_boss := false

var max_hp := 1.0
var hp := 1.0
var base := {"atk": 0.0, "def": 0.0, "rec": 0.0, "speed": 1.0, "crit": BASE_CRIT, "crit_dmg": BASE_CRIT_DMG}

var skills: Array = []
var support: Dictionary = {}
var support_timer := 0.0
var attack_timer := 0.0
var skill_timer := 0.0
var cooldown_mult := 1.0
var extra_max_mp := 0.0
var traits: Array = []
var trait_clock: Dictionary = {}

var shield := 0.0
var shield_time := 0.0
var statuses: Array = []


static func create(p_side: int, p_slot: int, id: String, p_level: int, boost: int = 0) -> BattleUnit:
	var u := BattleUnit.new()
	var def := DB.monster(id)
	var st := DB.stats_at(id, p_level, boost)
	u.side = p_side
	u.slot = p_slot
	u.monster_id = id
	u.name = def.name
	u.element = def.element
	u.level = p_level
	u.max_hp = float(st.hp) * HP_SCALE
	u.hp = u.max_hp
	u.base.atk = float(st.atk)
	u.base.def = float(st.def)
	u.base.rec = float(st.rec)
	u.skills = def.skills
	u.support = def.support_skill
	return u


func alive() -> bool:
	return hp > 0.0


func hp_ratio() -> float:
	return hp / max_hp if max_hp > 0.0 else 0.0


func stat(key: String) -> float:
	var v: float = base.get(key, 0.0)
	var mult := 1.0
	for s in statuses:
		if s.get("stat", "") != key:
			continue
		if s.type == "buff":
			mult += float(s.pct)
		elif s.type == "debuff":
			mult -= float(s.pct)
	if key == "speed":
		for s in statuses:
			if s.type == "dot" and s.kind == "freeze":
				mult -= 0.3
	if key == "crit" or key == "crit_dmg":
		return v + (mult - 1.0)
	return v * maxf(0.1, mult)


func has_status(type: String) -> bool:
	for s in statuses:
		if s.type == type:
			return true
	return false


func status_value(type: String, key: String) -> float:
	var best := 0.0
	for s in statuses:
		if s.type == type:
			best = maxf(best, float(s.get(key, 0.0)))
	return best


func can_act() -> bool:
	return alive() and not has_status("stun")


func can_cast() -> bool:
	return can_act() and not has_status("silence")


func attack_interval() -> float:
	return BASE_ATTACK_INTERVAL / maxf(0.25, stat("speed"))
