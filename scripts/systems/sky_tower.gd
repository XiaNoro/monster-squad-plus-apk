class_name SkyTower
extends RefCounted

const FLOORS := 50
const MAX_TICKETS := 5
const TICKET_SECONDS := 7200
const ROOMS := 3
const ROOM_SECONDS := 90.0
const SHORT_ROOM_SECONDS := 60.0
const TICKET_GEMS := 30
const RIVALS := 99
const PAIRS := [["blessed", "clarity"], ["thunder", "spirit"], ["windfury", "destruction"], ["vitality", "steel"], ["bravery", "time"]]
const TRAITS := [
	{"id": "anti_heal", "tip": "Counter enemy healers by using skills that reduce the target's Recovery."},
	{"id": "curse", "tip": "Don't let the enemy curses keep you down. Lift negative status effects early and often."},
	{"id": "weakness", "tip": "Enemies have moments of weakness in battle. Time your attacks for when they become weak."},
	{"id": "armored", "tip": "Certain skills like bleed, burn, freeze and poison ignore defense. Use them to take down durable opponents."},
	{"id": "pierce", "tip": "Boss enemies periodically lash out with powerful attacks. These attacks ignore shields, so build a team of monsters with high HP."},
	{"id": "healer", "tip": "The boss heals itself. Bring stuns and burst damage to stop the heal."},
	{"id": "enrage", "tip": "The boss grows stronger every 20 seconds. Defeat it quickly!"},
	{"id": "swift", "tip": "The boss attacks with blinding speed. Slow it down or keep your shields up."},
	{"id": "reflect", "tip": "The boss reflects damage back at attackers. Keep an eye on your HP."},
	{"id": "time_limit", "tip": "The boss room is short on time. Save your Fever for the boss!"},
]


static var _known: Dictionary = {}


static func known(floor: int) -> Dictionary:
	if _known.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/tower_floors.json"))
		_known = parsed if parsed is Dictionary else {"_": true}
	return _known.get(str(floor), {})


static func traits_for(floor: int) -> Array:
	var out := [TRAITS[(floor - 1) % TRAITS.size()]]
	if floor > 30:
		var extra: Dictionary = TRAITS[(floor * 3 + 1) % TRAITS.size()]
		if extra.id != out[0].id:
			out.append(extra)
	return out


static func pair_for(floor: int) -> Array:
	return PAIRS[(floor - 1) % PAIRS.size()]


static func drop_ranks(floor: int) -> Vector2i:
	var band := (floor - 1) / 5
	var common := clampi(band, 0, MagicStones.A)
	var rare := clampi(MagicStones.B + band / 3, MagicStones.B, MagicStones.S)
	return Vector2i(common, rare)


