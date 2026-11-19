class_name LeagueSeasons
extends RefCounted

const BOOST_ATK := 1000.0
const SIX_STAR_HALF := {"stars": 6, "stat": "atk", "mult": 0.5, "text": "6-star Monster ATK decreased by 50%"}
const NORMAL_DEF := {"element": "normal", "stat": "def", "add": -100.0, "text": "Normal Monster DEF decreased by 100"}
const SIX_STAR_DEF := {"stars": 6, "stat": "def", "add": -100.0, "text": "6-star Monster DEF decreased by 100"}
const SEASONS := [
	{"name": "Robo Island League", "badge": "robo", "bg": "robo_island", "boost": ["urscout_p", "urscout_o", "urscout_b", "urscout_g"], "rules": [SIX_STAR_HALF, SIX_STAR_DEF]},
	{"name": "Dino Gorge League", "badge": "dino", "bg": "dino_cave", "boost": ["glinthide", "rubyhide", "jadehide", "azurehide"], "rules": [SIX_STAR_HALF]},
	{"name": "Deep Ocean League", "bg": "deep_ocean_island", "boost": ["whalgent", "shaark", "mini_coral"], "rules": [
		{"element": "water", "stat": "def", "add": 100.0, "text": "Water Monster DEF increased by 100"},
		{"element": "fire", "stat": "atk", "mult": 0.9, "text": "Fire Monsters ATK decreased by 10%"},
		SIX_STAR_HALF,
	]},
	{"name": "Volcano Isle League", "badge": "volcano", "bg": "duel_cave", "team": 8, "boost": ["red_antlar", "bonk_pyro", "twinbark", "flame_steed"], "boost_atk": 0.0, "rules": [
		{"id": "red_antlar", "stat": "atk", "add": 1000.0, "text": "Red Antlar ATK increased by 1000"},
		{"id": "bonk_pyro", "stat": "atk", "add": 1000.0, "text": "Bonk Pyro ATK increased by 1000"},
		{"id": "twinbark", "stat": "atk", "add": 1000.0, "text": "Twinbark ATK increased by 1000"},
		{"id": "flame_steed", "stat": "atk", "add": 2500.0, "text": "Flame Steed ATK increased by 2500"},
		SIX_STAR_HALF,
	]},
	{"name": "Spirit Forest League", "bg": "nature_spirits_forest", "team": 8, "boost": ["aqua_spirit", "leaf_spirit", "volt_spirit"], "rules": [
		{"element": "nature", "stat": "def", "add": 100.0, "text": "Nature Monster DEF increased by 100"},
		{"element": "normal", "stat": "atk", "mult": 0.9, "text": "Normal Monsters ATK decreased by 10%"},
		SIX_STAR_HALF,
	]},
	{"name": "Pharaoh League", "bg": "pharaoh_desert", "boost": ["anuk", "aqus", "granuk"], "boost_atk": 0.0, "rules": [
		{"id": "anuk", "stat": "atk", "add": 1000.0, "text": "Anuk ATK increased by 1000"},
		{"id": "aqus", "stat": "atk", "add": 1000.0, "text": "Aqus ATK increased by 1000"},
		{"id": "granuk", "stat": "atk", "add": 2500.0, "text": "Granuk ATK increased by 2500"},
		NORMAL_DEF,
		SIX_STAR_HALF,
		SIX_STAR_DEF,
	]},
	{"name": "Maple League", "bg": "maple_castle", "team": 8, "boost": ["pink_bean", "e_pink_bean"], "rules": [
		{"stars": 3, "stat": "hp", "mult": 5.0, "text": "3-star Monster HP increased by 400%"},
		{"stars": 6, "stat": "atk", "mult": 0.9, "text": "6-star Monster ATK decreased by 10%"},
	]},
	{"name": "Sprout Island League", "badge": "sprout", "bg": "sprout_meadow", "team": 8, "boost": ["ulmigrand", "patchuus", "smullock"], "boost_atk": 0.0, "rules": [
		{"id": "ulmigrand", "stat": "atk", "add": 1000.0, "text": "Ulmigrand ATK increased by 1000"},
		{"stars": 3, "stat": "hp", "mult": 5.0, "text": "3-star Monster HP increased by 400%"},
		{"element": "nature", "stat": "def", "add": 100.0, "text": "Nature Monster DEF increased by 100"},
		{"stars": 6, "stat": "atk", "mult": 0.9, "text": "6-star Monster ATK decreased by 10%"},
		{"element": "water", "stat": "atk", "mult": 0.9, "text": "Water Monsters ATK decreased by 10%"},
		{"id": "patchuus", "stat": "rec", "mult": 5.0, "text": "Patchuus REC increased by 400%"},
		{"id": "smullock", "stat": "atk", "add": 1000.0, "text": "Smullock ATK increased by 1000"},
	]},
	{"name": "Sky Island League", "bg": "sky_island", "boost": ["smish", "smoovie", "smulling", "smelly"], "rules": [
		{"stars": 2, "stat": "hp", "mult": 5.0, "text": "2-star Monster HP increased by 400%"},
		{"element": "water", "stat": "atk", "mult": 0.9, "text": "Water Monsters ATK decreased by 10%"},
		SIX_STAR_HALF,
	]},
	{"name": "Halloween League", "bg": "halloween_graveyard", "team": 8, "boost": ["ghoulflame", "ghouldrop", "ghoulseed", "ghouldig"], "rules": [NORMAL_DEF, SIX_STAR_HALF]},
	{"name": "Desert Island League", "badge": "desert", "bg": "desert_isle", "boost": ["friby", "waby", "spriby"], "rules": [SIX_STAR_HALF, NORMAL_DEF]},
	{"name": "1 vs 1 League", "badge": "onevone", "bg": "mansion_hall", "team": 1, "intro": "Let's find out the best monster in Monster Squad!", "boost": ["mewer"], "boost_atk": 0.0, "rules": []},
]
const WINGS := 7
const GRADES := ["gold", "silver", "bronze"]
const BADGE_POINTS := {"gold": 3, "silver": 2, "bronze": 1}
const REWARDS := [
	["Rank 1st", 1, 1500, 100, "gold"], ["2nd~3rd", 3, 1100, 70, "silver"], ["4th~10th", 10, 800, 55, "bronze"], ["11th~20th", 20, 500, 45, ""],
	["21st~30th", 30, 350, 40, ""], ["31st~50th", 50, 300, 35, ""], ["51st~75th", 75, 250, 30, ""], ["76th~100th", 100, 150, 15, ""],
]


