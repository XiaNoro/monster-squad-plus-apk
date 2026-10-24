class_name HubScreen
extends Screen

const SPOTS := ["ID_IMAGE_Leader", "ID_IMAGE_monA", "ID_IMAGE_monB", "ID_IMAGE_monC"]
const SPOT_SHIFT: Array[Vector2] = [Vector2.ZERO, Vector2(24, 0), Vector2(-70, 0), Vector2(24, 0)]
const BABY_SCALE := 0.82
const LEADER_BOX := Vector2(250, 225)
const MEMBER_BOX := Vector2(190, 170)
const MAX_GROW := Vector2(1.15, 1.2)
var lay: Layout
var nav: Layout


func build() -> void:
	Sfx.play_music("lobby")
	UI.background(self, UI.tex("res://assets/ui/lobby_bg.png"))
	lay = Layout.load_into(self, "R_main")
	nav = Layout.load_into(self, "B_navigation")
	add_top_bar("1")
	_setup_profile()
	_setup_menus()
	_setup_navigation()
	_show_team()
	_show_team_info()
	Tutorial.maybe_start(self, "hub", {"mission_ready": _missions_ready()})
	if tutorial == null and (not Tutorial.enabled() or Tutorial.is_done("intro")):
		var quest_steps := StoryQuests.steps_for_hub()
		if not quest_steps.is_empty():
			tutorial = Tutorial.play(self, quest_steps)
	if tutorial == null and (not Tutorial.enabled() or Tutorial.is_done("intro")) and Save.attendance_ready() and not "--test-nopopup" in OS.get_cmdline_user_args():
		_show_attendance()
	if args.has("options"):
		open_options()
	if args.has("events"):
		_show_event()
	if args.has("mail"):
		_show_mail()
	if args.has("popup") and int(args.popup) < Save.data.team.size():
		_open_popup(int(Save.data.team[int(args.popup)]))
		if args.has("tree"):
			(get_child(get_child_count() - 1).get_meta("popup") as MonsterPopup)._show_tree()


func _setup_profile() -> void:
	top.text("ID_LABEL_1", String(Save.data.get("name", "Tamer")))
	var holder := top.node("ID_photo")
	for c in holder.get_children():
		c.queue_free()
	var id := profile_id()
	if id != "":
		var pic := profile_pic(id, Vector2(80, 80))
		holder.add_child(pic)
	holder.mouse_filter = MOUSE_FILTER_STOP
	holder.tooltip_text = "Change profile picture"
	if not holder.has_meta("wired"):
		holder.set_meta("wired", true)
		holder.gui_input.connect(func(e: InputEvent):
			if UI.tapped(e):
				_pick_profile())


static func profile_id() -> String:
	var id := String(Save.data.get("profile_icon", ""))
	if id != "" and Save.data.owned.has(id):
		return id
	var members := Save.team_members()
	return String(members[0].id) if not members.is_empty() else ""


