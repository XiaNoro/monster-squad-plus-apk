class_name TowerScreen
extends Screen

var lay: Layout
var floor_sel := 1
var _tab := "floors"
var _slots: Dictionary = {}


static func unlocked() -> bool:
	return Save.is_island_unlocked("boneyard_island", "normal")


func build() -> void:
	UI.background(self, UI.tex("res://assets/apk/images/Forest_1.png"), 0.25)
	lay = Layout.load_into(self, "R_towerEnterPage")
	add_top_bar("2", "Sky Tower", "hub")
	floor_sel = clampi(int(args.get("floor", int(Save.data.tower_floor) + 1)), 1, SkyTower.FLOORS)
	for i in [1, 2]:
		lay.on("ID_tapFloorList%d" % i, _set_tab.bind("floors"))
		lay.on("ID_tapOverall%d" % i, _set_tab.bind("overall"))
		lay.on("ID_btnMyRank%d" % i, _show_my_rank)
	lay.on("ID_btnEnter", _enter)
	lay.on("ID_btnBuyT", _buy_ticket)
	lay.on("ID_btnTipAlert", _show_tip_popup)
	lay.on("ID_btnTeam", func(): main.go("squad", {"back": "tower"}))
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_refresh_tickets)
	add_child(timer)
	_fill_team()
	_fill_floor_list()
	_fill_overall()
	_set_tab(String(args.get("tab", "floors")))
	_refresh_info()
	_refresh_tickets()
	_refresh_fever()


func _set_tab(tab: String) -> void:
	_tab = tab
	lay.show("ID_floorList", tab == "floors")
	lay.show("ID_overall", tab == "overall")
	for i in [1, 2]:
		lay.select_tab(["ID_tapFloorList%d" % i, "ID_tapOverall%d" % i], ("ID_tapFloorList%d" if tab == "floors" else "ID_tapOverall%d") % i)


func _refresh_fever() -> void:
	var f := SkyTower.fever()
	for i in [1, 2]:
		lay.text("ID_txtF%d" % i, str(f))
		lay.text("ID_txtMaxF%d" % i, "/%d" % int(BattleEngine.FEVER_MAX))
		var g: Control = lay.node("ID_feverGraph%d" % i)
		g.size.x = 174.0 * f / BattleEngine.FEVER_MAX
		g.visible = f > 0


func _fill_floor_list() -> void:
	_slots.clear()
	var best := int(Save.data.tower_floor)
	var friends := {}
	for f in Save.data.friends:
		var ff := SkyTower.friend_floor(String(f.name))
		if not friends.has(ff):
			friends[ff] = f
	var rows := []
	for f in range(SkyTower.FLOORS, 0, -1):
		var s := Layout.instance("R_towerFloorSlot")
		s.text("ID_txtFloorNum", "Floor %d" % f)
		s.show("ID_lock", f > best + 1)
		s.show("ID_tagNew", f == best + 1)
		s.show("ID_selection", f == floor_sel)
		if friends.has(f):
			var fr: Dictionary = friends[f]
			s.show("ID_IMAGE_2", false)
			var pic := UI.monster_card(String(fr.monster), 0, 0, Vector2(56, 56))
			pic.mouse_filter = MOUSE_FILTER_IGNORE
			pic.tooltip_text = String(fr.name)
			s.put("ID_userPic", pic)
		var slot: Control = s.node("ID_btnSlot")
		slot.mouse_filter = MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_floor.bind(f))
		_slots[f] = s
		rows.append(s.root)
	var list := lay.list_into("ID_arrayPosition1", rows, 0)
	var scroll := list.get_parent() as ScrollContainer
	await get_tree().process_frame
	scroll.scroll_vertical = maxi(0, (SkyTower.FLOORS - floor_sel) * 80 - 120)


func _on_floor(e: InputEvent, f: int) -> void:
	if not UI.tapped(e):
		return
	if f > int(Save.data.tower_floor) + 1:
		UI.toast(self, "Clear Floor %d first" % (f - 1))
		return
	if _slots.has(floor_sel):
		_slots[floor_sel].show("ID_selection", false)
	floor_sel = f
	_slots[f].show("ID_selection", true)
	Sfx.play("click")
	_refresh_info()


