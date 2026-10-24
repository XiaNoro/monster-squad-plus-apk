extends Node

const LIMIT := 1700.0

var main: Main
var _clock := 0.0
var _total := 0.0
var _last_screen := ""


func _ready() -> void:
	Engine.time_scale = 8.0


func _process(delta: float) -> void:
	_total += delta / Engine.time_scale
	if Tutorial.all_done():
		print("TUT ALL CHAPTERS DONE in %.0fs real time" % _total)
		get_tree().quit()
		return
	if _total > LIMIT:
		var left := []
		for c in Tutorial.data().chapters:
			if not Tutorial.is_done(String(c.id)):
				left.append(c.id)
		print("TUT TIMEOUT on %s, not done: %s" % [main.current_name, ", ".join(left)])
		get_tree().quit()
		return
	_clock += delta
	if _clock < 2.0:
		return
	_clock = 0.0
	var s: Variant = main.current
	if s == null or not is_instance_valid(s) or s.is_queued_for_deletion():
		return
	if main.current_name != _last_screen:
		_last_screen = main.current_name
		print("TUT   screen ", _last_screen)
	if _reveal(s):
		return
	if s.tutorial != null and is_instance_valid(s.tutorial):
		return
	for c in s.get_children():
		if c is Tutorial:
			return
	match main.current_name:
		"hub":
			main.go("islands")
		"islands":
			if s.map.root.visible:
				if s.tab != "story":
					s._set_tab("story")
				s._pick_land(_latest_island())
			elif s.special_id != "":
				main.go("hub")
			elif s.island_id != "" and s.island_id != _latest_island():
				s._show_map()
			elif s.island_id != "":
				s._start_story(mini(Save.cleared_stages(s.island_id, "normal"), DB.island(s.island_id).difficulties.normal.stages.size() - 1))
		"ready":
			Save.data.energy = maxi(int(Save.data.energy), int(Save.data.energy_cap))
			var e: Array = s._entries()
			for f in e:
				if not Friends.used_today(f):
					s._pick(f)
					break
			s._go()
		"battle":
			_battle(s)
		_:
			main.go("hub")


func _latest_island() -> String:
	var latest: String = DB.islands[0].id
	for island in DB.islands:
		if Save.is_island_unlocked(island.id, "normal"):
			latest = island.id
	return latest


func _reveal(s: Variant) -> bool:
	for c in s.get_children():
		if c is CubeReveal:
			if c.done:
				var pick: Dictionary = c.buttons[0] if not c.buttons.is_empty() else {}
				for b in c.buttons:
					if String(b.text) == "Next Field" or (String(b.text) == "Leave" and String(pick.get("text", "")) != "Next Field"):
						pick = b
				c._press(pick.get("cb", Callable()))
			else:
				c._skip = true
			return true
	for b in s.find_children("*", "BaseButton", true, false):
		if b.has_meta("tut_ok") and b.is_visible_in_tree():
			print("TUT   dialog -> ", b.name)
			b.set_meta("tut_ok", false)
			b.remove_meta("tut_ok")
			(b as BaseButton).pressed.emit()
			return true
	if main.current_name != "battle":
		for c in s.find_children("*", "ColorRect", true, false):
			if c.z_index == 50 and c.is_visible_in_tree():
				for b in c.find_children("*", "Button", true, false):
					print("TUT   dialog -> ", b.text)
					b.pressed.emit()
					return true
	return false


func _battle(s: Variant) -> void:
	if not s._finished:
		s.engine.auto_skills = true
		return
	for c in s.get_children():
		if c is CubeReveal:
			if c.done:
				var pick: Dictionary = c.buttons[0]
				for b in c.buttons:
					if String(b.text) == "Next Field" or (String(b.text) == "Leave" and String(pick.get("text", "")) != "Next Field"):
						pick = b
				c._press(pick.get("cb", Callable()))
			else:
				c._skip = true
			return
		if String(c.name) == "R_d_reward":
			for id in ["ID_btnOk", "ID_btnNext", "ID_btnEsc"]:
				var b := c.find_child(id, true, false) as BaseButton
				if b != null and b.is_visible_in_tree():
					b.pressed.emit()
					return
	if s.engine.result == "lose":
		print("TUT   lost ", s.quest.get("title", ""), " - training the team")
		for m in Save.team_members():
			m.level = mini(DB.MAX_LEVEL, int(m.level) + 3)
		s._retreat()
