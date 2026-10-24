class_name MagicStones
extends RefCounted

const RANKS := ["E", "D", "C", "B", "A", "S", "S+"]
const B := 3
const A := 4
const S := 5
const SP := 6
const VARIANTS := ["", "I", "II", "III"]

const TYPES := {
	"bravery": {"name": "Bravery", "cat": "attack", "stat": "atk", "values": [10, 22, 35, 50, 70, 100, 240]},
	"windfury": {"name": "Windfury", "cat": "attack", "stat": "speed", "values": [2, 4, 6, 8, 10, 13, 18], "pct": true},
	"thunder": {"name": "Thunder", "cat": "attack", "stat": "crit", "values": [1, 2, 3, 5, 7, 9, 13], "pct": true},
	"destruction": {"name": "Destruction", "cat": "attack", "stat": "crit_dmg", "values": [3, 6, 10, 15, 20, 28, 40], "pct": true},
	"vitality": {"name": "Vitality", "cat": "defense", "stat": "hp", "values": [140, 300, 480, 680, 950, 1360, 3260]},
	"steel": {"name": "Steel", "cat": "defense", "stat": "def", "values": [6, 13, 21, 30, 42, 60, 144]},
	"blessed": {"name": "Blessed", "cat": "defense", "stat": "rec", "values": [40, 88, 140, 200, 280, 400, 960]},
	"time": {"name": "Time", "cat": "skill", "stat": "cooldown", "values": [3, 5, 8, 11, 14, 17, 22], "pct": true},
	"clarity": {"name": "Clarity", "cat": "skill", "stat": "mp_regen", "values": [3, 6, 9, 12, 16, 20, 28], "pct": true},
	"spirit": {"name": "Spirit", "cat": "skill", "stat": "max_mp", "values": [5, 10, 15, 20, 30, 40, 60]},
}
const SECONDARY := {
	"attack": [["speed", [5, 7, 10], true], ["rec", [100, 150, 200], false], ["cooldown", [8, 10, 12], true]],
	"defense": [["def", [20, 30, 45], false], ["hp", [300, 450, 680], false], ["crit_dmg", [10, 15, 20], true]],
	"skill": [["hp", [300, 450, 680], false], ["crit", [3, 5, 8], true], ["rec", [100, 150, 200], false]],
}
const STAT_NAMES := {"atk": "Offense", "hp": "Max HP", "def": "Defense", "rec": "Recovery", "speed": "Speed", "crit": "Critical Hit", "crit_dmg": "Critical Damage", "cooldown": "Cooldown Rdc", "mp_regen": "MP Recovery", "max_mp": "Max MP"}

const CRAFT_COST := [0, 1000, 2000, 5000, 12000, 35000, 70000]
const EQUIP_COST := [1000, 2000, 3000, 10000, 25000, 50000, 80000]
const UNEQUIP_COST := [1000, 2000, 3000, 10000, 40000, 60000, 80000]
const CRAFT_COUNT := [0, 2, 3, 4, 4, 6, 2]
const CRAFT_FLOOR := [0, 0, 0, 9, 15, 25, 0]
const SPLUS_FLOOR := {"destruction": 35, "vitality": 36, "thunder": 37, "clarity": 38, "blessed": 39, "spirit": 40, "bravery": 41, "steel": 42, "windfury": 43, "time": 44}
const DEFAULT_SLOTS := 2
const MAX_SLOTS := 3
const THIRD_SLOT_GEMS := 60
const START_STONE_CAP := 30


static func label(stone: Dictionary) -> String:
	var r := int(stone.rank)
	var v := int(stone.get("variant", 0))
	return "%s Stone %s(%s)" % [TYPES[stone.type].name, (VARIANTS[v] + " ") if v > 0 else "", RANKS[r]]


static func bonuses(stone: Dictionary) -> Dictionary:
	var t: Dictionary = TYPES[stone.type]
	var r := int(stone.rank)
	var out := {}
	out[t.stat] = float(t.values[r]) / (100.0 if t.get("pct", false) else 1.0)
	var v := int(stone.get("variant", 0))
	if v > 0 and r >= B:
		var sec: Array = SECONDARY[t.cat][v - 1]
		var tier := mini(r - B, 2)
		var amount := float(sec[1][tier]) * (1.3 if r == SP else 1.0)
		var key: String = sec[0]
		out[key] = out.get(key, 0.0) + amount / (100.0 if sec[2] else 1.0)
	return out


static func describe(stone: Dictionary) -> String:
	var parts := []
	var b := bonuses(stone)
	for k in b:
		var v: float = b[k]
		var pct: bool = k in ["speed", "crit", "crit_dmg", "cooldown", "mp_regen"]
		var sign := "-" if k == "cooldown" else "+"
		parts.append("%s %s%s" % [STAT_NAMES[k], sign, ("%d%%" % roundi(v * 100.0)) if pct else str(roundi(v))])
	return ",  ".join(parts)


static func badge(rank: int) -> Texture2D:
	return UI.tex("betaGacha00/K_stoneRarity%s_01.png" % ["E", "D", "C", "B", "A", "S", "S"][rank])


static func total_bonuses(stones: Array) -> Dictionary:
	var out := {}
	for s in stones:
		var b := bonuses(s)
		for k in b:
			out[k] = out.get(k, 0.0) + b[k]
	return out


static func craft_requirements(stone: Dictionary, tower_floor: int) -> Dictionary:
	var r := int(stone.rank)
	if r >= SP:
		return {"ok": false, "reason": "Highest rank"}
	var next := r + 1
	var floor_needed: int = SPLUS_FLOOR[stone.type] if next == SP else CRAFT_FLOOR[next]
	if tower_floor < floor_needed:
		return {"ok": false, "reason": "Clear Sky Tower floor %d first" % floor_needed, "floor": floor_needed}
	return {"ok": true, "count": CRAFT_COUNT[next], "cost": CRAFT_COST[next], "floor": floor_needed, "rank": next}