func _fill_overall() -> void:
	var ranks := SkyTower.rank_list()
	var rows := []
	for r in ranks.slice(0, 50):
		rows.append(_rank_slot(r))
	for r in ranks:
		if bool(r.get("me", false)) and int(r.rank) > 50:
			rows.append(_rank_slot(r))
	lay.list_into("ID_arrayPosition2", rows, 0)


func _rank_slot(r: Dictionary) -> Control:
	var s := Layout.instance("R_towerRankSlot")
	s.show("ID_btnInvite", false)
	s.show("ID_myIcon", bool(r.get("me", false)))
	var n := int(r.rank)
	for k in 3:
		s.show(["ID_rank1st", "ID_rank2nd", "ID_rank3rd"][k], n == k + 1)
	var pic := UI.monster_card(String(r.monster), 0, 0, Vector2(74, 74))
	pic.mouse_filter = MOUSE_FILTER_IGNORE
	s.put("ID_kakaoPic", pic)
	s.text("ID_friendName", String(r.name))
	s.text("ID_friendScore", _floor_text(r))
	s.text("ID_friendScore1", "Rank %d" % n)
	return s.root


static func _floor_text(r: Dictionary) -> String:
	if int(r.floor) <= 0:
		return "No floor cleared"
	return "Floor %d (%.1f Seconds)" % [int(r.floor), float(r.secs)]


func _show_my_rank() -> void:
	var ranks := SkyTower.rank_list()
	var d := Layout.load_into(self, "R_d_towerRank")
	d.root.z_index = 60
	d.node("ID_9PATCH_2").mouse_filter = MOUSE_FILTER_STOP
	d.text("ID_titleText", "Sky Tower Rank")
	d.on("ID_btnEsc", d.root.queue_free)
	for k in 3:
		var r: Dictionary = ranks[k]
		var i := k + 1
		d.show("ID_btnInvite%d" % i, false)
		d.text("ID_name%d" % i, String(r.name))
		d.text("ID_noRank%d" % i, "Rank %d" % i)
		d.text("ID_stageTime%d" % i, _floor_text(r))
		var pic := UI.monster_card(String(r.monster), 0, 0, Vector2(74, 74))
		pic.mouse_filter = MOUSE_FILTER_IGNORE
		d.put("ID_kakaoPic%d" % i, pic)
	var me: Dictionary = ranks.filter(func(x): return bool(x.get("me", false)))[0]
	var mine := int(me.rank)
	for k in 4:
		d.show("ID_rankN%d" % (k + 1), (mine == k + 1) or (k == 3 and mine > 3))
	d.text("ID_rankNumber", str(mine) if mine > 3 else "")
	d.text("ID_name4", String(me.name))
	d.text("ID_noRank4", "Rank %d" % mine)
	d.text("ID_stageTime4", _floor_text(me))
	var mp := UI.monster_card(String(me.monster), 0, 0, Vector2(74, 74))
	mp.mouse_filter = MOUSE_FILTER_IGNORE
	d.put("ID_kakaoPic4", mp)


func _fill_team() -> void:
	var members := Save.team_members()
	var holders := ["ID_leaderIcon", "ID_monIconA", "ID_monIconB", "ID_monIconC"]
	for i in holders.size():
		if i >= members.size():
			continue
		var m: Dictionary = members[i]
		var card := UI.monster_card(m.id, int(m.level), int(m.boost), Vector2(92, 92))
		card.mouse_filter = MOUSE_FILTER_IGNORE
		lay.put(holders[i], card)
		var def := DB.monster(m.id)
		if i == 0:
			for k in mini(5, def.skills.size()):
				_skill_icon("ID_leaderSkill%d" % (k + 1), String(def.skills[k].icon), "%s (%d MP): %s" % [def.skills[k].name, int(def.skills[k].mp), def.skills[k].description])
		elif String(def.support_skill.get("name", "")) != "":
			_skill_icon(["", "ID_skillA", "ID_skillB", "ID_skillC"][i], String(def.support_skill.icon), "%s: %s" % [def.support_skill.name, def.support_skill.description])
	HubScreen.show_team_type(lay, Arena.team_type(members))
	lay.set_image("ID_rankImage", Layout.texture("T_rank%s_01.png" % Arena.team_rank(members)))


