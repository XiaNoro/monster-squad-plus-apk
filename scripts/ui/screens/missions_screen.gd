class_name MissionsScreen
extends Screen

signal closed

const TABS := {"daily": "ID_tapBtn1", "weekly": "ID_tapBtn2", "endless": "ID_tapBtn3", "event": "ID_tapBtn4"}

var tab := "daily"
var _bulk := false
var lay: Layout


func build() -> void:
	if args.get("overlay", false):
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.6)
		dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		add_child(dim)
	else:
		UI.background(self, UI.tex("res://assets/apk/images/Forest_1.png"))
	lay = Layout.load_into(self, "R_d_dailyQuest")
	tab = args.get("tab", "daily")
	for t in TABS:
		lay.on(TABS[t], _set_tab.bind(t))
	lay.on("ID_btnEsc", _close)
	lay.on("ID_btnOk", _receive_all)
	lay.text("ID_LABEL_4", "Event")
	if tab == "attendance":
		tab = "daily"
		show_attendance(self)
	_refresh()
	_ticker()
	Tutorial.maybe_start(self, "missions")


static func open_over(parent: Screen, start_tab: String = "daily") -> MissionsScreen:
	var m := MissionsScreen.new()
	m.main = parent.main
	m.args = {"tab": start_tab, "overlay": true}
	m.z_index = 60
	parent.add_child(m)
	return m


func _close() -> void:
	if args.get("overlay", false):
		closed.emit()
		queue_free()
	else:
		main.go("hub")


func tutorial_target(name: String) -> Control:
	match name:
		"receive_all":
			return lay.node("ID_btnOk")
		"tab:endless":
			return lay.node(TABS.endless)
	return null


func _set_tab(t: String) -> void:
	tab = t
	_refresh()


func _entries(t: String) -> Array:
	var out := []
	match t:
		"daily":
			for m in Missions.DAILY:
				out.append(_entry("daily", m))
			out.append({"text": "Complete every daily mission", "have": 1 if Save.daily_all_done() else 0, "goal": 1, "reward": Missions.DAILY_ALL, "claimed": Save.mission_claimed("daily", "all"), "claim": _claim_bonus, "kind": t})
		"weekly":
			for m in Missions.WEEKLY:
				out.append(_entry("weekly", m))
		"event":
			for m in Missions.EVENT:
				out.append(_entry("event", m))
		"endless":
			for m in Missions.ENDLESS:
				var tier := Missions.endless_tier(m, Save.endless_tier_of(m.id))
				out.append({"text": tier.text, "have": Missions.progress("endless", m.event), "goal": int(tier.goal), "reward": tier.reward, "claimed": tier.done_all, "claim": _claim_endless.bind(m), "kind": t})
	return out


func _entry(kind: String, m: Dictionary) -> Dictionary:
	return {"text": m.text, "have": Missions.progress(kind, m.event), "goal": int(m.goal), "reward": m.reward, "claimed": Save.mission_claimed(kind, m.id), "claim": _claim.bind(kind, m), "kind": kind}


static func _ready_count(entries: Array) -> int:
	var n := 0
	for e in entries:
		if not e.claimed and int(e.have) >= int(e.goal):
			n += 1
	return n


func _refresh() -> void:
	lay.select_tab(TABS.values(), TABS.get(tab, ""))
	lay.show("ID_IMAGE_2", _ready_count(_entries("daily")) > 0)
	lay.show("ID_IMAGE_3", _ready_count(_entries("weekly")) > 0)
	lay.show("ID_IMAGE_3_1", _ready_count(_entries("endless")) > 0)
	lay.show("ID_IMAGE_4", _ready_count(_entries("event")) > 0)
	_clock()
	var entries := _entries(tab)
	entries.sort_custom(func(a, b): return _order(a) < _order(b))
	var rows := []
	for e in entries:
		rows.append(_slot(e))
	lay.list_into("ID_arrayPosition_2", rows)
	var ok := lay.node("ID_btnOk") as BaseButton
	ok.disabled = _ready_count(entries) == 0
	ok.modulate = Color.WHITE if not ok.disabled else Color(0.6, 0.6, 0.6)


static func seconds_left_in_day() -> int:
	var t := Time.get_time_dict_from_system()
	return 86400 - (int(t.hour) * 3600 + int(t.minute) * 60 + int(t.second))


static func _left_text(s: int) -> String:
	if s >= 86400:
		return "%dd %dh" % [floori(s / 86400.0), floori((s % 86400) / 3600.0)]
	return "%dh %02dm" % [floori(s / 3600.0), floori((s % 3600) / 60.0)]


func _clock() -> void:
	lay.text("ID_friendName", "Daily resets in " + _left_text(seconds_left_in_day()))
	lay.text("ID_LABEL_1", "Weekly resets in " + _left_text(Arena.seconds_left_in_week()))


func _ticker() -> void:
	var day := Time.get_date_string_from_system()
	var week := Arena.week_id()
	while is_inside_tree():
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree():
			return
		if day != Time.get_date_string_from_system() or week != Arena.week_id():
			day = Time.get_date_string_from_system()
			week = Arena.week_id()
			_refresh()
			UI.toast(self, "Missions have been refreshed!", UI.GOLD)
		else:
			_clock()


static func _order(e: Dictionary) -> int:
	if e.claimed:
		return 2
	return 0 if int(e.have) >= int(e.goal) else 1


