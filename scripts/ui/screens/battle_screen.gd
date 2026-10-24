extends Screen

const ALLY_SPOTS := [Vector2(450, 320), Vector2(290, 205), Vector2(160, 330), Vector2(290, 445)]
const ALLY_SPOTS_5 := [Vector2(460, 320), Vector2(305, 195), Vector2(165, 270), Vector2(165, 400), Vector2(305, 455)]
const ENEMY_LAYOUTS := [
	[Vector2(782, 293)],
	[Vector2(799, 209), Vector2(897, 395)],
	[Vector2(782, 293), Vector2(942, 182), Vector2(942, 413)],
	[Vector2(782, 293), Vector2(915, 178), Vector2(1048, 293), Vector2(915, 417)],
	[Vector2(782, 306), Vector2(888, 182), Vector2(1039, 244), Vector2(1039, 400), Vector2(888, 457)],
	[Vector2(755, 240), Vector2(755, 391), Vector2(888, 164), Vector2(888, 315), Vector2(888, 466), Vector2(1030, 240), Vector2(1030, 391)],
]
const ENEMY_SPOTS_4 := [Vector2(782, 293), Vector2(915, 178), Vector2(1048, 293), Vector2(915, 417)]
const BOSS_SPOT := Vector2(773, 298)
const BOSS_MINION_LAYOUTS := [
	[Vector2(986, 293)],
	[Vector2(942, 169), Vector2(942, 435)],
	[Vector2(924, 164), Vector2(924, 440), Vector2(1057, 302)],
	[Vector2(906, 164), Vector2(1048, 240), Vector2(1048, 395), Vector2(906, 453)],
	[Vector2(888, 151), Vector2(888, 457), Vector2(986, 266), Vector2(986, 391), Vector2(1075, 169), Vector2(1075, 320), Vector2(1075, 471)],
]
const INTRO_WALK := 1.3
const WAVE_WALK := 0.6
const BOX_GROUND_TIME := 1.2
const SPEEDS := [1.0, 1.5]
const CONTINUE_GEMS := 10
const MAX_STEP := 0.05

var engine: BattleEngine
var island: Dictionary
var difficulty := "normal"
var stage_index := 0
var quest: Dictionary = {}
var team_owned: Array = []
var views: Dictionary = {}
var field: Control
var rng := RandomNumberGenerator.new()

var _mp_bar: Range
var _mp_label: Label
var _skill_buttons: Array[BaseButton] = []
var _wave_label: Label
var _time_label: Label
var _banner: Label
var hud: Layout
var _skill_back: Control
var _speed_index := 0
var _paused := false
var _finished := false
var _last_hit_sound := 0.0
var _gold_label: Label
var _rewards: Dictionary = {}
var _gold_collected := 0
var _gold_per_kill := 0
var _enemies_left := 0
var _fever_bar: Range
var _fever_label: Label
var _fever_button: BaseButton
var _tower_stones: Array = []
var _box_at: Dictionary = {}
var _kill_count := 0
var _box_row: HBoxContainer
var _drop_quest: Dictionary = {}
var _drop_state: Dictionary = {}
var _first_clear := false
var _live_drops: Array = []
var _friend: Dictionary = {}
var _tut_paused := false
var _ready_badges: Dictionary = {}
var _hints: Array = []
var _boss_spoken := false
var _victory_pending := false
var _last_kill := Vector2(-1, -1)
var _bg_strip: Control
var _bg_tex: Texture2D
var _bg_x := 0.0
var _ground_boxes: Array = []
var _boxes_in_air := 0
var _cleared := false


func build() -> void:
	island = DB.island(args.get("island", DB.islands[0].id))
	difficulty = args.get("difficulty", "normal")
	stage_index = int(args.get("stage", 0))
	quest = args.get("quest", {})
	if quest.is_empty():
		quest = StageBuilder.story_quest(island, difficulty, stage_index)
	rng.randomize()
	Sfx.play_music(Sfx.battle_music(quest, String(island.id), false))
	if quest.kind == "tower":
		_bg_tex = load("res://assets/battle_bg/sky_tower.png")
		UI.background(self, _bg_tex)
	else:
		var bg_id := String(island.id) if quest.kind == "story" else String(quest.get("bg", ""))
		if bg_id == "":
			bg_id = String(quest.get("special_id", ""))
		if quest.kind == "raid":
			bg_id = String(quest.get("raid_id", ""))
			if bg_id == "mansion_of_madness":
				bg_id = "mansion_hall" if int(quest.get("room", 0)) >= 8 else "mansion_garden"
			elif bg_id == "pharaohs_curse":
				bg_id = ["pharaoh_ruins", "pharaoh_wall", "pharaoh_desert"][clampi(int(quest.get("room", 0)) / 4, 0, 2)]
		if quest.kind == "story" and StageBuilder.stage_backdrop(bg_id, stage_index) != "":
			bg_id = StageBuilder.stage_backdrop(bg_id, stage_index)
		var bg_path := "res://assets/battle_bg/%s.png" % bg_id
		var flip_path := bg_path.trim_suffix(".png") + "_flip.png"
		_bg_tex = load(bg_path) if ResourceLoader.exists(bg_path) else UI.tex("res://assets/apk/images/Forest_1.png")
		_scroll_backdrop(_bg_tex, load(flip_path) if ResourceLoader.exists(flip_path) else null)

	field = Control.new()
	field.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	field.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(field)

	var is_raid: bool = quest.kind == "raid"
	team_owned = Save.team_members()
	if quest.kind == "league":
		team_owned = LeagueScreen._owned(Save.league().team)
	if is_raid:
		team_owned = []
		for uid in args.get("party", []):
			team_owned.append(Save.get_owned(int(uid)))
	var team := []
	for m in team_owned:
		var spec := {"id": m.id, "level": int(m.level), "boost": int(m.boost), "stones": Save.stone_bonuses(m), "pet": Save.pet_spec(m)}
		if is_raid:
			spec["hp_ratio"] = Save.raid_hp(int(m.uid))
		team.append(spec)
	_friend = args.get("friend", {})
	if not _friend.is_empty() and quest.kind in ["story", "special"]:
		team.append(Friends.battle_spec(_friend))

	engine = BattleEngine.new()
	engine.auto_skills = bool(Save.data.get("auto", false))
	engine.manual_supports = quest.kind != "league"
	if not OS.has_feature("mobile"):
		engine.endless = bool(Save.data.get("dev_endless", false))
		engine.immortal_enemies = bool(Save.data.get("dev_immortal_enemies", false))
		engine.infinite_mp = bool(Save.data.get("dev_infinite_mp", false))
	_speed_index = clampi(int(Save.data.get("speed", 0)), 0, SPEEDS.size() - 1)
	engine.battle_event.connect(_on_event)
	engine.fever_enabled = bool(quest.get("fever", false))
	engine.pvp = bool(quest.get("pvp", false))
	engine.wave_heal = float(quest.get("wave_heal", BattleEngine.WAVE_HEAL))
	if float(quest.get("time_limit", 0.0)) > 0.0:
		engine.time_limit = float(quest.time_limit)
	engine.room_limit = float(quest.get("room_limit", 0.0))
	engine.final_room_limit = float(quest.get("final_room_limit", 0.0))
	if quest.kind == "tower":
		engine.fever = SkyTower.fever()
	_build_hud()
	var waves := StageBuilder.waves_for(quest, rng)
	_rewards = StageBuilder.base_rewards(quest, rng)
	for w in waves:
		_enemies_left += w.size()
	_gold_per_kill = int(_rewards.gold) / maxi(1, _enemies_left)
	if quest.kind == "tower":
		_tower_stones = SkyTower.roll_stones(int(quest.floor), rng, bool(quest.get("bought", false)))
		var order := range(1, _enemies_left + 1)
		order.shuffle()
		for k in _tower_stones.size():
			_box_at[int(order[k])] = k
	elif bool(quest.get("drops", false)):
		_drop_quest = quest
		_first_clear = (quest.kind == "story" and stage_index >= Save.cleared_stages(island.id, difficulty)) or (quest.kind == "special" and not Save.data.special_clears.has(quest.key))
		if Tutorial.enabled() and quest.kind == "story" and island.id == "sprout_island" and _first_clear:
			_drop_quest = quest.duplicate()
			_drop_quest.first_clear_drop = true
		_drop_state = StageBuilder.drop_state(_drop_quest)
	if quest.kind == "league":
		engine.setup_league(quest.league_team, quest.league_enemy)
	else:
		engine.setup(team, waves)
	var spots: Array = ALLY_SPOTS_5 if engine.allies.size() > 4 else ALLY_SPOTS
	for u in engine.allies:
		_add_view(u, spots[u.slot], Vector2(165, 145) if u.is_leader else Vector2(125, 110))
	_refresh_hud()
	_show_loading()


func _process(delta: float) -> void:
	if _finished or _paused or _tut_paused:
		return
	var remaining: float = delta * SPEEDS[_speed_index]
	while remaining > 0.0 and engine.result == "":
		var dt := minf(MAX_STEP, remaining)
		engine.step(dt)
		remaining -= dt
		if engine.time > 0.5 and "--test-instawin" in OS.get_cmdline_user_args():
			for u in engine.enemies:
				u.hp = 0.0
		if engine.time > 1.5 and not _tut_fired.has("enemies_near"):
			_tut_fired["enemies_near"] = true
			tut_notify("enemies_near")
	engine.tick_fever(delta)
	for u in views:
		views[u].refresh()
	_refresh_hud()
	_refresh_ready_badges()


