extends Screen

const MAX_MATERIALS := 1
const SORTS := ["Obtained", "Level", "Rank"]

var lay: Layout
var mode := "boost"
var uid := -1
var _picked: Array = []
var _cards: Dictionary = {}
var _sort := 0
var _mat_box: Control
var _rate_label: Label
var _fail_label: Label


func build() -> void:
	mode = String(args.get("mode", "boost"))
	uid = int(args.get("uid", -1))
	UI.brown_background(self)
	lay = Layout.load_into(self, "R_comStrengthPage" if mode == "boost" else "R_comEvolutionPage")
	add_top_bar("2", {"boost": "Boost", "evolve": "Evolution", "fusion": "Fusion"}[mode], "squad")
	_back_args = {"mode": "train", "uid": uid}
	if mode == "boost":
		lay.on("ID_btnComSt", _do_boost)
		lay.hide_all(["ID_eventTag_St", "ID_IMAGE_2"])
		lay.text("ID_LABEL_3", "Select Material")
		_setup_boost_panel()
	else:
		lay.hide_all(["ID_eventTag_Fu", "ID_eventTag_Ev", "ID_btnChange", "ID_Crystal"])
		lay.show("ID_btnComFu", mode == "fusion")
		lay.show("ID_btnComEv", mode == "evolve")
		lay.on("ID_btnComFu", _do_fusion)
		lay.on("ID_btnComEv", _do_evolve)
		lay.on("ID_btnEvInfo", func(): MonsterPopup.show_tree(self, uid, _do_evolve if mode == "evolve" else Callable()))
		lay.text("ID_LABEL_2", "Ev Tree")
		lay.text("ID_LABEL_1", "Matl")
		lay.text("ID_LABEL_3", "Select" if mode == "evolve" else "Select Partner")
		lay.text("ID_titleName", "Evolution" if mode == "evolve" else "Fusion")
		lay.text("ID_LABEL_ev", "Evolve")
		if mode == "evolve":
			lay.hide_all(["ID_expensive", "ID_IMAGE_8", "ID_IMAGE_10"])
			var mat_card: Control = lay.node("ID_monFrame2")
			mat_card.mouse_filter = MOUSE_FILTER_STOP
			mat_card.gui_input.connect(_on_touch_material)
	_sort = SORTS.find("Rank")
	var hero: Control = lay.node("ID_ev1")
	hero.mouse_filter = MOUSE_FILTER_STOP
	hero.gui_input.connect(func(e: InputEvent): if _tapped(e): MonsterPopup.info(self, uid))
	lay.on("ID_btnAlign", _next_sort)
	_refresh()
	if args.has("pickmat") and not _cards.is_empty():
		for u in _cards:
			if not Save.in_team(int(u)):
				_picked = [int(u)]
				break
		_refresh()
		if String(args.pickmat) == "confirm":
			_do_boost()
	Tutorial.maybe_start(self, "combine")


func _target() -> Dictionary:
	return Save.get_owned(uid)


func _candidates() -> Array:
	var t := _target()
	var td := DB.monster(t.id)
	var out := []
	for m in Save.data.monsters:
		if int(m.uid) == uid:
			continue
		var d := DB.monster(m.id)
		match mode:
			"boost":
				if int(d.stars) > int(td.stars):
					continue
			"fusion":
				if int(d.stars) != int(td.stars) or not Save.is_maxed(m):
					continue
			"evolve":
				if int(d.stars) != int(td.stars):
					continue
		out.append(m)
	match SORTS[_sort]:
		"Obtained":
			out.sort_custom(func(a, b): return int(a.uid) > int(b.uid))
		"Level":
			out.sort_custom(func(a, b): return int(a.level) > int(b.level) or (int(a.level) == int(b.level) and int(a.uid) > int(b.uid)))
		_:
			out.sort_custom(func(a, b): return DB.compare_grade(a, b) > 0 or (DB.compare_grade(a, b) == 0 and int(a.level) > int(b.level)))
	return out


func _next_sort() -> void:
	_sort = (_sort + 1) % SORTS.size()
	_refresh()


static func _tapped(e: InputEvent) -> bool:
	return UI.tapped(e)


