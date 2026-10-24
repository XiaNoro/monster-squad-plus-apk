extends Screen

const COLS := 5

var lay: Layout
var raid: Dictionary = {}
var _picked: Array = []
var _party: Array = []
var _tiles: Dictionary = {}


func build() -> void:
	var navy := ColorRect.new()
	navy.color = Color("2c3a84")
	navy.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(navy)
	key_kind = "raid"
	var today := Save.raid_today()
	if Save.raid_needs_squad():
		raid = Raids.raid(String(today.id))
		_build_squad()
	elif not today.is_empty():
		raid = Raids.raid(String(today.id))
		_build_lobby(today)
	elif args.has("raid") and Save.has_raid_key():
		raid = Raids.raid(String(args.raid))
		_build_squad()
	else:
		main.go.call_deferred("islands", {"tab": "raid"})
		return
	add_top_bar("7", "Raid", "islands")
	_back_args = {"tab": "raid"}


static func _power(m: Dictionary) -> float:
	var st := DB.stats_at(m.id, int(m.level), int(m.boost))
	return float(st.hp) + 4.0 * float(st.atk) + 2.0 * float(st.rec)


func _raid_art() -> Texture2D:
	var art := DB.island_art(String(raid.id))
	if art == null:
		var rooms: Array = raid.rooms
		art = DB.battle_sprite(String(rooms[Raids.ROOMS - 1][0]))
	return art


func _tile(m: Dictionary, on_tap: Callable) -> Layout:
	var t := Layout.instance("B_monsterIcon_technical")
	t.show("ID_frameSize_2", false)
	t.hide_all(["ID_att", "ID_grade", "ID_check", "ID_Select", "ID_dead", "ID_party"])
	var card := UI.monster_card(String(m.id), 0, 0, Vector2(92, 92))
	card.position = Vector2(5, 13)
	card.mouse_filter = MOUSE_FILTER_IGNORE
	var frame := t.node("ID_frameSize_1")
	frame.add_child(card)
	frame.move_child(card, 1)
	t.text("ID_level", "Lv.%d" % int(m.level))
	t.text("ID_strenth", "+%d" % int(m.boost))
	for id in ["ID_level", "ID_strenth"]:
		var l := t.node(id) as Label
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_constant_override("outline_size", 4)
		l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
		frame.move_child(l, frame.get_child_count() - 1)
	t.root.mouse_filter = MOUSE_FILTER_STOP
	t.root.gui_input.connect(_on_tile_input.bind(on_tap, int(m.uid)))
	return t


func _on_tile_input(e: InputEvent, on_tap: Callable, uid: int) -> void:
	UI.hold(e, func():
		if is_inside_tree() and not Save.get_owned(uid).is_empty():
			MonsterPopup.info(self, uid))
	if UI.tapped(e):
		on_tap.call(uid)


func _boss_ids() -> Array:
	var out := []
	for i in Raids.BOSS_ROOMS:
		out.append(String(raid.rooms[i][0]))
	return out


func _build_squad() -> void:
	lay = Layout.load_into(self, "R_squadChoicePage")
	lay.text("ID_islandName", String(raid.name))
	lay.text("ID_pageName", "Squad Formation")
	lay.text("ID_LABEL_3", "Create a squad of up to %d." % Raids.PICK)
	var desc := lay.text("ID_textDes", String(raid.get("desc", "12 stages, with bosses on 4, 8 and 12. HP carries over, and knocked-out monsters rest until the next key.")))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 14)
	desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc.clip_text = true
	var bosses := _boss_ids()
	for k in 3:
		var seen: bool = Save.data.seen.has(bosses[k])
		var card := UI.monster_card(bosses[k], 0, 0, Vector2(92, 92), not seen)
		card.mouse_filter = MOUSE_FILTER_IGNORE
		lay.put("ID_monFrame%d" % (k + 1), card)
	var art := UI.image(_raid_art(), Vector2(330, 250))
	art.size = Vector2(330, 250)
	art.position = Vector2(46, 172)
	lay.root.add_child(art)
	lay.on("ID_btnOK", _confirm_squad)
	_refresh_squad()


func _refresh_squad() -> void:
	var owned: Array = Save.data.monsters.duplicate()
	owned.sort_custom(func(a, b): return _power(a) > _power(b))
	_tiles.clear()
	var rows := []
	var row: HBoxContainer
	for i in owned.size():
		if i % COLS == 0:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 0)
			rows.append(row)
		var t := _tile(owned[i], _toggle_pick)
		t.show("ID_9PATCH_Lifegage", false)
		t.show("ID_Select", _picked.has(int(owned[i].uid)))
		_tiles[int(owned[i].uid)] = t
		row.add_child(t.root)
	var keep := 0
	var holder := lay.node("ID_arrayPosition")
	for sc in holder.find_children("*", "ScrollContainer", false, false):
		keep = (sc as ScrollContainer).scroll_vertical
	lay.list_into("ID_arrayPosition", rows, 0)
	for sc in holder.find_children("*", "ScrollContainer", false, false):
		(sc as ScrollContainer).set_deferred("scroll_vertical", keep)
	lay.text("ID_numText", "%d" % _picked.size())
	lay.text("ID_maxText", "/%d" % Raids.PICK)


