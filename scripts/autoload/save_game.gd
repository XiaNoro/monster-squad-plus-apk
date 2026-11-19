extends Node

signal changed

var save_path := "user://save.json"
const VERSION := 1
const EXPORT_EXT := "mssave"
const EXPORT_KEY := "o1Nn9WWrvc0SlA4_XdrTwz71TG4BRh6xmZx_iySZG7U"
const ENERGY_REGEN_SECONDS := 180
const ENERGY_REFILL_GEMS := 5
const START_ENERGY_CAP := 40
const TEAM_SIZE := 4
const START_INVENTORY := 60

var data: Dictionary = {}


func _ready() -> void:
	load_game()


func is_new_game() -> bool:
	return data.monsters.is_empty()


func load_game() -> void:
	if FileAccess.file_exists(save_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if parsed is Dictionary and int(parsed.get("version", 0)) == VERSION:
			reset()
			for k in parsed:
				data[k] = parsed[k]
			data.team = _uids(data.team)
			data.teams = data.teams.map(_uids)
			while data.teams.size() < TEAM_PRESETS:
				data.teams.append([])
			if data.league.has("team"):
				data.league.team = _uids(data.league.team)
			_drop_unknown()
			if not parsed.has("tutorial"):
				data.erase("tutorial")
				Tutorial.skip_all()
			if not data.monsters.is_empty():
				Friends.ensure_defaults()
			_tick_energy()
			return
	reset()


func _drop_unknown() -> void:
	var gone := []
	for m in data.monsters:
		if not DB.monsters.has(String(m.get("id", ""))):
			gone.append(int(m.get("uid", -1)))
	if gone.is_empty():
		return
	for uid in gone:
		remove_monster(uid)
	var keep := func(u): return not int(u) in gone
	if data.league.has("team"):
		data.league.team = data.league.team.filter(keep)
	for k in ["picked", "party"]:
		if data.raid.get(k) is Array:
			data.raid[k] = data.raid[k].filter(keep)
	if data.team.is_empty() and not data.monsters.is_empty():
		set_team([int(data.monsters[0].uid)])
	push_warning("Removed %d monsters with unknown ids from the save" % gone.size())


static func _uids(list: Array) -> Array:
	var out := []
	for u in list:
		if not int(u) in out:
			out.append(int(u))
	return out


func reset() -> void:
	data = {
		"version": VERSION,
		"gold": 3000,
		"gems": 0,
		"free_cubes": 1,
		"best_times": {},
		"special_unlocks": {},
		"special_clears": {},
		"raid": {},
		"arena": {},
		"arena_tokens": Arena.MAX_TOKENS,
		"arena_stamp": Time.get_unix_time_from_system(),
		"honor": 0,
		"league": {},
		"badges": {},
		"raid_cleared": {},
		"tower_floor": 0,
		"tower_tickets": SkyTower.MAX_TICKETS,
		"tower_stamp": Time.get_unix_time_from_system(),
		"stones": [],
		"pets": [],
		"counters": {},
		"claimed": {},
		"endless": {},
		"attendance": {},
		"cube_items": {},
		"stone_cap": MagicStones.START_STONE_CAP,
		"energy": START_ENERGY_CAP,
		"energy_cap": START_ENERGY_CAP,
		"energy_stamp": Time.get_unix_time_from_system(),
		"inventory_cap": START_INVENTORY,
		"next_uid": 1,
		"monsters": [],
		"team": [],
		"teams": [[], [], [], [], []],
		"team_index": 0,
		"progress": {},
		"seen": {},
		"owned": {},
		"maxed": {},
		"fp": 0,
		"friends": [],
		"friend_used": {},
		"name": "Tamer",
	}


func start_new_game(starter: String = "pheona") -> void:
	reset()
	var team := []
	for id in [starter, "firepaw"]:
		team.append(int(add_monster(id, 1).uid))
	set_team(team)
	Tutorial.begin_new_game()
	data.friends = Friends.starting_friends()
	save_game()


func save_game() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	changed.emit()


func export_to(path: String) -> bool:
	save_game()
	var f := FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, EXPORT_KEY)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true


func read_export(path: String) -> Dictionary:
	var f := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, EXPORT_KEY)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary and int(parsed.get("version", 0)) == VERSION and parsed.get("monsters") is Array:
		return parsed
	return {}


func import_save(saved: Dictionary) -> void:
	export_to(save_path.get_basename() + "_before_load." + EXPORT_EXT)
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(saved, "\t"))
	f.close()
	load_game()
	changed.emit()


func add_monster(id: String, level: int = 1) -> Dictionary:
	var m := {"uid": int(data.next_uid), "id": id, "level": level, "exp": 0, "boost": 0, "locked": false}
	data.next_uid = int(data.next_uid) + 1
	data.monsters.append(m)
	data.seen[id] = true
	data.owned[id] = true
	var def := DB.monster(id)
	if not def.is_empty() and not def.get("material", false):
		track("get:0")
		track("get:%d" % int(def.stars))
	return m


func get_owned(uid: int) -> Dictionary:
	for m in data.monsters:
		if int(m.uid) == uid:
			return m
	return {}


func remove_monster(uid: int) -> void:
	for st in data.stones:
		if int(st.get("on", -1)) == uid:
			st.on = -1
	for pt in data.pets:
		if int(pt.get("on", -1)) == uid:
			pt.on = -1
	for i in data.monsters.size():
		if int(data.monsters[i].uid) == uid:
			data.monsters.remove_at(i)
			break
	data.team = data.team.filter(func(u): return int(u) != uid)
	for i in data.teams.size():
		data.teams[i] = data.teams[i].filter(func(u): return int(u) != uid)


func inventory_full() -> bool:
	return data.monsters.size() >= int(data.inventory_cap)