static func week_start(index: int) -> int:
	return index * Arena.WEEK_SECONDS + Arena.WEEK_OFFSET


static func shift() -> int:
	return int(Save.data.get("league_shift", 0))


static func now() -> int:
	return Events.now() + shift() * Arena.WEEK_SECONDS


static func index(at: int = -1) -> int:
	return Arena.week_id(float(now() if at < 0 else at))


static func season(i: int = -1) -> Dictionary:
	if i < 0:
		i = index()
	var s: Dictionary = SEASONS[posmod(i, SEASONS.size())].duplicate()
	s["id"] = i
	s["start"] = week_start(i)
	s["end"] = week_start(i + 1)
	return s


static func team_size(s: Dictionary = {}) -> int:
	return int((season() if s.is_empty() else s).get("team", Save.LEAGUE_TEAM))


static func boost_atk(s: Dictionary) -> float:
	return float(s.get("boost_atk", BOOST_ATK))


static func intro(s: Dictionary) -> String:
	return String(s.get("intro", "Rewards will be given once league is over"))


static func bg_path() -> String:
	return "res://assets/battle_bg/%s.png" % String(season().bg)


static func progress() -> float:
	var s := season()
	return clampf(float(now() - int(s.start)) / float(int(s.end) - int(s.start)), 0.0, 1.0)


static func title(s: Dictionary) -> String:
	var a := Time.get_datetime_dict_from_unix_time(int(s.start))
	var b := Time.get_datetime_dict_from_unix_time(int(s.end) - 1)
	return "%s (%02d.%02d~%02d.%02d)" % [s.name, a.month, a.day, b.month, b.day]


static func end_text(s: Dictionary) -> String:
	var b := Time.get_datetime_dict_from_unix_time(int(s.end) - 1)
	return "League will end on %d/%d 23:59 (UTC)" % [b.month, b.day]


static func rule_lines(s: Dictionary) -> Array:
	var out := []
	if boost_atk(s) > 0.0:
		for id in s.boost:
			out.append("%s ATK increased by %d" % [DB.monster(String(id)).name, int(boost_atk(s))])
	for r in s.rules:
		out.append(String(r.text))
	return out if not out.is_empty() else ["No Rule!!"]


static func reward_for(rank: int) -> Array:
	for i in REWARDS.size():
		var row: Array = REWARDS[i]
		if rank <= int(row[1]):
			return [int(row[2]), int(row[3]), String(row[4]), i + 1 if i < WINGS else 0]
	return [0, 0, "", 0]


static func apply(u: BattleUnit, s: Dictionary) -> void:
	if (s.boost as Array).has(u.monster_id):
		u.base.atk += boost_atk(s)
	var m := DB.monster(u.monster_id)
	for r in s.rules:
		if r.has("stars") and int(m.get("stars", 0)) != int(r.stars):
			continue
		if r.has("element") and u.element != String(r.element):
			continue
		if r.has("id") and u.monster_id != String(r.id):
			continue
		var stat := String(r.stat)
		if stat == "hp":
			u.max_hp = maxf(1.0, u.max_hp * float(r.get("mult", 1.0)) + float(r.get("add", 0.0)))
			u.hp = u.max_hp
			continue
		if r.has("mult"):
			u.base[stat] = float(u.base[stat]) * float(r.mult)
		if r.has("add"):
			u.base[stat] = maxf(0.0, float(u.base[stat]) + float(r.add))


static func badge_key(season_id: int, grade: String) -> String:
	return "%d:%s" % [posmod(season_id, SEASONS.size()), grade]


static func badge_name(i: int) -> String:
	return String(SEASONS[posmod(i, SEASONS.size())].name).trim_suffix(" League").trim_suffix(" league") + " Badge"


static func badge_texture(i: int, grade: String) -> Texture2D:
	var art := String(SEASONS[posmod(i, SEASONS.size())].get("badge", ""))
	if art != "":
		return UI.tex("res://assets/badges/%s_%s.png" % [art, grade])
	return UI.tex("betaUI00/I_badge%s_01.png" % grade.capitalize())


static func badge_rank_text(grade: String) -> String:
	for row in REWARDS:
		if String(row[4]) == grade:
			return String(row[0])
	return ""


static func badges_owned(grade: String = "") -> int:
	var n := 0
	for k in Save.data.get("badges", {}):
		if grade == "" or String(k).ends_with(":" + grade):
			n += int(Save.data.badges[k])
	return n


static func badge_points() -> int:
	var n := 0
	for k in Save.data.get("badges", {}):
		n += int(BADGE_POINTS.get(String(k).get_slice(":", 1), 0)) * int(Save.data.badges[k])
	return n
