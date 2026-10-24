# Converts the Fandom wiki dump (research/wiki/wikitext.json) into game data.
# Run: godot --headless --path <project> --script res://tools/build_db.gd
extends SceneTree

const WIKI_PATH := "res://research/wiki/wikitext.json"
const IMAGES_PATH := "res://research/wiki/images.json"
const OUT_MONSTERS := "res://data/monsters.json"
const OUT_ISLANDS := "res://data/islands.json"
const OUT_PETS := "res://data/pets.json"
const OUT_REPORT := "res://research/build_report.txt"

const DEFAULT_MP_COSTS := [40, 60, 100, 150]
const DEFAULT_SUPPORT_COOLDOWN := 12.0
const MANA_BY_STARS := {1: 80, 2: 100, 3: 120, 4: 160, 5: 200, 6: 240}
const RARITY_BY_STARS := {1: "common", 2: "uncommon", 3: "rare", 4: "super_rare", 5: "epic", 6: "legendary"}
const ELEMENTS := ["fire", "water", "nature", "normal"]
const STORY_ISLANDS := ["Sprout Island", "Lake Island", "Desert Isle", "Moonlight Desert", "Boneyard Island", "Dino Gorge", "Robo Island", "Sky Island"]

var report: PackedStringArray = []
var unparsed: Dictionary = {}
var redirects: Dictionary = {}


func _init() -> void:
	var wiki: Dictionary = _load_json(WIKI_PATH)
	var images: Dictionary = _image_index(_load_json(IMAGES_PATH))

	var redirect_rx := _rx("^#REDIRECT\\s*\\[\\[([^\\]#|]+)")
	for title in wiki:
		var rm := redirect_rx.search(String(wiki[title]))
		if rm:
			redirects[_slug(title)] = _slug(rm.get_string(1))

	var monsters: Dictionary = {}
	for title in wiki:
		var text: String = String(wiki[title]).replace("{{Monster_Box", "{{Monster Box")
		var box := _find_template(text, "Monster Box")
		if box.is_empty():
			box = _infobox_as_monster_box(_find_template(text, "Infobox Monster"))
		if box.is_empty():
			continue
		var m := _build_monster(title, box, images)
		if not m.is_empty():
			monsters[m.id] = m

	_link_evolutions(monsters)
	var islands := _build_islands(wiki, monsters)

	_save_json(OUT_MONSTERS, monsters)
	_save_json(OUT_ISLANDS, islands)
	var pets := _build_pets(wiki, images)
	_save_json(OUT_PETS, pets)
	report.append("pets: %d" % pets.size())

	report.append("monsters: %d" % monsters.size())
	report.append("islands: %d" % islands.size())
	var keys := unparsed.keys()
	keys.sort_custom(func(a, b): return unparsed[a] > unparsed[b])
	report.append("unparsed skill clauses: %d distinct" % keys.size())
	for k in keys:
		report.append("  %d\t%s" % [unparsed[k], k])
	var f := FileAccess.open(OUT_REPORT, FileAccess.WRITE)
	f.store_string("\n".join(report))
	print("\n".join(report.slice(0, 40)))
	quit()


# ---------------------------------------------------------------- monsters