func team_members() -> Array:
	var out := []
	for uid in data.team:
		var m := get_owned(int(uid))
		if not m.is_empty():
			out.append(m)
	return out


func team_size() -> int:
	var sprout: Dictionary = DB.islands[0]
	var cleared := cleared_stages(sprout.id, "normal")
	if cleared >= sprout.difficulties.normal.stages.size():
		return TEAM_SIZE
	return TEAM_SIZE - 1 if cleared >= 3 else TEAM_SIZE - 2


const TEAM_PRESETS := 5


func set_team(uids: Array) -> void:
	data.team = uids.slice(0, team_size())
	data.teams[clampi(int(data.team_index), 0, TEAM_PRESETS - 1)] = data.team.duplicate()
	save_game()


func switch_team(index: int) -> void:
	var cur := clampi(int(data.team_index), 0, TEAM_PRESETS - 1)
	data.teams[cur] = data.team.duplicate()
	var seen := {}
	var picked := []
	for u in data.teams[index]:
		var m := get_owned(int(u))
		if not m.is_empty() and not seen.has(m.id):
			seen[m.id] = true
			picked.append(int(u))
	data.team_index = index
	data.team = picked.slice(0, team_size())
	data.teams[index] = data.team.duplicate()
	save_game()


func in_active_team(uid: int) -> bool:
	for u in data.team:
		if int(u) == uid:
			return true
	return false


func preset_of(uid: int) -> int:
	for i in data.teams.size():
		if i != int(data.team_index) and data.teams[i].any(func(u): return int(u) == uid):
			return i
	return -1


func in_team(uid: int) -> bool:
	return in_active_team(uid) or preset_of(uid) >= 0


func exp_after(m: Dictionary, amount: int) -> Dictionary:
	var stars: int = DB.monster(m.id).stars
	var level := int(m.level)
	var xp := int(m.get("exp", 0)) + amount
	var cap := max_level(m)
	while level < cap and xp >= DB.exp_to_next(level, stars):
		xp -= DB.exp_to_next(level, stars)
		level += 1
	if level >= cap:
		xp = 0
	var need := DB.exp_to_next(level, stars)
	return {"level": level, "exp": xp, "ratio": 1.0 if level >= cap or need <= 0 else clampf(float(xp) / float(need), 0.0, 1.0)}


func grant_exp(m: Dictionary, amount: int) -> int:
	var r := exp_after(m, amount)
	var gained := int(r.level) - int(m.level)
	m.level = int(r.level)
	m.exp = int(r.exp)
	if gained > 0 and int(m.level) >= DB.MAX_LEVEL and not DB.monster(m.id).get("material", false):
		track("reach30")
	if int(m.level) >= DB.MAX_LEVEL:
		if not data.maxed.has(m.id):
			data.maxed[m.id] = true
			track("lv30")
			LevelReward.reached(m)
	return gained


func max_level(m: Dictionary) -> int:
	return int(m.get("max_level", DB.MAX_LEVEL))


func is_maxed(m: Dictionary) -> bool:
	return int(m.level) >= DB.MAX_LEVEL and int(m.boost) >= DB.MAX_BOOST


func dev(key: String) -> bool:
	return not OS.has_feature("mobile") and bool(data.get(key, false))


func boost_preview(target_uid: int, material_uid: int) -> Dictionary:
	var target := get_owned(target_uid)
	var mat := get_owned(material_uid)
	if target.is_empty() or mat.is_empty() or target_uid == material_uid:
		return {"ok": false, "reason": "Pick a material"}
	if int(target.boost) >= DB.MAX_BOOST:
		return {"ok": false, "reason": "Already +%d" % DB.MAX_BOOST}
	if mat.locked or in_team(material_uid):
		return {"ok": false, "reason": "Material is locked or in the team"}
	var chance := minf(1.0, DB.boost_chance(target.id, mat.id) * Events.effect("boost_chance") + float(target.get("boost_pt", 0)) / 200.0)
	if bool(DB.monster(mat.id).get("boost_fail", false)):
		chance = 0.0
	if dev("dev_boost_100"):
		chance = 1.0
	return {"ok": true, "chance": chance, "cost": roundi(DB.boost_cost(target.id, int(target.boost)) * Events.effect("boost_cost"))}


func boost(target_uid: int, material_uid: int) -> Dictionary:
	var p := boost_preview(target_uid, material_uid)
	if not p.ok:
		return p
	if int(data.gold) < int(p.cost):
		return {"ok": false, "reason": "Not enough gold"}
	var target := get_owned(target_uid)
	var pt_gain := DB.boost_pt_on_fail(target.id, get_owned(material_uid).id)
	data.gold = int(data.gold) - int(p.cost)
	remove_monster(material_uid)
	var success := randf() < float(p.chance)
	track("boost")
	if success:
		target.boost = int(target.boost) + 1
		target.boost_pt = 0
	else:
		target.boost_pt = int(target.get("boost_pt", 0)) + pt_gain
	save_game()
	return {"ok": true, "success": success, "boost": int(target.boost), "boost_pt": int(target.get("boost_pt", 0))}


func fusion_preview(a_uid: int, b_uid: int) -> Dictionary:
	var a := get_owned(a_uid)
	var b := get_owned(b_uid)
	if a.is_empty() or b.is_empty() or a_uid == b_uid:
		return {"ok": false, "reason": "Pick a partner"}
	var stars: int = DB.monster(a.id).stars
	if stars >= 6:
		return {"ok": false, "reason": "6★ monsters can't be fused"}
	if int(DB.monster(b.id).stars) != stars:
		return {"ok": false, "reason": "Partner must also be %d★" % stars}
	if not is_maxed(a) or not is_maxed(b):
		return {"ok": false, "reason": "Both must be Lv%d +%d" % [DB.MAX_LEVEL, DB.MAX_BOOST]}
	if b.locked or in_team(b_uid):
		return {"ok": false, "reason": "Partner is locked or in the team"}
	return {"ok": true, "cost": roundi(DB.fusion_cost(stars) * Events.effect("fusion_cost")), "stars": stars + 1}