func _toggle_pick(uid: int) -> void:
	if _picked.has(uid):
		_picked.erase(uid)
	elif _picked.size() < Raids.PICK:
		_picked.append(uid)
	else:
		return
	Sfx.play("click")
	(_tiles[uid] as Layout).show("ID_Select", _picked.has(uid))
	lay.text("ID_numText", "%d" % _picked.size())


func _confirm_squad() -> void:
	if _picked.is_empty():
		UI.notice(self, "Notice", "Select the monsters for your squad.")
		return
	var body := "Enter %s with %d monster(s)?\nThe squad can't be changed until the island resets." % [raid.name, _picked.size()]
	var d := Layout.load_into(self, "R_d_conform_2button")
	d.root.z_index = 80
	d.node("ID_9PATCH_2").mouse_filter = MOUSE_FILTER_STOP
	d.text("ID_titleText", "Notice")
	var l := d.text("ID_baseText", body)
	if l != null:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", UI.BROWN)
	var root := d.root
	for b in d.nodes_named("ID_btnOk"):
		(b as BaseButton).pressed.connect(_start_raid.bind(root))
	for id in ["ID_btnCancel", "ID_btnEsc", "ID_btnNo"]:
		if d.has(id):
			d.on(id, root.queue_free)


func _start_raid(dialog: Control) -> void:
	dialog.queue_free()
	if Save.start_raid(String(raid.id), _picked.duplicate()):
		Sfx.play("buff_big")
		main.go("raid")


func _build_lobby(today: Dictionary) -> void:
	lay = Layout.load_into(self, "R_technicaldungeonLobby")
	var alive := Save.raid_alive()
	_party = []
	for u in today.get("party", []):
		if alive.has(int(u)) and _party.size() < Raids.PARTY:
			_party.append(int(u))
	if _party.is_empty():
		_party = alive.slice(0, Raids.PARTY)
	_refresh_lobby()
	var room := int(today.room)
	var done := bool(today.done)
	lay.text("ID_LABEL_1", ("Clear!" if room >= Raids.ROOMS else "Raid Over") if done else "Stage %d / %d" % [room + 1, Raids.ROOMS])
	lay.text("ID_LABEL_2", "GO")
	lay.on("ID_9BUTTON_1", _fight)
	var stage := lay.node("ID_stage")
	stage.mouse_filter = MOUSE_FILTER_STOP
	stage.gui_input.connect(_on_road_input.bind(mini(room, Raids.ROOMS - 1)))
	for i in Raids.ROOMS:
		var n := "%02d" % (i + 1)
		var reached := i <= room
		lay.show("ID_MosterON_" + n, reached)
		lay.show("ID_MosterOFF_" + n, not reached)
		lay.show("ID_IMAGE_" + n, i == room and not done)
		lay.show("ID_pointing_" + n, i == room and not done)
		for id in ["ID_MosterON_" + n, "ID_MosterOFF_" + n]:
			var img := lay.node(id)
			img.mouse_filter = MOUSE_FILTER_STOP
			img.gui_input.connect(_on_road_input.bind(i))
		if i < room:
			lay.node("ID_MosterON_" + n).modulate = Color(0.75, 0.75, 0.75)
	if done:
		UI.notice(self, "Notice", ("%s cleared!" % raid.name if room >= Raids.ROOMS else "Your squad is out of monsters.") + "\nGold earned: %s\nA new key arrives at 00:00am." % Screen._thousands(int(today.get("gold", 0))))