func _build_monster(title: String, p: Dictionary, images: Dictionary) -> Dictionary:
	var element := _clean(p.get("attr", "")).to_lower()
	if element not in ELEMENTS:
		report.append("skip %s: element '%s'" % [title, element])
		return {}
	var stars := clampi(_int(p.get("stars", "1")), 1, 6)
	var m := {
		"id": _slug(title),
		"name": title,
		"element": element,
		"class": _clean(p.get("class", "C")).to_upper().replace(" ", ""),
		"stars": stars,
		"rarity": RARITY_BY_STARS[stars],
		"material": _clean(p.get("material", "")).to_lower() == "yes" or title.ends_with("Fruit"),
		"quote": _clean(p.get("quote", "")),
		"location": _clean(p.get("location", "")),
		"passive": _clean(p.get("ability", "")),
		"image": _image_url(p.get("image", ""), title, images),
	}

	var mana := _int(p.get("statmana", "0"))
	if mana <= 0:
		mana = MANA_BY_STARS[stars]
	m["stats"] = {
		"hp": _int(p.get("stathp", "0")),
		"atk": _int(p.get("statatk", "0")),
		"def": _int(p.get("statdef", "0")),
		"rec": _int(p.get("statrec", "0")),
		"mp": mana,
	}
	# "3128+782" = value at Lv30, +782 at max boost (+5).
	m["stats_max"] = {
		"hp": _int(p.get("stathpmax", "0")),
		"atk": _int(p.get("statatkmax", "0")),
		"def": _int(p.get("statdefmax", "0")),
		"rec": _int(p.get("statrecmax", "0")),
	}
	# Lv50 (fully awakened) stats, listed on some 6★ pages as "5144+1286".
	if p.has("stathp50"):
		m["stats_50"] = {"hp": _int(p.get("stathp50", "0")), "atk": _int(p.get("statatk50", "0")), "def": _int(p.get("statdef50", "0")), "rec": _int(p.get("statrec50", "0"))}
	m["passive_effect"] = _parse_passive(m.passive)

	var skills: Array = []
	for i in range(1, 5):
		var sname := _clean(p.get("skill%d_name" % i, ""))
		var desc := _clean(p.get("skill%d_description" % i, p.get("skill%d_descripton" % i, "")))
		if sname == "" and desc == "":
			continue
		var cost := _int(p.get("skill%d_MPcost" % i, "0"))
		if cost <= 0:
			cost = DEFAULT_MP_COSTS[i - 1]
		var icon := _clean(p.get("skill%d_icon" % i, ""))
		skills.append({"name": sname, "description": desc, "icon": icon, "mp": cost, "effects": _parse_skill(desc, icon)})
	m["skills"] = skills

	var sdesc := _clean(p.get("supportskill_description", p.get("supportskill_descrption", "")))
	var sicon := _clean(p.get("supportskill_icon", ""))
	var cd := float(_int(p.get("supportskill_cooldown", "0")))
	m["support_skill"] = {
		"name": _clean(p.get("supportskill_name", "")),
		"description": sdesc,
		"icon": sicon,
		"cooldown": cd if cd > 0 else DEFAULT_SUPPORT_COOLDOWN,
		"effects": _parse_skill(sdesc, sicon),
	}

	# Evolution tree: stage_i evolves into stage_{i+1} by consuming material_i x quantity_i.
	var tree: Array = []
	for i in range(1, 7):
		var st := _clean(p.get("evolutiontree_stage%d" % i, ""))
		if st == "":
			break
		tree.append({
			"monster": _slug(st),
			"material": _slug(_clean(p.get("evolutiontree_material%d" % i, ""))),
			"quantity": maxi(1, _int(p.get("evolutiontree_material_quantity%d" % i, p.get("evolutiontree_quantity%d" % i, "1")))),
		})
	m["evolution_tree"] = tree
	m["evolves_from"] = _slug(_clean(p.get("evofrom", "")))
	m["evolves_into"] = _slug(_clean(p.get("evointo", "")))
	m["evolve_material"] = _slug(_clean(p.get("evomonster", "")))
	m["evolve_quantity"] = 1
	return m


func _link_evolutions(monsters: Dictionary) -> void:
	# Prefer the tree's material/quantity for this monster's own stage.
	for id in monsters:
		var m: Dictionary = monsters[id]
		var tree: Array = m.evolution_tree
		for i in tree.size():
			if tree[i].monster == id and i + 1 < tree.size():
				m.evolves_into = tree[i + 1].monster
				if tree[i].material != "":
					m.evolve_material = tree[i].material
					m.evolve_quantity = tree[i].quantity
			if tree[i].monster == id and i > 0 and m.evolves_from == "":
				m.evolves_from = tree[i - 1].monster
		if m.evolves_into in [id, m.evolves_from]:
			m.evolves_into = ""
		for k in ["evolves_from", "evolves_into", "evolve_material"]:
			if redirects.has(m[k]):
				m[k] = redirects[m[k]]
			if m[k] != "" and not monsters.has(m[k]):
				report.append("%s: unknown %s '%s'" % [id, k, m[k]])
				m[k] = ""


