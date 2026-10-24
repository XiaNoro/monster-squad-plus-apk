extends Screen

const SLOT_IDS := ["ID_leader", "ID_surportA", "ID_surportB", "ID_surportC"]
const ICON_IDS := ["ID_leaderIcon", "ID_surportAIcon", "ID_surportBIcon", "ID_surportCIcon"]
const SORTS := ["Level", "Grade", "Element", "Recent"]

var lay: Layout
var _selected_slot := -1
var _pick_mode := ""
var _pick_target := -1
var _food: Dictionary = {}
var _sort := 0
var _pick_bar: Control
var _feed_button: Button
var _train := false
var _sel := -1
var _selling := false
var _sell_pick: Dictionary = {}
var _cards: Dictionary = {}
var _pick_uid := -1
var _remove_box: Control

const SELL_MAX := 20
const PICK_REMOVE := -2


func build() -> void:
	UI.brown_background(self)
	_train = String(args.get("mode", "")) == "train"
	lay = Layout.load_into(self, "R_comMainPage" if _train else "R_teamEditPage")
	add_top_bar("2", "Train" if _train else "Team", String(args.get("back", "hub")))
	_back_args = args.get("back_args", {})
	lay.on("ID_btnAlign", _next_sort)
	lay.on("ID_btnAdd", _buy_slots)
	if _train:
		_setup_train()
	else:
		for i in range(1, 6):
			lay.show("ID_btn%dteam" % i, i <= Save.TEAM_PRESETS)
			lay.show("ID_teamLock%d" % i, false)
			if i <= Save.TEAM_PRESETS:
				lay.on("ID_btn%dteam" % i, _switch_team.bind(i - 1))
		for i in SLOT_IDS.size():
			var slot: Control = lay.node(SLOT_IDS[i])
			slot.mouse_filter = MOUSE_FILTER_STOP
			slot.gui_input.connect(_on_slot_input.bind(i))
	var title: Control = lay.node("ID_9PATCH_4")
	var right := lay.node("ID_btnAlign").get_global_rect().end.x - title.global_position.x
	var bw := floorf((right - title.size.x - 8.0 - 6.0) / 2.0)
	_pick_bar = Control.new()
	_pick_bar.mouse_filter = MOUSE_FILTER_IGNORE
	_feed_button = UI.button("Feed!", _do_feed, "yellow", Vector2(bw, 46) * 2.0, 34)
	var cancel := UI.button("Cancel", _cancel_pick, "blue", Vector2(bw, 46) * 2.0, 34)
	cancel.position.x = bw + 6.0
	for b in [_feed_button, cancel]:
		b.scale = Vector2(0.5, 0.5)
		_pick_bar.add_child(b)
	_pick_bar.position = Vector2(title.size.x + 8, (title.size.y - 46.0) / 2.0)
	title.add_child(_pick_bar)
	_refresh()
	if args.has("pick") and not Save.data.monsters.is_empty():
		_pick_uid = PICK_REMOVE if String(args.pick) == "remove" else int(Save.data.monsters[Save.data.monsters.size() - 1].uid)
		_refresh()
	if args.has("popup") and int(args.popup) < Save.data.team.size():
		_open_detail(int(Save.data.team[int(args.popup)]), int(args.popup))
	if args.has("action") and not Save.get_owned(int(args.get("uid", -1))).is_empty():
		var uid := int(args.uid)
		match String(args.action):
			"feed", "boost", "fusion", "awaken":
				_start_pick(String(args.action), uid)
			"stones":
				_stones_dialog(uid)
			"pet":
				_pet_dialog(uid)
			"evolve":
				_evolve(uid)
			"sell":
				_sell(uid)
	if _train and Tutorial.enabled() and Tutorial.is_done("evolve") and not Tutorial.is_done("evolve_page2"):
		_evolve_gift()
	Tutorial.maybe_start(self, "train" if _train else "squad")


func _evolve_gift() -> void:
	for id in ["ayn", "greebi"]:
		var have := false
		for m in Save.data.monsters:
			if m.id == id and not Save.in_team(int(m.uid)):
				m.level = DB.MAX_LEVEL
				m.boost = DB.MAX_BOOST
				have = true
				break
		if not have:
			var m := Save.add_monster(id, DB.MAX_LEVEL)
			m.boost = DB.MAX_BOOST
	Save.save_game()
	_refresh()


func tutorial_target(name: String) -> Control:
	match name:
		"boost":
			return lay.node("ID_btnComSt")
		"evolve":
			return lay.node("ID_btnComEv") if _train else null
		"monster:newest":
			var best := -1
			for u in _cards:
				best = maxi(best, int(u))
			return _cards.get(best)
		"monster:material":
			var pick := -1
			var low := 99
			for u in _cards:
				var m := Save.get_owned(int(u))
				if int(u) == _pick_target or Save.in_team(int(u)) or m.locked:
					continue
				if int(DB.monster(m.id).stars) < low:
					low = int(DB.monster(m.id).stars)
					pick = int(u)
			return _cards.get(pick)
		"help:remove":
			return lay.node("ID_btnAlign")
		"help:skill":
			return lay.node("ID_skill1") if lay.has("ID_skill1") else null
		"help:slot":
			return lay.node(SLOT_IDS[1]) if lay.has(SLOT_IDS[1]) else null
		"help:list":
			return lay.node("ID_ID_arrayPosition")
	if name.begins_with("slot:") and not _train:
		return lay.node(SLOT_IDS[int(name.trim_prefix("slot:"))])
	if name.begins_with("monster:"):
		var id := name.trim_prefix("monster:")
		for u in _cards:
			if Save.get_owned(int(u)).id == id and not Save.in_team(int(u)):
				return _cards[u]
	return null