func _refresh_lobby() -> void:
	var today := Save.raid_today()
	var picked: Array = today.get("picked", [])
	for i in 20:
		var holder := lay.node("ID_mon%02d" % (i + 1))
		for c in holder.get_children():
			c.queue_free()
		if i >= picked.size():
			continue
		var m := Save.get_owned(int(picked[i]))
		if m.is_empty():
			continue
		var t := _tile(m, _toggle_party)
		var hp := Save.raid_hp(int(m.uid))
		var gauge := t.node("ID_9PATCH_3")
		gauge.size.x = 80.0 * clampf(hp, 0.0, 1.0)
		gauge.visible = hp > 0.0
		t.show("ID_dead", hp <= 0.0)
		t.show("ID_party", _party.has(int(m.uid)))
		holder.add_child(t.root)
	var members := []
	for u in _party:
		members.append(Save.get_owned(int(u)))
	var slots := ["ID_Monicon", "ID_Monicon_1", "ID_Monicon_2", "ID_Monicon_3", "ID_Monicon_4"]
	for k in slots.size():
		var h := lay.node(slots[k])
		for c in h.get_children():
			c.queue_free()
		if k < members.size():
			var card := UI.monster_card(String(members[k].id), int(members[k].level), int(members[k].boost), Vector2(92, 92))
			card.position = Vector2(3, 13)
			card.mouse_filter = MOUSE_FILTER_IGNORE
			h.add_child(card)
	for k in 5:
		var h := lay.node("ID_leaderSkill%d" % (k + 1))
		for c in h.get_children():
			c.queue_free()
		if members.is_empty():
			continue
		var def := DB.monster(String(members[0].id))
		if k < def.skills.size():
			var ic := UI.image(DB.skill_icon(String(def.skills[k].icon)), Vector2(40, 40))
			ic.size = Vector2(40, 40)
			ic.mouse_filter = MOUSE_FILTER_STOP
			UI.tip(ic, "%s (%d MP): %s" % [def.skills[k].name, int(def.skills[k].mp), def.skills[k].description])
			h.add_child(ic)
	lay.show("ID_teamRank", not members.is_empty())
	if not members.is_empty():
		lay.set_image("ID_rankImage", Layout.texture("T_rank%s_01.png" % Arena.team_rank(members)))
		var kind := Arena.team_type(members)
		lay.show("ID_IMAGE_14", kind == "attack")
		lay.show("ID_IMAGE_22", kind == "defence")
		lay.show("ID_IMAGE_23", kind == "support")
	var lines := []
	for k in range(1, members.size()):
		var p := String(DB.monster(String(members[k].id)).passive)
		if p != "":
			lines.append("- " + p)
	if lines.is_empty():
		lines.append("- Tap monsters on the left to form a party of up to %d." % Raids.PARTY)
	for k in 4:
		var l := lay.text("ID_ef%dText_1" % (k + 1), String(lines[k]) if k < lines.size() else "")
		l.clip_text = true


func _toggle_party(uid: int) -> void:
	var today := Save.raid_today()
	if bool(today.done):
		return
	if Save.raid_hp(uid) <= 0.0:
		UI.notice(self, "Notice", "This monster was knocked out.\nIt can fight again tomorrow.")
		return
	if _party.has(uid):
		_party.erase(uid)
	elif _party.size() < Raids.PARTY:
		_party.append(uid)
	else:
		UI.notice(self, "Notice", "A party can have up to %d monsters." % Raids.PARTY)
		return
	Sfx.play("click")
	today["party"] = _party.duplicate()
	Save.save_game()
	_refresh_lobby()


func _on_road_input(e: InputEvent, room: int) -> void:
	if UI.tapped(e):
		_preview(room)


func _preview(room: int) -> void:
	var q := Raids.room_quest(raid, room)
	var d := Layout.load_into(self, "R_d_technicaldungeonLobby")
	d.root.z_index = 80
	var enemies: Array = q.enemies
	var boss := Raids.is_boss_room(room)
	var which := "ID_Dialog_boss" if boss else ("ID_Dialog_slot5" if enemies.size() >= 5 else "ID_Dialog_slot4")
	for k in ["ID_Dialog_boss", "ID_Dialog_slot5", "ID_Dialog_slot4"]:
		d.show(k, k == which)
	d.node(which).mouse_filter = MOUSE_FILTER_STOP
	var title := "Stage %d" % (room + 1)
	var root := d.root
	if boss:
		d.text("ID_titleText", title)
		d.text("ID_itemName", "BOSS")
		_preview_icon(d, "ID_9PATCH_MonIcon", String(enemies[0]))
		d.on("ID_btnOk", root.queue_free)
		d.on("ID_btnEsc", root.queue_free)
	elif which == "ID_Dialog_slot5":
		d.text("ID_titleText_5", title)
		for k in 5:
			if k < enemies.size():
				_preview_icon(d, "ID_MonIcon5_%d" % (k + 1), String(enemies[k]))
		d.on("ID_btnOk_1_1", root.queue_free)
		d.on("ID_btnEsc_5", root.queue_free)
	else:
		d.text("ID_titleText_4", title)
		for k in 4:
			if k < enemies.size():
				_preview_icon(d, "ID_MonIcon4_%d" % (k + 1), String(enemies[k]))
		d.on("ID_btnOk_1_1_1", root.queue_free)
		d.on("ID_btnEsc_3", root.queue_free)


func _preview_icon(d: Layout, holder: String, id: String) -> void:
	var seen: bool = Save.data.seen.has(id)
	var card := UI.monster_card(id, 0, 0, Vector2(92, 92), not seen)
	card.position = Vector2(5, 13)
	card.mouse_filter = MOUSE_FILTER_IGNORE
	d.put(holder, card)


func _fight() -> void:
	var today := Save.raid_today()
	if bool(today.done):
		UI.notice(self, "Notice", "A new key arrives at 00:00am.")
		return
	if _party.is_empty():
		UI.notice(self, "Notice", "Tap monsters on the left to form a party.")
		return
	var q := Raids.room_quest(raid, int(today.room))
	main.go("battle", {"quest": q, "party": _party.duplicate()})