func fuse(a_uid: int, b_uid: int) -> Dictionary:
	var p := fusion_preview(a_uid, b_uid)
	if not p.ok:
		return p
	if int(data.gold) < int(p.cost):
		return {"ok": false, "reason": "Not enough gold"}
	var pool := DB.ids_where(func(m): return int(m.stars) == int(p.stars) and not m.material)
	if pool.is_empty():
		return {"ok": false, "reason": "Nothing to fuse into"}
	data.gold = int(data.gold) - int(p.cost)
	track("fuse")
	var was_leader: bool = not data.team.is_empty() and int(data.team[0]) == a_uid
	remove_monster(a_uid)
	remove_monster(b_uid)
	var result := add_monster(pool[randi() % pool.size()], 1)
	if was_leader:
		data.team.insert(0, int(result.uid))
	save_game()
	return {"ok": true, "into": result.id, "uid": int(result.uid)}


func feed(target_uid: int, food_uids: Array) -> Dictionary:
	var target := get_owned(target_uid)
	var foods := []
	for u in food_uids:
		var f := get_owned(int(u))
		if not f.is_empty() and int(u) != target_uid and not f.locked and not in_team(int(u)):
			foods.append(f)
	if foods.is_empty():
		return {"ok": false, "reason": "Pick monsters to feed"}
	if int(target.level) >= max_level(target):
		return {"ok": false, "reason": "Already at max level"}
	var cost := DB.feed_cost(target.id) * foods.size()
	if int(data.gold) < cost:
		return {"ok": false, "reason": "Needs %s gold" % Screen._thousands(cost)}
	var xp := 0
	for f in foods:
		xp += DB.feed_exp(f.id, int(f.level))
		remove_monster(int(f.uid))
	data.gold = int(data.gold) - cost
	var levels := grant_exp(target, xp)
	save_game()
	return {"ok": true, "exp": xp, "levels": levels, "cost": cost}


func awaken_preview(target_uid: int, material_uid: int) -> Dictionary:
	var t := get_owned(target_uid)
	var mat := get_owned(material_uid)
	if t.is_empty() or mat.is_empty() or target_uid == material_uid:
		return {"ok": false, "reason": "Pick a material"}
	var td := DB.monster(t.id)
	var md := DB.monster(mat.id)
	if int(td.stars) < 6:
		return {"ok": false, "reason": "Only 6★ monsters can awaken"}
	if int(md.stars) < 6 or md.element != td.element:
		return {"ok": false, "reason": "Material must be a 6★ %s monster" % String(td.element).capitalize()}
	if int(mat.level) < DB.MAX_LEVEL:
		return {"ok": false, "reason": "Material must be Lv%d" % DB.MAX_LEVEL}
	if mat.locked or in_team(material_uid):
		return {"ok": false, "reason": "Material is locked or in the team"}
	var cap := max_level(t)
	if cap >= DB.AWAKEN_MAX:
		return {"ok": false, "reason": "Already Lv%d cap" % DB.AWAKEN_MAX}
	var gain := 3 if mat.id == t.id else 1
	if Events.has("awaken"):
		gain += 1
	return {"ok": true, "gain": mini(gain, DB.AWAKEN_MAX - cap), "cost": DB.AWAKEN_GOLD_PER_CAP * cap}


func awaken(target_uid: int, material_uid: int) -> Dictionary:
	var p := awaken_preview(target_uid, material_uid)
	if not p.ok:
		return p
	if int(data.gold) < int(p.cost):
		return {"ok": false, "reason": "Needs %s gold" % Screen._thousands(int(p.cost))}
	var t := get_owned(target_uid)
	data.gold = int(data.gold) - int(p.cost)
	remove_monster(material_uid)
	t.max_level = max_level(t) + int(p.gain)
	save_game()
	return {"ok": true, "cap": int(t.max_level)}


func add_pet(pet_id: String) -> Dictionary:
	var def := DB.pet(pet_id)
	var passives: Array = def.passives
	var pt := {"uid": int(data.next_uid), "id": pet_id, "passive": randi() % passives.size() if not passives.is_empty() else -1, "on": -1}
	data.next_uid = int(data.next_uid) + 1
	data.pets.append(pt)
	return pt


func free_pets() -> Array:
	return data.pets.filter(func(p): return int(p.get("on", -1)) < 0)


func pet_of(m: Dictionary) -> Dictionary:
	if int(m.get("uid", -1)) < 0:
		return {}
	for p in data.pets:
		if int(p.get("on", -1)) == int(m.uid):
			return p
	return {}


func pet_equip_cost(pet: Dictionary) -> Dictionary:
	var stars: int = DB.pet(pet.id).stars
	return {"gold": 4000 * stars, "gems": stars + 2}


func equip_pet(monster_uid: int, pet_uid: int, use_gems: bool) -> Dictionary:
	var m := get_owned(monster_uid)
	var pet: Dictionary = {}
	for p in data.pets:
		if int(p.uid) == pet_uid:
			pet = p
	if m.is_empty() or pet.is_empty():
		return {"ok": false, "reason": "Pick a pet"}
	var need: int = DB.PET_LEVEL.get(int(DB.pet(pet.id).stars), 30)
	if int(m.level) < need:
		return {"ok": false, "reason": "Needs Lv%d" % need}
	var cost := pet_equip_cost(pet)
	if use_gems:
		if int(data.gems) < int(cost.gems):
			return {"ok": false, "reason": "Not enough gems"}
		data.gems = int(data.gems) - int(cost.gems)
	else:
		if int(data.gold) < int(cost.gold):
			return {"ok": false, "reason": "Not enough gold"}
		data.gold = int(data.gold) - int(cost.gold)
	var old := pet_of(m)
	if not old.is_empty():
		data.pets.erase(old)
	pet.on = monster_uid
	save_game()
	return {"ok": true, "replaced": not old.is_empty()}