func _switch_team(index: int) -> void:
	if index == int(Save.data.team_index):
		return
	Save.switch_team(index)
	_selected_slot = -1
	_pick_uid = -1
	_refresh()


func _next_sort() -> void:
	_sort = (_sort + 1) % SORTS.size()
	_refresh()


func _refresh() -> void:
	if _train:
		_refresh_train()
	else:
		var team: Array = Save.data.team
		var members := Save.team_members()
		var tabs: Array = []
		for i in Save.TEAM_PRESETS:
			tabs.append("ID_btn%dteam" % (i + 1))
		lay.select_tab(tabs, "ID_btn%dteam" % (int(Save.data.team_index) + 1))
		for i in SLOT_IDS.size():
			_fill_slot(i, Save.get_owned(int(team[i])) if i < team.size() else {})
		_fill_effects(members)
		HubScreen.show_team_type(lay, Arena.team_type(members))
		lay.set_image("ID_rankImage", Layout.texture("T_rank%s_01.png" % Arena.team_rank(members)))

	var hint := "Monster List"
	if _pick_mode == "feed":
		var xp := 0
		for u in _food:
			var fm := Save.get_owned(int(u))
			xp += DB.feed_exp(fm.id, int(fm.level))
		var gold := DB.feed_cost(Save.get_owned(_pick_target).id) * _food.size()
		hint = "Feed %d monster%s\n+%s EXP  ·  %s Gold" % [_food.size(), "" if _food.size() == 1 else "s", Screen._thousands(xp), Screen._thousands(gold)]
		if _food.is_empty():
			hint = "Select monsters\nto feed"
	elif _pick_mode != "":
		hint = {"awaken": "Pick: Awaken", "boost": "Pick: Boost", "fusion": "Pick: Fusion"}.get(_pick_mode, hint)
	elif _selected_slot >= 0:
		hint = "Pick a monster"
	var title := lay.text("ID_LABEL_3", hint)
	if not title.has_meta("home"):
		title.set_meta("home", Rect2(title.position, title.size))
	var home: Rect2 = title.get_meta("home")
	title.position = home.position
	title.size = home.size
	title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	title.add_theme_font_size_override("font_size", 30 if hint == "Monster List" else 22)
	if "\n" in hint:
		var box := (title.get_parent() as Control).size
		var font := title.get_theme_font("font")
		var lines := Array(hint.split("\n"))
		var pad := 2.0 * title.get_theme_constant("outline_size") + 4.0
		var room := Vector2(box.x - home.position.x - 10.0, box.y - 6.0)
		var fs := 19
		while fs > 11 and (lines.any(func(line): return font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + pad > room.x) \
				or (font.get_height(fs) + title.get_theme_constant("line_spacing")) * lines.size() > room.y):
			fs -= 1
		title.add_theme_font_size_override("font_size", fs)
		title.size = Vector2(room.x, 0)
		var h := title.get_minimum_size().y
		title.size = Vector2(room.x, h)
		title.position = Vector2(home.position.x, (box.y - h) / 2.0)
	_pick_bar.visible = _pick_mode != ""
	_feed_button.visible = _pick_mode == "feed"
	lay.show("ID_btnAlign", _pick_mode == "")
	lay.text("ID_LABEL_4", SORTS[_sort]).add_theme_font_size_override("font_size", 17)
	lay.text("ID_numText", str(Save.data.monsters.size()))
	lay.text("ID_maxText", "/%d" % int(Save.data.inventory_cap))

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	var owned: Array = Save.data.monsters.duplicate()
	owned.sort_custom(_compare_owned)
	_cards.clear()
	_remove_box = null
	if not _train:
		_remove_box = _remove_tile()
		grid.add_child(_remove_box)
	for m in owned:
		var uid := int(m.uid)
		var card := UI.monster_card(m.id, int(m.level), int(m.boost), Vector2(96, 96))
		_cards[uid] = card
		if m.locked:
			var chain := UI.image(Layout.texture("I_lock_05.png"), Vector2(96, 30))
			chain.size = Vector2(96, 30)
			chain.position = Vector2(0, 16)
			card.add_child(chain)
		var other := Save.preset_of(uid)
		if Save.in_active_team(uid) or other >= 0:
			var tag := UI.label("PARTY" if Save.in_active_team(uid) else "TEAM %d" % (other + 1), 15, Color("ffb21a") if Save.in_active_team(uid) else Color("9fd8ff"))
			tag.add_theme_constant_override("outline_size", 5)
			tag.add_theme_color_override("font_outline_color", Color("3a1a00"))
			tag.position = Vector2(24, 2)
			tag.mouse_filter = MOUSE_FILTER_IGNORE
			card.add_child(tag)
		if _train and (uid == _sel and not _selling or _sell_pick.has(uid)):
			card.add_child(_select_frame("Sell" if _selling else "Select"))
		if not _train and uid == _pick_uid:
			card.add_child(_select_frame("Select"))
		if uid == _pick_target:
			card.modulate = Color(1.4, 1.4, 0.7)
		elif _food.has(uid):
			card.modulate = Color(0.6, 1.4, 0.6)
		card.gui_input.connect(_on_monster_input.bind(uid))
		grid.add_child(card)
	lay.list_into("ID_ID_arrayPosition", [grid])
	if not _train:
		_show_slot_arrows()


