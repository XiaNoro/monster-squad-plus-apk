class_name Events
extends RefCounted

const DATA := "res://data/events.json"
const STORY_IDS := ["sprout_island", "lake_island", "desert_isle", "moonlight_desert", "boneyard_island", "dino_gorge", "robo_island", "sky_island"]

static var _data: Dictionary = {}
static var _cache_day := ""
static var _cache: Array = []


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		if parsed is Dictionary:
			_data = parsed
	return _data


static func _day_key(unix: int) -> String:
	var d := Time.get_date_dict_from_unix_time(unix)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


static func _days(unix: int) -> int:
	var first := Time.get_unix_time_from_datetime_string(String(data().get("first_monday", "2016-07-04")) + "T00:00:00")
	return floori(float(unix - first) / 86400.0)


static func week_count() -> int:
	return data().get("weeks", []).size()


static func week_index(unix: int) -> int:
	return posmod(floori(_days(unix) / 7.0), maxi(1, week_count()))


static func weekly_on_day(unix: int) -> Array:
	var weeks: Array = data().get("weeks", [])
	if weeks.is_empty():
		return []
	var week: Array = weeks[week_index(unix)]
	return week[posmod(_days(unix), 7)]


static func shift_days(days: int) -> void:
	Save.data["event_shift"] = int(Save.data.get("event_shift", 0)) + days
	Save.save_game()


static func next_week() -> void:
	shift_days(7 - posmod(_days(now()), 7))


static func reset_shift() -> void:
	Save.data["event_shift"] = 0
	Save.save_game()


static func limited_on_day(unix: int) -> Array:
	var md := _day_key(unix).substr(5)
	return data().get("limited", []).filter(func(l): return md >= String(l.from) and md <= String(l.to))


static func on_day(unix: int) -> Array:
	var out: Array = weekly_on_day(unix).duplicate()
	for l in limited_on_day(unix):
		out.append_array(l.events)
	return out


static func monthly(island_id: String, difficulty: String, stage_index: int) -> Dictionary:
	for e in today():
		if String(e.type) == "monthly" and String(e.where) == island_id and String(e.difficulty) == difficulty and int(e.stage) == stage_index:
			return e
	return {}


static func now() -> int:
	var shift := int(Save.data.get("event_shift", 0)) * 86400
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--test-date="):
			return Time.get_unix_time_from_datetime_string(a.trim_prefix("--test-date=") + "T12:00:00") + shift
	return int(Time.get_unix_time_from_system()) + shift


static func today() -> Array:
	var t := now()
	var key := _day_key(t)
	if key != _cache_day:
		_cache_day = key
		_cache = on_day(t)
	return _cache


static func text(list: Array = today()) -> String:
	var lines: Array = []
	for e in list:
		lines.append(String(e.text))
	return "\n".join(lines)


static func has(type: String) -> bool:
	for e in today():
		if String(e.type) == type:
			return true
	return false


static func _covers(where: String, island_id: String, difficulty: String) -> bool:
	match where:
		"", "all":
			return true
		"story":
			return island_id in STORY_IDS
		"story_normal":
			return island_id in STORY_IDS and difficulty in ["", "normal"]
		"special":
			return island_id != "" and not island_id in STORY_IDS
	return where == island_id


static func mult(type: String, island_id: String = "", difficulty: String = "") -> float:
	var m := 1.0
	for e in today():
		if String(e.type) == type and _covers(String(e.get("where", "")), island_id, difficulty):
			var x := float(e.get("x", data().get("effects", {}).get(type, 1.0)))
			m = minf(m, x) if x < 1.0 else maxf(m, x)
	return m


static func effect(type: String) -> float:
	return mult(type) if has(type) else 1.0


static func affects(island_id: String, difficulty: String = "") -> bool:
	for e in today():
		if _shown(e, difficulty) and String(e.get("where", "")) != "all" and _covers(String(e.get("where", "")), island_id, difficulty):
			return true
	return false


static func describe(island_id: String, difficulty: String = "") -> String:
	var lines: Array = []
	for e in current(island_id, difficulty):
		lines.append("★ " + String(e.text))
	return "\n".join(lines)


static func current(island_id: String, difficulty: String = "") -> Array:
	return today().filter(func(e): return _shown(e, difficulty) and _covers(String(e.get("where", "")), island_id, difficulty))


static func _shown(e: Dictionary, difficulty: String) -> bool:
	return String(e.type) in ["gold", "cube", "xp", "energy", "open"] or (String(e.type) == "monthly" and difficulty == "")


static func popup_text(island_id: String) -> String:
	var lines: Array = []
	var hours := ceili((86400 - now() % 86400) / 3600.0)
	for e in current(island_id):
		var x := float(e.get("x", data().get("effects", {}).get(String(e.type), 2.0)))
		var label: String = {"gold": "%sX Gold Drop ▲", "cube": "%sX Cube Drop ▲", "xp": "%sX EXP ▲", "energy": "Energy Cost ▼", "open": "Island Open", "monthly": "Monthly Quest"}[String(e.type)]
		if label.contains("%s"):
			label = label % str(snappedf(x, 0.1)).trim_suffix(".0")
		lines.append("%s\n(%dHrs remaining)" % [label, hours])
	return "\n".join(lines)


static func tag(c: Control, island_id: String, difficulty: String = "") -> void:
	if c == null:
		return
	var text := describe(island_id, difficulty)
	c.tooltip_text = text
	if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		c.mouse_filter = Control.MOUSE_FILTER_PASS
	if c.has_meta("event_tip"):
		c.set_meta("event_tip", text)
		return
	c.set_meta("event_tip", text)
	c.gui_input.connect(func(e: InputEvent):
		if String(c.get_meta("event_tip", "")) != "":
			UI.hold(e, func():
				var top := c.get_tree().current_scene as Control
				UI.toast(top if top else c, String(c.get_meta("event_tip")))))


static func opens(special_id: String) -> bool:
	for e in today():
		if String(e.get("where", "")) == special_id:
			return true
	return false


static func event_only(special_id: String) -> bool:
	return special_id in data().get("event_only", [])