# ---------------------------------------------------------------- skills

var _rx_cache: Dictionary = {}

func _rx(pattern: String) -> RegEx:
	if not _rx_cache.has(pattern):
		var r := RegEx.new()
		r.compile(pattern)
		_rx_cache[pattern] = r
	return _rx_cache[pattern]


func _parse_skill(desc: String, icon: String) -> Array:
	var effects: Array = []
	var text := desc.to_lower()
	text = _rx("\\{\\{[^}]*\\}\\}").sub(text, "", true)
	text = _rx("\\[[^\\]]*\\]").sub(text, "", true)
	text = text.replace("frezze", "freeze").replace("attack all", "attacks all").replace("attack with", "attacks with")
	text = _rx("(\\d+)\\s*(?:seconds?|secs?|s)\\b").sub(text, "$1s", true)
	text = text.replace("critical hit chance", "critical hit").replace("critical chance", "critical hit").replace(" cri ", " critical hit ")
	text = text.replace("teams ", "team's ").replace("offense", "atk").replace("armor", "def").replace("defense", "def")
	var aoe := text.contains("all enem") or text.contains("attacks all") or text.contains("to all") or text.contains("on all")

	for clause in _rx("[;,+]| then ").sub(text, "|", true).split("|", false):
		var c := clause.strip_edges()
		if c == "":
			continue
		var before := effects.size()
		_match_clause(c, aoe, effects)
		if effects.size() == before:
			unparsed[c] = unparsed.get(c, 0) + 1

	if effects.is_empty():
		effects = _effects_from_icon(icon)
	return effects


func _num(r: RegExMatch, group: int, fallback: float = 0.0) -> float:
	var s := r.get_string(group)
	return float(s) if s != "" else fallback


