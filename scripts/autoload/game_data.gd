extends Node

const MAX_LEVEL := 30
const MAX_BOOST := 5
const BOOST_PCT := 0.05
const ELEMENT_BONUS := 1.5
const ELEMENT_PENALTY := 0.5
const BEATS := {"fire": "nature", "nature": "water", "water": "fire"}
const DIFFICULTIES := ["normal", "hard", "hell"]

var monsters: Dictionary = {}
var islands: Array = []
var special_islands: Array = []
var raids: Array = []
var pets: Array = []
var tips: Array = []

var _avg_base_by_stars: Dictionary = {}
var _avg_growth_by_stars: Dictionary = {}
var _portraits: Dictionary = {}
var _placeholder: Texture2D


func _ready() -> void:
	monsters = _load_json("res://data/monsters.json")
	for id in monsters:
		var m: Dictionary = monsters[id]
		if m.has("passive"):
			m.passive = String(m.passive).strip_edges().lstrip("-").strip_edges()
	islands = _load_json("res://data/islands.json")
	islands.sort_custom(func(a, b): return a.order < b.order)
	special_islands = _load_json("res://data/special_islands.json").islands
	raids = _load_json("res://data/raids.json").raids
	pets = _load_json("res://data/pets.json")
	tips = _load_json("res://data/tips.json").tips
	_merge_footage_quotes()
	_compute_fallbacks()


func monster(id: String) -> Dictionary:
	return monsters.get(id, {})


const GRADES := ["C", "B", "A", "S", "S+"]


func grade_rank(id: String) -> int:
	return GRADES.find(String(monster(id).get("class", "")))


func compare_grade(a: Dictionary, b: Dictionary) -> int:
	var ga := grade_rank(a.id)
	var gb := grade_rank(b.id)
	if ga != gb:
		return ga - gb
	return int(monster(a.id).stars) - int(monster(b.id).stars)


func has_monster(id: String) -> bool:
	return monsters.has(id)


func island(id: String) -> Dictionary:
	for i in islands:
		if i.id == id:
			return i
	return {}


func pet(id: String) -> Dictionary:
	for p in pets:
		if p.id == id:
			return p
	return {}


func pet_texture(id: String) -> Texture2D:
	for ext in ["png", "webp"]:
		var path := "res://assets/pets/%s.%s" % [id, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return _get_placeholder()


func special(id: String) -> Dictionary:
	for s in special_islands:
		if s.id == id:
			return s
	return {}


func special_open_today(s: Dictionary) -> bool:
	if Events.opens(String(s.id)):
		return true
	if Events.event_only(String(s.id)):
		return false
	var days: Array = s.days
	var wd := int(Time.get_date_dict_from_unix_time(Events.now()).weekday)
	return days.is_empty() or days.has(float(wd)) or days.has(wd)


const WEEKDAYS := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]


func special_days_text(s: Dictionary) -> String:
	var days: Array = s.days
	if Events.event_only(String(s.id)):
		return "Opens during events"
	if days.is_empty():
		return "Always open"
	var names := []
	for d in days:
		names.append(WEEKDAYS[int(d)])
	return "Open " + "/".join(names)


func stats_at(id: String, level: int, boost: int = 0) -> Dictionary:
	var m := monster(id)
	var base: Dictionary = m.stats
	var top: Dictionary = m.stats_max
	var t := clampf(float(level - 1) / float(MAX_LEVEL - 1), 0.0, 1.0)
	var mult := 1.0 + BOOST_PCT * clampi(boost, 0, MAX_BOOST)
	var out := {}
	var top50: Dictionary = m.get("stats_50", {})
	for k in ["hp", "atk", "def", "rec"]:
		var lo := float(base[k])
		var hi := float(top[k])
		var v := lerpf(lo, hi, t)
		if level > MAX_LEVEL:
			var above := float(level - MAX_LEVEL)
			if top50.has(k) and float(top50[k]) > hi:
				v = lerpf(hi, float(top50[k]), above / float(AWAKEN_MAX - MAX_LEVEL))
			else:
				v = hi + above * 4.0 * (hi - lo) / float(MAX_LEVEL - 1)
		out[k] = roundi(v * (mult if k != "def" else 1.0))
	out["mp"] = int(base.mp)
	return out


func element_mult(attacker: String, defender: String) -> float:
	if BEATS.get(attacker, "") == defender:
		return ELEMENT_BONUS
	if BEATS.get(defender, "") == attacker:
		return ELEMENT_PENALTY
	return 1.0


