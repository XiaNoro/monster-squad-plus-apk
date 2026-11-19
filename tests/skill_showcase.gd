extends Node

const ELEMENTS := ["water", "fire", "nature", "normal"]
const ALLY := {"water": "blue_dragongod", "fire": "firepaw", "nature": "leavbal", "normal": "marell"}
const ENEMY := "imuki"
const SHOTS := [0.2, 0.45, 0.75, 1.15]
const STEP := 1.7
const TOLERANCE := 1.5

var main: Node
var out_dir := ""
var limit := 0
var screen: Node
var current := ""
var report := {"casts": 0, "follow_fail": {}, "follow_max": 0.0, "carrier_max": 0.0, "carriers": 0, "unanchored": {}, "aura_ok": 0, "aura_bad": {}, "loops_front": {}, "anchored": 0, "captures": [], "imuki": {}}
var _offsets: Dictionary = {}
var _seen_specs: Dictionary = {}


func _ready() -> void:
	main = get_parent()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--showcase-out="):
			out_dir = a.trim_prefix("--showcase-out=")
		if a.begins_with("--showcase-limit="):
			limit = int(a.trim_prefix("--showcase-limit="))
	DirAccess.make_dir_recursive_absolute(out_dir)
	Save.data["dev_endless"] = true
	Save.data["dev_immortal_enemies"] = true
	Save.data["speed"] = 0
	RenderingServer.frame_pre_draw.connect(_measure)
	_run.call_deferred()


func _skills_for(element: String) -> Array:
	var seen := {}
	var out := []
	for id in DB.ids_where(func(d): return String(d.element) == element and not d.material):
		var def := DB.monster(id)
		var list: Array = def.get("skills", []).duplicate()
		if def.get("support_skill") is Dictionary and not def.support_skill.is_empty():
			list.append(def.support_skill)
		for s in list:
			var n := String(s.get("name", "")).strip_edges().trim_suffix(":")
			if n == "" or seen.has(n):
				continue
			seen[n] = true
			out.append({"skill": s, "from": id, "support": s == def.get("support_skill")})
	return out


func _quest(ally: String) -> Dictionary:
	return {"kind": "league", "key": "league", "title": "Skill showcase", "rival_name": "Imuki", "rival_skill": 0.0, "energy": 0, "level": 30, "boss": ENEMY, "enemies": [], "stages": 1, "gold": 0.0, "exp": 0.0, "drops": false, "boss_drop_chance": 0.0, "drop_level": [1, 1], "first_clear_drop": false, "pvp": true,
		"league_team": [{"id": ally, "level": 30, "boost": 5, "stones": {}, "pet": {}}],
		"league_enemy": [{"id": ENEMY, "level": 30, "boost": 5, "stones": {}, "pet": {}}]}


func _run() -> void:
	for element in ELEMENTS:
		main.go("battle", {"quest": _quest(ALLY[element])})
		screen = main.current
		while screen._paused or screen.engine.time < 2.0:
			await get_tree().process_frame
		_calm()
		await _shot("intro_%s" % element, "%s vs imuki" % ALLY[element], 0.0)
		_check_imuki(element)
		var list := _skills_for(element)
		if limit > 0:
			list = list.slice(0, limit)
		print("SHOWCASE %s: %d skills" % [element, list.size()])
		for item in list:
			await _play(item, element)
	_finish()


func _calm() -> void:
	var e = screen.engine
	e.time_limit = 1.0e9
	e.enemy_mp = 0.0
	e.enemy_mp_regen = 0.0
	for u in e.allies + e.enemies:
		u.support_timer = 1.0e9
		u.hp = u.max_hp
		u.statuses = []
		u.shield = 0.0