func _match_clause(c: String, aoe: bool, out: Array) -> void:
	var r: RegExMatch
	# Damage
	r = _rx("(\\d+)% (?:atk|attack|damage)").search(c)
	if r == null:
		r = _rx("attacks?(?: all| \\d enemy| single target)?(?: enemies)? (?:with )?\\(?(?:atk )?(\\d+)%").search(c)
	if r == null:
		r = _rx("(?:single target|single damage attack) (\\d+)%").search(c)
	var buffish := (c.contains("increase") or c.contains("decrease")) and not c.contains("attacks")
	if r != null and not buffish:
		var all := c.contains("all") or (aoe and not c.contains("single") and not c.contains("1 enemy"))
		out.append({"type": "damage", "target": "all_enemies" if all else "enemy", "mult": _num(r, 1) / 100.0})
	# Heal
	r = _rx("heals?(?: (most hurt ally|all allies|all|leader))?(?: with)? (\\d+)%").search(c)
	if r != null:
		var tgt: String = {"most hurt ally": "most_hurt", "all": "all_allies", "all allies": "all_allies", "leader": "leader"}.get(r.get_string(1), "most_hurt")
		out.append({"type": "heal", "target": tgt, "mult": _num(r, 2) / 100.0})
	else:
		r = _rx("(\\d+)% heal(?: to)? ?(all|ally)?").search(c)
		if r != null:
			out.append({"type": "heal", "target": "all_allies" if r.get_string(2) == "all" else "most_hurt", "mult": _num(r, 1) / 100.0})
		else:
			r = _rx("heals? (?:hp )?(?:by )?\\(?(?:rec )?(\\d+)%").search(c)
			if r != null:
				out.append({"type": "heal", "target": "self", "mult": _num(r, 1) / 100.0})
	if c.contains("recover leader hp"):
		out.append({"type": "heal", "target": "leader", "mult": 1.0})
	if c.contains("recovers hp while attacking"):
		out.append({"type": "lifesteal", "pct": 0.3, "duration": 20.0})
	# Stun / silence
	r = _rx("stuns?(?: all)?(?: for)? (\\d+(?:\\.\\d+)?)s(?: \\((\\d+)% chance\\))?").search(c)
	if r == null:
		r = _rx("(\\d+)% chance (?:of|to) (?:(\\d+)s )?stun(?: for (\\d+)s)?").search(c)
		if r != null:
			var dur := _num(r, 2, _num(r, 3, 2.0))
			out.append({"type": "stun", "target": "all_enemies" if aoe else "enemy", "duration": dur, "chance": _num(r, 1) / 100.0})
	else:
		out.append({"type": "stun", "target": "all_enemies" if (aoe or c.contains("all")) else "enemy", "duration": _num(r, 1), "chance": _num(r, 2, 100.0) / 100.0})
	if c.contains("stuns self"):
		out.append({"type": "stun", "target": "self", "duration": 3.0, "chance": 1.0})
	r = _rx("silence(?:s)?(?: all)?(?: for)? ?(\\d+)?").search(c)
	if r != null:
		out.append({"type": "silence", "target": "all_enemies" if c.contains("all") else "enemy", "duration": _num(r, 1, 3.0)})
	# Damage over time
	r = _rx("(?:stage|level) (\\d+) (?:powerful |severe )?(bleed|poison|burn|freeze|chill)(?:.*?(\\d+)s)?").search(c)
	if r != null:
		var kind := r.get_string(2)
		if kind == "chill":
			kind = "freeze"
		out.append({"type": "dot", "kind": kind, "stage": int(_num(r, 1, 1)), "target": "all_enemies" if aoe else "enemy", "duration": _num(r, 3, 10.0)})
	# Shield
	r = _rx("(?:stage|level) (\\d+) shields?").search(c)
	if r != null:
		var team := c.contains("team") or c.contains("all") or aoe
		out.append({"type": "shield", "target": "all_allies" if team else "leader", "stage": int(_num(r, 1, 1)), "duration": 15.0})
	r = _rx("(\\d+)% shield bonus").search(c)
	if r != null:
		out.append({"type": "shield", "target": "all_allies", "stage": 2, "duration": 4.0})
	if c.contains("shield all allies"):
		out.append({"type": "shield", "target": "all_allies", "stage": 1, "duration": 15.0})
	r = _rx("(?:stage|level) (\\d+) def(?: \\((\\d+)s\\))?").search(c)
	if r != null:
		out.append({"type": "buff", "stat": "def", "target": "all_allies" if c.contains("all") else "leader", "pct": 0.15 * _num(r, 1, 1), "duration": _num(r, 2, 10.0)})
	if c.ends_with("speed bonus") or c.ends_with("attack bonus"):
		out.append({"type": "buff", "stat": "speed" if c.contains("speed") else "atk", "target": "random_ally", "pct": 0.2, "duration": 15.0})
	if c.contains("reflects all bad status"):
		out.append({"type": "immune", "target": "all_allies", "duration": _num(_rx("(\\d+)s").search(c), 1, 6.0) if _rx("(\\d+)s").search(c) else 6.0})
	# Buffs
	r = _rx("(?:increases )?(leader|team|random ally)'?s? (atk|speed|critical hit|def|rec|critical damage)(?: and (speed|atk))?(?: by| increases by| \\+)? ?(\\d+)%(?: for (\\d+)s)?").search(c)
	if r != null and not c.contains("decrease"):
		var tgt: String = {"leader": "leader", "team": "all_allies", "random ally": "random_ally"}[r.get_string(1)]
		for stat in [r.get_string(2), r.get_string(3)]:
			if stat != "":
				out.append({"type": "buff", "stat": _stat_key(stat), "target": tgt, "pct": _num(r, 4) / 100.0, "duration": _num(r, 5, 20.0)})
	# Debuffs
	r = _rx("decreases? (?:(\\d) enemy'?s|enemies'|all enem\\w*'?s?)? ?(atk|speed|def|rec)(?: by)? (\\d+)%(?: for (\\d+)s)?").search(c)
	if r == null:
		r = _rx("(all enemies'?|all|1 enemy'?s?)? ?(atk|def|rec|speed) -(\\d+)%(?: (?:for )?\\(?(\\d+)s)?").search(c)
		if r != null:
			out.append({"type": "debuff", "stat": _stat_key(r.get_string(2)), "target": "enemy" if r.get_string(1).begins_with("1") else "all_enemies", "pct": _num(r, 3) / 100.0, "duration": _num(r, 4, 10.0)})
			r = null
	if r == null:
		r = _rx("(?:reduce|decrease)s? (def|atk|attack|rec)()").search(c)
		if r != null:
			out.append({"type": "debuff", "stat": _stat_key(r.get_string(1).replace("attack", "atk")), "target": "enemy", "pct": 0.3, "duration": 10.0})
			r = null
	else:
		var tgt := "enemy" if r.get_string(1) != "" else "all_enemies"
		out.append({"type": "debuff", "stat": _stat_key(r.get_string(2)), "target": tgt, "pct": _num(r, 3) / 100.0, "duration": _num(r, 4, 10.0)})
	# Utility
	if _rx("removes? (?:\\d|all)? ?(?:status )?boosts?|void all enemy buff|de-?spell|dispel").search(c) != null:
		out.append({"type": "dispel", "target": "all_enemies"})
	if _rx("cures?|removes all status effects").search(c) != null:
		out.append({"type": "cleanse", "target": "all_allies"})
	r = _rx("provokes?(?: target| all)?(?: for)? (\\d+)").search(c)
	if r != null:
		out.append({"type": "provoke", "duration": _num(r, 1, 10.0)})
	r = _rx("(?:returns?|reflects?) (\\d+)% of (?:the )?damage(?:.*?(\\d+)s)?").search(c)
	if r != null:
		out.append({"type": "reflect", "pct": _num(r, 1) / 100.0, "duration": _num(r, 2, 15.0)})
	if c.contains("shield break") or _rx("removes \\d enemy'?s shield").search(c) != null:
		out.append({"type": "shield_break", "target": "enemy"})
	if c.contains("time bomb") or c.contains("time-bomb"):
		out.append({"type": "time_bomb", "target": "enemy", "damage": 6666, "delay": 5.0})