func _show_slot_arrows() -> void:
	var team: Array = Save.data.team
	for i in SLOT_IDS.size():
		var slot: Control = lay.node(ICON_IDS[i])
		for c in slot.get_children():
			if c.has_meta("arrow"):
				c.queue_free()
		var want := false
		if _pick_uid == PICK_REMOVE:
			want = i < team.size() and team.size() > 1
		elif _pick_uid >= 0:
			want = i < Save.team_size() and i <= team.size()
		if want:
			var arrow := Tutorial.Pointer.new()
			arrow.scale_px = 1.0
			arrow.set_meta("arrow", true)
			arrow.z_index = 10
			arrow.position = Vector2(46, 34)
			slot.add_child(arrow)


func _remove_tile() -> Control:
	var box := TextureRect.new()
	box.texture = UI.tex("betaUI00/B_monEmpty_02.png")
	box.custom_minimum_size = Vector2(96, 96)
	box.size = Vector2(96, 96)
	box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	box.stretch_mode = TextureRect.STRETCH_SCALE
	box.mouse_filter = MOUSE_FILTER_STOP
	if _pick_uid == PICK_REMOVE:
		box.add_child(_select_frame("Select"))
	box.gui_input.connect(_on_remove)
	return box


func _on_remove(e: InputEvent) -> void:
	if not _pressed(e):
		return
	if _selected_slot >= 0 and _selected_slot < Save.data.team.size():
		_remove_slot(_selected_slot)
		_selected_slot = -1
		_pick_uid = -1
	else:
		_selected_slot = -1
		_pick_uid = -1 if _pick_uid == PICK_REMOVE else PICK_REMOVE
	Sfx.play("click")
	_refresh()


func _remove_slot(slot: int) -> void:
	var team: Array = Save.data.team.duplicate()
	if team.size() <= 1:
		UI.toast(self, "A team needs at least one monster", Color("ff8080"))
		return
	team.remove_at(slot)
	Save.set_team(team)
	if slot == 0:
		UI.toast(self, "%s is the new leader" % _name(int(team[0])))
	Sfx.play("click")


func _fill_slot(i: int, m: Dictionary) -> void:
	var slot: Control = lay.node(SLOT_IDS[i])
	var letter: String = ["", "A", "B", "C"][i]
	var icon_holder: Control = lay.node(ICON_IDS[i])
	for c in icon_holder.get_children():
		c.queue_free()
	_find(slot, "ID_leaderChange" if i == 0 else "ID_surport%sChange" % letter).visible = i == _selected_slot
	var locked := i >= Save.team_size()
	if i > 0:
		var lock_label := _find(slot, "ID_LABEL_lock") as Label
		lock_label.visible = m.is_empty()
		lock_label.text = ("Complete Sprout-%d" % (3 if i == 2 else 6)) if locked else ""
		lock_label.add_theme_font_size_override("font_size", 16)
		for c in lock_label.get_children():
			var n := String(c.name)
			if n.begins_with("ID_LABEL_lock"):
				c.visible = not locked
				(c as Label).text = "Add to Team"
			elif c is TextureRect:
				c.visible = locked
	var skill_ids := ["ID_leaderSkill1", "ID_leaderSkill2", "ID_leaderSkill3", "ID_leaderSkill4", "ID_leaderSkill5", "ID_leaderSkill6"] if i == 0 else ["ID_surport%sSkill1" % letter]
	for sid in skill_ids:
		for c in lay.node(sid).get_children():
			c.queue_free()
	var stat_ids := ["ID_leaderHp", "ID_leaderAp", "ID_leaderDp", "ID_leaderRe"] if i == 0 else ["ID_surport%sHp" % letter, "ID_surport%sAp" % letter]
	if m.is_empty():
		for s in stat_ids:
			lay.text(s, "-")
		if i == 0:
			lay.text("ID_LABEL_leader", "Leader")
		return
	var def := DB.monster(m.id)
	var card := UI.monster_card(m.id, int(m.level), int(m.boost), Vector2(92, 92))
	card.mouse_filter = MOUSE_FILTER_IGNORE
	icon_holder.add_child(card)
	var st := DB.stats_at(m.id, int(m.level), int(m.boost))
	var values := [st.hp, st.atk, st.def, st.rec]
	for k in stat_ids.size():
		lay.text(stat_ids[k], str(int(values[k])))
	if i == 0:
		lay.text("ID_LABEL_leader", String(def.name))
		for k in mini(4, def.skills.size()):
			_skill_icon(skill_ids[k], def.skills[k].icon, "%s (%d MP): %s" % [def.skills[k].name, int(def.skills[k].mp), def.skills[k].description])
	elif String(def.support_skill.name) != "":
		_skill_icon(skill_ids[0], def.support_skill.icon, "%s (every %ds): %s" % [def.support_skill.name, int(def.support_skill.cooldown), def.support_skill.description])


func _skill_icon(holder_id: String, icon_file: String, text: String) -> void:
	var t := DB.skill_icon(icon_file)
	if t == null:
		return
	var r := UI.image(t, Vector2(40, 40))
	r.size = Vector2(40, 40)
	r.mouse_filter = MOUSE_FILTER_STOP
	UI.tip(r, text)
	lay.node(holder_id).add_child(r)