const EXP_TABLE := [
	[2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 18, 20, 22, 24],
	[9, 9, 9, 10, 11, 12, 13, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 35, 38, 41, 44, 47, 50, 54, 58, 62, 66, 70, 75],
	[16, 17, 18, 20, 22, 24, 26, 29, 32, 35, 38, 42, 46, 50, 54, 58, 62, 67, 72, 77, 82, 88, 94, 100, 107, 114, 121, 129, 137],
	[20, 22, 24, 27, 30, 33, 36, 40, 44, 48, 52, 57, 62, 67, 72, 78, 84, 90, 97, 104, 111, 119, 127, 135, 143, 152, 161, 170, 180],
	[27, 30, 33, 36, 40, 44, 48, 53, 58, 63, 69, 75, 82, 89, 97, 105, 114, 123, 133, 143, 154, 166, 179, 193, 208, 224, 241, 259, 278],
	[40, 45, 50, 55, 61, 67, 73, 80, 87, 95, 103, 112, 121, 131, 141, 152, 163, 175, 188, 202, 217, 233, 250, 268, 287, 307, 328, 350, 373],
]
const BOOST_CHANCE := [1.0, 0.8, 0.4, 0.2, 0.1, 0.05]
const BOOST_PT := [0, 32, 16, 6, 2, 0]
const BOOST_COST := [
	[576, 657, 1472, 2451, 3591],
	[747, 853, 1912, 3185, 4668],
	[868, 995, 2231, 3714, 5446],
	[1139, 1301, 2917, 4857, 7120],
	[1431, 1639, 3677, 6122, 8975],
	[1837, 2097, 4706, 7836, 11487],
]
const FUSION_COST := {1: 1000, 2: 20000, 3: 50000, 4: 100000, 5: 500000}
const AWAKEN_MAX := 50
const AWAKEN_GOLD_PER_CAP := 5000
const PET_LEVEL := {1: 30, 2: 33, 3: 35, 4: 30}


func exp_to_next(level: int, stars: int) -> int:
	var row: Array = EXP_TABLE[clampi(stars, 1, 6) - 1]
	if level < 30:
		return int(row[level - 1])
	return int(float(row[28]) * (1.0 + 0.1 * (level - 29)))


func boost_chance(target_id: String, material_id: String) -> float:
	var diff: int = int(monster(target_id).stars) - int(monster(material_id).stars)
	return BOOST_CHANCE[clampi(diff, 0, 5)]


func boost_pt_on_fail(target_id: String, material_id: String) -> int:
	var diff: int = int(monster(target_id).stars) - int(monster(material_id).stars)
	return BOOST_PT[clampi(diff, 0, 5)]


func boost_cost(target_id: String, current_boost: int) -> int:
	return BOOST_COST[clampi(int(monster(target_id).stars), 1, 6) - 1][clampi(current_boost, 0, 4)]


func fusion_cost(stars: int) -> int:
	return FUSION_COST.get(stars, 500000)


func feed_exp(id: String, level: int) -> int:
	var stars: int = clampi(int(monster(id).stars), 1, 6)
	var spent := 0
	for l in range(1, mini(level, 30)):
		spent += int(EXP_TABLE[stars - 1][l - 1])
	return 30 * stars + spent / 2


func feed_cost(target_id: String) -> int:
	return 120 * int(monster(target_id).stars)

func lv30_gems(stars: int) -> int:
	return {1: 1, 2: 2, 3: 3, 4: 5, 5: 10, 6: 15}.get(stars, 1)


func evolve_cost(_id: String) -> int:
	return 0


func portrait(id: String) -> Texture2D:
	if _portraits.has(id):
		return _portraits[id]
	var path := "res://assets/monsters/%s.webp" % id
	if not ResourceLoader.exists(path):
		path = "res://assets/monsters/%s.png" % id
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else _get_placeholder()
	_portraits[id] = tex
	return tex


func icon(id: String) -> Texture2D:
	var key := "icon:" + id
	if _portraits.has(key):
		return _portraits[key]
	var tex: Texture2D = null
	for ext in ["png", "webp", "jpg"]:
		var path := "res://assets/icons/%s.%s" % [id, ext]
		if ResourceLoader.exists(path):
			tex = load(path)
			break
	if tex == null:
		tex = battle_sprite(id)
	_portraits[key] = tex
	return tex