var _tut_fired: Dictionary = {}


func set_tutorial_pause(on: bool) -> void:
	_tut_paused = on


func tutorial_event_started(name: String) -> void:
	if name == "support_ready":
		for u in engine.allies:
			if not u.is_leader and u.alive() and not u.support.is_empty():
				u.support_timer = 0.01
				return


func _refresh_ready_badges() -> void:
	for u in engine.allies:
		var v: BattleUnitView = views.get(u)
		if v == null:
			continue
		var ready := engine.support_ready(u)
		v.set_charge(_charge(u, ready))
		var badge: TextureRect = _ready_badges.get(u)
		if ready and badge == null:
			var sup: Dictionary = u.support
			var t := DB.skill_icon(String(DB.monster(u.monster_id).get("support_skill", {}).get("icon", "")))
			badge = UI.image(t if t != null else UI.tex("betaHud00/IconLeader.png"), Vector2(40, 40))
			badge.size = Vector2(40, 40)
			badge.position = Vector2(-22, v.size.y * 0.25)
			badge.pivot_offset = Vector2(20, 20)
			v.add_child(badge)
			var tw := badge.create_tween().set_loops()
			tw.tween_property(badge, "scale", Vector2(1.15, 1.15), 0.35)
			tw.tween_property(badge, "scale", Vector2.ONE, 0.35)
			_ready_badges[u] = badge
		elif not ready and badge != null:
			badge.queue_free()
			_ready_badges.erase(u)
	_refresh_hints()


func _charge(u: BattleUnit, ready: bool) -> float:
	if u.is_leader:
		if engine.fever_active:
			return 1.0
		var cheapest := INF
		for s in u.skills:
			cheapest = minf(cheapest, float(s.mp))
		return clampf(engine.mp / cheapest, 0.0, 1.0) if cheapest < INF and cheapest > 0.0 else 0.0
	if ready:
		return 1.0
	var full := float(u.support.get("cooldown", 12.0)) * u.cooldown_mult
	return clampf(1.0 - u.support_timer / full, 0.0, 0.99) if full > 0.0 else 0.0


func _refresh_hints() -> void:
	var want := []
	var learning: bool = Tutorial.enabled() and quest.kind == "story" and String(island.get("id", "")) == "sprout_island" and not tutorial_active()
	if learning and not engine.auto_skills:
		for i in _skill_buttons.size():
			if not _skill_buttons[i].disabled:
				want.append(_skill_buttons[i].get_global_rect())
				break
		for u in _ready_badges:
			want.append((views[u] as Control).get_global_rect())
	while _hints.size() > want.size():
		_hints.pop_back().queue_free()
	while _hints.size() < want.size():
		var p := Tutorial.Pointer.new()
		p.z_index = 30
		add_child(p)
		_hints.append(p)
	for k in want.size():
		var r: Rect2 = want[k]
		_hints[k].position = Vector2(r.get_center().x, r.position.y) - global_position


func _show_loading() -> void:
	_paused = true
	var pvp: bool = quest.kind in ["arena", "duel"]
	var kind := "pvp" if pvp else "battle"
	if quest.kind == "special" and DB.special(String(quest.special_id)).has("promo"):
		kind = "island:" + String(quest.special_id)
	var overlay := LoadingScreen.make(self, kind)
	await get_tree().create_timer(LoadingScreen._wait(LoadingScreen.SECONDS if pvp else 1.8)).timeout
	overlay.fade()
	await overlay.done
	_paused = false
	_intro()
	_start_tutorial()


func _pve() -> bool:
	return not quest.kind in ["arena", "duel", "league"]


func _intro() -> void:
	if not _pve():
		return
	var t := INTRO_WALK / float(SPEEDS[_speed_index])
	engine.hold = INTRO_WALK
	_march(t)
	for u in views:
		if u.side == BattleUnit.ENEMY:
			views[u].enter_from(Vector2(_walk_offset(), 0), t)
	_alert_enemies(t)


func _walk_offset() -> float:
	return get_viewport_rect().size.x * 0.45


func _alert_enemies(after: float) -> void:
	for u in views:
		if u.side == BattleUnit.ENEMY:
			views[u].alert(after + randf_range(0.0, 0.45))


func _win_leader(parent: Control) -> void:
	if team_owned.is_empty():
		return
	await get_tree().process_frame
	if not is_instance_valid(parent):
		return
	for v in views.values():
		(v as Control).visible = false
	var tex := DB.battle_sprite(String(team_owned[0].id))
	var left := get_viewport_rect().size.x * 0.5 - 272.0
	var box := Vector2(minf(260.0, left - 20.0), 250)
	var drawn := tex.get_size() * minf(box.x / tex.get_width(), box.y / tex.get_height()) if tex.get_width() > 0 else box
	var vs := get_viewport_rect().size
	var pic := UI.image(tex, drawn)
	pic.size = drawn
	pic.position = Vector2(left * 0.5 - drawn.x * 0.5, vs.y * 0.66 - drawn.y)
	pic.pivot_offset = Vector2(drawn.x * 0.5, drawn.y)
	pic.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(pic)
	UI.add_shadow(parent, tex, Rect2(pic.position, drawn), pic.get_index())
	var tw := pic.create_tween().set_loops()
	tw.tween_property(pic, "position:y", pic.position.y - 26, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(pic, "position:y", pic.position.y, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.9)


func _leave_win(cb: Callable) -> Callable:
	return func():
		LoadingScreen.cover(main, cb)


func _start_tutorial() -> void:
	if quest.kind == "story":
		Tutorial.maybe_start(self, "battle", {"island": island.id, "difficulty": difficulty, "stage": stage_index})


func _build_hud() -> void:
	hud = Layout.load_into(self, "battleBeta")
	hud.root.z_index = 10
	hud.hide_all(["ID_4P", "ID_5P", "ID_profile_1", "ID_profile_2", "ID_vsMark", "ID_pvpMonster", "ID_pvpSpeed",
		"ID_LABEL_SKILL_ERROR", "ID_IMAGE_frame_pvp", "ID_BUTTON_AUTO_r_off", "ID_BUTTON_AUTO_r_on", "ID_BUTTON_speed1.4"])
	hud.on("ID_BUTTON_PAUSE", _pause)
	hud.on("ID_BUTTON_AUTO", _toggle_auto)
	hud.on("ID_BUTTON_STOP", _toggle_auto)
	hud.on("ID_BUTTON_speed1.0", _toggle_speed)
	hud.on("ID_BUTTON_speed1.5", _toggle_speed)
	_time_label = hud.text("ID_LABEL_TIME", "00 : 00")
	_wave_label = hud.text("ID_LABEL_STAGE", "")
	_gold_label = hud.text("ID_LABEL_1", "0")
	var gold_back := _gold_label.get_parent() as Control
	var coin_right: float = (hud.node("ID_IMAGE_1") as Control).position.x + (hud.node("ID_IMAGE_1") as Control).size.x
	_gold_label.position = Vector2(coin_right, 0)
	_gold_label.size = Vector2(gold_back.size.x - coin_right - 6, gold_back.size.y)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gold_label.add_theme_font_size_override("font_size", 22)
	_gold_label.add_theme_color_override("font_color", Color("ffe23a"))
	_gold_label.add_theme_color_override("font_outline_color", Color(0.18, 0.09, 0.0))
	_gold_label.add_theme_constant_override("outline_size", 6)
	_banner = hud.text("ID_LABEL_SKILL", "")
	_banner.add_theme_color_override("font_color", Color("59f0ff"))
	_skill_back = hud.node("ID_9PATCH_SKILL_BACK")
	_skill_back.modulate.a = 0.0
	_mp_bar = hud.node("ID_PROGRESSBAR_MP") as Range
	_mp_label = hud.text("ID_LABEL_MP", "")
	_mp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var vw := get_viewport_rect().size
	var bottom := vw.y
	var league: bool = quest.kind == "league"
	hud.show("ID_IMAGE_MP_BASE", not league)
	if not league and not team_owned.is_empty():
		var pc := UI.monster_card(team_owned[0].id, 0, 0, Vector2(84, 84))
		pc.mouse_filter = MOUSE_FILTER_IGNORE
		pc.position = Vector2(4, bottom - 88)
		hud.root.add_child(pc)
	var lead_skills: Array = DB.monster(team_owned[0].id).skills if not team_owned.is_empty() and not league else []
	var n := mini(lead_skills.size(), 4)
	for i in n:
		var s: Dictionary = lead_skills[i]
		var b := TextureButton.new()
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.size = Vector2(96, 96)
		b.position = Vector2(Layout.DESIGN_W - (n - i) * 100.0 - 6.0, bottom - 100)
		var icon := UI.image(_skill_face(DB.skill_icon(String(s.icon))), Vector2(86, 86))
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.size = Vector2(86, 86)
		icon.position = Vector2(5, 5)
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		icon.material = _round_mat()
		b.add_child(icon)
		var frame := UI.image(UI.tex("betaHud00/SkillFrame.png"), Vector2(96, 96))
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.size = Vector2(96, 96)
		frame.mouse_filter = MOUSE_FILTER_IGNORE
		frame.material = _frame_mat()
		b.add_child(frame)
		var mp := UI.label(str(int(s.mp)), 26, Color("aef5c8"))
		mp.add_theme_color_override("font_outline_color", Color.BLACK)
		mp.add_theme_constant_override("outline_size", 6)
		mp.position = Vector2(8, 58)
		b.add_child(mp)
		var desc := "%s: %s" % [s.name, s.description]
		b.tooltip_text = desc
		b.gui_input.connect(func(e: InputEvent): UI.hold(e, func(): UI.toast(self, desc)))
		b.pressed.connect(func():
			if UI.was_held():
				return
			Sfx.play("click")
			_cast(i))
		hud.root.add_child(b)
		_skill_buttons.append(b)
	if bool(quest.get("fever", false)):
		var ul := Layout.load_into(self, "battleUnlimited")
		var base: Control = ul.node("ID_IMAGE_FEVER_BASE")
		base.reparent(hud.root, true)
		_fever_bar = ul.node("ID_PROGRESSBAR_FEVER") as Range
		_fever_bar.max_value = BattleEngine.FEVER_MAX
		_fever_label = ul.node("ID_LABEL_FEVER") as Label
		_fever_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_fever_button = ul.node("ID_BUTTON_FEVER") as BaseButton
		_fever_button.reparent(hud.root, true)
		_fever_button.position = Vector2(4, bottom - 88)
		_fever_button.scale = Vector2(84, 84) / _fever_button.size
		_fever_button.pressed.connect(_fever)
		ul.root.queue_free()
	if quest.kind == "tower":
		var clock: TextureRect = hud.node("ID_IMAGE_2") as TextureRect
		if clock:
			clock.texture = UI.tex("betaHud00/H_skull_01.png")
	if quest.kind == "tower" or bool(quest.get("drops", false)):
		_box_row = HBoxContainer.new()
		_box_row.add_theme_constant_override("separation", -10)
		var tb: Control = hud.node("ID_9PATCH_TIME_BACK")
		_box_row.position = Vector2(tb.size.x + 6, -4)
		tb.add_child(_box_row)
	if quest.kind in ["arena", "duel"]:
		_arena_hud()
	elif quest.kind != "story":
		var title := UI.label(String(quest.title).split("  ·  ")[0] if quest.kind == "raid" else String(quest.title), 18, UI.GOLD)
		title.add_theme_constant_override("outline_size", 5)
		title.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.0))
		title.position = Vector2(14, 80)
		hud.root.add_child(title)