func _fill_effects(members: Array) -> void:
	var lines := []
	for k in range(1, members.size()):
		var p := String(DB.monster(members[k].id).passive)
		if p != "":
			lines.append("- " + p)
	if Save.badge_bonus() > 0.0:
		lines.append("- Badge: team HP & ATK +%d%%" % roundi(Save.badge_bonus() * 100.0))
	if lines.is_empty():
		lines.append("- Supports' passives show here")
	var ids := ["ID_ef1Text_1", "ID_ef2Text_1", "ID_ef3Text_1", "ID_ef3Text_1_1", "ID_ef3Text_1_1_1", "ID_ef3Text_1_1_1_1"]
	for k in ids.size():
		lay.text(ids[k], lines[k] if k < lines.size() else "")


static func _find(parent: Node, prefix: String) -> Control:
	for c in parent.find_children("*", "", true, false):
		if String(c.name).begins_with(prefix):
			return c
	return null


func _name(uid: int) -> String:
	return DB.monster(Save.get_owned(uid).get("id", "")).get("name", "?")


func _corner_tag(text: String, color: Color) -> Label:
	var l := UI.label(text, 13, color)
	l.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	l.grow_horizontal = GROW_DIRECTION_BEGIN
	l.position.x -= 4
	return l


func _cancel_pick() -> void:
	_pick_mode = ""
	_pick_target = -1
	_food.clear()
	_refresh()


func _pressed(e: InputEvent) -> bool:
	return UI.tapped(e)


func _on_slot_input(e: InputEvent, slot: int) -> void:
	if _pick_mode != "":
		return
	var team: Array = Save.data.team
	var detail := func():
		if slot < team.size() and not tutorial_active():
			_open_detail(int(team[slot]), slot)
	if UI.right_pressed(e):
		detail.call()
		return
	UI.hold(e, detail)
	if not _pressed(e):
		return
	if slot >= Save.team_size():
		UI.toast(self, "Complete Sprout-%d to open this slot" % (3 if slot == 2 else 6))
		return
	if tutorial_active():
		_selected_slot = slot
		_refresh()
		tut_notify("slot:%d" % slot)
		return
	if _pick_uid == PICK_REMOVE:
		_pick_uid = -1
		if slot < team.size():
			_remove_slot(slot)
		_refresh()
		return
	if _pick_uid >= 0:
		var u := _pick_uid
		_pick_uid = -1
		_assign(u, mini(slot, team.size()))
		return
	_selected_slot = -1 if _selected_slot == slot else slot
	Sfx.play("click")
	_refresh()


func _on_monster_input(e: InputEvent, uid: int) -> void:
	var detail := func():
		if _pick_mode == "" and not tutorial_active():
			_open_detail(uid, Save.data.team.find(uid))
	if UI.right_pressed(e):
		detail.call()
		return
	UI.hold(e, detail)
	if not _pressed(e):
		return
	_tut_monster(uid)
	if _pick_mode == "feed":
		if uid == _pick_target or Save.in_team(uid) or Save.get_owned(uid).locked:
			UI.toast(self, "Can't use that monster")
		elif _food.has(uid):
			_food.erase(uid)
		else:
			_food[uid] = true
		_refresh()
		return
	if _pick_mode == "awaken":
		_confirm_awaken(_pick_target, uid)
		return
	if _pick_mode == "boost":
		_confirm_boost(_pick_target, uid)
		return
	if _pick_mode == "fusion":
		_confirm_fusion(_pick_target, uid)
		return
	if _selected_slot >= 0:
		_assign(uid, _selected_slot)
		return
	if _train:
		if _selling:
			_toggle_sell(uid)
		else:
			_sel = uid
			_refresh()
		return
	if tutorial_active() and not Save.in_team(uid) and Save.data.team.size() < Save.team_size():
		_assign(uid, Save.data.team.size())
		return
	_pick_uid = -1 if _pick_uid == uid else uid
	Sfx.play("click")
	_refresh()


func _tut_monster(uid: int) -> void:
	if not tutorial_active():
		return
	var m := Save.get_owned(uid)
	tut_notify("monster:" + String(m.id))
	var best := -1
	for u in _cards:
		best = maxi(best, int(u))
	if uid == best:
		tut_notify("monster:newest")
	if _pick_mode == "boost":
		tut_notify("monster:material")


func _setup_train() -> void:
	lay.hide_all(["ID_eventTag_St", "ID_eventTag_Ev", "ID_sell"])
	lay.on("ID_btnComSt", func():
		if int(Save.get_owned(_sel).get("boost", 0)) >= DB.MAX_BOOST:
			UI.toast(self, "Already +%d" % DB.MAX_BOOST)
			return
		_start_pick("boost", _sel))
	lay.on("ID_btnComEv", _evolve_or_fuse)
	lay.on("ID_btnComStone", func(): _stones_dialog(_sel))
	lay.on("ID_btnComTrans", func(): _start_pick("awaken", _sel))
	lay.on("ID_btnExpBoost", func(): _start_pick("feed", _sel))
	lay.on("ID_btnPet", func(): _pet_dialog(_sel))
	lay.on("ID_btn_monster_open", func(): _toggle_lock(_sel))
	lay.on("ID_btn_monster_lock", func(): _toggle_lock(_sel))
	lay.on("ID_btnSell", _set_selling.bind(true))
	lay.on("ID_btnReturn", _set_selling.bind(false))
	lay.text("ID_LABEL_1_1", "Train")
	lay.on("ID_btnSell_1", _confirm_sell)
	lay.text("ID_maxText_1", "/ %d" % SELL_MAX)
	var team: Array = Save.data.team
	_sel = int(team[0]) if not team.is_empty() else (int(Save.data.monsters[0].uid) if not Save.data.monsters.is_empty() else -1)
	if args.has("uid"):
		_sel = int(args.uid)