func _effects_from_icon(icon: String) -> Array:
	var i := icon.to_lower().replace("_", " ")
	if i.begins_with("attack all"):
		return [{"type": "damage", "target": "all_enemies", "mult": 1.0}]
	if i.begins_with("heal all"):
		return [{"type": "heal", "target": "all_allies", "mult": 1.0}]
	if i.begins_with("heal"):
		return [{"type": "heal", "target": "most_hurt", "mult": 1.5}]
	if i.begins_with("shield"):
		return [{"type": "shield", "target": "all_allies", "stage": 2, "duration": 15.0}]
	if i.begins_with("stun"):
		return [{"type": "damage", "target": "enemy", "mult": 1.5}, {"type": "stun", "target": "enemy", "duration": 2.0, "chance": 1.0}]
	if i.contains("down"):
		return [{"type": "debuff", "stat": "atk", "target": "all_enemies", "pct": 0.3, "duration": 10.0}]
	if i.contains("up"):
		return [{"type": "buff", "stat": "atk", "target": "all_allies", "pct": 0.3, "duration": 20.0}]
	return [{"type": "damage", "target": "enemy", "mult": 1.0}]


func _parse_passive(text: String) -> Dictionary:
	var t := text.to_lower().replace("critical chance", "critical hit")
	var r := _rx("increases (?:(fire|water|nature|normal|all) (?:type )?monsters?'?s?|leader'?s?|all monsters'?|team'?s?) ?(hp|atk|def|rec|critical hit|critical damage|mp recovery|speed)(?: by)? (\\d+)(%?)").search(t)
	if r == null:
		return {}
	var scope := r.get_string(1)
	if scope == "":
		scope = "leader" if t.contains("leader") else "all"
	var stat := _stat_key(r.get_string(2))
	# "Increases leader's HP by 300" is a flat bonus; everything else is a percentage.
	if r.get_string(4) == "":
		return {"element": scope, "stat": stat, "flat": float(r.get_string(3))}
	return {"element": scope, "stat": stat, "pct": float(r.get_string(3)) / 100.0}


