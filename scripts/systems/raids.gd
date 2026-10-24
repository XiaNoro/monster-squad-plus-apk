class_name Raids
extends RefCounted

const PICK := 20
const PARTY := 5
const ROOMS := 12
const BOSS_ROOMS := [3, 7, 11]
const HP_MULT := 5.0
const ATK_MULT := 2.0
const ROOM_GOLD := 9000
const BOSS_GOLD := 14000
const FINAL_GOLD := 40000
const LOW_DROP := 0.35
const HIGH_DROP := 0.5


static func all() -> Array:
	return DB.raids


static func raid(id: String) -> Dictionary:
	for r in DB.raids:
		if r.id == id:
			return r
	return {}


static func is_boss_room(index: int) -> bool:
	return BOSS_ROOMS.has(index)


static func room_gold(index: int) -> int:
	if index == ROOMS - 1:
		return FINAL_GOLD
	return BOSS_GOLD if is_boss_room(index) else ROOM_GOLD


static func room_quest(r: Dictionary, index: int) -> Dictionary:
	var lineup: Array = r.rooms[index]
	var boss := is_boss_room(index)
	var level := mini(DB.MAX_LEVEL, int(r.level) + index / 3)
	var wave := []
	for i in lineup.size():
		var spec := {"id": lineup[i], "level": level, "boss": boss and i == 0, "hp_mult": HP_MULT, "atk_mult": ATK_MULT}
		if spec.boss:
			spec["traits"] = ["enrage", "immune"] if bool(r.get("boss_immune", false)) else ["enrage"]
		wave.append(spec)
	return {
		"kind": "raid",
		"key": "raid/%s/%d" % [r.id, index],
		"title": "%s  ·  Stage %d / %d" % [r.name, index + 1, ROOMS],
		"raid_id": r.id, "room": index,
		"energy": 0,
		"level": level,
		"boss": lineup[0],
		"enemies": lineup,
		"stages": 1,
		"fixed_waves": [wave],
		"gold": float(room_gold(index)),
		"exp": 0.0,
		"drops": false,
		"boss_drop_chance": 0.0,
		"drop_level": [1, 1],
		"first_clear_drop": false,
		"wave_heal": 0.0,
	}


static func roll_drops(r: Dictionary, index: int, rng: RandomNumberGenerator) -> Array:
	var low: Array = r.drops_low
	var high: Array = r.drops_high if not r.drops_high.is_empty() else low
	var out := []
	if is_boss_room(index):
		out.append(high[rng.randi() % high.size()])
	elif index >= 8:
		if rng.randf() < HIGH_DROP:
			out.append(high[rng.randi() % high.size()])
	elif not low.is_empty() and rng.randf() < LOW_DROP:
		out.append(low[rng.randi() % low.size()])
	return out