func _refresh_train() -> void:
	if Save.get_owned(_sel).is_empty() and not Save.data.monsters.is_empty():
		_sel = int(Save.data.monsters[0].uid)
	lay.show("ID_upgrade", not _selling)
	lay.show("ID_sell", _selling)
	lay.show("ID_btnSell", not _selling)
	lay.show("ID_btnReturn", _selling)
	if _selling:
		_refresh_sell()
		return
	if _sel < 0:
		return
	MonsterPopup.fill(lay, _sel, self)
	var m := Save.get_owned(_sel)
	var def := DB.monster(m.id)
	lay.show("ID_btn_monster_open", not m.locked)
	lay.show("ID_btn_monster_lock", bool(m.locked))
	_grey(lay.node("ID_btnComSt"), int(m.boost) >= DB.MAX_BOOST, false)


func _combine_from_popup(uid: int) -> void:
	_sel = uid
	_evolve_or_fuse()


func _need_maxed(def: Dictionary) -> void:
	var what := "Evolution" if String(def.evolves_into) != "" else "Fusion"
	UI.notice(self, what, "Only [+%d] [Lv.%d] monsters can use %s." % [DB.MAX_BOOST, DB.MAX_LEVEL, what])


func _can_combine(def: Dictionary) -> bool:
	return String(def.evolves_into) != "" or int(def.stars) < 6


func _grey(b: Control, off: bool, lock: bool) -> void:
	if b == null:
		return
	b.modulate = Color(0.5, 0.5, 0.5) if off else Color.WHITE
	var old := b.get_node_or_null("lock")
	if old != null:
		old.free()
	if off and lock:
		var ic := UI.image(Layout.texture("I_lock_03.png"), Vector2(44, 52))
		ic.name = "lock"
		ic.size = Vector2(44, 52)
		ic.position = (b.size - ic.size) * 0.5
		ic.mouse_filter = MOUSE_FILTER_IGNORE
		b.add_child(ic)


func _evolve_or_fuse() -> void:
	var m := Save.get_owned(_sel)
	var def := DB.monster(m.id)
	if not _can_combine(def):
		UI.toast(self, "This monster can't be fused any further")
		return
	var free_evolve := Save.dev("dev_free_evolve") and String(def.evolves_into) != ""
	if not Save.is_maxed(m) and not tutorial_active() and not free_evolve:
		_need_maxed(def)
		return
	if String(def.evolves_into) != "":
		main.go("combine", {"mode": "evolve", "uid": _sel})
	else:
		_start_pick("fusion", _sel)


func _select_frame(text: String) -> Control:
	var f := NinePatchRect.new()
	f.texture = Layout.texture("9_frame_03.png")
	f.patch_margin_left = 12
	f.patch_margin_right = 12
	f.patch_margin_top = 12
	f.patch_margin_bottom = 12
	f.size = Vector2(96, 96)
	f.mouse_filter = MOUSE_FILTER_IGNORE
	var l := UI.label(text, 24, Color("fff6a0"))
	l.size = Vector2(96, 96)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	f.add_child(l)
	return f


func _set_selling(on: bool) -> void:
	_selling = on
	_sell_pick.clear()
	_refresh()


func _toggle_sell(uid: int) -> void:
	var m := Save.get_owned(uid)
	if m.locked or Save.in_team(uid):
		UI.toast(self, "Locked and party monsters can't be sold")
		return
	if _sell_pick.has(uid):
		_sell_pick.erase(uid)
	elif _sell_pick.size() < SELL_MAX:
		_sell_pick[uid] = true
	_refresh()


func _refresh_sell() -> void:
	var total := 0
	var icons := GridContainer.new()
	icons.columns = 5
	for u in _sell_pick:
		var m := Save.get_owned(int(u))
		total += Save.sell_price(m)
		icons.add_child(UI.monster_card(m.id, int(m.level), int(m.boost), Vector2(76, 76)))
	lay.text("ID_numberText", "%02d" % _sell_pick.size())
	lay.text("ID_numberText_1", Screen._thousands(total))
	lay.show("ID_PushText", _sell_pick.is_empty())
	lay.text("ID_TextPush", "Pick monsters to sell")
	var holder: Control = lay.node("ID_sellect_position")
	for c in holder.get_children():
		c.queue_free()
	holder.add_child(icons)


func _confirm_sell() -> void:
	if _sell_pick.is_empty():
		UI.toast(self, "Pick monsters to sell first")
		return
	var gold := 0
	for u in _sell_pick:
		gold += Save.sell(int(u))
	Sfx.play("buff")
	UI.toast(self, "Sold %d monsters for %s gold" % [_sell_pick.size(), Screen._thousands(gold)], UI.GOLD)
	_sell_pick.clear()
	_refresh()