func pet_sell_price(pet: Dictionary) -> int:
	return 1000 * int(DB.pet(pet.id).stars)


func sell_pet(pet_uid: int) -> int:
	for p in data.pets:
		if int(p.uid) == pet_uid and int(p.get("on", -1)) < 0:
			var price := pet_sell_price(p)
			data.pets.erase(p)
			data.gold = int(data.gold) + price
			return price
	return 0


func pet_spec(m: Dictionary) -> Dictionary:
	var pet := pet_of(m)
	if pet.is_empty():
		return {}
	var def := DB.pet(pet.id)
	var passive: Dictionary = def.passives[int(pet.passive)] if int(pet.passive) >= 0 and int(pet.passive) < def.passives.size() else {}
	return {"id": String(pet.id), "stats": def.stats, "passive": passive}


func can_evolve(uid: int) -> Dictionary:
	var m := get_owned(uid)
	var def := DB.monster(m.id)
	if def.evolves_into == "":
		return {"ok": false, "reason": "Final form"}
	if dev("dev_free_evolve"):
		return {"ok": true}
	if not is_maxed(m):
		return {"ok": false, "reason": "Needs Lv%d +%d" % [DB.MAX_LEVEL, DB.MAX_BOOST]}
	var need: int = def.evolve_quantity
	var have := evolve_materials(uid)
	if def.evolve_material != "" and have.size() < need:
		return {"ok": false, "reason": "Needs %d× %s at Lv%d +%d" % [need, DB.monster(def.evolve_material).get("name", def.evolve_material), DB.MAX_LEVEL, DB.MAX_BOOST]}
	if int(data.gold) < DB.evolve_cost(m.id):
		return {"ok": false, "reason": "Needs %d gold" % DB.evolve_cost(m.id)}
	return {"ok": true}


func evolve_materials(uid: int) -> Array:
	var m := get_owned(uid)
	var mat: String = DB.monster(m.id).evolve_material
	var out := []
	for o in data.monsters:
		if o.id == mat and int(o.uid) != uid and not o.locked and not in_team(int(o.uid)) and is_maxed(o):
			out.append(int(o.uid))
	return out


func evolve(uid: int) -> Dictionary:
	var check := can_evolve(uid)
	if not check.ok:
		return check
	var m := get_owned(uid)
	var def := DB.monster(m.id)
	if not dev("dev_free_evolve"):
		var mats := evolve_materials(uid)
		for i in int(def.evolve_quantity):
			if i < mats.size():
				remove_monster(mats[i])
		data.gold = int(data.gold) - DB.evolve_cost(m.id)
	track("evolve")
	m.id = def.evolves_into
	m.level = 1
	m.exp = 0
	m.boost = 0
	m.boost_pt = 0
	data.seen[m.id] = true
	data.owned[m.id] = true
	save_game()
	return {"ok": true, "into": m.id}

func sell_price(m: Dictionary) -> int:
	if DB.monster(m.id).has("sell_price"):
		return int(DB.monster(m.id).sell_price)
	return 100 *int(DB.monster(m.id).stars) * int(DB.monster(m.id).stars) + 20 * int(m.level)


func sell(uid: int) -> int:
	var m := get_owned(uid)
	if m.is_empty() or m.locked or in_team(uid):
		return 0
	var price := sell_price(m)
	remove_monster(uid)
	data.gold = int(data.gold) + price
	save_game()
	return price


func energy() -> int:
	_tick_energy()
	return int(data.energy)


func seconds_to_next_energy() -> int:
	if int(data.energy) >= int(data.energy_cap):
		return 0
	var elapsed := Time.get_unix_time_from_system() - float(data.energy_stamp)
	return maxi(0, ENERGY_REGEN_SECONDS - int(elapsed))


func pay_quest(quest: Dictionary) -> bool:
	var gems := int(quest.get("gems", 0))
	if gems > 0:
		if int(data.gems) < gems:
			return false
		data.gems = int(data.gems) - gems
		save_game()
		return true
	var fp := int(quest.get("fp", 0))
	if fp > 0:
		if int(data.get("fp", 0)) < fp:
			return false
		data.fp = int(data.fp) - fp
		save_game()
		return true
	return spend_energy(int(quest.energy))


func spend_energy(amount: int) -> bool:
	_tick_energy()
	if int(data.energy) < amount:
		return false
	var was_full := int(data.energy) >= int(data.energy_cap)
	data.energy = int(data.energy) - amount
	track("energy", amount)
	if was_full:
		data.energy_stamp = Time.get_unix_time_from_system()
	save_game()
	return true


func refill_energy() -> bool:
	_tick_energy()
	if int(data.gems) < ENERGY_REFILL_GEMS or int(data.energy) >= int(data.energy_cap):
		return false
	data.gems = int(data.gems) - ENERGY_REFILL_GEMS
	data.energy = int(data.energy_cap)
	data.energy_stamp = Time.get_unix_time_from_system()
	save_game()
	return true


func add_item_boost(kind: String, seconds: int) -> void:
	var key := kind + "_boost_until"
	var now := Time.get_unix_time_from_system()
	data[key] = maxf(float(data.get(key, 0.0)), now) + seconds
	save_game()


func item_boost_left(kind: String) -> int:
	return maxi(0, int(float(data.get(kind + "_boost_until", 0.0)) - Time.get_unix_time_from_system()))


func _tick_energy() -> void:
	if int(data.energy) >= int(data.energy_cap):
		data.energy_stamp = Time.get_unix_time_from_system()
		return
	var now := Time.get_unix_time_from_system()
	var ticks := int((now - float(data.energy_stamp)) / ENERGY_REGEN_SECONDS)
	if ticks > 0:
		data.energy = mini(int(data.energy_cap), int(data.energy) + ticks)
		data.energy_stamp = float(data.energy_stamp) + ticks * ENERGY_REGEN_SECONDS