func _stat_key(s: String) -> String:
	return {"atk": "atk", "speed": "speed", "critical hit": "crit", "def": "def", "defense": "def", "rec": "rec", "hp": "hp", "critical damage": "crit_dmg", "mp recovery": "mp_regen"}.get(s, s)


# ---------------------------------------------------------------- pets

## Pet pages (patch 2.00.16962): infobox stats plus a list of possible passives (one is rolled).
func _build_pets(wiki: Dictionary, images: Dictionary) -> Array:
	var pets: Array = []
	var index: String = wiki.get("Pet System", "")
	for icon in _rx("\\{\\{Monster Icon\\|([^}|]+)").search_all(index):
		var title := icon.get_string(1).strip_edges()
		var page: String = wiki.get(title, "")
		if page == "":
			continue
		var stats := {}
		for key in ["HP", "ATK", "DEF", "REC"]:
			var r := _rx("!\\s*" + key + "\\s*\\n\\|\\s*(\\d+)").search(page)
			stats[key.to_lower()] = int(r.get_string(1)) if r else 0
		var attr_m := _rx("!\\s*Attribute\\s*\\n\\|\\s*(\\w+)").search(page)
		var stars_m := _rx("!\\s*Rarity\\s*\\n\\|\\s*(★+)").search(page)
		var passives: Array = []
		for pm in _rx("Increase'?s (Fire|Water|Nature|Normal|All) Monsters (HP|ATK|DEF|Critical Chance) by (\\d+)%").search_all(page):
			passives.append({"element": pm.get_string(1).to_lower(), "stat": {"HP": "hp", "ATK": "atk", "DEF": "def", "Critical Chance": "crit"}[pm.get_string(2)], "pct": float(pm.get_string(3)) / 100.0})
		var stars := stars_m.get_string(1).length() if stars_m else 1
		pets.append({
			"id": _slug(title), "name": title,
			"element": attr_m.get_string(1).to_lower() if attr_m else "all",
			"stars": stars, "stats": stats, "passives": passives,
			"image": _image_url(title + ".png", title, images),
			"cube": "rare" if stars >= 4 else "normal",
		})
	return pets


# ---------------------------------------------------------------- islands

func _build_islands(wiki: Dictionary, monsters: Dictionary) -> Array:
	var islands: Array = []
	var name_to_id: Dictionary = {}
	for id in monsters:
		name_to_id[monsters[id].name.to_lower()] = id
	var order := 0
	for island_name in STORY_ISLANDS:
		if not wiki.has(island_name):
			report.append("island page missing: " + island_name)
			continue
		var text: String = wiki[island_name]
		var island := {"id": _slug(island_name), "name": island_name, "order": order, "difficulties": {}}
		order += 1
		# <tabber> sections: |-|Normal= ... |-|Hard= ...
		var tab_rx := _rx("\\|-\\|\\s*([A-Za-z ]+?)\\s*=")
		var tabs := tab_rx.search_all(text)
		for t in tabs.size():
			var diff := tabs[t].get_string(1).strip_edges().to_lower()
			var start := tabs[t].get_end()
			var end := tabs[t + 1].get_start() if t + 1 < tabs.size() else text.find("</tabber>", start)
			if end < 0:
				end = text.length()
			var body := text.substr(start, end - start)
			var cost_m := _rx("Energy Cost:\\s*(\\d+)").search(body)
			var stages: Array = []
			var stage_rx := _rx("\\*\\s*([^\\n]+?)\\s*\\n")
			var stage_hits := stage_rx.search_all(body)
			for s in stage_hits.size():
				var sbeg := stage_hits[s].get_end()
				var send := stage_hits[s + 1].get_start() if s + 1 < stage_hits.size() else body.length()
				var enemies: Array = []
				for icon in _rx("\\{\\{Monster Icon\\|([^}|]+)").search_all(body.substr(sbeg, send - sbeg)):
					var mname := icon.get_string(1).strip_edges().to_lower()
					if name_to_id.has(mname):
						enemies.append(name_to_id[mname])
					else:
						report.append("%s: unknown monster '%s'" % [island_name, mname])
				if not enemies.is_empty():
					stages.append({"name": stage_hits[s].get_string(1).strip_edges(), "boss": enemies[0], "enemies": enemies})
			if not stages.is_empty():
				island.difficulties[diff] = {"energy": int(cost_m.get_string(1)) if cost_m else 2, "stages": stages}
		if not island.difficulties.is_empty():
			islands.append(island)
	return islands