func has_icon(id: String) -> bool:
	return icon(id) != battle_sprite(id)


func skill_icon(icon_file: String) -> Texture2D:
	var key := icon_file.get_basename().replace(" ", "_").to_lower()
	for k in [key, key.replace("_and_", "_+_"), key.replace("heal_+_cure", "cure"), key.split("_+_")[0]]:
		for ext in ["webp", "png", "jpg"]:
			var path := "res://assets/skill_icons/%s.%s" % [k, ext]
			if ResourceLoader.exists(path):
				return load(path)
	return null


func island_art(id: String) -> Texture2D:
	for ext in ["png", "webp", "jpg"]:
		var path := "res://assets/islands/%s.%s" % [id, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null


func battle_sprite(id: String) -> Texture2D:
	var key := "cut:" + id
	if _portraits.has(key):
		return _portraits[key]
	var path := "res://assets/monsters_cut/%s.png" % id
	var tex: Texture2D
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		var card := portrait(id)
		var atlas := AtlasTexture.new()
		atlas.atlas = card
		var s := card.get_size()
		atlas.region = Rect2(s.x * 0.08, s.y * 0.16, s.x * 0.84, s.y * 0.64)
		tex = atlas
	_portraits[key] = tex
	return tex


func element_color(element: String) -> Color:
	return {"fire": Color("e85a2a"), "water": Color("2f8fe8"), "nature": Color("4fb83a"), "normal": Color("c9a24a")}.get(element, Color.WHITE)


func ids_where(filter: Callable) -> Array:
	var out := []
	for id in monsters:
		if filter.call(monsters[id]):
			out.append(id)
	return out


func _compute_fallbacks() -> void:
	var sums := {}
	var growth := {}
	for id in monsters:
		var m: Dictionary = monsters[id]
		var s: int = m.stars
		if int(m.stats.hp) > 0:
			if not sums.has(s):
				sums[s] = {"hp": 0.0, "atk": 0.0, "def": 0.0, "rec": 0.0, "n": 0}
			for k in ["hp", "atk", "def", "rec"]:
				sums[s][k] += float(m.stats[k])
			sums[s].n += 1
			if int(m.stats_max.hp) > 0:
				if not growth.has(s):
					growth[s] = {"hp": 0.0, "atk": 0.0, "rec": 0.0, "n": 0}
				for k in ["hp", "atk", "rec"]:
					growth[s][k] += float(m.stats_max[k]) / maxf(1.0, float(m.stats[k]))
				growth[s].n += 1
	for s in sums:
		var n: float = sums[s].n
		_avg_base_by_stars[s] = {"hp": sums[s].hp / n, "atk": sums[s].atk / n, "def": sums[s].def / n, "rec": sums[s].rec / n}
	for s in growth:
		var n: float = growth[s].n
		_avg_growth_by_stars[s] = {"hp": growth[s].hp / n, "atk": growth[s].atk / n, "rec": growth[s].rec / n}

	for id in monsters:
		var m: Dictionary = monsters[id]
		var s: int = m.stars
		if int(m.stats.hp) <= 0 and _avg_base_by_stars.has(s):
			for k in ["hp", "atk", "def", "rec"]:
				m.stats[k] = roundi(_avg_base_by_stars[s][k])
		for k in ["hp", "atk", "rec"]:
			if int(m.stats_max[k]) <= 0:
				m.stats_max[k] = roundi(float(m.stats[k]) * _avg_growth_by_stars.get(s, {"hp": 2.0, "atk": 1.6, "rec": 2.0})[k])
		if int(m.stats_max.def) <= 0:
			m.stats_max.def = m.stats.def


func _merge_footage_quotes() -> void:
	var data: Variant = _load_json("res://data/quotes_footage.json")
	if not data is Dictionary:
		return
	var fixes := {"•": "'", " l.": " I.", " l ": " I ", "rne": "me", ".,": "...", "  ": " "}
	for id in data.quotes:
		if not monsters.has(id) or String(monsters[id].get("quote", "")) != "":
			continue
		var q: String = data.quotes[id]
		for k in fixes:
			q = q.replace(k, fixes[k])
		monsters[id].quote = q.strip_edges()


func _get_placeholder() -> Texture2D:
	if _placeholder == null:
		var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.3, 0.25, 0.2))
		_placeholder = ImageTexture.create_from_image(img)
	return _placeholder


func _load_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if data == null:
		push_error("failed to parse " + path)
	return data