func cleared_stages(island_id: String, difficulty: String) -> int:
	return int(data.progress.get(island_id, {}).get(difficulty, 0))


func is_island_unlocked(island_id: String, difficulty: String) -> bool:
	var idx := -1
	for i in DB.islands.size():
		if DB.islands[i].id == island_id:
			idx = i
	if idx < 0:
		return false
	var diff_idx := DB.DIFFICULTIES.find(difficulty)
	if diff_idx > 0:
		var prev_diff: String = DB.DIFFICULTIES[diff_idx - 1]
		var stages: int = DB.islands[idx].difficulties.get(prev_diff, {}).get("stages", []).size()
		return cleared_stages(island_id, prev_diff) >= stages
	if idx == 0:
		return true
	var prev: Dictionary = DB.islands[idx - 1]
	return cleared_stages(prev.id, "normal") >= prev.difficulties.normal.stages.size()


func mark_stage_cleared(island_id: String, difficulty: String, stage_index: int) -> bool:
	if not data.progress.has(island_id):
		data.progress[island_id] = {}
	var before := cleared_stages(island_id, difficulty)
	if stage_index + 1 > before:
		data.progress[island_id][difficulty] = stage_index + 1
		var island := DB.island(island_id)
		var total: int = island.difficulties[difficulty].stages.size()
		if stage_index + 1 == total and difficulty != "normal":
			data.energy_cap = int(data.energy_cap) + 1
		return true
	return false


const SPECIAL_UNLOCK_GEMS := 60
const SPECIAL_UNLOCK_SECONDS := 3600


func special_available(s: Dictionary) -> bool:
	return DB.special_open_today(s) or special_unlock_seconds_left(s.id) > 0


func special_unlock_seconds_left(id: String) -> int:
	return maxi(0, int(float(data.special_unlocks.get(id, 0)) - Time.get_unix_time_from_system()))


func special_unlock_gems(id: String) -> int:
	return int(DB.special(id).get("unlock_gems", SPECIAL_UNLOCK_GEMS))


func unlock_special(id: String) -> bool:
	var cost := special_unlock_gems(id)
	if int(data.gems) < cost:
		return false
	data.gems = int(data.gems) - cost
	data.special_unlocks[id] = Time.get_unix_time_from_system() + SPECIAL_UNLOCK_SECONDS
	save_game()
	return true


func mark_quest_cleared(quest: Dictionary) -> bool:
	if quest.kind == "story":
		return mark_stage_cleared(quest.island_id, quest.difficulty, int(quest.stage_index))
	if data.special_clears.has(quest.key):
		return false
	data.special_clears[quest.key] = true
	return true


func tower_tickets() -> int:
	var now := Time.get_unix_time_from_system()
	if int(data.tower_tickets) >= SkyTower.MAX_TICKETS:
		data.tower_stamp = now
	else:
		var ticks := int((now - float(data.tower_stamp)) / SkyTower.TICKET_SECONDS)
		if ticks > 0:
			data.tower_tickets = mini(SkyTower.MAX_TICKETS, int(data.tower_tickets) + ticks)
			data.tower_stamp = float(data.tower_stamp) + ticks * SkyTower.TICKET_SECONDS
	return int(data.tower_tickets)


func seconds_to_next_ticket() -> int:
	if tower_tickets() >= SkyTower.MAX_TICKETS:
		return 0
	return maxi(0, SkyTower.TICKET_SECONDS - int(Time.get_unix_time_from_system() - float(data.tower_stamp)))


func spend_ticket() -> bool:
	if tower_tickets() <= 0:
		return false
	if int(data.tower_tickets) >= SkyTower.MAX_TICKETS:
		data.tower_stamp = Time.get_unix_time_from_system()
	data.tower_tickets = int(data.tower_tickets) - 1
	save_game()
	return true


func mark_floor_cleared(floor: int) -> bool:
	if floor <= int(data.tower_floor):
		return false
	data.tower_floor = floor
	data.tower_tickets = int(data.tower_tickets) + 1
	return true


func add_stone(stone: Dictionary) -> Dictionary:
	var st := {"uid": int(data.next_uid), "type": stone.type, "rank": int(stone.rank), "variant": int(stone.get("variant", 0)), "on": -1}
	data.next_uid = int(data.next_uid) + 1
	data.stones.append(st)
	return st


func sell_stone(uid: int) -> int:
	var st := get_stone(uid)
	if st.is_empty() or int(st.get("on", -1)) >= 0:
		return 0
	var price: int = MagicStones.SELL_PRICE[clampi(int(st.rank), 0, MagicStones.SELL_PRICE.size() - 1)]
	data.stones.erase(st)
	data.gold = int(data.gold) + price
	save_game()
	return price


func sell_stones(uids: Array) -> int:
	var gold := 0
	for uid in uids:
		var st := get_stone(int(uid))
		if st.is_empty() or int(st.get("on", -1)) >= 0:
			continue
		gold += int(MagicStones.SELL_PRICE[clampi(int(st.rank), 0, MagicStones.SELL_PRICE.size() - 1)])
		data.stones.erase(st)
	if gold > 0:
		data.gold = int(data.gold) + gold
		save_game()
	return gold


func expand_stone_box() -> bool:
	if int(data.gems) < MagicStones.STONE_SLOT_GEMS:
		return false
	data.gems = int(data.gems) - MagicStones.STONE_SLOT_GEMS
	data.stone_cap = int(data.stone_cap) + MagicStones.STONE_SLOT_STEP
	save_game()
	return true