# ---------------------------------------------------------------- wikitext helpers

func _infobox_as_monster_box(ib: Dictionary) -> Dictionary:
	if ib.is_empty():
		return {}
	var remap := {"attribute": "attr", "rarity": "stars", "hp": "stathp", "atk": "statatk", "def": "statdef", "rec": "statrec", "image": "image", "class": "class"}
	var box: Dictionary = {}
	for k in remap:
		if ib.has(k):
			box[remap[k]] = ib[k]
	return box


func _find_template(text: String, name: String) -> Dictionary:
	var hit := _rx("\\{\\{\\s*(?:Template:)?" + name).search(text)
	if hit == null:
		return {}
	var start := hit.get_start()
	# Walk forward splitting on top-level '|', respecting nested {{ }} and [[ ]].
	var depth_t := 0
	var depth_l := 0
	var parts: Array = []
	var cur := ""
	var i := start + 2
	while i < text.length():
		var two := text.substr(i, 2)
		if two == "{{":
			depth_t += 1; cur += two; i += 2; continue
		if two == "}}":
			if depth_t == 0:
				parts.append(cur)
				break
			depth_t -= 1; cur += two; i += 2; continue
		if two == "[[":
			depth_l += 1; cur += two; i += 2; continue
		if two == "]]":
			depth_l = maxi(0, depth_l - 1); cur += two; i += 2; continue
		var ch := text[i]
		if ch == "|" and depth_t == 0 and depth_l == 0:
			parts.append(cur); cur = ""
		else:
			cur += ch
		i += 1
	var params: Dictionary = {}
	for j in range(1, parts.size()):
		var kv: String = parts[j]
		var eq := kv.find("=")
		if eq > 0:
			params[kv.substr(0, eq).strip_edges()] = kv.substr(eq + 1).strip_edges()
	return params


func _clean(s: String) -> String:
	# [[Page|Label]] -> Label, [[Page]] -> Page, strip templates/tags.
	var out := _rx("\\[\\[(?:[^\\]|]*\\|)?([^\\]]*)\\]\\]").sub(s.replace(char(0xA0), " "), "$1", true)
	out = _rx("\\{\\{[^}]*\\}\\}").sub(out, "", true)
	out = _rx("<br\\s*/?>").sub(out, " ", true)
	out = _rx("<[^>]+>").sub(out, "", true)
	out = _rx("'''?").sub(out, "", true)
	return _rx("\\s+").sub(out, " ", true).strip_edges()


func _int(s: String) -> int:
	var r := _rx("-?\\d[\\d,]*").search(s)
	return int(r.get_string().replace(",", "")) if r else 0


func _slug(s: String) -> String:
	return _rx("[^a-z0-9]+").sub(s.to_lower(), "_", true).trim_prefix("_").trim_suffix("_")


func _image_index(list) -> Dictionary:
	var idx: Dictionary = {}
	for img in list:
		idx[String(img.name).replace("_", " ").to_lower()] = img.url
	return idx


func _image_url(field: String, title: String, images: Dictionary) -> String:
	var candidates := [_clean(field), title + ".png", title + ".jpg"]
	for c in candidates:
		var k: String = c.replace("_", " ").to_lower().trim_prefix("file:")
		if images.has(k):
			return images[k]
	return ""


func _load_json(path: String):
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _save_json(path: String, data) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