func _on_material_slot(e: InputEvent) -> void:
	if _tapped(e) and not _picked.is_empty():
		MonsterPopup.info(self, int(_picked[0]))


func _setup_boost_panel() -> void:
	var notice := lay.node("ID_boostNOTICE")
	lay.hide_all(["ID_NOTICEText", "ID_noticeDetailText", "ID_NOTICE_bg"])
	var frame := NinePatchRect.new()
	frame.texture = Layout.texture("9_Back_08.png")
	frame.patch_margin_left = 16
	frame.patch_margin_right = 16
	frame.patch_margin_top = 16
	frame.patch_margin_bottom = 16
	frame.size = Vector2(100, 100)
	frame.position = Vector2(80, 12)
	frame.mouse_filter = MOUSE_FILTER_STOP
	frame.gui_input.connect(_on_material_slot)
	notice.add_child(frame)
	_mat_box = Control.new()
	_mat_box.size = Vector2(92, 92)
	_mat_box.position = Vector2(4, 4)
	_mat_box.mouse_filter = MOUSE_FILTER_IGNORE
	frame.add_child(_mat_box)
	lay.hide_all(["ID_IMAGE_2"])
	var plus := UI.image(Layout.texture("K_add_01.png"), Vector2(44, 44))
	plus.size = Vector2(44, 44)
	plus.position = Vector2(14, 42)
	plus.mouse_filter = MOUSE_FILTER_IGNORE
	notice.add_child(plus)
	_rate_label = _small(notice, Vector2(30, 120), 18, Color("e8cfa6"))
	_fail_label = _small(notice, Vector2(30, 146), 16, Color("e8cfa6"))
	_rate_label.size.x = 202
	_fail_label.size.x = 202
	var sel := lay.node("ID_monSelected")
	for k in sel.get_children():
		(k as CanvasItem).visible = false
	var bottom := sel.position.y + sel.size.y
	sel.position.y = bottom - 94.0
	sel.size.y = 94
	var note := _small(sel, Vector2(10, 10), 19, UI.BROWN)
	note.size = Vector2(410, 74)
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "Boost PT are given when boost fails.\nEarned Boost PT add to the success rate."
	var pt := lay.node("ID_stPoiint") as NinePatchRect
	pt.texture = Layout.texture("9_Back_02.png")
	pt.size = Vector2(430, 62)
	pt.position = Vector2(25, sel.position.y - 70.0)
	var ptl := lay.node("ID_pointText") as Label
	ptl.add_theme_color_override("font_color", UI.BROWN)
	ptl.add_theme_constant_override("outline_size", 0)
	ptl.add_theme_font_size_override("font_size", 26)
	ptl.position = Vector2(0, 0)
	ptl.size = pt.size
	ptl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ptl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _small(parent: Control, pos: Vector2, font: int, color: Color) -> Label:
	var l := UI.label("", font, color)
	l.add_theme_constant_override("outline_size", 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = pos
	l.size = Vector2(232, 24)
	parent.add_child(l)
	return l


func _refresh() -> void:
	var t := _target()
	if t.is_empty():
		main.go("squad", {"mode": "train"})
		return
	_fill_target(t)
	var list := _candidates()
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	_cards.clear()
	for m in list:
		var u := int(m.uid)
		var card := UI.monster_card(m.id, int(m.level), int(m.boost), Vector2(96, 96))
		var blocked := Save.in_team(u) or bool(m.locked) or (mode == "evolve" and not _valid_material(m))
		if blocked:
			card.modulate = Color(0.45, 0.45, 0.45)
		if _picked.has(u):
			var f := NinePatchRect.new()
			f.texture = Layout.texture("9_frame_03.png")
			f.patch_margin_left = 12
			f.patch_margin_right = 12
			f.patch_margin_top = 12
			f.patch_margin_bottom = 12
			f.size = Vector2(96, 96)
			f.mouse_filter = MOUSE_FILTER_IGNORE
			card.add_child(f)
		card.gui_input.connect(_on_pick.bind(u, blocked))
		_cards[u] = card
		grid.add_child(card)
	var tiles := grid.get_child_count()
	for i in maxi(16, ceili(tiles / 4.0) * 4) - tiles:
		var empty := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.71, 0.46, 0.28)
		sb.border_color = Color(0.6, 0.37, 0.21)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		empty.add_theme_stylebox_override("panel", sb)
		empty.custom_minimum_size = Vector2(96, 96)
		empty.mouse_filter = MOUSE_FILTER_IGNORE
		grid.add_child(empty)
	lay.list_into("ID_ID_arrayPosition", [grid])
	lay.text("ID_numText", "%d / %d" % [_picked.size(), _need()] if mode == "evolve" else str(list.size()))
	lay.text("ID_LABEL_4", SORTS[_sort])
	if mode == "boost":
		_fill_boost(t)
	else:
		_fill_evolution(t)