func _assign(uid: int, slot: int) -> void:
	var team: Array = Save.data.team.duplicate()
	var new_id: String = Save.get_owned(uid).id
	for i in team.size():
		if i != slot and int(team[i]) != uid and Save.get_owned(int(team[i])).id == new_id:
			UI.toast(self, "Each monster in your team must be unique", Color("ff8080"))
			_selected_slot = -1
			_refresh()
			return
	var existing := team.find(uid)
	if slot < team.size():
		if existing >= 0:
			team[existing] = team[slot]
		team[slot] = uid
	else:
		if existing >= 0:
			team.remove_at(existing)
		team.append(uid)
	Save.set_team(team)
	_selected_slot = -1
	_pick_uid = -1
	Sfx.play("click")
	_refresh()


func _open_detail(uid: int, team_slot: int = -1) -> void:
	var actions := {
		"feed": func(u: int): _start_pick("feed", u), "boost": func(u: int): _start_pick("boost", u),
		"fusion": _combine_from_popup, "awaken": func(u: int): _start_pick("awaken", u),
		"stones": _stones_dialog, "pet": _pet_dialog, "evolve": _evolve,
		"lock": _toggle_lock, "sell": _sell,
	}
	if team_slot >= 0:
		actions["change"] = _change_slot.bind(team_slot)
	MonsterPopup.open(self, uid, actions)


func _change_slot(_uid: int, slot: int) -> void:
	_selected_slot = slot
	_refresh()


func _train_dialog(uid: int) -> void:
	var m := Save.get_owned(uid)
	var evo := Save.can_evolve(uid)
	var lines := VBoxContainer.new()
	lines.add_child(MonsterDetail._text("Feed: use monsters as exp (gold per material).   Boost: +1 to +5 (5% stats each).", 16))
	lines.add_child(MonsterDetail._text("Fusion: two Lv30 +5 monsters of one rank → a random monster one rank higher.", 16))
	lines.add_child(MonsterDetail._text("Evolve: Lv30 +5 with its Lv30 +5 material (free).   Awaken: 6★ only, raises the level cap toward 50.", 16))
	lines.add_child(MonsterDetail._text("Level %d / %d   ·   %s" % [int(m.level), Save.max_level(m), "Evolve ready!" if evo.ok else "Evolve: " + String(evo.reason)], 16))
	UI.dialog(self, "Train %s" % _name(uid), lines, [
		{"text": "Feed", "color": "yellow", "cb": _start_pick.bind("feed", uid)},
		{"text": "Boost", "color": "blue", "cb": _start_pick.bind("boost", uid)},
		{"text": "Fusion", "color": "purple", "cb": _start_pick.bind("fusion", uid)},
		{"text": "Evolve", "color": "yellow" if evo.ok else "blue", "cb": _evolve.bind(uid)},
		{"text": "Awaken", "color": "purple", "cb": _start_pick.bind("awaken", uid)},
		{"text": "Close", "color": "blue"},
	])


func _equip_dialog(uid: int) -> void:
	var m := Save.get_owned(uid)
	var pet := Save.pet_of(m)
	var lines := VBoxContainer.new()
	lines.add_child(MonsterDetail._text("Stones equipped: %d / %d" % [Save.equipped_stones(m).size(), Save.stone_slots(m)], 18))
	if pet.is_empty():
		lines.add_child(MonsterDetail._text("Pet: none", 18))
	else:
		lines.add_child(MonsterDetail._text("Pet: %s  ·  %s" % [DB.pet(pet.id).name, _pet_text(pet)], 18))
	UI.dialog(self, "Equip %s" % _name(uid), lines, [
		{"text": "Stones", "color": "purple", "cb": _stones_dialog.bind(uid)},
		{"text": "Pet", "color": "yellow", "cb": _pet_dialog.bind(uid)},
		{"text": "Close", "color": "blue"},
	])


static func _pet_text(pet: Dictionary) -> String:
	var def := DB.pet(pet.id)
	var s: Dictionary = def.stats
	var out := "HP +%d  ATK +%d  DEF +%d  REC +%d" % [int(s.hp), int(s.atk), int(s.def), int(s.rec)]
	if int(pet.passive) >= 0 and int(pet.passive) < def.passives.size():
		var p: Dictionary = def.passives[int(pet.passive)]
		out += "  ·  %s monsters %s +%d%%" % [String(p.element).capitalize(), {"hp": "HP", "atk": "ATK", "def": "DEF", "crit": "Crit"}[p.stat], roundi(float(p.pct) * 100.0)]
	return out