func stone_stacks(stones: Array) -> Array:
	var by_key := {}
	var out := []
	for st in stones:
		var k := "%s|%d|%d" % [st.type, int(st.rank), int(st.get("variant", 0))]
		if not by_key.has(k):
			by_key[k] = {"key": k, "stone": st, "uids": []}
			out.append(by_key[k])
		by_key[k].uids.append(int(st.uid))
	return out


func get_stone(uid: int) -> Dictionary:
	for st in data.stones:
		if int(st.uid) == uid:
			return st
	return {}


func free_stones() -> Array:
	return data.stones.filter(func(st): return int(st.get("on", -1)) < 0)


func stone_box_full() -> bool:
	return free_stones().size() >= int(data.stone_cap)


func _same_stones(stone: Dictionary) -> Array:
	return free_stones().filter(func(st): return st.type == stone.type and int(st.rank) == int(stone.rank) and int(st.variant) == int(stone.variant))


func craft_stone(uid: int, variant: int = 1) -> Dictionary:
	var stone := get_stone(uid)
	if stone.is_empty() or int(stone.get("on", -1)) >= 0:
		return {"ok": false, "reason": "Unequip the stone first"}
	var req := MagicStones.craft_requirements(stone, int(data.tower_floor))
	if not req.ok:
		return req
	var same := _same_stones(stone)
	if same.size() < int(req.count):
		return {"ok": false, "reason": "Needs %d× %s" % [int(req.count), MagicStones.label(stone)]}
	if int(data.gold) < int(req.cost):
		return {"ok": false, "reason": "Needs %s gold" % Screen._thousands(int(req.cost))}
	data.gold = int(data.gold) - int(req.cost)
	var used := 0
	for st in same:
		if used >= int(req.count):
			break
		data.stones.erase(st)
		used += 1
	var next_variant := int(stone.variant)
	if int(req.rank) == MagicStones.B:
		next_variant = clampi(variant, 1, 3)
	var made := add_stone({"type": stone.type, "rank": int(req.rank), "variant": next_variant})
	save_game()
	return {"ok": true, "stone": made}


func stone_slots(m: Dictionary) -> int:
	return int(m.get("stone_slots", MagicStones.DEFAULT_SLOTS))


func equipped_stones(m: Dictionary) -> Array:
	if int(m.get("uid", -1)) < 0:
		return []
	return data.stones.filter(func(st): return int(st.get("on", -1)) == int(m.uid))


func stone_in_slot(m: Dictionary, slot: int) -> Dictionary:
	for st in equipped_stones(m):
		if int(st.get("slot", 0)) == slot:
			return st
	return {}


func equip_stone(monster_uid: int, slot: int, stone_uid: int) -> Dictionary:
	var m := get_owned(monster_uid)
	var stone := get_stone(stone_uid)
	if m.is_empty() or stone.is_empty() or slot >= stone_slots(m):
		return {"ok": false, "reason": "Slot locked"}
	var cost: int = MagicStones.EQUIP_COST[int(stone.rank)]
	if int(data.gold) < cost:
		return {"ok": false, "reason": "Needs %s gold" % Screen._thousands(cost)}
	var old := stone_in_slot(m, slot)
	if not old.is_empty():
		data.stones.erase(old)
	data.gold = int(data.gold) - cost
	stone.on = monster_uid
	stone.slot = slot
	save_game()
	return {"ok": true, "replaced": not old.is_empty()}


func unequip_stone(monster_uid: int, slot: int) -> Dictionary:
	var m := get_owned(monster_uid)
	var stone := stone_in_slot(m, slot)
	if stone.is_empty():
		return {"ok": false, "reason": "Empty slot"}
	if stone_box_full():
		return {"ok": false, "reason": "Stone box is full"}
	var cost: int = MagicStones.UNEQUIP_COST[int(stone.rank)]
	if int(data.gold) < cost:
		return {"ok": false, "reason": "Needs %s gold" % Screen._thousands(cost)}
	data.gold = int(data.gold) - cost
	stone.on = -1
	stone.erase("slot")
	save_game()
	return {"ok": true}


func unlock_third_slot(monster_uid: int) -> bool:
	var m := get_owned(monster_uid)
	if stone_slots(m) >= MagicStones.MAX_SLOTS or int(data.gems) < MagicStones.THIRD_SLOT_GEMS:
		return false
	data.gems = int(data.gems) - MagicStones.THIRD_SLOT_GEMS
	m.stone_slots = MagicStones.MAX_SLOTS
	save_game()
	return true


func stone_bonuses(m: Dictionary) -> Dictionary:
	return MagicStones.total_bonuses(equipped_stones(m))


func _today() -> String:
	return Time.get_date_string_from_system()


func raid_today() -> Dictionary:
	var r: Dictionary = data.raid
	if r.is_empty() or r.get("date", "") != _today():
		return {}
	return r


func has_raid_key() -> bool:
	return raid_today().is_empty()


func unlock_raid(raid_id: String) -> bool:
	if not has_raid_key():
		return false
	data.raid = {"date": _today(), "id": raid_id, "picked": [], "hp": {}, "room": 0, "done": false, "gold": 0, "party": []}
	save_game()
	return true


func raid_unlocked(raid_id: String) -> bool:
	return String(raid_today().get("id", "")) == raid_id


func raid_needs_squad() -> bool:
	var r := raid_today()
	return not r.is_empty() and Array(r.get("picked", [])).is_empty()


func start_raid(raid_id: String, uids: Array) -> bool:
	if uids.is_empty() or uids.size() > Raids.PICK:
		return false
	if not has_raid_key() and not (raid_unlocked(raid_id) and raid_needs_squad()):
		return false
	var hp := {}
	var party := []
	var kinds := {}
	for u in uids:
		hp[str(u)] = 1.0
		var kind: String = get_owned(int(u)).get("id", "")
		if not kinds.has(kind) and party.size() < Raids.PARTY:
			kinds[kind] = true
			party.append(u)
	data.raid = {"date": _today(), "id": raid_id, "picked": uids.duplicate(), "hp": hp, "room": 0, "done": false, "gold": 0, "party": party}
	save_game()
	return true