func _play(item: Dictionary, element: String) -> void:
	_calm()
	var e = screen.engine
	var ally = e.allies[0]
	var foe = e.enemies[0]
	var s: Dictionary = item.skill
	current = "%s [%s] (%s)" % [s.name, element, item.from]
	var spec_key := JSON.stringify(SkillFx.spec(String(s.name))) + element
	var capture: bool = not _seen_specs.has(spec_key)
	_seen_specs[spec_key] = true
	var lead: float = screen.CUT_IN if (not item.support and float(s.get("mp", 0.0)) >= screen.ULTIMATE_MP) else 0.0
	e._cast(ally, s, "support" if item.support else "leader")
	report.casts += 1
	var av = screen.views[ally]
	var fv = screen.views[foe]
	get_tree().create_timer(lead + 0.3).timeout.connect(func():
		if is_instance_valid(av) and is_instance_valid(fv):
			av.lunge(fv.home + fv.size / 2.0, true, fv.size.x))
	get_tree().create_timer(lead + 0.75).timeout.connect(func():
		if is_instance_valid(av) and is_instance_valid(fv):
			fv.lunge(av.home + av.size / 2.0, true, av.size.x))
	var t := 0.0
	if capture:
		var idx: int = report.captures.size()
		var frames := []
		for at in SHOTS:
			await get_tree().create_timer(lead + at - t).timeout
			t = lead + at
			var f := "cap_%03d_%d.png" % [idx, frames.size()]
			_save(f)
			frames.append(f)
		report.captures.append({"name": current, "frames": frames})
	await get_tree().create_timer(maxf(0.05, lead + STEP - t)).timeout
	e.mp = e.max_mp


func _shot(file: String, label: String, wait: float) -> void:
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	_save(file + ".png")
	report.captures.append({"name": label, "frames": [file + ".png"]})


func _save(file: String) -> void:
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))


func _check_imuki(element: String) -> void:
	for u in screen.views:
		var v = screen.views[u]
		if u.monster_id in DB.FACES_LEFT:
			report.imuki["%s_%s" % [u.monster_id, "ally" if u.side == BattleUnit.PLAYER else "enemy"]] = {"flip_h": v.sprite.flip_h, "texture_flipped": not (v.sprite.texture is CompressedTexture2D)}


func _sheet(fx: FrameFx) -> String:
	if fx._frames.is_empty() or fx._frames[0] == null:
		return "?"
	return String(fx._frames[0].resource_path).get_file().get_basename().rstrip("0123456789").trim_suffix("_")


func _measure() -> void:
	if screen == null or not is_instance_valid(screen) or not "field" in screen or screen.field == null:
		return
	var field: Control = screen.field
	for c in field.get_children():
		if c is FrameFx:
			var fx := c as FrameFx
			if is_instance_valid(fx._anchor):
				var off := fx.position - fx._anchor.position
				var id := fx.get_instance_id()
				if not _offsets.has(id):
					_offsets[id] = off
					report.anchored += 1
				else:
					var dev: float = (off - _offsets[id]).length()
					report.follow_max = maxf(report.follow_max, dev)
					if dev > TOLERANCE:
						var k := _sheet(fx)
						var prev: Dictionary = report.follow_fail.get(k, {"max": 0.0, "skill": current, "count": 0})
						prev.count += 1
						if dev > prev.max:
							prev.max = dev
							prev.skill = current
						report.follow_fail[k] = prev
			elif fx.rotation == 0.0 and not fx.loop:
				report.unanchored[_sheet(fx)] = current
		elif c.get_class() == "Control" and c.get_script() != null and "anchor" in c and c.get_child_count() > 0:
			if not _offsets.has(c.get_instance_id()):
				_offsets[c.get_instance_id()] = true
				report.carriers += 1
			if is_instance_valid(c.anchor):
				report.carrier_max = maxf(report.carrier_max, (c.position - c.anchor.position).length())
	for u in screen.views:
		var v = screen.views[u]
		var si: int = v.sprite.get_index()
		var loops: Array = v._loops.values()
		for c in v.get_children():
			if not c is FrameFx or c == v.target_mark:
				continue
			var name := _sheet(c)
			if c in loops:
				if c.get_index() > si or c.z_index > 0:
					report.loops_front[name] = true
			elif name.begins_with("ui_target"):
				continue
			elif not _offsets.has(c.get_instance_id()):
				_offsets[c.get_instance_id()] = true
				if c.z_index == 0 and c.get_index() < si:
					report.aura_ok += 1
				else:
					report.aura_bad[name] = current


func _finish() -> void:
	var f := FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print("SHOWCASE DONE casts=%d follow_max=%.2f carrier_max=%.2f fails=%d" % [report.casts, report.follow_max, report.carrier_max, report.follow_fail.size()])
	get_tree().quit()