static func floor_quest(floor: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * floor
	var band := clampi(2 + floor / 10, 2, 6)
	var pool := DB.ids_where(func(m): return int(m.stars) == band and not m.material)
	var boss_pool := DB.ids_where(func(m): return int(m.stars) == mini(6, band + 1) and not m.material)
	var enemies := []
	for i in 4:
		enemies.append(pool[rng.randi() % pool.size()])
	var traits := traits_for(floor)
	var trait_ids := []
	for t in traits:
		trait_ids.append(t.id)
	var past15 := maxi(0, floor - 15)
	var info := known(floor)
	if info.has("enemies"):
		enemies = info.enemies.duplicate()
	var boss: String = String(info.get("boss", boss_pool[rng.randi() % boss_pool.size()]))
	var q := {
		"kind": "tower",
		"key": "tower/%d" % floor,
		"title": "Sky Tower  ·  Floor %d" % floor,
		"floor": floor,
		"energy": 0,
		"level": mini(DB.MAX_LEVEL, 10 + floor / 2),
		"boss": boss,
		"enemies": enemies,
		"stages": ROOMS,
		"gold": 300.0 * floor,
		"exp": 0.0,
		"drops": false,
		"boss_drop_chance": 0.0,
		"drop_level": [1, 1],
		"first_clear_drop": false,
		"hp_mult": 1.0 + 0.15 * past15,
		"atk_mult": 1.0 + 0.05 * past15,
		"boss_traits": trait_ids,
		"tips": traits.map(func(t): return t.tip),
		"room_limit": ROOM_SECONDS,
		"final_room_limit": SHORT_ROOM_SECONDS if trait_ids.has("time_limit") else 0.0,
		"fever": true,
	}
	if info.has("rooms"):
		var waves := []
		var rooms: Array = info.rooms
		for r in rooms.size():
			var wave := []
			for i in rooms[r].size():
				var last: bool = r == rooms.size() - 1 and i == 0
				wave.append({"id": rooms[r][i], "level": mini(DB.MAX_LEVEL, int(q.level) + (1 if last else 0)), "boss": last,
					"traits": trait_ids if last else [], "hp_mult": q.hp_mult, "atk_mult": q.atk_mult})
			waves.append(wave)
		q["fixed_waves"] = waves
		q["enemies"] = rooms[0]
	return q


static func possible_drops(floor: int, bought: bool = false) -> Array:
	var info := known(floor)
	if info.has("drops") and not bought:
		var out := []
		for d in info.drops:
			out.append({"type": String(d[0]), "rank": MagicStones.RANKS.find(String(d[1])), "variant": int(d[2])})
		return out
	var pair := pair_for(floor)
	var ranks := drop_ranks(floor)
	var variant := 3 - ((floor - 1) / 5) % 3
	var rare := {"type": pair[0], "rank": ranks.y, "variant": variant}
	var rare2 := {"type": pair[1], "rank": ranks.y, "variant": variant}
	var common := {"type": pair[0], "rank": ranks.x, "variant": 0 if ranks.x < MagicStones.B else variant}
	if bought:
		var lower := maxi(0, ranks.y - 1)
		return [{"type": pair[1], "rank": lower, "variant": variant if lower >= MagicStones.B else 0}, common]
	return [rare, rare2, common]


static func roll_stones(floor: int, rng: RandomNumberGenerator, bought: bool = false) -> Array:
	var roll := rng.randf()
	var boxes := 0 if roll < 0.15 else (1 if roll < 0.75 else 2)
	var drops := possible_drops(floor, bought)
	var out := []
	for i in boxes:
		var pick: Dictionary = drops[drops.size() - 1]
		if rng.randf() < 0.12:
			pick = drops[rng.randi() % (drops.size() - 1)]
		out.append(pick.duplicate())
	return out


static func box_texture(stone: Dictionary) -> Texture2D:
	return UI.tex("betaHud00/H_cube_0%d.png" % (3 if int(stone.rank) < MagicStones.B else (4 if int(stone.rank) < MagicStones.S else 5)))


static func fever() -> int:
	return int(Save.data.get("tower_fever", 0))


static func set_fever(v: float) -> void:
	Save.data["tower_fever"] = clampi(int(v), 0, int(BattleEngine.FEVER_MAX))


static func buy_ticket() -> bool:
	if int(Save.data.gems) < TICKET_GEMS or Save.tower_tickets() >= MAX_TICKETS:
		return false
	Save.data.gems = int(Save.data.gems) - TICKET_GEMS
	Save.data.tower_tickets = int(Save.data.tower_tickets) + 1
	Save.data["tower_bought"] = int(Save.data.get("tower_bought", 0)) + 1
	Save.save_game()
	return true


static func enter(floor: int) -> Dictionary:
	if not Save.spend_ticket():
		return {}
	var q := floor_quest(floor)
	q["bought"] = use_bought_ticket()
	Save.save_game()
	return q


static func use_bought_ticket() -> bool:
	var n := int(Save.data.get("tower_bought", 0))
	if n <= 0:
		return false
	Save.data["tower_bought"] = n - 1
	return true


static func _rival(i: int, week: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = week * 6151 + i * 97
	var name := ""
	for k in rng.randi_range(2, 3):
		name += Arena.SYLLABLES[rng.randi() % Arena.SYLLABLES.size()]
	name = name.capitalize() + (str(rng.randi_range(1, 999)) if rng.randf() < 0.5 else "")
	var top := clampi(FLOORS - int(pow(rng.randf(), 0.55) * FLOORS), 1, FLOORS)
	var pool := DB.ids_where(func(m): return int(m.stars) >= 5 and not m.material)
	return {"name": name, "floor": top, "secs": snappedf(rng.randf_range(4.0, 80.0) + top * 0.6, 0.1), "monster": pool[rng.randi() % pool.size()]}


static func friend_floor(name: String) -> int:
	var h := absi(hash(name))
	return clampi(h % (int(Save.data.tower_floor) + 6) + 1, 1, FLOORS)


static func rank_list() -> Array:
	var week := Arena.week_id()
	var out := []
	for i in RIVALS:
		out.append(_rival(i, week))
	var mine := int(Save.data.tower_floor)
	var lead: Array = Save.team_members()
	out.append({"name": String(Save.data.get("name", "Tamer")), "floor": mine,
		"secs": snappedf(float(Save.data.best_times.get("tower/%d" % mine, 0.0)), 0.1),
		"monster": lead[0].id if not lead.is_empty() else "firepaw", "me": true})
	out.sort_custom(func(a, b): return int(a.floor) > int(b.floor) or (int(a.floor) == int(b.floor) and float(a.secs) < float(b.secs)))
	for i in out.size():
		out[i]["rank"] = i + 1
	return out