static var _round_shader: Shader
static var _frame_shader: Shader


static func _skill_face(t: Texture2D) -> Texture2D:
	if t == null:
		return null
	var img := t.get_image()
	if img.is_compressed():
		img.decompress()
	var r := img.get_used_rect()
	return ImageTexture.create_from_image(img.get_region(r.grow(-roundi(r.size.x * 0.065))))


static func _round_mat() -> ShaderMaterial:
	if _round_shader == null:
		_round_shader = Shader.new()
		_round_shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec2 q = abs(UV - 0.5) - 0.5 + 0.16;\n\tfloat d = length(max(q, 0.0)) - 0.16;\n\tCOLOR = texture(TEXTURE, UV);\n\tCOLOR.a *= 1.0 - smoothstep(-0.012, 0.0, d);\n}"
	var m := ShaderMaterial.new()
	m.shader = _round_shader
	return m


static func _frame_mat() -> ShaderMaterial:
	if _frame_shader == null:
		_frame_shader = Shader.new()
		_frame_shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tCOLOR = texture(TEXTURE, UV);\n\tCOLOR.a *= 1.0 - smoothstep(0.35, 0.75, dot(COLOR.rgb, vec3(0.333)));\n}"
	var m := ShaderMaterial.new()
	m.shader = _frame_shader
	return m


func _arena_hud() -> void:
	hud.hide_all(["ID_9PATCH_STAGE_BACK", "ID_9PATCH_GOLD_BACK", "ID_pvpMonNum", "ID_pvpMonNum_2", "ID_BUTTON_speed1.0", "ID_BUTTON_speed1.5"])
	hud.show("ID_profile_1")
	hud.show("ID_profile_2")
	hud.show("ID_vsMark")
	hud.text("ID_txtUserName", String(Save.data.get("name", "Tamer"))).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.text("ID_txtUserName_2", String(quest.get("rival_name", "Rival"))).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud.put("ID_photo", HubScreen.profile_pic(HubScreen.profile_id(), Vector2(72, 72)))
	var rival: Array = quest.fixed_waves[0] if quest.has("fixed_waves") else []
	if not rival.is_empty():
		hud.put("ID_photo_2", HubScreen.profile_pic(String(rival[0].id), Vector2(72, 72)))


func _skill_color(s: Dictionary) -> String:
	for e in s.effects:
		match String(e.type):
			"heal", "cleanse":
				return "yellow"
			"buff", "shield", "reflect", "provoke", "immune":
				return "blue"
			"debuff", "stun", "silence", "dot", "dispel":
				return "purple"
	return "orange"


func _refresh_hud() -> void:
	_mp_bar.max_value = engine.max_mp
	_mp_bar.value = engine.mp
	_mp_label.text = "%d/%d" % [int(engine.mp), int(engine.max_mp)]
	var lead := engine.leader()
	for i in (0 if engine.league else _skill_buttons.size()):
		var s: Dictionary = lead.skills[i]
		var off: bool = (engine.mp < float(s.mp) and not engine.fever_active) or not lead.can_cast()
		_skill_buttons[i].disabled = off
		_skill_buttons[i].modulate = Color(0.45, 0.45, 0.45) if off else Color.WHITE
	if engine.league:
		_wave_label.text = "%d/%d  vs  %d/%d" % [engine.remaining(BattleUnit.PLAYER), engine.ally_total, engine.remaining(BattleUnit.ENEMY), engine.enemy_total]
	elif quest.kind == "raid":
		_wave_label.text = "Stage %d/%d" % [int(quest.room) + 1, Raids.ROOMS]
	elif engine.endless:
		_wave_label.text = "Endless · Stage %d" % (engine.wave_index + 1)
	else:
		_wave_label.text = "Stage %d/%d" % [engine.wave_index + 1, engine.waves.size()]
	var secs := int(engine.time)
	if engine.room_limit_now() > 0.0:
		secs = maxi(0, ceili(engine.room_limit_now() - engine.room_time))
		_time_label.add_theme_color_override("font_color", Color("ff7060") if secs <= 20 else Color.WHITE)
	elif engine.time_limit < BattleEngine.TIME_LIMIT:
		secs = maxi(0, int(engine.time_limit - engine.time))
		_time_label.add_theme_color_override("font_color", Color("ff7060") if secs <= 20 else Color.WHITE)
	_time_label.text = "%02d : %02d" % [secs / 60, secs % 60]
	if _fever_bar != null:
		var shown := engine.fever_left / BattleEngine.FEVER_SECONDS * BattleEngine.FEVER_MAX if engine.fever_active else engine.fever
		_fever_bar.value = shown
		_fever_label.text = "FEVER!" if engine.fever_active else "%d/%d" % [int(engine.fever), int(BattleEngine.FEVER_MAX)]
		_fever_button.visible = engine.fever >= BattleEngine.FEVER_MAX and not engine.fever_active and engine.result == ""
	hud.show("ID_BUTTON_AUTO", not engine.auto_skills)
	hud.show("ID_BUTTON_STOP", engine.auto_skills)
	hud.show("ID_BUTTON_speed1.0", _speed_index == 0 and not quest.kind in ["arena", "duel"])
	hud.show("ID_BUTTON_speed1.5", _speed_index == 1 and not quest.kind in ["arena", "duel"])

func _cast(i: int) -> void:
	if not engine.cast_leader_skill(i):
		UI.toast(self, "Not enough MP", Color("9fd0ff"))
		return
	tut_notify("skill:any")
	tut_notify("skill_used")


func tutorial_target(name: String) -> Control:
	match name:
		"skill:any":
			engine.mp = engine.max_mp
			_refresh_hud()
			return _skill_buttons[0] if not _skill_buttons.is_empty() else null
		"support:any":
			for u in engine.allies:
				if not u.is_leader and u.alive() and not u.support.is_empty():
					u.support_timer = 0.0
					_refresh_ready_badges()
					return views.get(u)
	return null


func _toggle_auto() -> void:
	engine.auto_skills = not engine.auto_skills
	Save.data.auto = engine.auto_skills


func _toggle_speed() -> void:
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	Save.data.speed = _speed_index