static func profile_pic(id: String, size: Vector2) -> Control:
	var pic := UI.image(DB.icon(id), size, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	pic.size = size
	pic.mouse_filter = MOUSE_FILTER_IGNORE
	return pic


func _pick_profile() -> void:
	var ids: Array = Save.data.owned.keys()
	ids.sort_custom(func(a, b): return DB.compare_grade({"id": a}, {"id": b}) > 0 or (DB.compare_grade({"id": a}, {"id": b}) == 0 and String(DB.monster(a).name) < String(DB.monster(b).name)))
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var current := profile_id()
	var close := {}
	for id in ids:
		var card := UI.monster_card(String(id), 0, 0, Vector2(84, 84))
		card.tooltip_text = String(DB.monster(id).name)
		if String(id) == current:
			var f := NinePatchRect.new()
			f.texture = Layout.texture("9_frame_03.png")
			f.patch_margin_left = 12
			f.patch_margin_right = 12
			f.patch_margin_top = 12
			f.patch_margin_bottom = 12
			f.size = Vector2(84, 84)
			f.mouse_filter = MOUSE_FILTER_IGNORE
			card.add_child(f)
		card.gui_input.connect(func(e: InputEvent):
			if UI.tapped(e):
				Save.data.profile_icon = String(id)
				Save.save_game()
				Sfx.play("click")
				_setup_profile()
				if close.has("root") and is_instance_valid(close.root):
					close.root.queue_free())
		grid.add_child(card)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(grid)
	close.root = UI.dialog(self, "Profile Picture", scroll, [{"text": "Close", "color": "blue"}])


func _setup_menus() -> void:
	lay.hide_all(["ID_btnPost", "ID_btnCoupon", "ID_IMAGE_14", "ID_IMAGE_13", "ID_IMAGE_10", "ID_IMAGE_16"])
	lay.on("ID_btnStory", func(): main.go("islands"))
	lay.sound(["ID_btnStory"], "begin_quest")
	lay.on("ID_btnBattle", ArenaScreen.open_select.bind(self))
	lay.on("ID_btnTower", _open_tower)
	lay.on("ID_hotTime", _show_hot_time)
	lay.on("ID_btnMission", func(): main.go("missions"))
	lay.on("ID_btnAchieve", func(): main.go("missions", {"tab": "endless"}))
	lay.on("ID_btnBeginner", func(): main.go("missions", {"tab": "weekly"}))
	lay.on("ID_btnIsland", func(): main.go("islands", {"tab": "special"}))
	lay.on("ID_btnMessage", _show_mail)
	lay.on("ID_btnDailyJem", _claim_daily_gems)

	lay.show("ID_hotTime", not Events.today().is_empty())
	lay.show("ID_IMAGE_15", Events.STORY_IDS.any(func(id): return Events.affects(id)))
	var star := lay.node("ID_IMAGE_15")
	UI.tip(star, Events.text())
	lay.show("ID_IMAGE_lock1", not TowerScreen.unlocked())
	var arena_locked := not ArenaScreen.unlocked() and not bool(Tutorial.state().get("mission_done", false))
	lay.show("ID_IMAGE_6", not arena_locked and Save.arena_tokens() >= Arena.MAX_TOKENS)
	if arena_locked:
		var lock := UI.image(Layout.texture("I_lock_03.png"))
		lock.size = lock.texture.get_size()
		lock.position = Vector2(82, 16)
		lay.node("ID_btnBattle").add_child(lock)
	var ready := _missions_ready()
	lay.show("ID_IMAGE_1", ready)
	lay.show("ID_IMAGE_11", false)
	lay.show("ID_IMAGE_12", false)
	lay.show("ID_btnDailyJem", Save.daily_bonus_ready())
	if not Tutorial.enabled() or Tutorial.is_done("intro"):
		Mail.refresh()
	lay.show("ID_IMAGE_1_1", Mail.unread() > 0)
	var mail_timer := Timer.new()
	mail_timer.wait_time = 30.0
	mail_timer.autostart = true
	mail_timer.timeout.connect(func():
		if not Tutorial.enabled() or Tutorial.is_done("intro"):
			Mail.refresh()
			lay.show("ID_IMAGE_1_1", Mail.unread() > 0))
	add_child(mail_timer)

	var open := []
	for s in DB.special_islands:
		if DB.special_open_today(s):
			open.append(String(s.name))
	_bubble("ID_questStart_1", "ID_LABEL_7_2", "Open today: " + ", ".join(open.slice(0, 2)) if not open.is_empty() else "")
	lay.node("ID_questStart_1").z_index = 5
	lay.node("ID_questStart_2").z_index = 5
	var mission := Tutorial.active_mission()
	if mission == "" and not ready:
		mission = StoryQuests.tracker_text()
	if mission == "":
		_bubble("ID_questStart_2", "ID_LABEL_7", "Mission rewards are ready!" if ready else "")
	else:
		var b: Control = lay.node("ID_questStart_2")
		b.visible = mission != _mission_shown
		_mission_shown = mission
		if not b.visible:
			return
		b.modulate.a = 1.0
		var ml := lay.text("ID_LABEL_7", mission)
		ml.autowrap_mode = TextServer.AUTOWRAP_WORD
		ml.add_theme_font_size_override("font_size", 17)
		b.mouse_filter = MOUSE_FILTER_STOP
		b.gui_input.connect(func(e: InputEvent):
			if UI.pressed(e):
				b.visible = false)
		var tw := b.create_tween()
		tw.tween_interval(6.0)
		tw.tween_property(b, "modulate:a", 0.0, 0.5)
		tw.tween_callback(func(): b.visible = false)


static var _bubbles_shown: Dictionary = {}
static var _mission_shown := ""


func _bubble(box: String, label: String, text: String) -> void:
	var show := text != "" and not Tutorial.enabled() and not _bubbles_shown.has(box)
	if show:
		_bubbles_shown[box] = true
	lay.show(box, show)
	var l := lay.text(label, text)
	if l:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.add_theme_font_size_override("font_size", 17)
	if not show:
		return
	var b: Control = lay.node(box)
	b.modulate.a = 1.0
	var tw := b.create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(b, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): b.visible = false)