func _skill_icon(holder: String, icon_file: String, text: String) -> void:
	var t := DB.skill_icon(icon_file)
	if t == null:
		return
	var r := UI.image(t, Vector2(40, 40))
	r.size = Vector2(40, 40)
	r.mouse_filter = MOUSE_FILTER_STOP
	r.tooltip_text = text
	r.gui_input.connect(func(e): if UI.tapped(e): UI.toast(self, text))
	lay.put(holder, r)


func _refresh_info() -> void:
	var q := SkyTower.floor_quest(floor_sel)
	lay.text("ID_txtFloorNum", "Floor %d" % floor_sel)
	var drops := SkyTower.possible_drops(floor_sel, int(Save.data.get("tower_bought", 0)) > 0)
	for k in 3:
		var holder: Control = lay.node("ID_msIcon_%d" % (k + 1))
		for c in holder.get_children():
			c.queue_free()
		if k >= drops.size():
			continue
		var st: Dictionary = drops[k]
		var icon := StonesScreen.stone_icon(st, 92)
		icon.mouse_filter = MOUSE_FILTER_STOP
		var text := "%s\n%s" % [MagicStones.label(st), MagicStones.describe(st)]
		icon.tooltip_text = text
		icon.gui_input.connect(func(e): if UI.tapped(e): UI.toast(self, text.replace("\n", "  ·  ")))
		holder.add_child(icon)
	var boss: Control = lay.node("ID_bossIcon")
	for c in boss.get_children():
		c.queue_free()
	var card := UI.monster_card(String(q.boss), 0, 0, Vector2(92, 92))
	card.mouse_filter = MOUSE_FILTER_STOP
	card.tooltip_text = "%s  ·  Lv.%d" % [DB.monster(q.boss).name, int(q.level) + 1]
	card.gui_input.connect(func(e): if UI.tapped(e): _show_tip_popup())
	boss.add_child(card)
	var open := floor_sel <= int(Save.data.tower_floor) + 1
	lay.node("ID_btnEnter").modulate = Color.WHITE if open else Color(0.55, 0.55, 0.55)


func _show_tip_popup() -> void:
	var q := SkyTower.floor_quest(floor_sel)
	var d := Layout.load_into(self, "R_d_towerTip")
	d.root.z_index = 60
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	shade.mouse_filter = MOUSE_FILTER_STOP
	d.root.add_child(shade)
	d.root.move_child(shade, 0)
	var l := d.text("ID_LABEL_1", "\n".join(PackedStringArray(q.tips)))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	d.on("ID_btnOK", d.root.queue_free)


func _refresh_tickets() -> void:
	var n := Save.tower_tickets()
	for i in SkyTower.MAX_TICKETS:
		lay.show("ID_ticket_%02d" % (i + 1), i < n)
	var wait := Save.seconds_to_next_ticket()
	lay.text("ID_ticketTime2", "--:--" if wait <= 0 else "%d:%02d" % [wait / 60, wait % 60])
	_refresh_top()


func _buy_ticket() -> void:
	if Save.tower_tickets() >= SkyTower.MAX_TICKETS:
		UI.toast(self, "Your tickets are full")
		return
	UI.confirm(self, "Notice", "Buy 1 Sky Tower ticket for %d gems?\nFloors entered with a bought ticket have a lower Drop List." % SkyTower.TICKET_GEMS, _do_buy)


func _do_buy() -> void:
	if not SkyTower.buy_ticket():
		UI.toast(self, "Not enough gems", Color("ff8080"))
		return
	Sfx.play("buff")
	_refresh_tickets()
	_refresh_info()


func _enter() -> void:
	if floor_sel > int(Save.data.tower_floor) + 1:
		UI.toast(self, "Clear Floor %d first" % (floor_sel - 1))
		return
	if Save.team_members().is_empty():
		UI.toast(self, "Your squad is empty!")
		return
	if Save.stone_box_full():
		UI.stone_box_full(self, main.go.bind("stones", {"back": "tower"}))
		return
	var q := SkyTower.enter(floor_sel)
	if q.is_empty():
		UI.toast(self, "No tickets left — one recharges every 2 hours", Color("ff8080"))
		return
	main.go("battle", {"quest": q})