func _pause() -> void:
	if _finished or _paused:
		return
	_paused = true
	var d := Layout.load_into(self, "R_d_pause")
	d.root.z_index = 80
	var groups := ["ID_gamePause", "ID_gamePause_1", "ID_gamePause_pvp", "ID_gamePause_pvp2", "ID_gamePause_tower", "ID_gamePause_tower2"]
	var resume := func():
		_paused = false
		d.root.queue_free()
	var which := "ID_gamePause_1"
	match String(quest.kind):
		"tower":
			which = "ID_gamePause_tower"
		"arena", "league":
			which = "ID_gamePause_pvp"
		"duel":
			which = "ID_gamePause_pvp2"
	for g in groups:
		d.show(g, g == which)
	d.show("ID_maskTip3_1", false)
	match which:
		"ID_gamePause_tower":
			d.text("ID_LABEL_stage", "Floor %d" % int(quest.floor))
			d.on("ID_btnGiveUp_2_1", _retreat)
			d.on("ID_btnContinue_2_1", resume)
		"ID_gamePause_pvp":
			d.on("ID_btnGiveUp_1", func(): UI.confirm(self, "Notice", "Leaving now will be considered forfeit, and you will lose Victory Points.", _retreat))
			d.on("ID_btnContinue_1", resume)
		"ID_gamePause_pvp2":
			d.on("ID_btnGiveUp_2", _retreat)
			d.on("ID_btnContinue_2", resume)
		_:
			d.text("ID_LABEL_1_1", _pause_title())
			d.text("ID_LABEL_1_1_1", _pause_title())
			d.text("ID_numGold", Screen._thousands(_gold_collected))
			d.text("ID_numCube", str(_cubes_so_far()))
			UI.fit_text(d.node("ID_LABEL_2_1") as Label, 26, 16)
			d.on("ID_btnContinue", resume)
			d.on("ID_btnGiveUp", func():
				d.show("ID_gamePause_1", false)
				d.show("ID_gamePause", true))
			d.on("ID_btnCancel", func():
				d.show("ID_gamePause", false)
				d.show("ID_gamePause_1", true))
			d.on("ID_btnOk", _retreat)


func _cubes_so_far() -> int:
	if not _drop_state.is_empty():
		return _live_drops.size()
	return roundi(float(engine.kills.size()) * StageBuilder.DROP_CHANCE)


func _pause_title() -> String:
	if quest.kind == "story":
		return String(island.difficulties[difficulty].stages[stage_index].name)
	if quest.kind == "raid":
		return "%s %d" % [Raids.raid(quest.raid_id).name, int(quest.room) + 1]
	return String(quest.get("title", "")).split("  ·  ")[0]

func _fever() -> void:
	engine.activate_fever()