func _setup_navigation() -> void:
	nav.on("ID_BUTTON_1", func(): main.go("squad"))
	nav.on("ID_BUTTON_2", func(): main.go("squad", {"mode": "train"}))
	nav.on("ID_BUTTON_6", func(): main.go("stones"))
	nav.on("ID_BUTTON_3", func(): main.go("friends"))
	nav.on("ID_BUTTON_4", func(): nav.show("ID_9PATCH_1", not nav.node("ID_9PATCH_1").visible))
	nav.on("ID_BUTTON_5", func(): main.go("cubes"))
	nav.on("ID_btnMonster", func(): main.go("book"))
	nav.on("ID_btnBadge", _show_badge)
	nav.hide_all(["ID_9PATCH_1", "ID_newMark", "ID_newMark_1", "ID_btnEvent_1"])
	nav.node("ID_9PATCH_1").z_index = 10
	nav.show("ID_btnEvent", Events.has("awaken"))
	nav.on("ID_btnEvent", func(): main.go("squad", {"mode": "train"}))


func _show_team() -> void:
	var members := Save.team_members()
	for i in front_to_back(self, lay, members.size()):
		var m: Dictionary = members[i]
		var feet := spot_feet(self, lay, i)
		var tex := DB.battle_sprite(m.id)
		var size := team_sprite_size(String(m.id), tex, i == 0)
		var sprite := UI.living(tex, size)
		sprite.position = feet - Vector2(size.x / 2.0, size.y)
		sprite.mouse_filter = MOUSE_FILTER_STOP
		sprite.gui_input.connect(_on_member_input.bind(i))
		add_child(sprite)
		move_child(sprite, lay.root.get_index() + 1)
		UI.add_shadow(self, tex, Rect2(sprite.position, size), sprite.get_index())
		var bob := sprite.create_tween().set_loops()
		bob.tween_property(sprite, "position:y", sprite.position.y - 6, 0.9 + 0.1 * i).set_trans(Tween.TRANS_SINE)
		bob.tween_property(sprite, "position:y", sprite.position.y, 0.9 + 0.1 * i).set_trans(Tween.TRANS_SINE)
		monster_tag(self, m, feet + Vector2(0, -size.y - 4), i == 0)


func tutorial_target(name: String) -> Control:
	match name:
		"begin_quest":
			return lay.node("ID_btnStory")
		"missions":
			return lay.node("ID_btnMission")
		"nav:team":
			return nav.node("ID_BUTTON_1")
		"nav:train":
			return nav.node("ID_BUTTON_2")
		"nav:friends":
			return nav.node("ID_BUTTON_3")
		"nav:store":
			return nav.node("ID_BUTTON_5")
		"arena":
			return lay.node("ID_btnBattle")
		"special_islands":
			return lay.node("ID_btnIsland")
	return null


func _on_member_input(e: InputEvent, slot: int) -> void:
	if UI.tapped(e):
		_open_popup(int(Save.data.team[slot]))


func _open_popup(uid: int) -> void:
	var actions := {"lock": _toggle_lock, "evolve": _to_squad.bind("evolve")}
	for a in ["feed", "boost", "fusion", "awaken", "stones", "pet", "sell"]:
		actions[a] = _to_squad.bind(a)
	MonsterPopup.open(self, uid, actions)


func _to_squad(uid: int, action: String) -> void:
	main.go("squad", {"action": action, "uid": uid})


func _toggle_lock(uid: int) -> void:
	var m := Save.get_owned(uid)
	m.locked = not m.locked
	Save.save_game()


