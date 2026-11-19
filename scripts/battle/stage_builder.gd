class_name StageBuilder
extends RefCounted

const STAGES_PER_QUEST := [2, 3, 4, 4, 4, 5, 5, 4]
const SPECIAL_STAGES := 3
const DIFF_LEVEL_BONUS := {"normal": 0, "hard": 6, "hell": 12}
const DIFF_REWARD_MULT := {"normal": 1.0, "hard": 1.85, "hell": 2.7}
const DIFF_STAT_MULT := {"normal": 1.2, "hard": 1.45, "hell": 1.7}
const DIFF_MULT_PER_ISLAND := {"normal": 0.05, "hard": 0.05, "hell": 0.1}
const ATK_BONUS_SHARE := 0.5
const FIRST_CLEAR_GEMS := [2, 3, 4, 4, 4, 7, 7, 7]
const ISLAND_CLEAR_GEMS := [10, 20, 20, 40, 60, 100, 120, 150]
const DROP_CHANCE := 0.12
const BOSS_DROP_CHANCE := 0.05
const SPECIAL_BOSS_DROP_CHANCE := 0.35
const STAGE_BACKDROPS := {
	"sprout_island": [[3, "sprout_trail"], [6, "sprout_meadow"]],
	"lake_island": [[4, "lake_river"], [12, "lake_pond"]],
	"desert_isle": [[4, "desert_hills"], [8, "desert_dunes"], [12, "desert_oasis"]],
	"moonlight_desert": [[4, "moonlight_cactus"], [12, "moonlight_canyon"]],
	"boneyard_island": [[4, "boneyard_cactus"], [8, "boneyard_bones"], [14, "boneyard_lava"]],
	"dino_gorge": [[4, "dino_cave"], [8, "dino_acid"], [14, "dino_ice"]],
	"robo_island": [[4, "robo_machine"], [8, "robo_brick"], [12, "robo_lab"], [14, "robo_cyber"]],
	"sky_island": [[2, "sky_meadow"], [4, "sky_whale"], [6, "sky_wings"], [8, "sky_castle"]],
}


static func stage_backdrop(island_id: String, stage_index: int) -> String:
	for b in STAGE_BACKDROPS.get(island_id, []):
		if stage_index < int(b[0]):
			return String(b[1])
	return ""


static func enemy_level(island_order: int, stage_index: int, difficulty: String) -> int:
	if difficulty == "hell":
		return DB.MAX_LEVEL
	return clampi(1 + island_order * 3 + stage_index / 2 + DIFF_LEVEL_BONUS.get(difficulty, 0), 1, DB.MAX_LEVEL)


static func stage_count(island_order: int, stage_index: int) -> int:
	if island_order == 0:
		return 2 if stage_index == 0 else (4 if stage_index >= 5 else 3)
	return STAGES_PER_QUEST[clampi(island_order, 0, STAGES_PER_QUEST.size() - 1)]