func _pet_dialog(uid: int) -> void:
	var free := Save.free_pets()
	if free.is_empty():
		UI.toast(self, "No spare pets — buy a Pet Cube in Cubes")
		return
	var list := VBoxContainer.new()
	var holder: Array = [null]
	for pt in free:
		var pet_uid := int(pt.uid)
		var cost := Save.pet_equip_cost(pt)
		var row := HBoxContainer.new()
		row.add_child(UI.image(DB.pet_texture(pt.id), Vector2(64, 64)))
		var need: int = DB.PET_LEVEL.get(int(DB.pet(pt.id).stars), 30)
		row.add_child(MonsterDetail._text("%s %s (needs Lv%d)\n%s" % [DB.pet(pt.id).name, "★".repeat(int(DB.pet(pt.id).stars)), need, _pet_text(pt)], 15))
		var by_gold := func() -> void:
			holder[0].queue_free()
			_equip_pet(uid, pet_uid, false)
		var by_gems := func() -> void:
			holder[0].queue_free()
			_equip_pet(uid, pet_uid, true)
		row.add_child(UI.button("%s G" % Screen._thousands(int(cost.gold)), by_gold, "yellow", Vector2(130, 52), 16))
		row.add_child(UI.button("%d gems" % int(cost.gems), by_gems, "purple", Vector2(120, 52), 16))
		list.add_child(row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(860, 380)
	scroll.add_child(list)
	holder[0] = UI.dialog(self, "Choose a pet (the current pet is replaced and lost)", scroll, [{"text": "Cancel", "color": "blue"}])


func _equip_pet(uid: int, pet_uid: int, gems: bool) -> void:
	var r := Save.equip_pet(uid, pet_uid, gems)
	if not r.ok:
		UI.toast(self, r.reason, Color("ff8080"))
	else:
		Sfx.play("buff")
		UI.toast(self, "Pet equipped!", UI.GOLD)

func _stones_dialog(uid: int) -> void:
	main.go("stones", {"uid": uid, "back": "squad", "back_args": {"mode": "train", "uid": uid} if _train else {}})


func _stones_dialog_old(uid: int) -> void:
	var m := Save.get_owned(uid)
	var body := VBoxContainer.new()
	body.add_child(MonsterDetail._text("Equipping costs gold; filling an occupied slot destroys the old stone. Removing one costs gold and returns it to the stone box.", 16))
	var buttons := []
	for slot in MagicStones.MAX_SLOTS:
		var st := Save.stone_in_slot(m, slot)
		var n := slot + 1
		if slot >= Save.stone_slots(m):
			body.add_child(MonsterDetail._text("Slot %d: locked" % n, 18))
			buttons.append({"text": "Unlock %d (%d gems)" % [n, MagicStones.THIRD_SLOT_GEMS], "color": "purple", "cb": _unlock_slot.bind(uid)})
		elif st.is_empty():
			body.add_child(MonsterDetail._text("Slot %d: empty" % n, 18))
			buttons.append({"text": "Fill %d" % n, "color": "yellow", "cb": _pick_stone.bind(uid, slot)})
		else:
			body.add_child(MonsterDetail._text("Slot %d: %s  (%s)" % [n, MagicStones.label(st), MagicStones.describe(st)], 18))
			buttons.append({"text": "Replace %d" % n, "color": "yellow", "cb": _pick_stone.bind(uid, slot)})
			buttons.append({"text": "Remove %d" % n, "color": "orange", "cb": _unequip.bind(uid, slot)})
	buttons.append({"text": "Close", "color": "blue"})
	UI.dialog(self, "%s · Stones" % _name(uid), body, buttons)


func _pick_stone(uid: int, slot: int) -> void:
	var free := Save.free_stones()
	if free.is_empty():
		UI.toast(self, "No spare stones — clear Sky Tower floors to find some")
		return
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 360)
	var grid := GridContainer.new()
	grid.columns = 2
	scroll.add_child(grid)
	var holder: Array = [null]
	for st in free:
		var stone_uid := int(st.uid)
		var pick := func() -> void:
			if holder[0] != null:
				holder[0].queue_free()
			_equip(uid, slot, stone_uid)
		grid.add_child(StonesScreen.stone_tile(st, pick))
	holder[0] = UI.dialog(self, "Choose a stone (equip cost by rank: %s)" % "/".join(MagicStones.EQUIP_COST.map(func(c): return Screen._thousands(c))), scroll, [{"text": "Cancel", "color": "blue"}])


func _equip(uid: int, slot: int, stone_uid: int) -> void:
	var r := Save.equip_stone(uid, slot, stone_uid)
	if not r.ok:
		UI.toast(self, r.reason, Color("ff8080"))
	else:
		Sfx.play("buff")
		UI.toast(self, "Stone equipped" + (" (old stone destroyed)" if r.replaced else ""), UI.GOLD)
	_stones_dialog(uid)


func _unequip(uid: int, slot: int) -> void:
	var r := Save.unequip_stone(uid, slot)
	if not r.ok:
		UI.toast(self, r.reason, Color("ff8080"))
	_stones_dialog(uid)


func _unlock_slot(uid: int) -> void:
	if not Save.unlock_third_slot(uid):
		UI.toast(self, "Not enough gems", Color("ff8080"))
	_stones_dialog(uid)


func _start_pick(mode: String, uid: int) -> void:
	var m := Save.get_owned(uid)
	if mode == "boost" and int(m.boost) >= DB.MAX_BOOST:
		UI.toast(self, "Already +%d" % DB.MAX_BOOST)
		return
	if mode == "fusion" and not Save.is_maxed(m) and not tutorial_active():
		_need_maxed(DB.monster(m.id))
		return
	if mode in ["boost", "fusion"]:
		main.go("combine", {"mode": mode, "uid": uid})
		return
	if mode == "awaken" and int(DB.monster(m.id).stars) < 6:
		UI.toast(self, "Only 6★ monsters can awaken")
		return
	if mode == "feed" and int(m.level) >= Save.max_level(m):
		UI.toast(self, "Already at max level")
		return
	_food.clear()
	if mode == "fusion" and not Save.is_maxed(m):
		UI.toast(self, "Fusion needs Lv%d +%d" % [DB.MAX_LEVEL, DB.MAX_BOOST])
		return
	_pick_mode = mode
	_pick_target = uid
	_refresh()


func _do_feed() -> void:
	var r := Save.feed(_pick_target, _food.keys())
	if not r.ok:
		UI.toast(self, r.reason, Color("ff8080"))
		return
	UI.toast(self, "+%d exp%s" % [int(r.exp), (", +%d levels" % int(r.levels)) if int(r.levels) > 0 else ""], Color("7dff7a"))
	_food.clear()
	_cancel_pick()