static func team_sprite_size(id: String, tex: Texture2D, leader: bool) -> Vector2:
	var box := LEADER_BOX if leader else MEMBER_BOX
	var def := DB.monster(id)
	if String(def.get("evolves_from", "")) == "" and String(def.get("evolves_into", "")) not in ["", id] and int(def.get("stars", 1)) < 5:
		box *= BABY_SCALE
	if tex == null or tex.get_width() <= 0:
		return box
	var s := tex.get_size()
	return s * minf(sqrt(box.x * box.y / (s.x * s.y)), minf(box.x * MAX_GROW.x / s.x, box.y * MAX_GROW.y / s.y))


static func spot_feet(screen: Control, l: Layout, i: int, shift: Array = SPOT_SHIFT) -> Vector2:
	var spot: Control = l.node(SPOTS[i])
	return spot.global_position - screen.global_position + spot.size * Vector2(0.5, 1.0) + shift[i]


static func front_to_back(screen: Control, l: Layout, count: int, shift: Array = SPOT_SHIFT) -> Array:
	var order := range(mini(count, SPOTS.size()))
	order.sort_custom(func(a, b): return spot_feet(screen, l, a, shift).y > spot_feet(screen, l, b, shift).y)
	return order


static func monster_tag(parent: Control, m: Dictionary, at: Vector2, leader: bool) -> void:
	var def := DB.monster(m.id)
	var tag := Layout.load_into(parent, "B_monsterTag", at, 0.0)
	var stars := int(def.get("stars", 1))
	for g in 6:
		tag.show("ID_grade%d" % (g + 1), g < stars)
	tag.set_image("ID_waterIcon", Layout.texture({"fire": "A_fire_03.png", "water": "A_water_03.png", "nature": "A_natural_03.png"}.get(def.get("element", ""), "A_balance_03.png")))
	var level := _tag_text(tag.text("ID_level", "Lv.%d" % int(m.level)), 18, Color("3c1600"))
	var name_l := _tag_text(tag.text("ID_monsterName", String(def.get("name", m.id))), 18, Color("2a1a10"))
	name_l.add_theme_color_override("font_color", Color("ece6d2"))
	_tag_text(tag.text("ID_strenth", "+%d" % int(m.boost)), 20, Color("2a0c48"))
	tag.show("ID_leader", leader)
	var plus5 := int(m.boost) >= DB.MAX_BOOST
	var gold := plus5 and int(m.level) >= 50
	tag.show("ID_maxLevel", gold)
	var rank: NinePatchRect = tag.node("ID_pvpRank")
	rank.texture = null
	rank.visible = plus5 and int(m.level) >= DB.MAX_LEVEL
	if rank.visible:
		var wing := UI.image(UI.tex("res://assets/ui/wing_%s.png" % ("white" if gold else "gold")), Vector2(72, 72))
		wing.size = Vector2(72, 72)
		wing.position = Vector2(-6, -6)
		rank.add_child(wing)
	if gold:
		level.position.x += 7.0
	var level_w := level.get_theme_font("font").get_string_size(level.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	name_l.position.x = level.position.x + level_w + 10.0
	if gold:
		var bar: Control = tag.node("ID_maxLevel")
		name_l.position.x = maxf(name_l.position.x, bar.position.x + bar.size.x + 6.0)
	name_l.size.x = 220.0
	var name_w := name_l.get_theme_font("font").get_string_size(name_l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var left := (tag.node("ID_waterIcon") as Control).global_position.x
	var right := name_l.global_position.x + name_w * name_l.get_global_transform().get_scale().x
	if stars > 0:
		var g: Control = tag.node("ID_grade%d" % mini(stars, 6))
		right = maxf(right, g.global_position.x + g.size.x * g.get_global_transform().get_scale().x)
	tag.root.position.x += at.x - (left + right) / 2.0 + parent.global_position.x


static func _tag_text(l: Label, size: int, outline: Color) -> Label:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", outline)
	return l


func _show_team_info() -> void:
	var members := Save.team_members()
	show_team_type(lay, Arena.team_type(members))
	var img := UI.image(Layout.texture("T_rank%s_01.png" % Arena.team_rank(members)), Vector2(120, 60))
	img.size = Vector2(120, 60)
	lay.put("ID_rankImage", img)


static func show_team_type(l: Layout, kind: String) -> void:
	var ids := {"attack": "ID_typeAttack", "defence": "ID_typeDefence", "support": "ID_typeSupport"}
	for k in ids:
		l.show(ids[k], k == kind)


func _missions_ready() -> bool:
	for m in Missions.DAILY:
		if not Save.mission_claimed("daily", m.id) and Missions.progress("daily", m.event) >= int(m.goal):
			return true
	return false


func _show_hot_time() -> void:
	var d := Layout.load_into(self, "R_d_hotTime")
	d.root.z_index = 80
	d.node("ID_9PATCH_2").mouse_filter = MOUSE_FILTER_STOP
	d.text("ID_titleText", "Hot time Benefits")
	var rows := []
	for e in Events.today():
		var s := Layout.instance("R_hotTimeSlot")
		var name_l := s.text("ID_eventName", String(e.text))
		name_l.add_theme_color_override("font_color", UI.BROWN)
		name_l.add_theme_constant_override("outline_size", 0)
		name_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		s.show("ID_eventStat", false)
		rows.append(s.root)
	if rows.is_empty():
		var none := UI.label("No Hot Time today.", 22, UI.BROWN)
		none.add_theme_constant_override("outline_size", 0)
		rows.append(none)
	d.list_into("ID_arrayPosition", rows, 2)
	var root := d.root
	d.on("ID_btnOk", root.queue_free)
	var week := UI.button("This Week", func():
		root.queue_free()
		_show_event(), "blue", Vector2(150, 50), 18)
	var ok: Control = d.node("ID_btnOk")
	week.position = ok.position + Vector2(-164, (ok.size.y - 50) / 2.0)
	ok.get_parent().add_child(week)


func _show_event() -> void:
	var now := Events.now()
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	for d in 7:
		var list := Events.weekly_on_day(now + d * 86400)
		var day := Time.get_date_dict_from_unix_time(now + d * 86400)
		var row := HBoxContainer.new()
		var name_l := UI.label("Today" if d == 0 else DB.WEEKDAYS[int(day.weekday)], 20, Color("b8501a") if d == 0 else UI.BROWN)
		name_l.add_theme_constant_override("outline_size", 0)
		name_l.custom_minimum_size.x = 90
		row.add_child(name_l)
		var ev_l := UI.label(Events.text(list).replace("\n", ", ") if not list.is_empty() else "-", 20, UI.BROWN)
		ev_l.add_theme_constant_override("outline_size", 0)
		row.add_child(ev_l)
		body.add_child(row)
	for l in Events.limited_on_day(now):
		var months := ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
		var span := "%s %d - %s %d" % [months[int(String(l.from).substr(0, 2))], int(String(l.from).substr(3)), months[int(String(l.to).substr(0, 2))], int(String(l.to).substr(3))]
		var ll := UI.label("%s: %s" % [span, Events.text(l.events).replace("\n", ", ")], 18, Color("8a3a8a"))
		ll.add_theme_constant_override("outline_size", 0)
		body.add_child(ll)
	var note := UI.label("All events start at Midnight UTC and last ALL DAY.", 16, UI.BROWN)
	note.add_theme_constant_override("outline_size", 0)
	body.add_child(note)
	UI.dialog(self, "Weekly Events · Week %d of %d" % [Events.week_index(now) + 1, Events.week_count()], body, [{"text": "OK", "color": "yellow"}])


func _show_badge() -> void:
	var badge := String(Save.data.get("badge", ""))
	UI.toast(self, "Badge: %s" % badge.capitalize() if badge != "" else "Win a PvP League season to earn a badge")


func _claim_daily_gems() -> void:
	if Save.claim_daily_bonus():
		Sfx.play("buff_big")
		UI.toast(self, "Daily gift received!", UI.GOLD)
		lay.show("ID_btnDailyJem", false)


func _show_mail() -> void:
	MailBox.open(self, func(): lay.show("ID_IMAGE_1_1", Mail.unread() > 0))


func _show_attendance() -> void:
	MissionsScreen.show_attendance(self)


func _open_tower() -> void:
	if not TowerScreen.unlocked():
		UI.toast(self, "Beat Moonlight Desert to open the Sky Tower!")
		return
	main.go("tower")