func raid_alive() -> Array:
	var r := raid_today()
	var out := []
	for u in r.get("picked", []):
		if float(r.hp.get(str(int(u)), 0.0)) > 0.0 and not get_owned(int(u)).is_empty():
			out.append(int(u))
	return out


func raid_hp(uid: int) -> float:
	return float(raid_today().get("hp", {}).get(str(uid), 0.0))


func record_raid_room(hp_by_uid: Dictionary, won: bool, gold: int) -> void:
	var r := raid_today()
	if r.is_empty():
		return
	for k in hp_by_uid:
		r.hp[str(int(k))] = float(hp_by_uid[k])
	if won:
		track("raid_room")
		r.gold = int(r.get("gold", 0)) + gold
		r.room = int(r.room) + 1
		if int(r.room) >= Raids.ROOMS:
			r.done = true
			data.raid_cleared[r.id] = int(data.raid_cleared.get(r.id, 0)) + 1
	if raid_alive().is_empty():
		r.done = true
	save_game()


func arena_tokens() -> int:
	var now := Time.get_unix_time_from_system()
	if int(data.arena_tokens) >= Arena.MAX_TOKENS:
		data.arena_stamp = now
	else:
		var ticks := int((now - float(data.arena_stamp)) / Arena.TOKEN_SECONDS)
		if ticks > 0:
			data.arena_tokens = mini(Arena.MAX_TOKENS, int(data.arena_tokens) + ticks)
			data.arena_stamp = float(data.arena_stamp) + ticks * Arena.TOKEN_SECONDS
	return int(data.arena_tokens)


func seconds_to_next_token() -> int:
	if arena_tokens() >= Arena.MAX_TOKENS:
		return 0
	return maxi(0, Arena.TOKEN_SECONDS - int(Time.get_unix_time_from_system() - float(data.arena_stamp)))


func arena_state() -> Dictionary:
	var week := Arena.week_id()
	var a: Dictionary = data.arena
	if a.is_empty() or int(a.get("week", -1)) != week:
		var summary := {}
		if not a.is_empty() and int(a.get("entries", 0)) > 0:
			summary = _settle_arena_week(a)
		data.arena = {"week": week, "points": 0, "entries": 0, "wins": 0, "losses": 0, "last_week": summary}
		save_game()
	return data.arena


func _settle_arena_week(a: Dictionary) -> Dictionary:
	var rank := arena_rank(a, 1.0)
	var honour := Arena.honour_for_rank(rank, Arena.RIVALS + 1)
	var gems := Arena.entry_gems(int(a.entries))
	data.honor = int(data.honor) + honour
	data.gems = int(data.gems) + gems
	var lucky := []
	for t in Arena.lucky_draw():
		Mail.send(Mail.TEAM, {String(t[1]): "red" if t[1] == "cube" else int(t[2])}, "Lucky Chest %s!" % String(t[0]), true)
		lucky.append(String(t[0]))
	return {"rank": rank, "points": int(a.points), "honor": honour, "gems": gems, "lucky": lucky}


func arena_rank(a: Dictionary, progress: float) -> int:
	var rank := 1
	for r in Arena.rivals(int(a.week)):
		if Arena.rival_points(r, progress) > int(a.points):
			rank += 1
	return rank


func spend_arena_entry() -> bool:
	if arena_tokens() > 0:
		if int(data.arena_tokens) >= Arena.MAX_TOKENS:
			data.arena_stamp = Time.get_unix_time_from_system()
		data.arena_tokens = int(data.arena_tokens) - 1
	elif int(data.gems) >= Arena.GEM_ENTRY:
		data.gems = int(data.gems) - Arena.GEM_ENTRY
	else:
		return false
	var a := arena_state()
	a.entries = int(a.entries) + 1
	save_game()
	return true


func record_arena(win: bool, rival_skill: float) -> int:
	var a := arena_state()
	track("arena")
	var delta := Arena.points_for(win, rival_skill)
	a.points = maxi(0, int(a.points) + delta)
	if win:
		a.wins = int(a.wins) + 1
		a["streak"] = int(a.get("streak", 0)) + 1
		a["best_streak"] = maxi(int(a.get("best_streak", 0)), int(a.streak))
	else:
		a.losses = int(a.losses) + 1
		a["streak"] = 0
	save_game()
	return delta