func _fill_target(t: Dictionary) -> void:
	var def := DB.monster(t.id)
	var art: Control = lay.node("ID_ev1")
	for c in art.get_children():
		if c.has_meta("art"):
			c.queue_free()
	var pic := UI.living(DB.battle_sprite(t.id), Vector2(170, 130))
	pic.set_meta("art", true)
	pic.position = Vector2(10, 22)
	art.add_child(pic)
	for g in 6:
		lay.show("ID_mon1Grade%d" % (g + 1), g < int(def.stars))
	lay.text("ID_level", "Lv.%d/%d" % [int(t.level), Save.max_level(t)])
	lay.text("ID_stNum", "+%d" % int(t.boost))
	lay.show("ID_maxLevel", int(t.level) >= Save.max_level(t))


func _on_pick(e: InputEvent, u: int, blocked: bool) -> void:
	if not tutorial_active():
		UI.hold(e, func():
			if is_inside_tree():
				MonsterPopup.info(self, u))
	if not _tapped(e):
		return
	if blocked:
		var m := Save.get_owned(u)
		if mode == "evolve" and not _valid_material(m):
			UI.toast(self, _need_text())
		else:
			UI.toast(self, "Locked and party monsters can't be used")
		return
	if _picked.has(u):
		_picked.erase(u)
	else:
		_picked.clear()
		_picked.append(u)
	Sfx.play("click")
	_refresh()
	tut_notify("monster:material")


func _fill_boost(t: Dictionary) -> void:
	for c in _mat_box.get_children():
		c.queue_free()
	var cost := DB.boost_cost(t.id, int(t.boost))
	var chance := 0.0
	var fail_pt := 0
	if _picked.is_empty():
		var l := UI.label("Material", 22, Color("e8cfa6"))
		l.add_theme_constant_override("outline_size", 0)
		l.size = Vector2(92, 92)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_mat_box.add_child(l)
	else:
		var m := Save.get_owned(int(_picked[0]))
		var card := UI.monster_card(m.id, int(m.level), int(m.boost), Vector2(92, 92))
		card.mouse_filter = MOUSE_FILTER_IGNORE
		_mat_box.add_child(card)
		var p := Save.boost_preview(uid, int(_picked[0]))
		if p.ok:
			chance = float(p.chance)
			cost = int(p.cost)
		fail_pt = DB.boost_pt_on_fail(t.id, m.id)
	_rate_label.text = "Success Rate: %d%%" % roundi(chance * 100.0)
	_fail_label.text = "If fail:+%d Boost PT" % fail_pt
	var pt := int(t.get("boost_pt", 0))
	lay.text("ID_pointText", "Earned Boost PT: %d (+%d%%)" % [pt, roundi(pt / 2.0)])
	lay.text("ID_goldText", Screen._thousands(cost))
	lay.text("ID_titleName", "Boost")
	lay.text("ID_LABEL_4", SORTS[_sort])
	var b := lay.node("ID_btnComSt") as BaseButton
	(b.get_child(0) as CanvasItem).modulate = Color.WHITE if not _picked.is_empty() and int(t.boost) < DB.MAX_BOOST else Color(0.2, 0.22, 0.42)