static func story_quest(island: Dictionary, difficulty: String, stage_index: int) -> Dictionary:
	var info: Dictionary = island.difficulties[difficulty]
	var stage: Dictionary = info.stages[stage_index]
	var order := int(island.order)
	var mult: float = DIFF_REWARD_MULT.get(difficulty, 1.0)
	var stat_mult: float = DIFF_STAT_MULT.get(difficulty, 1.0) + DIFF_MULT_PER_ISLAND.get(difficulty, 0.0) * order
	var gold_mult := Events.mult("gold", island.id, difficulty)
	var energy := maxi(1, roundi(int(info.energy) * Events.mult("energy", island.id, difficulty)))
	var boss := String(stage.boss)
	var enemies: Array = stage.enemies.slice(1)
	var footage_boss := String(Tutorial.boss_line(island.id, difficulty, stage_index).get("say", ""))
	if footage_boss != "" and footage_boss != boss and not DB.monster(footage_boss).is_empty() and not bool(stage.get("boss_fixed", false)):
		boss = footage_boss
		enemies = stage.enemies.filter(func(e): return e != boss)
	var monthly := Events.monthly(String(island.id), difficulty, stage_index)
	var drop_pool: Array = stage.get("drops", [])
	if not monthly.is_empty():
		boss = String(monthly.boss)
		if not drop_pool.is_empty():
			drop_pool = drop_pool + [boss]
	return {
		"kind": "story",
		"key": "%s/%s/%d" % [island.id, difficulty, stage_index],
		"title": "%s  ·  %s" % [stage.name, difficulty.capitalize()],
		"island_id": island.id, "island_order": order, "difficulty": difficulty, "stage_index": stage_index,
		"energy": energy,
		"level": int(stage.get("level", enemy_level(order, stage_index, difficulty))),
		"boss": boss,
		"enemies": enemies,
		"hp_mult": stat_mult,
		"atk_mult": 1.0 + (stat_mult - 1.0) * ATK_BONUS_SHARE,
		"boost": DB.MAX_BOOST if difficulty == "hell" else 0,
		"stages": int(stage.get("waves", stage_count(order, stage_index))),
		"boss_wave": monthly.get("boss_wave", stage.get("boss_wave", [])),
		"say": String(monthly.get("say", "")),
		"boss_drop_id": String(monthly.get("drop", "")),
		"gold": (330.0 + 250.0 * order + 8.0 * stage_index) * mult * gold_mult,
		"exp": (50.0 + 17.0 * order + 2.0 * stage_index) * mult * Events.mult("xp", island.id, difficulty),
		"drops": true,
		"boss_drop_chance": float(monthly.get("drop_chance", stage.get("boss_drop", BOSS_DROP_CHANCE))),
		"drop_mult": Events.mult("cube", island.id, difficulty),
		"drop_level": [1, 1],
		"drop_pool": drop_pool,
		"first_clear_drop": false,
	}


static func special_quest(special: Dictionary, index: int) -> Dictionary:
	var q: Dictionary = special.quests[index]
	var tab := String(q.get("tab", ""))
	var level := DB.MAX_LEVEL if tab == "hell" else int(q.level)
	var kind: String = special.kind
	var order_equiv := clampi((int(q.level) - 1) / 3, 0, 7)
	return {
		"kind": "special",
		"key": "%s/%d" % [special.id, index],
		"title": "%s  ·  %s" % [special.name, q.name],
		"special_id": special.id, "quest_index": index, "tab": tab,
		"energy": maxi(0 if int(q.energy) == 0 else 1, roundi(int(q.energy) * Events.mult("energy", special.id))),
		"fp": int(q.get("fp", 0)),
		"level": level,
		"boss": q.boss,
		"boss_traits": q.get("boss_traits", []),
		"say": String(q.get("say", "")),
		"rare": q.get("rare", []),
		"hp_mult": DIFF_STAT_MULT.get(tab, 1.0),
		"atk_mult": 1.0 + (DIFF_STAT_MULT.get(tab, 1.0) - 1.0) * ATK_BONUS_SHARE,
		"boost": DB.MAX_BOOST if tab == "hell" else 0,
		"enemies": q.enemies,
		"wave_pools": q.get("wave_pools", []),
		"wave_sizes": q.get("wave_sizes", []),
		"bg": String(q.get("bg", "")),
		"stages": int(q.get("stages", special.get("stages", SPECIAL_STAGES))),
		"gold": float(q.get("gold", 330.0 + 250.0 * order_equiv)) * Events.mult("gold", special.id),
		"gems": int(q.get("gems", 0)),
		"red_cube_chance": float(q.get("red_cube_chance", 0.0)),
		"exp": float(q.get("exp", 50.0 + 17.0 * order_equiv)) * Events.mult("xp", special.id),
		"drops": (kind != "exp" and kind != "gold") or q.has("drops"),
		"boss_drop_chance": SPECIAL_BOSS_DROP_CHANCE,
		"drop_mult": Events.mult("cube", special.id) * float(q.get("drop_mult", 1.0)),
		"drop_level": q.get("drop_level", [1, 1]),
		"drop_pool": q.get("drops", []),
		"first_clear_drop": bool(special.get("first_clear_drop", false)),
	}