func _drop_box(v: BattleUnitView, tex: Texture2D) -> void:
	if _box_row == null:
		return
	_boxes_in_air += 1
	var box := UI.image(tex, Vector2(64, 64))
	box.size = Vector2(64, 64)
	box.z_index = 20
	add_child(box)
	box.pivot_offset = Vector2(32, 32)
	var start: Vector2 = (v.global_position + v.size * 0.5 - Vector2(32, 32)) if v != null else get_viewport_rect().size * 0.5
	var ground := start.y + 30.0
	var drift := randf_range(-50.0, 50.0)
	box.global_position = start
	box.scale = Vector2(0.2, 0.2)
	var tw := box.create_tween()
	tw.tween_property(box, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(box, "global_position:y", start.y - 70.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(box, "global_position:x", start.x + drift * 0.45, 0.22)
	tw.parallel().tween_property(box, "rotation", deg_to_rad(drift * 0.4), 0.22)
	tw.tween_property(box, "global_position:y", ground, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(box, "global_position:x", start.x + drift, 0.28)
	tw.parallel().tween_property(box, "rotation", 0.0, 0.28)
	tw.parallel().tween_property(box, "scale", Vector2.ONE, 0.28)
	tw.tween_property(box, "scale", Vector2(1.25, 0.75), 0.06)
	tw.tween_property(box, "global_position:y", ground - 22.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(box, "scale", Vector2(0.9, 1.1), 0.14)
	tw.tween_property(box, "global_position:y", ground, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(box, "scale", Vector2.ONE, 0.12)
	tw.tween_callback(Sfx.play.bind("cube_get"))
	for a in [8.0, -8.0, 5.0, 0.0]:
		tw.tween_property(box, "rotation", deg_to_rad(a), 0.06)
	tw.parallel().tween_property(box, "modulate", Color(1.8, 1.8, 1.8), 0.12)
	tw.tween_property(box, "modulate", Color.WHITE, 0.15)
	tw.tween_callback(func():
		_boxes_in_air -= 1
		var entry := [box, tex]
		_ground_boxes.append(entry)
		if _cleared:
			_collect_boxes(0.35)
		else:
			_collect_boxes(BOX_GROUND_TIME, [entry]))


func _collect_boxes(delay: float = 0.6, only: Array = []) -> void:
	var boxes := _ground_boxes.duplicate() if only.is_empty() else only.filter(func(b): return b in _ground_boxes)
	for b in boxes:
		_ground_boxes.erase(b)
	for k in boxes.size():
		var box: TextureRect = boxes[k][0]
		var tex: Texture2D = boxes[k][1]
		if not is_instance_valid(box):
			continue
		var tw := box.create_tween()
		tw.tween_interval(delay + 0.18 * k)
		tw.tween_callback(func():
			Sfx.play("cube_pickup")
			FrameFx.play(self, "CubeCatch_01", box.global_position - global_position + Vector2(32, -40), Vector2(210, 315), 24))
		tw.tween_property(box, "modulate", Color(2.2, 2.2, 2.2, 0.0), 0.2)
		tw.parallel().tween_property(box, "scale", Vector2(0.6, 1.4), 0.2)
		tw.tween_callback(func():
			box.queue_free()
			var icon := UI.image(tex, Vector2(36, 36))
			icon.custom_minimum_size = Vector2(36, 36)
			icon.pivot_offset = Vector2(18, 18)
			_box_row.add_child(icon)
			icon.scale = Vector2(1.5, 1.5)
			icon.create_tween().tween_property(icon, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK))


func _retreat() -> void:
	if quest.kind == "league":
		if not _finished:
			Save.record_league(false, float(quest.rival_skill))
		main.go("league")
		return
	if quest.kind == "arena":
		if not _finished:
			Save.record_arena(false, float(quest.rival_skill))
		main.go("arena")
		return
	if quest.kind == "duel":
		main.go("visit", {"name": String(quest.friend_name)})
		return
	if quest.kind == "raid":
		if not _finished:
			Save.record_raid_room(_raid_hp(), false, 0)
		main.go("raid")
		return
	if quest.kind == "tower":
		if not _finished:
			SkyTower.set_fever(engine.fever)
		Save.save_game()
		main.go("tower", {"floor": int(quest.floor)})
		return
	Save.save_game()
	if _finished and Tutorial.pending("hub", {"mission_ready": false}):
		main.go("hub")
		return
	if quest.kind == "special":
		main.go("islands", {"tab": "special", "special": quest.special_id, "difficulty": String(quest.get("tab", "")) if String(quest.get("tab", "")) != "" else "normal"})
	else:
		main.go("islands", {"island": island.id, "difficulty": difficulty})


func _show_banner(text: String, color: Color = UI.GOLD) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_skill_back.modulate.a = 1.0
	var tw := _skill_back.create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(_skill_back, "modulate:a", 0.0, 0.4)


func _add_view(u: BattleUnit, pos: Vector2, sprite_size: Vector2) -> void:
	var v := BattleUnitView.new()
	field.add_child(v)
	v.setup(u, pos, sprite_size)
	v.tapped.connect(_on_unit_tapped)
	views[u] = v
	_sort_views()


func _sort_views() -> void:
	var list: Array = views.values().filter(func(x): return is_instance_valid(x) and x.get_parent() == field)
	if list.is_empty():
		return
	var first: int = list.map(func(x): return x.get_index()).min()
	list.sort_custom(func(a, b): return a.position.y + a.size.y < b.position.y + b.size.y)
	for i in list.size():
		field.move_child(list[i], first + i)


func _on_unit_tapped(v: BattleUnitView) -> void:
	if v.unit.side == BattleUnit.PLAYER:
		if engine.cast_support(v.unit):
			tut_notify("support:any")
			tut_notify("support_used")
		return
	if not v.unit.alive():
		return
	engine.set_focus(v.unit)
	for u in views:
		views[u].set_targeted(u == engine.focus)


func _on_event(e: Dictionary) -> void:
	match String(e.kind):
		"wave":
			_spawn_wave()
		"damage":
			var v: BattleUnitView = views.get(e.unit)
			if v == null:
				return
			var from: BattleUnit = e.get("from")
			if from != null and e.source == "attack" and views.has(from):
				views[from].lunge(v.position + v.size / 2.0)
			if float(e.amount) > 0.0:
				v.hit(bool(e.crit))
				var icon: Texture2D = null
				if from != null and DB.element_mult(from.element, e.unit.element) > 1.0:
					icon = UI.element_icon(from.element)
				v.damage_number(int(e.amount), bool(e.crit), icon, e.unit.side == BattleUnit.PLAYER)
			if float(e.absorbed) > 0.0:
				v.float_text("Shield", Color("9fd8ff"), 18)
			if from != null and (e.source == "skill" or e.crit):
				_hit_sound(from.element)
		"heal":
			var v: BattleUnitView = views.get(e.unit)
			if v != null:
				v.float_text("+%d" % int(e.amount), Color("7dff7a"), 22)
				v.pulse(Color(0.7, 1.6, 0.7))
		"status":
			var v: BattleUnitView = views.get(e.unit)
			if v != null and e.status == "shield":
				v.pulse(Color(0.8, 1.2, 1.8))
		"skill":
			_on_skill(e)
		"death":
			var v: BattleUnitView = views.get(e.unit)
			if v != null:
				v.die()
			if e.unit.side == BattleUnit.ENEMY:
				if v != null:
					_last_kill = v.position + v.size * 0.5
				_collect_gold(v)
				_kill_count += 1
				if _box_at.has(_kill_count):
					_drop_box(v, SkyTower.box_texture(_tower_stones[int(_box_at[_kill_count])]))
				elif not _drop_state.is_empty():
					var d := StageBuilder.roll_kill(_drop_quest, _drop_state, e.unit.monster_id, _first_clear, rng)
					if not d.is_empty():
						_live_drops.append(d)
						_drop_box(v, UI.tex("betaHud00/H_cube_0%d.png" % clampi(int(DB.monster(d.id).stars) - 1, 0, 5)))
		"revive":
			var rv: BattleUnitView = views.get(e.unit)
			if rv != null:
				rv.revive()
		"fever":
			_show_banner("FEVER!  Skills cost 0 MP", Color("ffb040"))
			Sfx.play("buff_big")
		"trait":
			var tv: BattleUnitView = views.get(e.unit)
			if tv != null:
				tv.float_text(String(e.text), Color("ff9a7a"), 22)
		"reinforce":
			var ru: BattleUnit = e.unit
			for old in views.keys():
				if old.side == ru.side and old.slot == ru.slot and not old.alive():
					views[old].queue_free()
					views.erase(old)
			var spot: Vector2 = ALLY_SPOTS[ru.slot] if ru.side == BattleUnit.PLAYER else ENEMY_SPOTS_4[ru.slot]
			_add_view(ru, spot, Vector2(125, 110))
		"support_ready":
			if e.unit.side == BattleUnit.PLAYER:
				tut_notify("support_ready")
		"wave_clear":
			_show_banner("Stage clear!")
			_cleared = true
			_after_clear()
		"end":
			_cleared = true
			_collect_boxes(0.35)
			_on_end(String(e.result))


func _after_clear() -> void:
	if _boxes_in_air > 0 or not _ground_boxes.is_empty():
		engine.hold = 99.0
		while _boxes_in_air > 0:
			await get_tree().process_frame
			if not is_inside_tree():
				return
		var n := _ground_boxes.size()
		_collect_boxes(0.3)
		await get_tree().create_timer(0.75 + 0.18 * n).timeout
		engine.hold = 0.0
	_march(1.2 / float(SPEEDS[_speed_index]))


func _spawn_wave() -> void:
	_cleared = false
	for u in views.keys():
		if u.side == BattleUnit.ENEMY:
			views[u].queue_free()
			views.erase(u)
	var has_boss := false
	for u in engine.enemies:
		Save.data.seen[u.monster_id] = true
		if u.is_boss:
			has_boss = true
	var count := engine.enemies.size()
	var normal_spots: Array = ENEMY_LAYOUTS[clampi(count - 1, 0, ENEMY_LAYOUTS.size() - 1)]
	if has_boss:
		normal_spots = BOSS_MINION_LAYOUTS[clampi(count - 2, 0, BOSS_MINION_LAYOUTS.size() - 1)]
	var body := Vector2(140, 124) if count <= 5 else Vector2(130, 115)
	var k := 0
	for u in engine.enemies:
		if u.is_boss:
			_add_view(u, BOSS_SPOT, Vector2(230, 200))
		else:
			_add_view(u, normal_spots[k % normal_spots.size()], body)
			k += 1
		if not views.has(u) or not _pve():
			continue
		if engine.wave_index == 0:
			views[u].position = views[u].home + Vector2(_walk_offset(), 0)
		else:
			views[u].enter_from(Vector2(_walk_offset(), 0), WAVE_WALK / float(SPEEDS[_speed_index]))
	if engine.wave_index > 0 and _pve():
		engine.hold = WAVE_WALK
		_alert_enemies(WAVE_WALK / float(SPEEDS[_speed_index]))
	if has_boss:
		Sfx.play_music(Sfx.battle_music(quest, String(island.id), true))
		_show_banner("BOSS!", Color("ff6a50"))
		call_deferred("_boss_line")
	else:
		_show_banner("Stage %d" % (engine.wave_index + 1))


func _scroll_backdrop(tex: Texture2D, flip_tex: Texture2D = null) -> void:
	var w := get_viewport_rect().size
	_bg_strip = Control.new()
	_bg_strip.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_bg_strip)
	for i in 4:
		var bg := UI.image(flip_tex if i % 2 == 1 and flip_tex != null else tex, w, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
		bg.size = w
		bg.position = Vector2(w.x * i, 0)
		bg.flip_h = i % 2 == 1
		bg.mouse_filter = MOUSE_FILTER_IGNORE
		_bg_strip.add_child(bg)


func _march(t: float) -> void:
	for u in views:
		if u.side == BattleUnit.PLAYER and u.alive():
			views[u].walk(t)
	if _bg_strip == null:
		return
	var w := get_viewport_rect().size.x
	if _bg_x >= w * 2.0:
		_bg_x -= w * 2.0
		_bg_strip.position.x = -_bg_x
	_bg_x += _walk_offset()
	var tw := _bg_strip.create_tween()
	tw.tween_property(_bg_strip, "position:x", -_bg_x, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _boss_line() -> void:
	if _boss_spoken:
		return
	var text := ""
	if quest.kind == "story" and stage_index >= Save.cleared_stages(island.id, difficulty):
		text = String(Tutorial.boss_line(island.id, difficulty, stage_index).get("text", ""))
	elif quest.kind == "special" and not Save.data.special_clears.has(quest.key):
		text = String(quest.get("say", ""))
		if text == "":
			text = Tutorial.monster_line(String(quest.boss))
	if text == "":
		return
	_boss_spoken = true
	var boss_id := String(quest.boss)
	for u in engine.enemies:
		if u.is_boss:
			boss_id = u.monster_id
	_show_stage_tag()
	Tutorial.speak(self, boss_id, text)


func _show_stage_tag() -> void:
	var tag := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.03, 0.02, 0.85)
	sb.border_color = Color("ff8a2a")
	sb.set_border_width_all(2)
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 60
	sb.content_margin_right = 18
	tag.add_theme_stylebox_override("panel", sb)
	tag.add_child(UI.label(String(quest.get("title", "")).split("  ")[0], 26, Color("ff9a3a")))
	tag.position = Vector2(-300, 70)
	tag.z_index = 95
	add_child(tag)
	var tw := tag.create_tween()
	tw.tween_property(tag, "position:x", 0.0, 0.25)
	tw.tween_interval(3.0)
	tw.tween_property(tag, "modulate:a", 0.0, 0.4)
	tw.tween_callback(tag.queue_free)


func _on_skill(e: Dictionary) -> void:
	var u: BattleUnit = e.unit
	var s: Dictionary = e.skill
	var v: BattleUnitView = views.get(u)
	if v != null:
		v.pulse(Color(1.6, 1.4, 0.8))
	if e.source == "leader":
		_show_banner(s.name)
	elif v != null:
		v.float_text(s.name, Color("ffd36a") if u.side == BattleUnit.PLAYER else Color("ff9a7a"), 18)
	var kind := _skill_color(s)
	match kind:
		"yellow":
			Sfx.play("heal")
		"blue":
			Sfx.play("buff")
		"purple":
			Sfx.play("debuff")
		_:
			Sfx.play("cast_" + u.element)


func _hit_sound(element: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_hit_sound > 0.08:
		_last_hit_sound = now
		Sfx.play("hit_" + element)


func _on_end(result: String) -> void:
	_finished = true
	if result == "win":
		await _final_slowmo()
	if quest.kind == "tower":
		SkyTower.set_fever(engine.fever)
		Save.save_game()
	Save.track("kill", engine.kills.size())
	for id in engine.kills:
		var element := String(DB.monster(id).get("element", ""))
		if element in ["fire", "water", "nature", "normal"]:
			Save.track("kill_" + element)
	if quest.kind == "arena":
		_end_arena(result == "win")
		return
	if quest.kind == "duel":
		_end_duel(result == "win")
		return
	if quest.kind == "league":
		_end_league(result == "win")
		return
	if quest.kind == "raid":
		if OS.get_cmdline_user_args().has("--test-log"):
			print("battle end: %s at %.1fs" % [result, engine.time])
		_end_raid(result == "win")
		return
	if OS.get_cmdline_user_args().has("--test-log"):
		print("battle end: %s at %.1fs (stage %d/%d) fever=%d" % [result, engine.time, engine.wave_index + 1, engine.waves.size(), int(engine.fever)])
	if result == "win":
		if tutorial_active():
			tut_notify("victory")
			await tutorial.finished
		await _island_clear_sequence()
		_win()
	else:
		_lose()


func _final_slowmo() -> void:
	if _last_kill.x < 0.0:
		return
	var normal := Engine.time_scale
	tree_exiting.connect(func(): Engine.time_scale = normal)
	field.pivot_offset = _last_kill
	Engine.time_scale = normal * 0.2
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.55)
	flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	flash.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(flash)
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(flash, "color:a", 0.0, 0.35)
	tw.parallel().tween_property(field, "scale", Vector2(1.15, 1.15), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.6)
	tw.tween_property(field, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_method(func(s: float): Engine.time_scale = s, normal * 0.2, normal, 0.35)
	tw.tween_callback(flash.queue_free)
	await tw.finished
	Engine.time_scale = normal


func _island_clear_sequence() -> void:
	if quest.kind != "story" or difficulty != "normal" or stage_index + 1 != _quest_count() or Save.cleared_stages(island.id, difficulty) > stage_index:
		return
	var t := Tutorial.play(self, Tutorial.island_clear_steps(island.id, StageBuilder.island_clear_gems(quest)))
	await t.finished


func _collect_gold(v: BattleUnitView) -> void:
	_enemies_left -= 1
	var amount := _gold_per_kill if _enemies_left > 0 else int(_rewards.gold) - _gold_collected
	_gold_collected += amount
	_gold_label.text = Screen._thousands(_gold_collected)
	if v != null:
		v.gold_pop(amount)
	if amount > 0:
		Sfx.play("coin")


func _win() -> void:
	if quest.kind == "tower":
		_win_tower()
		return
	var gold := int(_rewards.gold)
	Save.data.gold = int(Save.data.gold) + gold
	var level_ups := []
	var before := team_owned.map(_exp_pct)
	var ups := []
	for m in team_owned:
		var g := Save.grant_exp(m, int(_rewards.exp))
		ups.append(g)
		if g > 0:
			level_ups.append("%s Lv.%d" % [DB.monster(m.id).name, int(m.level)])
	await _exp_count(before, ups)
	var is_story: bool = quest.kind == "story"
	Save.track("quest")
	if is_story:
		Save.track("island:" + String(island.id))
		Save.track("stage:%s/%d" % [island.id, stage_index])
	else:
		Save.track("special")
		Save.track("special:" + String(quest.get("special_id", "")))
		Save.track("special:%s/%d" % [quest.get("special_id", ""), int(quest.get("quest_index", 0))])
		if String(quest.get("tab", "")) != "":
			Save.track("special:%s:%s" % [quest.get("special_id", ""), quest.tab])
	if not _friend.is_empty():
		Save.track("friend_use")
	var quest_count := _quest_count()
	if is_story:
		Tutorial.record_win("%s:%s:%d" % [island.id, difficulty, stage_index])
	var first := Save.mark_quest_cleared(quest)
	var first_gems := StageBuilder.first_clear_gems(quest) if first else 0
	var island_gems := StageBuilder.island_clear_gems(quest) if (is_story and first and difficulty == "normal" and stage_index + 1 == quest_count) else 0
	Save.data.gems = int(Save.data.gems) + first_gems + island_gems
	var best := float(Save.data.best_times.get(quest.key, 0.0))
	var new_best := best <= 0.0 or engine.time < best
	if new_best:
		Save.data.best_times[quest.key] = engine.time
	var caught := []
	var fresh := []
	var lost := 0
	for d in _live_drops:
		if Save.inventory_full():
			lost += 1
		else:
			fresh.append(not Save.data.owned.has(d.id))
			Save.add_monster(d.id, int(d.level))
			caught.append(d.id)
	var fp_gain := Friends.record_use(_friend)
	var red_cube: bool = rng.randf() < float(quest.get("red_cube_chance", 0.0))
	if red_cube:
		Save.data.cube_items["red"] = int(Save.data.cube_items.get("red", 0)) + 1
	Save.track("quest_cube", caught.size())
	Save.save_game()

	var index := stage_index if is_story else int(quest.quest_index)
	var buttons := []
	var same_tab := is_story or String(DB.special(quest.special_id).quests[mini(index + 1, quest_count - 1)].get("tab", "")) == String(quest.get("tab", ""))
	if index + 1 < quest_count and same_tab:
		buttons.append({"text": "Next Field", "color": "blue", "cb": _leave_win(_play.bind(index + 1))})
	buttons.append({"text": "Again", "color": "green", "cb": _leave_win(_play.bind(index))})
	buttons.append({"text": "Leave", "color": "orange", "cb": _leave_win(_retreat)})
	var r := Layout.load_into(self, "R_d_reward")
	r.root.z_index = 50
	r.node("ID_9PATCH_2").mouse_filter = MOUSE_FILTER_STOP
	r.show("ID_9PATCH_tech", false)
	_win_leader(r.root)
	r.show("ID_time", false)
	r.text("ID_expText", Screen._thousands(int(_rewards.exp)))
	r.hide_all(["ID_eventTag_E"])
	r.text("ID_pointText", "+%02d" % fp_gain)
	r.text("ID_goldText", Screen._thousands(gold))
	r.hide_all(["ID_double1", "ID_double2", "ID_eventTag_G"])
	var gems := first_gems + island_gems
	r.show("ID_fieldFirst", gems > 0)
	r.text("ID_LABEL_3_1", "×%d" % gems)
	r.hide_all(["ID_IMAGE_gold", "ID_IMAGE_energy"])
	if island_gems > 0:
		r.text("ID_LABEL_3", "%s complete!" % island.name)
	var shown := mini(caught.size(), 3)
	for k in ["ID_none", "ID_one", "ID_two", "ID_three"]:
		r.show(k, false)
	r.show(["ID_none", "ID_one", "ID_two", "ID_three"][shown], true)
	var cube_ids := {1: ["ID_IMAGE_5"], 2: ["ID_IMAGE_6", "ID_IMAGE_7"], 3: ["ID_IMAGE_8", "ID_IMAGE_9", "ID_IMAGE_10"]}
	for k in shown:
		var star := int(DB.monster(caught[k]).stars)
		r.set_image(cube_ids[shown][k], UI.tex("betaHud00/H_cube_0%d.png" % clampi(star - 1, 0, 5)))
	if caught.size() > 3:
		r.text("ID_baseText", "+%d more" % (caught.size() - 3))
	var opening := not caught.is_empty()
	r.show("ID_btnOk", opening)
	r.hide_all(["ID_btnNext", "ID_btnAgain", "ID_btnEsc"] if opening else [])
	r.show("ID_btnNext", not opening and index + 1 < quest_count)
	r.on("ID_btnOk", _open_reward_cubes.bind(r, caught, fresh, buttons))
	r.on("ID_btnNext", _leave_win(_play.bind(index + 1)))
	r.on("ID_btnAgain", _leave_win(_play.bind(index)))
	r.on("ID_btnEsc", _leave_win(_retreat))
	var notes := []
	if red_cube:
		notes.append("A RED CUBE dropped! Open it in the Store.")
	if lost > 0:
		notes.append("%d cube(s) lost — your monster box is full!" % lost)
	for k in notes.size():
		UI.toast(self, notes[k], UI.GOLD)
	if lost > 0 and not tutorial_active():
		CubesScreen.offer_slots(self, true)
	Sfx.play("quest_complete")


static func _exp_pct(m: Dictionary) -> float:
	var need := DB.exp_to_next(int(m.level), int(DB.monster(m.id).stars))
	if int(m.level) >= Save.max_level(m) or need <= 0:
		return 100.0
	return clampf(100.0 * float(m.exp) / float(need), 0.0, 100.0)


func _exp_count(before: Array, ups: Array) -> void:
	var args := OS.get_cmdline_user_args()
	if tutorial_active() or "--test-tutauto" in args or "--test-instawin" in args:
		return
	var bars := []
	var used := {}
	for k in team_owned.size():
		var m: Dictionary = team_owned[k]
		for u in engine.allies:
			if u.monster_id == m.id and not used.has(u) and views.has(u) and u.alive():
				used[u] = true
				var target := _exp_pct(m) + 100.0 * int(ups[k])
				bars.append({"v": views[u], "from": float(before[k]), "to": target, "lv": int(m.level) - int(ups[k]), "ups": int(ups[k]), "shown": 0})
				break
	if bars.is_empty():
		return
	for b in bars:
		(b.v as BattleUnitView).show_exp(int(b.lv), float(b.from))
	Sfx.fade_music(0.4)
	Sfx.play("stage_clear")
	await get_tree().create_timer(0.8).timeout
	var snd := Sfx.play("exp_count")
	var t := 0.0
	var ding := -1.0
	while t < 2.2:
		var f := minf(1.0, t / 2.0)
		f = 1.0 - pow(1.0 - f, 2.0)
		for b in bars:
			var p: float = lerpf(b.from, b.to, f)
			var gained := mini(int(p / 100.0), int(b.ups))
			if gained > int(b.shown):
				b.shown = gained
				(b.v as BattleUnitView).level_up()
				if t - ding > 0.2:
					ding = t
					Sfx.play("buff_big")
			var pct := minf(100.0, p - 100.0 * gained)
			(b.v as BattleUnitView).show_exp(int(b.lv) + gained, pct)
		await get_tree().process_frame
		t += get_process_delta_time()
	if snd != null:
		snd.stop()
	await get_tree().create_timer(0.6).timeout


func _open_reward_cubes(card: Layout, caught: Array, fresh: Array, buttons: Array) -> void:
	card.root.queue_free()
	var best := 1
	for id in caught:
		best = maxi(best, int(DB.monster(id).stars))
	var kind := "blue" if best <= 2 else ("yellow" if best <= 4 else "red")
	CubeReveal.play(self, kind, caught, fresh, buttons, false, false, _bg_tex)


func _stat_box(icon: String, value: String, badge: String = "") -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(118, 104)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("a8683a")
	sb.set_corner_radius_all(10)
	box.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	box.add_child(v)
	v.add_child(UI.image(UI.tex(icon), Vector2(44, 44)))
	var l := UI.label(value, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	if badge != "":
		var b := UI.label(badge, 16, Color("ff6a50"))
		b.position = Vector2(4, 0)
		box.add_child(b)
	return box


func _cube_row(caught: Array) -> Control:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	if caught.is_empty():
		var none := _result_line("[No Cubes Obtained]")
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(none)
		return col
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for id in caught:
		var cube := UI.image(UI.tex("betaHud00/H_cube_0%d.png" % clampi(int(DB.monster(id).stars) - 1, 0, 5)), Vector2(90, 90))
		cube.pivot_offset = Vector2(45, 45)
		row.add_child(cube)
	var open := UI.button("Open Cube" + ("s" if caught.size() > 1 else ""), func(): _open_cubes(row, caught), "yellow", Vector2(200, 56), 20)
	col.add_child(open)
	return col


func _open_cubes(row: HBoxContainer, caught: Array) -> void:
	for c in row.get_children():
		c.queue_free()
	for id in caught:
		row.add_child(UI.monster_card(id, 1, 0, Vector2(96, 96)))
	Sfx.play("buff")

func _lose() -> void:
	var d := Layout.load_into(self, "R_d_fieldFailure")
	d.root.z_index = 80
	for g in ["ID_9PATCH_Slot4", "ID_9PATCH_Slot5", "ID_9PATCH_tower", "ID_gamePause_tower2"]:
		d.show(g, false)
	d.text("ID_LABEL_2", _pause_title())
	d.text("ID_numGold", Screen._thousands(_gold_collected))
	d.text("ID_numCube", str(_cubes_so_far()))
	d.text("ID_LABEL_6", str(CONTINUE_GEMS))
	var root := d.root
	d.on("ID_btnGo", func():
		root.queue_free()
		_continue())
	d.on("ID_btnGiveUp", func():
		root.queue_free()
		if quest.kind == "story":
			StoryQuests.record_defeat()
		_failed_tips())


func _failed_tips() -> void:
	var d := Layout.load_into(self, "R_d_giveUp")
	d.root.z_index = 80
	d.node("ID_9PATCH_2").mouse_filter = MOUSE_FILTER_STOP
	var tips := {"ID_teamSlot": ["ID_btnTeam", "ID_btnTeam_2", "ID_LABEL_4", "Edit Team", "squad"], "ID_shop": ["ID_btnShop", "ID_btnShop_2", "ID_LABEL_6", "Go Store", "cubes"], "ID_combine": ["ID_btnTeam_1", "ID_btnCom_2", "ID_LABEL_7", "Go Train", "combine"]}
	var pick: String = tips.keys()[randi() % tips.size()]
	var base: Control = d.node("ID_teamSlot")
	for k in tips:
		d.show(k, k == pick)
		d.show(tips[k][1], k == pick)
	var panel: Control = d.node(pick)
	var btn: Control = d.node(tips[pick][1])
	if pick != "ID_teamSlot":
		btn.position += base.position - panel.position
		panel.position = base.position
	d.text(tips[pick][2], tips[pick][3])
	var go_to: String = tips[pick][4]
	var root := d.root
	for b in [tips[pick][0], tips[pick][1]]:
		d.on(b, func():
			root.queue_free()
			_retreat()
			main.go(go_to))
	d.on("ID_btnOk", func():
		root.queue_free()
		_retreat())


func _continue() -> void:
	if int(Save.data.gems) < CONTINUE_GEMS:
		UI.toast(self, "Not enough gems", Color("ff8080"))
		_lose()
		return
	Save.data.gems = int(Save.data.gems) - CONTINUE_GEMS
	Save.save_game()
	engine.revive_team()
	for u in engine.allies:
		var v: BattleUnitView = views[u]
		v.modulate.a = 1.0
		v.sprite.scale = Vector2.ONE
	_finished = false


func _quest_count() -> int:
	if quest.kind == "tower":
		return SkyTower.FLOORS
	if quest.kind == "story":
		return island.difficulties[difficulty].stages.size()
	return DB.special(quest.special_id).quests.size()


func _play(index: int) -> void:
	var next: Dictionary
	if quest.kind == "tower":
		var floor := index + 1
		if floor > int(Save.data.tower_floor) + 1:
			_retreat()
			return
		var tq := SkyTower.enter(floor)
		if tq.is_empty():
			UI.toast(self, "No tickets left", Color("ff8080"))
			_retreat()
			return
		main.go("battle", {"quest": tq})
		return
	if quest.kind == "story":
		next = StageBuilder.story_quest(island, difficulty, index)
	else:
		var sp := DB.special(quest.special_id)
		if not Save.special_available(sp):
			UI.toast(self, "%s has closed" % sp.name, Color("ff8080"))
			_retreat()
			return
		next = StageBuilder.special_quest(sp, index)
	if Tutorial.pending("hub", {"mission_ready": false}):
		main.go("hub")
		return
	var a := {"island": island.id, "difficulty": difficulty, "stage": index, "quest": next}
	if quest.kind == "special":
		a = {"special": quest.special_id, "quest": next, "difficulty": String(next.tab) if String(next.tab) != "" else "normal"}
	main.go("ready", a)

func _result_line(text: String) -> Label:
	var l := UI.label(text, 22, UI.BROWN)
	l.add_theme_constant_override("outline_size", 0)
	return l

func _win_tower() -> void:
	var floor := int(quest.floor)
	var gold := int(_rewards.gold)
	Save.data.gold = int(Save.data.gold) + gold
	Save.track("tower")
	var first := Save.mark_floor_cleared(floor)
	var best := float(Save.data.best_times.get(quest.key, 0.0))
	var new_best := best <= 0.0 or engine.time < best
	if new_best:
		Save.data.best_times[quest.key] = engine.time
	var got := []
	var lost := 0
	for st in _tower_stones:
		if Save.stone_box_full():
			lost += 1
		else:
			got.append(Save.add_stone(st))
	Save.save_game()

	var r := Layout.load_into(self, "R_d_reward")
	r.root.z_index = 50
	r.show("ID_9PATCH_2", false)
	_win_leader(r.root)
	r.node("ID_9PATCH_tech").mouse_filter = MOUSE_FILTER_STOP
	r.text("ID_timeText_1", UI.format_time(int(engine.time)))
	r.show("ID_new_1", new_best)
	r.text("ID_goldText_1", Screen._thousands(gold))
	r.hide_all(["ID_double2_1", "ID_eventTag_G_1"])
	r.show("ID_fieldFirst_1", first)
	r.text("ID_LABEL_3_3", "×1")
	var shown := mini(got.size(), 3)
	for k in ["ID_none_1", "ID_one_1", "ID_two_1", "ID_three_1"]:
		r.show(k, false)
	r.show(["ID_none_1", "ID_one_1", "ID_two_1", "ID_three_1"][shown], true)
	var cube_ids := {1: ["ID_IMAGE_5_1"], 2: ["ID_IMAGE_6_1", "ID_IMAGE_7_1"], 3: ["ID_IMAGE_8_1", "ID_IMAGE_9_1", "ID_IMAGE_10_1"]}
	for k in shown:
		r.set_image(cube_ids[shown][k], SkyTower.box_texture(got[k]))
	if shown == 0:
		r.text("ID_baseText_1", "[No Cubes Obtained]")
	var opening := not got.is_empty()
	r.show("ID_btnOk_1", opening)
	r.show("ID_btnNext_1", not opening and floor < SkyTower.FLOORS and floor <= int(Save.data.tower_floor))
	r.show("ID_btnAgain_1", not opening)
	r.show("ID_btnEsc_1", not opening)
	r.text("ID_LABEL_1_1_1", "Next Floor")
	r.on("ID_btnNext_1", _leave_win(_play.bind(floor)))
	r.on("ID_btnAgain_1", _leave_win(_play.bind(floor - 1)))
	r.on("ID_btnEsc_1", _leave_win(_retreat))
	r.on("ID_btnOk_1", func():
		r.root.queue_free()
		_reveal_stones(got, 0, floor))
	if lost > 0:
		UI.toast(self, "%d stone(s) lost — your stone box is full!" % lost, Color("ff8080"))
	Sfx.play("buff_big")


func _reveal_stones(got: Array, i: int, floor: int) -> void:
	if i >= got.size():
		var buttons := []
		if floor < SkyTower.FLOORS and floor <= int(Save.data.tower_floor):
			buttons.append({"text": "Next Floor", "color": "yellow", "cb": _leave_win(_play.bind(floor))})
		buttons.append({"text": "Again", "color": "orange", "cb": _leave_win(_play.bind(floor - 1))})
		buttons.append({"text": "Leave", "color": "blue", "cb": _leave_win(_retreat)})
		var list := VBoxContainer.new()
		for st in got:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.add_child(StonesScreen.stone_icon(st, 64))
			row.add_child(_result_line("%s\n%s" % [MagicStones.label(st), MagicStones.describe(st)]))
			list.add_child(row)
		UI.dialog(self, "Floor %d Cleared!" % floor, list, buttons)
		return
	var st: Dictionary = got[i]
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.8)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	shade.z_index = 60
	shade.mouse_filter = MOUSE_FILTER_STOP
	add_child(shade)
	var vs := get_viewport_rect().size
	var title := UI.label("RANK %s" % MagicStones.RANKS[int(st.rank)], 72, Color("9fe8ff"))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color("10304a"))
	title.size = Vector2(vs.x, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, vs.y * 0.18)
	shade.add_child(title)
	var icon := StonesScreen.stone_icon(st, 150)
	icon.position = Vector2(vs.x / 2.0 - 75, vs.y * 0.36)
	icon.pivot_offset = Vector2(75, 75)
	icon.scale = Vector2(0.2, 0.2)
	shade.add_child(icon)
	var name_l := UI.label("%s\n%s" % [MagicStones.label(st), MagicStones.describe(st)], 24)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.size = Vector2(vs.x, 80)
	name_l.position = Vector2(0, vs.y * 0.68)
	shade.add_child(name_l)
	var tw := icon.create_tween()
	tw.tween_property(icon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("buff_big" if int(st.rank) >= MagicStones.B else "buff")
	shade.gui_input.connect(func(e: InputEvent):
		if UI.pressed(e):
			shade.queue_free()
			_reveal_stones(got, i + 1, floor))

func _raid_hp() -> Dictionary:
	var hp := {}
	for i in engine.allies.size():
		hp[int(team_owned[i].uid)] = engine.allies[i].hp_ratio() if engine.allies[i].alive() else 0.0
	return hp


func _end_raid(won: bool) -> void:
	var r := Raids.raid(quest.raid_id)
	var room := int(quest.room)
	var gold := int(_rewards.gold) if won else 0
	Save.data.gold = int(Save.data.gold) + gold
	Save.record_raid_room(_raid_hp(), won, gold)
	var caught := []
	if won:
		for id in Raids.roll_drops(r, room, rng):
			if not Save.inventory_full():
				Save.add_monster(id, 1)
				caught.append(id)
	Save.save_game()
	if not won:
		_raid_failed(r, room)
		return
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	var fallen := 0
	for a in engine.allies:
		if not a.alive():
			fallen += 1
	if won:
		var boxes := HBoxContainer.new()
		boxes.alignment = BoxContainer.ALIGNMENT_CENTER
		boxes.add_child(_stat_box("betaHud00/H_clock_02.png", UI.format_time(int(engine.time))))
		boxes.add_child(_stat_box("betaHud00/H_money_02.png", Screen._thousands(gold)))
		body.add_child(boxes)
		body.add_child(_cube_row(caught))
	else:
		body.add_child(_result_line("The party was defeated. Send in other monsters to retry this room."))
	if fallen > 0:
		body.add_child(_result_line("%d monster(s) knocked out — they can't fight again today." % fallen))
	var title := "Raid cleared!" if won and room == Raids.ROOMS - 1 else ("Stage %d cleared!" % (room + 1) if won else "Stage failed")
	UI.dialog(self, title, body, [{"text": "Continue", "color": "yellow", "cb": _leave_win(main.go.bind("raid")) if won else func(): main.go("raid")}])

func _raid_failed(r: Dictionary, room: int) -> void:
	var vw := get_viewport_rect().size
	var band := ColorRect.new()
	band.color = Color(0.04, 0.03, 0.02, 0.78)
	band.size = Vector2(vw.x, 460)
	band.position = Vector2(0, (vw.y - 460) / 2.0)
	band.z_index = 80
	band.mouse_filter = MOUSE_FILTER_STOP
	add_child(band)
	for y in [0.0, 457.0]:
		var line := ColorRect.new()
		line.color = Color("e8761e")
		line.size = Vector2(vw.x, 3)
		line.position = Vector2(0, y)
		band.add_child(line)
	var t := UI.label("Quest Failed", 40, Color("ff5a2a"))
	t.add_theme_constant_override("outline_size", 0)
	t.size = Vector2(vw.x, 50)
	t.position = Vector2(0, 30)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	band.add_child(t)
	var sub := UI.label("%s-%d" % [String(r.name).split(" ")[0].replace("'s", ""), room + 1], 24, Color("f0d890"))
	sub.add_theme_constant_override("outline_size", 0)
	sub.size = Vector2(vw.x, 30)
	sub.position = Vector2(0, 82)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	band.add_child(sub)
	var left := []
	for e in engine.enemies:
		if e.alive():
			left.append(e)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.size = Vector2(vw.x, 130)
	row.position = Vector2(0, 150)
	band.add_child(row)
	for e in left.slice(0, 5):
		var col := VBoxContainer.new()
		col.add_child(UI.monster_card(e.monster_id, 0, 0, Vector2(110, 110)))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(100, 8)
		bar.show_percentage = false
		bar.max_value = e.max_hp
		bar.value = e.hp
		bar.modulate = Color("e04020")
		col.add_child(bar)
		row.add_child(col)
	var again := UI.button("Again", func(): main.go("raid"), "green", Vector2(300, 90), 30)
	again.position = Vector2((vw.x - 300) / 2.0, 330)
	band.add_child(again)
	Sfx.play("debuff")


func _end_duel(won: bool) -> void:
	var fp := Friends.finish_duel(won)
	var text := "Congratulations.\nYour duel was victorious." if won else "Your duel ended in defeat."
	if fp > 0:
		text += "\nDay's First Battle: +%d FP" % fp
	var d := UI.notice(self, "Match Won!" if won else "Match Lost", text, _leave_win(main.go.bind("visit", {"name": String(quest.friend_name)})) if won else func(): main.go("visit", {"name": String(quest.friend_name)}))
	UI.ribbon_title(d, "Match Won!" if won else "Match Lost")
	UI.orange_ok(d, "Leave")
	Sfx.play("buff_big" if won else "debuff")


func _end_arena(won: bool) -> void:
	if OS.get_cmdline_user_args().has("--test-log"):
		print("battle end: %s at %.1fs" % ["win" if won else "lose", engine.time])
	var delta := Save.record_arena(won, float(quest.rival_skill))
	var a := Save.arena_state()
	var draw := not won and engine.time_limit > 0.0 and engine.time >= engine.time_limit - 0.05
	var r := Layout.load_into(self, "R_d_pvpResult")
	r.root.z_index = 60
	r.show("ID_blackBack", false)
	r.show("ID_btnInvite", false)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	r.root.add_child(shade)
	r.root.move_child(shade, 0)
	var res := "resultWin" if won else ("resultDraw" if draw else "resultLose")
	for k in ["resultWin", "resultDraw", "resultLose"]:
		r.show(k, k == res)
	r.text("ID_score1", ("+" if delta >= 0 else "") + Screen._thousands(delta))
	r.text("ID_score2", Screen._thousands(int(a.points)))
	if not team_owned.is_empty():
		var art := UI.living(DB.battle_sprite(String(team_owned[0].id)), Vector2(280, 250))
		art.position = Vector2(-170.0, -250.0)
		r.node("ID_monsterAlign").add_child(art)
	for b in ["ID_btnExit1", "ID_btnExit2", "ID_btnExit3"]:
		r.on(b, _leave_win(main.go.bind("arena")) if won else func(): main.go("arena"))
	Sfx.play("buff_big" if won else "debuff")

func _end_league(won: bool) -> void:
	if OS.get_cmdline_user_args().has("--test-log"):
		print("battle end: %s at %.1fs (%d vs %d left)" % ["win" if won else "lose", engine.time, engine.remaining(BattleUnit.PLAYER), engine.remaining(BattleUnit.ENEMY)])
	var delta := Save.record_league(won, float(quest.rival_skill))
	var l := Save.league()
	var draw := not won and engine.time_limit > 0.0 and engine.time >= engine.time_limit - 0.05
	var r := Layout.load_into(self, "R_d_pvpResult")
	r.root.z_index = 60
	r.show("ID_resultBack", false)
	r.show("ID_btnInvite_1", false)
	var res := "resultWin_1" if won else ("resultDraw_1" if draw else "resultLose_1")
	for k in ["resultWin_1", "resultDraw_1", "resultLose_1"]:
		r.show(k, k == res)
	r.text("ID_score1_1", ("+" if delta >= 0 else "") + Screen._thousands(delta))
	r.text("ID_score2_1", Screen._thousands(int(l.points)))
	var mine: Array = quest.league_team
	for i in 12:
		if i < mine.size():
			var card := UI.monster_card(String(mine[i].id), int(mine[i].level), int(mine[i].boost), Vector2(82, 82))
			card.mouse_filter = MOUSE_FILTER_IGNORE
			r.put("ID_position%d" % i, card)
		else:
			r.show("ID_mon%d" % i, false)
	for b in ["ID_btnExit1_1", "ID_btnExit2_1", "ID_btnExit3_1"]:
		r.on(b, _leave_win(main.go.bind("league")) if won else func(): main.go("league"))
	Sfx.play("buff_big" if won else "debuff")