func _card_art(l: Layout, m: Dictionary, root_id: String = "ID_ev1") -> void:
	var def := DB.monster(m.id)
	var art: Control = l.node(root_id)
	var pic := UI.living(DB.battle_sprite(m.id), Vector2(170, 130))
	pic.position = Vector2(10, 22)
	art.add_child(pic)
	for g in 6:
		l.show("ID_mon1Grade%d" % (g + 1), g < int(def.stars))
	l.text("ID_level", "Lv.%d/%d" % [int(m.level), Save.max_level(m)])
	l.text("ID_stNum", "+%d" % int(m.boost))
	if l.has("ID_maxLevel"):
		l.show("ID_maxLevel", int(m.level) >= Save.max_level(m))


func _dialog(name: String, open_sfx: String = "popup_open") -> Layout:
	var d := Layout.load_into(self, name, Vector2.ZERO, Layout.SCREEN_H, open_sfx)
	d.root.z_index = 80
	d.node("ID_9PATCH_2").mouse_filter = MOUSE_FILTER_STOP
	return d


func _do_boost() -> void:
	if _picked.is_empty():
		UI.notice(self, "Notice", "Select a material monster first.")
		return
	var t := _target()
	if int(t.boost) >= DB.MAX_BOOST:
		UI.notice(self, "Notice", "This monster is already +%d." % DB.MAX_BOOST)
		return
	var mat := Save.get_owned(int(_picked[0]))
	var p := Save.boost_preview(uid, int(_picked[0]))
	if not p.ok:
		UI.notice(self, "Notice", String(p.reason))
		return
	if int(Save.data.gold) < int(p.cost):
		UI.notice(self, "Notice", "Not enough Gold.")
		return
	var d := _dialog("R_d_comStrength")
	d.show("ID_monMatl", false)
	_card_art(d, t)
	var card := UI.monster_card(mat.id, int(mat.level), int(mat.boost), Vector2(92, 92))
	card.mouse_filter = MOUSE_FILTER_IGNORE
	d.put("ID_mon1", card)
	d.show("ID_LABEL_1", false)
	var chance := float(p.chance)
	if tutorial_active():
		chance = 1.0
	d.text("ID_probabilityText", "Success Rate: %d%%" % roundi(chance * 100.0))
	d.text("ID_LABEL_2", "If fail +%d Boost PT" % DB.boost_pt_on_fail(t.id, mat.id))
	(d.node("ID_LABEL_2") as Label).add_theme_font_size_override("font_size", 15)
	var base := d.node("ID_baseText") as Label
	base.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	base.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	base.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	base.add_theme_color_override("font_color", UI.BROWN)
	base.add_theme_font_size_override("font_size", 21)
	base.size = Vector2(362, 70)
	var ok := d.on("ID_btnOk", _boost_now.bind(d))
	ok.set_meta("tut_ok", true)
	ok.set_meta("sfx", "click")
	d.on("ID_btnEsc", d.root.queue_free)


func _boost_now(d: Layout) -> void:
	var mat_uid := int(_picked[0])
	var hero_id := String(_target().id)
	var mat_id := String(Save.get_owned(mat_uid).id)
	var gain := DB.boost_pt_on_fail(hero_id, mat_id)
	if tutorial_active():
		_target()["boost_pt"] = maxi(int(_target().get("boost_pt", 0)), 200)
	var r := Save.boost(uid, mat_uid)
	_picked.clear()
	if not r.ok:
		d.root.queue_free()
		_refresh()
		UI.notice(self, "Notice", String(r.reason))
		return
	BoostScene.play(d, hero_id, mat_id, r.success, _boost_result.bind(d, r, gain))


func _boost_result(d: Layout, r: Dictionary, gain: int) -> void:
	d.root.queue_free()
	_refresh()
	var t := _target()
	if r.success:
		var s := _dialog("R_d_comStrength2", "")
		s.show("ID_jackpot", false)
		s.text("ID_titleText", "Boost Successful")
		s.text("ID_baseText", "Boosted to +%d." % int(t.boost))
		(s.node("ID_baseText") as Label).add_theme_color_override("font_color", UI.BROWN)
		_card_art(s, t)
		var ok := s.on("ID_btnOk", _boost_done.bind(s.root))
		ok.set_meta("tut_ok", true)
	else:
		var f := _dialog("R_d_comStrength3", "")
		f.text("ID_titleText", "Boost")
		var l := f.text("ID_baseText", "Boost failed.\nReceived %d Boost PT." % gain)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", UI.BROWN)
		var ok := f.on("ID_btnOk", _boost_done.bind(f.root))
		ok.set_meta("tut_ok", true)