static func waves_for(quest: Dictionary, rng: RandomNumberGenerator) -> Array:
	if quest.has("fixed_waves"):
		return quest.fixed_waves
	var pool: Array = quest.enemies
	if pool.is_empty():
		pool = [quest.boss]
	var level := int(quest.level)
	var count := int(quest.stages)
	var waves := []
	var pools: Array = quest.get("wave_pools", [])
	for w in count:
		var wave := []
		var size := mini(3, 2 + w % 2)
		if w < pools.size() and not pools[w].is_empty():
			pool = pools[w]
		if w == count - 1:
			wave.append({"id": quest.boss, "level": mini(DB.MAX_LEVEL, level + 1), "boss": true, "traits": quest.get("boss_traits", []), "hp_mult": quest.get("hp_mult", 1.0), "atk_mult": quest.get("atk_mult", 1.0), "boost": int(quest.get("boost", 0))})
			size = 2
		var sizes: Array = quest.get("wave_sizes", [])
		if w < sizes.size():
			size = int(sizes[w])
		var ids := []
		for i in size:
			ids.append(pool[rng.randi() % pool.size()])
		if w == count - 1 and not quest.get("boss_wave", []).is_empty():
			ids = quest.boss_wave
		for id in ids:
			wave.append({"id": id, "level": level, "boss": false, "hp_mult": quest.get("hp_mult", 1.0), "atk_mult": quest.get("atk_mult", 1.0), "boost": int(quest.get("boost", 0))})
		waves.append(wave)
	for r in quest.get("rare", []):
		if rng.randf() < float(r.chance):
			var wave: Array = waves[rng.randi() % maxi(1, count - 1)]
			wave[wave.size() - 1] = {"id": String(r.id), "level": level, "boss": false, "hp_mult": quest.get("hp_mult", 1.0), "atk_mult": quest.get("atk_mult", 1.0), "boost": int(quest.get("boost", 0))}
			break
	return waves


static func build_waves(island: Dictionary, difficulty: String, stage_index: int, rng: RandomNumberGenerator) -> Array:
	return waves_for(story_quest(island, difficulty, stage_index), rng)


static func base_rewards(quest: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var gold := float(quest.gold)
	if quest.kind == "story":
		gold *= rng.randf_range(0.9, 1.1)
	var exp_mult := 2 if Save.item_boost_left("exp") > 0 else 1
	return {"gold": int(gold), "exp": int(quest.exp) * exp_mult}


static func first_clear_gems(quest: Dictionary) -> int:
	if quest.kind != "story":
		return 0
	return FIRST_CLEAR_GEMS[clampi(int(quest.island_order), 0, FIRST_CLEAR_GEMS.size() - 1)]


static func island_clear_gems(quest: Dictionary) -> int:
	return ISLAND_CLEAR_GEMS[clampi(int(quest.island_order), 0, ISLAND_CLEAR_GEMS.size() - 1)]


static func roll_drops(quest: Dictionary, kills: Array, first_clear: bool, rng: RandomNumberGenerator) -> Array:
	var drops := []
	var state := drop_state(quest)
	for id in kills:
		var d := roll_kill(quest, state, id, first_clear, rng)
		if not d.is_empty():
			drops.append(d)
	return drops


static func drop_state(quest: Dictionary) -> Dictionary:
	return {"boss_dropped": false, "rare": Array(quest.get("rare", [])).map(func(r): return String(r.id))}


static func roll_kill(quest: Dictionary, state: Dictionary, id: String, first_clear: bool, rng: RandomNumberGenerator) -> Dictionary:
	if not quest.drops:
		return {}
	var rare: Array = state.rare
	var pool: Array = quest.get("drop_pool", [])
	var forced := bool(Save.data.get("dev_force_drops", false))
	if not forced and not pool.is_empty() and not pool.has(id) and not rare.has(id):
		return {}
	var is_boss: bool = id == quest.boss and not state.boss_dropped
	var chance: float = (float(quest.boss_drop_chance) if is_boss else DROP_CHANCE) * float(quest.get("drop_mult", 1.0))
	if Save.item_boost_left("drop") > 0:
		chance *= 2.0
	if is_boss and first_clear and quest.first_clear_drop:
		chance = 1.0
	if rare.has(id) and not is_boss:
		chance = 1.0
		rare.erase(id)
	if forced:
		chance = 1.0
	if rng.randf() >= chance:
		return {}
	if is_boss:
		state.boss_dropped = true
	var lv: Array = quest.drop_level
	if is_boss and String(quest.get("boss_drop_id", "")) != "":
		id = String(quest.boss_drop_id)
	return {"id": id, "level": rng.randi_range(int(lv[0]), int(lv[1]))}