func _confirm_awaken(target: int, material: int) -> void:
	var p := Save.awaken_preview(target, material)
	if not p.ok:
		UI.toast(self, p.reason, Color("ff8080"))
		return
	var cap := Save.max_level(Save.get_owned(target))
	var body := MonsterDetail._text("Use %s to awaken %s?\nLevel cap %d → %d     Cost: %s gold" % [_name(material), _name(target), cap, cap + int(p.gain), Screen._thousands(int(p.cost))], 18)
	UI.dialog(self, "Awaken", body, [
		{"text": "Awaken", "color": "purple", "cb": _do_awaken.bind(target, material)},
		{"text": "Cancel", "color": "blue"},
	])


func _do_awaken(target: int, material: int) -> void:
	var r := Save.awaken(target, material)
	if not r.ok:
		UI.toast(self, r.reason, Color("ff8080"))
	else:
		Sfx.play("buff_big")
		UI.toast(self, "Awakened! Level cap %d" % int(r.cap), UI.GOLD)
	_cancel_pick()


func _confirm_boost(target: int, material: int) -> void:
	var p := Save.boost_preview(target, material)
	if not p.ok:
		UI.toast(self, p.reason, Color("ff8080"))
		return
	var body := MonsterDetail._text("Use %s to boost %s?\nSuccess rate: %d%%     Cost: %s gold\nBoost PT are earned when a boost fails and add to the next success rate." % [_name(material), _name(target), roundi(float(p.chance) * 100.0), Screen._thousands(int(p.cost))], 18)
	UI.dialog(self, "Boost", body, [
		{"text": "Boost", "color": "yellow", "cb": _do_boost.bind(target, material)},
		{"text": "Cancel", "color": "blue"},
	])


func _do_boost(target: int, material: int) -> void:
	var r := Save.boost(target, material)
	if not r.ok:
		UI.toast(self, r.reason, Color("ff8080"))
	elif r.success:
		Sfx.play("buff_big")
		UI.toast(self, "Boost success!  +%d" % int(r.boost), Color("7dff7a"))
	else:
		UI.toast(self, "Boost failed…  Boost PT +%d%%" % int(r.boost_pt), Color("ffb080"))
	if r.ok and (int(Save.get_owned(target).get("boost", 0)) >= DB.MAX_BOOST or tutorial_active()):
		_pick_mode = ""
		_pick_target = -1
	_refresh()
	if r.ok:
		tut_notify("boosted")


func _confirm_fusion(a: int, b: int) -> void:
	var p := Save.fusion_preview(a, b)
	if not p.ok:
		UI.toast(self, p.reason, Color("ff8080"))
		return
	var body := MonsterDetail._text("Fuse %s and %s into a random %d★ monster?\nBoth will be consumed.     Cost: %s gold" % [_name(a), _name(b), int(p.stars), Screen._thousands(int(p.cost))], 18)
	UI.dialog(self, "Fusion", body, [
		{"text": "Fuse", "color": "purple", "cb": _do_fusion.bind(a, b)},
		{"text": "Cancel", "color": "blue"},
	])


func _do_fusion(a: int, b: int) -> void:
	var r := Save.fuse(a, b)
	_pick_mode = ""
	_pick_target = -1
	if not r.ok:
		UI.toast(self, r.reason, Color("ff8080"))
	else:
		Sfx.play("buff_big")
		UI.dialog(self, "Fusion result!", UI.monster_card(r.into, 1, 0, Vector2(220, 220)), [{"text": "OK", "color": "yellow"}])
	_refresh()


func _evolve(uid: int) -> void:
	var r := Save.evolve(uid)
	if not r.ok:
		UI.toast(self, r.reason, Color("ff8080"))
		return
	Sfx.play("buff_big")
	UI.toast(self, "Evolved into %s!" % DB.monster(r.into).name, UI.GOLD)
	_refresh()


func _toggle_lock(uid: int) -> void:
	var m := Save.get_owned(uid)
	m.locked = not m.locked
	Save.save_game()
	_refresh()


func _sell(uid: int) -> void:
	if Save.in_team(uid):
		UI.toast(self, "Remove it from the team first")
		return
	var price := Save.sell(uid)
	if price > 0:
		UI.toast(self, "Sold for %d gold" % price)
	else:
		UI.toast(self, "Locked monsters can't be sold")
	_refresh()


func _buy_slots() -> void:
	CubesScreen.offer_slots(self, Save.inventory_full(), _refresh)


func _compare_owned(a: Dictionary, b: Dictionary) -> bool:
	var sa: int = DB.monster(a.id).stars
	var sb: int = DB.monster(b.id).stars
	match SORTS[_sort]:
		"Level":
			if int(a.level) != int(b.level):
				return int(a.level) > int(b.level)
		"Element":
			var ea := String(DB.monster(a.id).element)
			var eb := String(DB.monster(b.id).element)
			if ea != eb:
				return ea < eb
		"Recent":
			return int(a.uid) > int(b.uid)
		"Grade":
			var g := DB.compare_grade(a, b)
			if g != 0:
				return g > 0
	if sa != sb:
		return sa > sb
	if int(a.level) != int(b.level):
		return int(a.level) > int(b.level)
	return int(a.uid) < int(b.uid)