func _boost_done(root: Control) -> void:
	root.queue_free()
	tut_notify("boosted")

func _fill_evolution(t: Dictionary) -> void:
	var def := DB.monster(t.id)
	var mat_uid := int(_picked[0]) if not _picked.is_empty() else -1
	var mat := Save.get_owned(mat_uid)
	var slot: Control = lay.node("ID_ev2")
	for c in slot.get_children():
		if c.has_meta("art"):
			c.queue_free()
	for g in 6:
		lay.show("ID_mon2Grade%d" % (g + 1), not mat.is_empty() and g < int(DB.monster(mat.id).stars))
	lay.text("ID_level2", ("Lv.%d/%d" % [int(mat.level), Save.max_level(mat)]) if not mat.is_empty() else "")
	lay.text("ID_stNum2", ("+%d" % int(mat.boost)) if not mat.is_empty() else "")
	var need := ""
	if mode == "evolve":
		var mname := String(DB.monster(String(def.get("evolve_material", ""))).get("name", "?"))
		need = "It needs\n[+5] [Lv.30]\n[%d %s]\nfor Material" % [maxi(1, int(def.get("evolve_quantity", 1))), mname] if String(def.evolves_into) != "" else "Final form"
	else:
		need = "Pick a Lv.30 +5\n%d★ partner" % int(def.stars)
	lay.text("ID_exText", need if mat.is_empty() else "")
	lay.show("ID_mon2Sh", not mat.is_empty())
	if not mat.is_empty():
		var pic := UI.living(DB.battle_sprite(mat.id), Vector2(170, 130))
		pic.set_meta("art", true)
		pic.position = Vector2(10, 22)
		slot.add_child(pic)
	for k in 3:
		var holder: Control = lay.node("ID_monFrame%d" % (k + 1))
		for c in holder.get_children():
			c.queue_free()
	var row := [t.id, String(def.get("evolve_material", "")) if mode == "evolve" else (mat.id if not mat.is_empty() else ""), String(def.evolves_into) if mode == "evolve" else ""]
	var levels := [[int(t.level), int(t.boost)], [int(mat.level), int(mat.boost)] if not mat.is_empty() else [0, 0], [1, 0]]
	for k in 3:
		if row[k] == "":
			continue
		var c := UI.monster_card(row[k], levels[k][0], levels[k][1], Vector2(92, 92))
		c.mouse_filter = MOUSE_FILTER_IGNORE
		lay.node("ID_monFrame%d" % (k + 1)).add_child(c)
		if k == 1 and mode == "evolve" and mat.is_empty():
			c.modulate = Color(0.5, 0.5, 0.5)
			var have := _materials().size()
			for line in [["Touch", 22.0], ["%d/%d" % [mini(have, _need()), _need()], 56.0]]:
				var l := UI.label(line[0], 22, Color.WHITE)
				l.size = Vector2(92, 30)
				l.position = Vector2(0, line[1])
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lay.node("ID_monFrame2").add_child(l)
	var ok := false
	var cost := 0
	if mode == "evolve":
		var ev := Save.can_evolve(uid)
		ok = ev.ok
		cost = 0 if Save.dev("dev_free_evolve") else DB.evolve_cost(t.id)
		lay.text("ID_probabilityText", "Touch and Select me (all)" if mat.is_empty() else ("All materials need [+5] & [Lv.30], too" if not ok else "I can evolve"))
	else:
		var p := Save.fusion_preview(uid, mat_uid) if mat_uid >= 0 else {"ok": false, "reason": "Pick a partner"}
		ok = p.ok
		cost = int(p.get("cost", DB.fusion_cost(int(def.stars))))
		lay.text("ID_probabilityText", "The results for Fusing are random" if ok else String(p.reason))
	lay.text("ID_goldText", Screen._thousands(cost))
	lay.node("ID_btnComFu").modulate = Color.WHITE if ok else Color(0.55, 0.55, 0.55)
	(lay.node("ID_btnComEv").get_child(0) as CanvasItem).modulate = Color.WHITE if ok else Color(0.2, 0.22, 0.42)