func track(event: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	var c: Dictionary = data.counters
	var day := _today()
	var week := str(Arena.week_id())
	if c.get("day", "") != day:
		c.day = day
		c.daily = {}
	if str(c.get("week", "")) != week:
		c.week = week
		c.weekly = {}
	if not c.has("total"):
		c.total = {}
	for bucket in ["daily", "weekly", "total"]:
		if not c.has(bucket):
			c[bucket] = {}
		c[bucket][event] = int(c[bucket].get(event, 0)) + amount


func counter(bucket: String, event: String) -> int:
	track("_", 0)
	var c: Dictionary = data.counters
	if bucket == "daily" and c.get("day", "") != _today():
		return 0
	if bucket == "weekly" and str(c.get("week", "")) != str(Arena.week_id()):
		return 0
	return int(c.get(bucket, {}).get(event, 0))


func _claim_key(kind: String, id: String) -> String:
	if kind == "event":
		return "event|" + id
	return "%s|%s|%s" % [kind, id, _today() if kind == "daily" else str(Arena.week_id())]


func mission_claimed(kind: String, id: String) -> bool:
	return data.claimed.has(_claim_key(kind, id))


func grant(r: Dictionary) -> void:
	data.gold = int(data.gold) + int(r.get("gold", 0))
	data.gems = int(data.gems) + int(r.get("gems", 0))
	data.energy = int(data.energy) + int(r.get("energy", 0))
	if r.has("cube"):
		data.cube_items[r.cube] = int(data.cube_items.get(r.cube, 0)) + 1
	if r.has("monster"):
		add_monster(String(r.monster), 1)


func claim_mission(kind: String, m: Dictionary) -> bool:
	if mission_claimed(kind, m.id) or Missions.progress(kind, m.event) < int(m.goal):
		return false
	data.claimed[_claim_key(kind, m.id)] = true
	grant(m.reward)
	if kind == "daily":
		track("daily_done")
	for k in data.claimed.keys():
		if not (k.begins_with("event|") or k.ends_with(_today()) or k.ends_with("|" + str(Arena.week_id()))):
			data.claimed.erase(k)
	save_game()
	return true


func daily_all_done() -> bool:
	for m in Missions.DAILY:
		if not mission_claimed("daily", m.id):
			return false
	return true


func daily_bonus_ready() -> bool:
	return daily_all_done() and not mission_claimed("daily", "all")


func claim_daily_bonus() -> bool:
	if not daily_all_done() or mission_claimed("daily", "all"):
		return false
	data.claimed[_claim_key("daily", "all")] = true
	grant(Missions.DAILY_ALL)
	save_game()
	return true


func endless_tier_of(id: String) -> int:
	return int(data.endless.get(id, 0))


func claim_endless(m: Dictionary) -> bool:
	var tier := endless_tier_of(m.id)
	var t := Missions.endless_tier(m, tier)
	if t.done_all or Missions.progress("endless", m.event) < int(t.goal):
		return false
	data.endless[m.id] = tier + 1
	grant(t.reward)
	save_game()
	return true


func attendance() -> Dictionary:
	var month := _today().substr(0, 7)
	var a: Dictionary = data.attendance
	if a.get("month", "") != month:
		data.attendance = {"month": month, "days": 0, "last": ""}
	return data.attendance


func attendance_ready() -> bool:
	var a := attendance()
	return a.last != _today() and int(a.days) < Missions.ATTENDANCE.size()


func claim_attendance() -> Dictionary:
	if not attendance_ready():
		return {}
	var a := attendance()
	var r: Dictionary = Missions.ATTENDANCE[int(a.days)]
	a.days = int(a.days) + 1
	a.last = _today()
	grant(r)
	save_game()
	return r


const LEAGUE_TEAM := 12
const LEAGUE_TICKETS := 10
const LEAGUE_TICKET_SECONDS := 1800
const LEAGUE_ENTRY := 2
const LEAGUE_GOLD_ENTRY := 10000
const LEAGUE_START_POINTS := 1000
const LEAGUE_SEASON_GAMES := 120.0


func league() -> Dictionary:
	var week := LeagueSeasons.index()
	var l: Dictionary = data.league
	if l.is_empty() or int(l.get("season", -1)) != week:
		var summary := {}
		if not l.is_empty() and int(l.get("rounds", 0)) > 0:
			summary = _settle_league(l)
		data.league = {"season": week, "points": LEAGUE_START_POINTS, "wins": 0, "streak": 0, "rounds": 0,
			"team": l.get("team", []), "tickets": int(l.get("tickets", LEAGUE_TICKETS)), "stamp": float(l.get("stamp", Time.get_unix_time_from_system())),
			"last_season": summary}
		save_game()
	return data.league


func _settle_league(l: Dictionary) -> Dictionary:
	var rank := league_rank(l, 1.0)
	var prize := LeagueSeasons.reward_for(rank)
	var honour: int = prize[0]
	var name := String(LeagueSeasons.season(int(l.season)).name)
	if honour > 0:
		Mail.send(Mail.TEAM, {"honor": honour}, "%s reward: finished rank %d" % [name, rank], true)
	if int(prize[1]) > 0:
		Mail.send(Mail.TEAM, {"gems": int(prize[1])}, "%s reward: finished rank %d" % [name, rank], true)
	var badge := String(prize[2])
	if badge != "":
		var key := LeagueSeasons.badge_key(int(l.season), badge)
		data.badges[key] = int(data.badges.get(key, 0)) + 1
	data.wing = int(prize[3])
	return {"rank": rank, "points": int(l.points), "honor": honour, "gems": int(prize[1]), "badge": badge, "wing": int(prize[3]), "name": name}


func league_rank(l: Dictionary, progress: float) -> int:
	var rank := 1
	for r in Arena.rivals(int(l.season) + 7777):
		if LEAGUE_START_POINTS + Arena.rival_points(r, progress, LEAGUE_SEASON_GAMES) > int(l.points):
			rank += 1
	return rank


func league_tickets() -> int:
	var l := league()
	var now := Time.get_unix_time_from_system()
	if int(l.tickets) >= LEAGUE_TICKETS:
		l.stamp = now
	else:
		var ticks := int((now - float(l.stamp)) / LEAGUE_TICKET_SECONDS)
		if ticks > 0:
			l.tickets = mini(LEAGUE_TICKETS, int(l.tickets) + ticks)
			l.stamp = float(l.stamp) + ticks * LEAGUE_TICKET_SECONDS
	return int(l.tickets)


func spend_league_entry() -> bool:
	if league_tickets() < LEAGUE_ENTRY:
		return false
	var l := league()
	if int(l.tickets) >= LEAGUE_TICKETS:
		l.stamp = Time.get_unix_time_from_system()
	l.tickets = int(l.tickets) - LEAGUE_ENTRY
	save_game()
	return true


func record_league(win: bool, rival_skill: float) -> int:
	var l := league()
	var delta := Arena.points_for(win, rival_skill)
	l.points = maxi(0, int(l.points) + delta)
	l.rounds = int(l.rounds) + 1
	if win:
		l.wins = int(l.wins) + 1
		l.streak = int(l.streak) + 1
	else:
		l.streak = 0
	track("arena")
	save_game()
	return delta