func _slot(e: Dictionary) -> Control:
	var s := Layout.instance("R_missionSlot")
	var have := mini(int(e.have), int(e.goal))
	var state := "Done" if e.claimed else ("ToGet" if int(e.have) >= int(e.goal) else "OnGoing")
	for v in ["ToGet", "Done", "OnGoing"]:
		s.show("ID_slot" + v, v == state)
	var info: String = {"ToGet": "ID_textMission_1_1", "Done": "ID_textMission", "OnGoing": "ID_textMission_1"}[state]
	s.text(info, String(e.text))
	var bar: Control = s.node("ID_bar" + state)
	bar.size.x = 250.0 * clampf(float(have) / maxf(1.0, float(e.goal)), 0.0, 1.0)
	bar.visible = bar.size.x >= 4.0
	s.text("ID_LABEL_1_1_1", "%s/%s" % [Screen._thousands(have), Screen._thousands(int(e.goal))])
	s.text("ID_LABEL_1_1", "%s/%s" % [Screen._thousands(have), Screen._thousands(int(e.goal))])
	var when: String = {"daily": "Today", "weekly": "This week"}.get(e.kind, "")
	for t in ["ID_textTime_1", "ID_textTime_2", "ID_textTime_3"]:
		s.text(t, when)
	if state == "ToGet":
		s.on("ID_slotToGet", e.claim)
	s.put("ID_rewardSize", Layout.reward_icon(e.reward, e.claimed))
	return s.root


func _receive_all() -> void:
	var got := 0
	_bulk = true
	for pass_i in 2:
		for e in _entries(tab):
			if not e.claimed and int(e.have) >= int(e.goal):
				e.claim.call()
				got += 1
	_bulk = false
	_refresh()
	if got > 0:
		Sfx.play("buff_big")
		UI.notice(self, "Notice", "Received all rewards.")
	tut_notify("receive_all")


func _claim(kind: String, m: Dictionary) -> void:
	if Save.claim_mission(kind, m) and not _bulk:
		Sfx.play("buff")
		UI.toast(self, "Received " + Missions.reward_text(m.reward), UI.GOLD)
	if not _bulk:
		_refresh()


func _claim_bonus() -> void:
	if Save.claim_daily_bonus() and not _bulk:
		Sfx.play("buff_big")
		UI.toast(self, "Received " + Missions.reward_text(Missions.DAILY_ALL), UI.GOLD)
	if not _bulk:
		_refresh()


func _claim_endless(m: Dictionary) -> void:
	var t := Missions.endless_tier(m, Save.endless_tier_of(m.id))
	if Save.claim_endless(m) and not _bulk:
		Sfx.play("buff")
		UI.toast(self, "Received " + Missions.reward_text(t.reward), UI.GOLD)
	if not _bulk:
		_refresh()


static func show_attendance(parent: Control) -> void:
	var got := Save.claim_attendance() if Save.attendance_ready() else {}
	var a := Save.attendance()
	var lay := Layout.load_into(parent, "R_d_attendance")
	lay.root.z_index = 60
	lay.root.mouse_filter = Control.MOUSE_FILTER_STOP
	lay.node("ID_9PATCH_2").mouse_filter = Control.MOUSE_FILTER_STOP
	lay.text("ID_titleText", "%s Attendance" % _month_name(String(a.month)))
	lay.text("ID_headText", "Log in every day to collect a reward.")
	lay.hide_all(["ID_ev1", "ID_monSkill", "ID_9PATCH_3"])
	lay.on("ID_btnEsc", lay.root.queue_free)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	lay.put("ID_arrayPosition", grid)
	for i in Missions.ATTENDANCE.size():
		grid.add_child(_attendance_slot(i, Missions.ATTENDANCE[i], i < int(a.days), not got.is_empty() and i == int(a.days) - 1))
	var frame: Control = lay.node("ID_9PATCH_1")
	frame.position.x = (lay.node("ID_baseback").size.x - frame.size.x) / 2.0
	if not got.is_empty():
		Sfx.play("buff_big")
		UI.toast(parent, "Day %d reward: %s" % [int(a.days), Missions.reward_text(got)], UI.GOLD)


static func _attendance_slot(i: int, r: Dictionary, stamped: bool, fresh: bool) -> Control:
	var s := Layout.instance("R_attendance_slot")
	s.text("ID_dayNum", str(i + 1))
	var kind := ""
	if r.has("cube"):
		kind = {"blue": "ID_cube_f", "yellow": "ID_cube_r", "red": "ID_cube_a"}.get(String(r.cube), "ID_cube_f")
	elif r.has("gems"):
		kind = "ID_crystal"
	elif r.has("energy"):
		kind = "ID_energy"
	elif r.has("gold"):
		kind = "ID_gold"
	var labels := {"ID_gold": "ID_TextNum1", "ID_crystal": "ID_TextNum2", "ID_fPoint": "ID_TextNum3", "ID_cube_f": "ID_TextNum4", "ID_cube_r": "ID_TextNum5", "ID_energy": "ID_TextNum6", "ID_cube_a": "ID_TextNum7"}
	for k in labels:
		s.show(k, k == kind)
	s.show("ID_qMon", false)
	if kind != "":
		var amount := 1 if r.has("cube") else int(r.get("gold", r.get("gems", r.get("energy", 0))))
		s.text(labels[kind], ("+" if kind == "ID_gold" else "×") + Screen._thousands(amount))
	s.show("ID_complete", stamped)
	if fresh:
		var stamp: Control = s.node("ID_complete")
		stamp.pivot_offset = stamp.size / 2.0
		stamp.scale = Vector2(2.2, 2.2)
		stamp.modulate.a = 0.0
		var tw := stamp.create_tween().set_parallel()
		tw.tween_property(stamp, "scale", Vector2.ONE, 0.35).set_delay(0.3).set_trans(Tween.TRANS_BACK)
		tw.tween_property(stamp, "modulate:a", 1.0, 0.2).set_delay(0.3)
	return s.root


static func _month_name(ym: String) -> String:
	var names := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
	var mth := int(ym.substr(5, 2))
	return names[clampi(mth - 1, 0, 11)]