func _valid_material(m: Dictionary) -> bool:
	return m.id == String(DB.monster(_target().id).get("evolve_material", "")) and Save.is_maxed(m)


func _materials() -> Array:
	return Save.data.monsters.filter(func(m): return int(m.uid) != uid and _valid_material(m) and not Save.in_team(int(m.uid)) and not m.locked)


func _need() -> int:
	return maxi(1, int(DB.monster(_target().id).get("evolve_quantity", 1)))


func _need_text() -> String:
	var mname := String(DB.monster(String(DB.monster(_target().id).get("evolve_material", ""))).get("name", "?"))
	return "It needs [+5] [Lv.30] [%d %s] for Material" % [_need(), mname]


func _on_touch_material(e: InputEvent) -> void:
	if not UI.tapped(e):
		return
	var mats := _materials()
	if mats.is_empty():
		UI.toast(self, _need_text())
		return
	Sfx.play("click")
	_picked = mats.slice(0, mini(_need(), MAX_MATERIALS)).map(func(m): return int(m.uid))
	_refresh()


func _do_evolve() -> void:
	var ev := Save.can_evolve(uid)
	if not ev.ok:
		UI.notice(self, "Evolution", String(ev.reason))
		return
	var t := _target()
	var def := DB.monster(t.id)
	var into := DB.monster(String(def.evolves_into))
	var d := Layout.load_into(self, "R_d_comEvolution")
	d.root.z_index = 80
	d.node("ID_9PATCH_2").mouse_filter = MOUSE_FILTER_STOP
	d.text("ID_titleText", "Evolution")
	var ids := [t.id, String(def.get("evolve_material", "")), String(def.evolves_into)]
	for k in 3:
		if ids[k] == "":
			continue
		var card := UI.monster_card(ids[k], 0, 0, Vector2(92, 92))
		card.mouse_filter = MOUSE_FILTER_IGNORE
		d.put("ID_monFrame%d" % (k + 1), card)
	var l := d.text("ID_baseText", "Material monster will disappear.\nEvolves into [%s (★%d)]." % [into.name, int(into.stars)])
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", UI.BROWN)
	l.add_theme_font_size_override("font_size", 21)
	var root := d.root
	var ok := d.on("ID_btnOk", _evolve_now.bind(root))
	ok.set_meta("tut_ok", true)
	d.on("ID_btnEsc", root.queue_free)


func _evolve_now(root: Control) -> void:
	root.queue_free()
	var from := [String(_target().id), String(DB.monster(_target().id).get("evolve_material", ""))]
	var fresh: bool = not Save.data.owned.has(String(DB.monster(_target().id).evolves_into))
	var r := Save.evolve(uid)
	if not r.ok:
		UI.notice(self, "Evolution", String(r.get("reason", "Can't evolve")))
		return
	_picked.clear()
	CubeReveal.evolve(self, from.filter(func(id): return id != ""), String(r.into), fresh, [{"text": "OK", "color": "green", "cb": _after_evolve}])


func _after_evolve() -> void:
	tut_notify("evolved")
	await get_tree().create_timer(0.3).timeout
	main.go("squad", {"mode": "train", "uid": uid})


func _do_fusion() -> void:
	if _picked.is_empty():
		UI.toast(self, "Pick a partner first")
		return
	var r := Save.fuse(uid, int(_picked[0]))
	if not r.ok:
		UI.notice(self, "Fusion", String(r.reason))
		return
	_picked.clear()
	uid = int(r.uid)
	_back_args = {"mode": "train", "uid": uid}
	CubeReveal.show_monster(self, String(r.into), [{"text": "OK", "color": "green", "cb": _refresh}])


func tutorial_target(name: String) -> Control:
	match name:
		"boost":
			return lay.node("ID_btnComSt")
		"evolve":
			return lay.node("ID_btnComEv")
		"monster:material":
			for u in _cards:
				if not Save.in_team(int(u)) and not Save.get_owned(int(u)).locked:
					return _cards[u]
	return null
