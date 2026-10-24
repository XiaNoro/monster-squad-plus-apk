extends Screen

const LAND_STEP := 318.0
const PAGE_SCROLL := 636.0
const MAP_TABS := {"story": "ID_btnStory", "special": "ID_btnSpecial", "raid": "ID_btnTechnical"}
const FIELD_TABS := {"normal": "ID_tapBtn1", "hard": "ID_tapBtn2", "hell": "ID_tapBtn3"}
const CHAIN_UNLOCK_FIELD := 9
const OCEAN := """
shader_type canvas_item;
uniform vec2 size = vec2(1066.0, 640.0);
uniform float scroll = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float crest(vec2 f, float w, float h) {
	float x = abs(f.x) / w;
	if (x >= 1.0) return 0.0;
	float d = abs(f.y + h * (1.0 - pow(x, 0.7)));
	float th = 0.4 + 2.4 * pow(1.0 - x, 0.6);
	return 1.0 - smoothstep(th - 0.8, th + 0.8, d);
}

void fragment() {
	vec2 px = UV * size;
	vec2 sea = px + vec2(scroll * 0.5, 0.0);
	vec3 col = mix(vec3(0.20, 0.62, 0.93), vec3(0.07, 0.38, 0.78), UV.y);
	col *= 0.96 + 0.08 * noise(sea / 140.0 + vec2(TIME * 0.05, TIME * 0.03));
	vec2 cell = vec2(150.0, 84.0);
	vec2 q = sea + vec2(TIME * 4.0, 0.0);
	q.x += mod(floor(q.y / cell.y), 2.0) * cell.x * 0.5;
	vec2 id = floor(q / cell);
	vec2 f = q - id * cell - cell * 0.5;
	float r = hash(id);
	float t = TIME * 0.9 + r * 6.283;
	f -= vec2((r - 0.5) * 40.0, (hash(id + 3.1) - 0.5) * 20.0);
	f.x += sin(t * 0.4) * 6.0;
	float w = 18.0 + 8.0 * hash(id + 7.0);
	float h = 8.0 + 2.0 * sin(t);
	float life = smoothstep(-0.2, 0.6, sin(TIME * 0.35 + r * 6.283)) * step(0.15, hash(id + 11.0));
	float a = crest(f, w, h);
	float s = crest(f - vec2(0.0, 2.5), w, h);
	if (hash(id + 5.0) > 0.6) {
		vec2 g = f - vec2(w * 1.1, -10.0);
		a = max(a, crest(g, w * 0.6, h * 0.7) * 0.8);
		s = max(s, crest(g - vec2(0.0, 2.5), w * 0.6, h * 0.7));
	}
	col = mix(col, col * 0.8, s * life * 0.5);
	col = mix(col, vec3(0.62, 0.86, 1.0), a * life * 0.85);
	COLOR = vec4(col, 1.0);
}
"""
const ROUNDED := """
shader_type canvas_item;
uniform float radius = 0.11;
void fragment() {
	vec2 px = vec2(abs(dFdx(UV.x)), abs(dFdy(UV.y)));
	vec2 r = vec2(radius * px.x / px.y, radius);
	vec2 q = max(abs(UV - 0.5) - 0.5 + r, 0.0) / r;
	COLOR.a *= clamp((1.0 - length(q)) * radius / px.y + 0.5, 0.0, 1.0);
}
"""

var tab := "story"
var island_id := ""
var special_id := ""
var difficulty := "normal"
var map: Layout
var strip: Layout
var field: Layout
var _clip: Control
var _area_w := 0.0
var _edge := 0.0
var _scroll_x := 0.0
var _strip_w := 0.0
var _dragging := false
var _grab := false
var _drag_dist := 0.0
var _field_art: TextureRect
var _stage_slots: Array = []
var _sea: ShaderMaterial
static var _map_scroll: Dictionary = {}
static var _rounded: ShaderMaterial


func build() -> void:
	Sfx.play_music("lobby")
	_ocean()
	map = Layout.load_into(self, "R_islandChoicePage")
	field = Layout.load_into(self, "R_fieldChoicePage")
	add_top_bar("2", "Adventure", "hub")
	tab = args.get("tab", "story")
	island_id = args.get("island", "")
	special_id = args.get("special", "")
	difficulty = args.get("difficulty", "normal")
	_setup_map()
	_setup_field()
	if island_id != "" or special_id != "":
		_open_field()
	else:
		_show_map()
	Tutorial.maybe_start(self, "field" if field.root.visible else "islands", {"special": special_id})


func _ocean() -> void:
	var sh := Shader.new()
	sh.code = OCEAN
	_sea = ShaderMaterial.new()
	_sea.shader = sh
	var sea := ColorRect.new()
	sea.material = _sea
	sea.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	sea.mouse_filter = MOUSE_FILTER_IGNORE
	sea.resized.connect(func(): _sea.set_shader_parameter("size", sea.size))
	add_child(sea)


func _setup_map() -> void:
	map.text("ID_LABEL_S2", "Special")
	map.text("ID_LABEL_T", "Raid")
	map.show("ID_IMAGE_3", false)
	map.on("ID_btnStory", _set_tab.bind("story"))
	map.on("ID_btnSpecial", _set_tab.bind("special"))
	map.on("ID_btnTechnical", _set_tab.bind("raid"))
	map.on("ID_btnLeft", _page.bind(-1))
	map.on("ID_btnRight", _page.bind(1))
	var area: Control = map.node("ID_slideArry")
	_area_w = area.size.x
	_edge = area.global_position.x - global_position.x
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.position = Vector2(-_edge, 0)
	_clip.size = Vector2(get_viewport_rect().size.x, area.size.y)
	_clip.mouse_filter = MOUSE_FILTER_STOP
	_clip.gui_input.connect(_on_map_input)
	area.add_child(_clip)
	strip = Layout.load_into(_clip, "R_islandSlot", Vector2.ZERO, area.size.y)
	for n in 30:
		var land := strip.node("ID_btnLand%d" % (n + 1))
		if land != null:
			land.gui_input.connect(_on_map_input)
	area.get_parent().move_child(area, 0)


func _set_tab(t: String) -> void:
	tab = t
	_show_map()


func _show_map() -> void:
	_scroll_x = float(_map_scroll.get(tab, 0.0))
	map.root.visible = true
	field.root.visible = false
	if _field_art:
		_field_art.visible = false
	map.select_tab(MAP_TABS.values(), MAP_TABS[tab])
	key_kind = "raid" if tab == "raid" else "tower"
	add_top_bar("7" if tab == "raid" else "2", "Adventure", "hub")
	var entries: Array = DB.islands if tab == "story" else (Raids.all() if tab == "raid" else DB.special_islands)
	for n in 30:
		var i := n + 1
		var land: Control = strip.node("ID_land%d" % i)
		if land == null:
			continue
		land.visible = n < entries.size()
		if land.visible:
			_fill_land(i, entries[n])
	_strip_w = LAND_STEP * entries.size() + 40.0
	_apply_scroll()


func _fill_land(i: int, e: Dictionary) -> void:
	if tab == "raid":
		_fill_raid_land(i, e)
		return
	var story := tab == "story"
	var unlocked: bool = Save.is_island_unlocked(e.id, "normal") if story else true
	var open: bool = true if story else Save.special_available(e)
	var btn := strip.node("ID_btnLand%d" % i) as TextureButton
	for c in btn.get_children():
		if c is RaidLock:
			c.queue_free()
	btn.self_modulate = Color.WHITE
	var art := DB.island_art(e.id)
	if art == null:
		art = DB.island_art("material_island" if not story else "sprout_island")
		btn.self_modulate = Color(0.85, 0.95, 1.1)
	btn.texture_normal = art
	var fit := minf(1.0, minf(340.0 / art.get_width(), 260.0 / art.get_height()))
	btn.size = art.get_size() * fit
	btn.position = Vector2((340.0 - btn.size.x) / 2.0, 290.0 - btn.size.y)
	btn.modulate = Color.WHITE if unlocked and open else Color(0.6, 0.6, 0.65)
	for c in btn.pressed.get_connections():
		btn.pressed.disconnect(c.callable)
	btn.pressed.connect(_pick_land.bind(e.id))
	var name_label := strip.text("ID_landNameText%d" % i, String(e.name))
	name_label.add_theme_color_override("font_color", UI.CREAM)
	name_label.add_theme_constant_override("outline_size", 5)
	name_label.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0))
	strip.show("ID_shadow%d" % i, false)
	strip.show("ID_lock%d" % i, story and not unlocked)
	strip.show("ID_btnOpenT_%d" % i, false)
	var gem_open := strip.node("ID_btnOpen%d" % i) as BaseButton
	gem_open.visible = not story and not open
	if gem_open.visible:
		for c in gem_open.pressed.get_connections():
			gem_open.pressed.disconnect(c.callable)
		gem_open.pressed.connect(_offer_unlock.bind(e.id))
		strip.text("ID_LABEL_%d" % i, str(Save.special_unlock_gems(e.id)))
	var ribbon := ""
	if not story:
		var left := Save.special_unlock_seconds_left(e.id)
		if left > 0 and not DB.special_open_today(e):
			ribbon = "Closes in %d Min(s)" % ceili(left / 60.0)
		elif DB.special_open_today(e):
			var t := Time.get_datetime_dict_from_system(true)
			ribbon = "Closes in %dHr(s)" % (24 - int(t.hour))
		else:
			ribbon = String(DB.special_days_text(e)).replace("Open ", "Free on ")
	strip.show("ID_eventTime%d" % i, ribbon != "")
	_style_ribbon(i)
	strip.text("ID_timeText%d" % i, ribbon)
	strip.show("ID_btnEvent%d" % i, _event_on(e.id, story))
	_wire_star(strip.node("ID_btnEvent%d" % i), String(e.id))


func _style_ribbon(i: int) -> void:
	var rib := strip.node("ID_eventTime%d" % i) as NinePatchRect
	if rib != null and not rib.has_meta("styled"):
		rib.set_meta("styled", true)
		rib.texture = null
		var bg := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.08, 0.12, 0.72)
		sb.set_corner_radius_all(12)
		bg.add_theme_stylebox_override("panel", sb)
		bg.position = Vector2(40, 0)
		bg.size = Vector2(rib.size.x - 80, rib.size.y)
		bg.mouse_filter = MOUSE_FILTER_IGNORE
		rib.add_child(bg)
		rib.move_child(bg, 0)


func _wire_star(star: Control, id: String) -> void:
	if star == null:
		return
	Events.tag(star, id)
	if star is BaseButton:
		var b := star as BaseButton
		for c in b.pressed.get_connections():
			b.pressed.disconnect(c.callable)
		b.pressed.connect(func():
			Sfx.play("click")
			UI.notice(self, "Current Events", Events.popup_text(id)))


static func _event_on(id: String, _story: bool) -> bool:
	return Events.affects(id)


func _fill_raid_land(i: int, r: Dictionary) -> void:
	var today := Save.raid_today()
	var entered := String(today.get("id", "")) == String(r.id)
	var btn := strip.node("ID_btnLand%d" % i) as TextureButton
	var art := DB.island_art(r.id)
	if art == null:
		var rooms: Array = r.rooms
		art = DB.battle_sprite(String(rooms[Raids.ROOMS - 1][0]))
	btn.self_modulate = Color.WHITE
	btn.texture_normal = art
	var fit := minf(300.0 / art.get_width(), 250.0 / art.get_height())
	btn.size = art.get_size() * fit
	btn.position = Vector2((340.0 - btn.size.x) / 2.0, 290.0 - btn.size.y)
	btn.modulate = Color.WHITE
	for c in btn.get_children():
		if c is RaidLock:
			c.queue_free()
	if not entered:
		RaidLock.make(btn)
	for c in btn.pressed.get_connections():
		btn.pressed.disconnect(c.callable)
	btn.pressed.connect(_pick_raid.bind(String(r.id), btn))
	var name_label := strip.text("ID_landNameText%d" % i, String(r.name))
	name_label.add_theme_color_override("font_color", UI.CREAM)
	name_label.add_theme_constant_override("outline_size", 5)
	name_label.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0))
	strip.show("ID_shadow%d" % i, false)
	strip.show("ID_lock%d" % i, false)
	strip.show("ID_btnOpenT_%d" % i, false)
	strip.show("ID_btnOpen%d" % i, false)
	strip.show("ID_btnEvent%d" % i, Events.affects(String(r.id)))
	_wire_star(strip.node("ID_btnEvent%d" % i), String(r.id))
	var ribbon := ""
	if entered:
		var t := Time.get_datetime_dict_from_system()
		var left := 86400 - (int(t.hour) * 3600 + int(t.minute) * 60 + int(t.second))
		ribbon = "Resets in %dHr(s) %dMin(s)" % [floori(left / 3600.0), floori((left % 3600) / 60.0)]
	strip.show("ID_eventTime%d" % i, ribbon != "")
	_style_ribbon(i)
	strip.text("ID_timeText%d" % i, ribbon)


func _pick_raid(id: String, btn: Control) -> void:
	if _dragging:
		return
	Sfx.play("click")
	if Save.raid_unlocked(id):
		main.go("raid")
	elif not Save.has_raid_key():
		UI.notice(self, "Notice", "Not enough keys.\n(Keys recharge daily at 00:00am.)")
	else:
		var d := UI.notice(self, "Notice", "Use key to unlock island?\n(Island resets at 00:00am daily.)", _unlock_raid.bind(id, btn))
		var shade := d.find_child("ID_9PATCH_2", true, false) as Control
		shade.gui_input.connect(func(e: InputEvent):
			if UI.pressed(e):
				d.queue_free())


func _unlock_raid(id: String, btn: Control) -> void:
	if not Save.unlock_raid(id):
		return
	_refresh_top()
	var lock: RaidLock = null
	for c in btn.get_children():
		if c is RaidLock:
			lock = c
	if lock == null:
		_show_map()
		return
	lock.opened.connect(_show_map)
	lock.open()


func _pick_land(id: String) -> void:
	if _dragging:
		return
	Sfx.play("click")
	if tab == "story":
		if not Save.is_island_unlocked(id, "normal"):
			UI.toast(self, "Clear the previous island first!")
			return
		island_id = id
		special_id = ""
		if not Save.is_island_unlocked(id, difficulty):
			difficulty = "normal"
	else:
		special_id = id
		island_id = ""
		if not Save.special_available(DB.special(id)):
			_offer_unlock(id)
			return
	_open_field()
	tut_notify("island:" + id)
	Tutorial.maybe_start(self, "field", {"special": special_id})


func _offer_unlock(id: String) -> void:
	var sp := DB.special(id)
	var d := Layout.load_into(self, "R_d_buy")
	d.root.z_index = 80
	d.nodes_named("ID_9PATCH_2")[0].mouse_filter = MOUSE_FILTER_STOP
	d.text("ID_titleText", "Purchase")
	var body := d.text("ID_baseText", "Would you like to open %s for %d hour(s)?" % [sp.name, Save.SPECIAL_UNLOCK_SECONDS / 3600])
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_color_override("font_color", UI.BROWN)
	d.show("ID_priceGold", false)
	d.text("ID_priceText2", str(Save.special_unlock_gems(id)))
	var root := d.root
	d.on("ID_btnOk", func():
		root.queue_free()
		_unlock(id))
	d.on("ID_btnEsc", root.queue_free)


func _unlock(id: String) -> void:
	if not Save.unlock_special(id):
		UI.toast(self, "Not enough gems", Color("ff8080"))
		return
	Sfx.play("buff_big")
	_show_map()


func _page(dir: int) -> void:
	_scroll_x += dir * PAGE_SCROLL
	_apply_scroll(true)


func _apply_scroll(animate: bool = false) -> void:
	_scroll_x = clampf(_scroll_x, 0.0, maxf(0.0, _strip_w - _area_w))
	_map_scroll[tab] = _scroll_x
	map.show("ID_btnLeft", _scroll_x > 1.0)
	map.show("ID_btnRight", _scroll_x < _strip_w - _area_w - 1.0)
	if animate:
		create_tween().tween_property(strip.root, "position:x", _edge - _scroll_x, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		strip.root.position.x = _edge - _scroll_x


func _process(_delta: float) -> void:
	if _sea and strip:
		_sea.set_shader_parameter("scroll", _edge - strip.root.position.x)


func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_grab = false
		if e.pressed:
			_dragging = false
			_drag_dist = 0.0
	elif e is InputEventMouseMotion and _grab and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_drag_dist += absf(e.relative.x)
		_dragging = _drag_dist > 8.0
		_scroll_x -= e.relative.x
		_apply_scroll()


func _on_map_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		_grab = true


func _setup_field() -> void:
	for d in FIELD_TABS:
		field.on(FIELD_TABS[d], _select_difficulty.bind(d))
	var ex := field.node("ID_EXtext") as Label
	ex.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ex.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ex.add_theme_font_size_override("font_size", 18)
	_field_art = UI.image(null, Vector2(330, 280))
	_field_art.size = Vector2(330, 280)
	_field_art.position = Vector2(Layout.DESIGN_W / 2.0 + (get_viewport_rect().size.x - Layout.DESIGN_W) / 2.0 - 500.0, 150)
	add_child(_field_art)
	move_child(_field_art, field.root.get_index())


func _open_field() -> void:
	map.root.visible = false
	field.root.visible = true
	_field_art.visible = true
	_back_target = "islands"
	_back_args = {"tab": tab}
	_refresh_field()


func _select_difficulty(d: String) -> void:
	if special_id != "":
		if not _chain_tab_open(DB.special(special_id), d):
			UI.toast(self, "Clear Field %d on %s first!" % [CHAIN_UNLOCK_FIELD, String(DB.DIFFICULTIES[DB.DIFFICULTIES.find(d) - 1]).capitalize()])
			return
		difficulty = d
		_refresh_field()
		return
	if not Save.is_island_unlocked(island_id, d):
		UI.toast(self, "Clear this island on %s first!" % String(DB.DIFFICULTIES[DB.DIFFICULTIES.find(d) - 1]).capitalize())
		return
	difficulty = d
	_refresh_field()


func _refresh_field() -> void:
	var story := island_id != ""
	var rows := []
	for d in ["hard", "hell"]:
		field.show(FIELD_TABS[d], story)
	field.text("ID_LABEL_1", "Normal")
	if story:
		var island := DB.island(island_id)
		_field_art.texture = DB.island_art(island_id)
		field.text("ID_islandName", String(island.name))
		field.select_tab(FIELD_TABS.values(), FIELD_TABS[difficulty])
		var hard_open := Save.is_island_unlocked(island_id, "hard")
		var hell_open := Save.is_island_unlocked(island_id, "hell")
		field.show("ID_IMAGE_2", not hard_open)
		field.show("ID_IMAGE_3", not hell_open)
		field.show("ID_LABEL_2", hard_open)
		field.show("ID_LABEL_3", hell_open)
		var info: Dictionary = island.difficulties[difficulty]
		var cleared := Save.cleared_stages(island_id, difficulty)
		var story_text: String = Tutorial.data().get("island_text", {}).get(island_id, "")
		if int(island.order) >= 2:
			story_text += "\nReward: %d Gems (Normal Mode)" % StageBuilder.ISLAND_CLEAR_GEMS[clampi(int(island.order), 0, 7)]
		if story_text == "":
			story_text = "%d / %d stages cleared." % [cleared, info.stages.size()]
		field.text("ID_EXtext", story_text.strip_edges())
		for i in range(0, mini(cleared, info.stages.size() - 1) + 1):
			var q := StageBuilder.story_quest(island, difficulty, i)
			var row := _field_slot(q, String(info.stages[i].name), i < cleared, true, i == cleared, _start_story.bind(i))
			row.set_meta("stage", i)
			rows.append(row)
	else:
		var sp := DB.special(special_id)
		_field_art.texture = DB.island_art(special_id)
		field.text("ID_islandName", String(sp.name))
		field.show("ID_IMAGE_2", false)
		var open := Save.special_available(sp)
		field.text("ID_EXtext", "%s\n%s" % [DB.special_days_text(sp), sp.desc])
		if sp.get("chain", false):
			if not _chain_tab_open(sp, difficulty):
				difficulty = "normal"
			field.select_tab(FIELD_TABS.values(), FIELD_TABS[difficulty])
			for d in ["hard", "hell"]:
				field.show(FIELD_TABS[d], true)
			field.show("ID_IMAGE_2", not _chain_tab_open(sp, "hard"))
			field.show("ID_IMAGE_3", not _chain_tab_open(sp, "hell"))
			field.show("ID_LABEL_2", _chain_tab_open(sp, "hard"))
			field.show("ID_LABEL_3", _chain_tab_open(sp, "hell"))
			var idx := _chain_fields(sp, difficulty)
			for k in idx.size():
				var i: int = idx[k]
				if k > 0 and not _special_cleared(sp, idx[k - 1]):
					break
				var cleared := _special_cleared(sp, i)
				var row := _field_slot(StageBuilder.special_quest(sp, i), String(sp.quests[i].name), cleared, open, not cleared, _start_special.bind(i))
				row.set_meta("stage", i)
				rows.append(row)
		else:
			field.select_tab(FIELD_TABS.values(), "ID_tapBtn1")
			for i in sp.quests.size():
				var q := StageBuilder.special_quest(sp, i)
				var cleared: bool = Save.data.special_clears.has(q.key)
				var row := _field_slot(q, String(sp.quests[i].name), cleared, open, false, _start_special.bind(i))
				row.set_meta("stage", i)
				rows.append(row)
	_stage_slots = rows
	field.list_into("ID_arrayPosition", rows)


func _chain_fields(sp: Dictionary, tab_name: String) -> Array:
	var out := []
	for i in sp.quests.size():
		if String(sp.quests[i].get("tab", "normal")) == tab_name:
			out.append(i)
	return out


func _special_cleared(sp: Dictionary, index: int) -> bool:
	return Save.data.special_clears.has("%s/%d" % [sp.id, index])


func _chain_tab_open(sp: Dictionary, tab_name: String) -> bool:
	var at := DB.DIFFICULTIES.find(tab_name)
	if at <= 0:
		return true
	var prev := _chain_fields(sp, String(DB.DIFFICULTIES[at - 1]))
	var need := int(sp.get("chain_unlock", CHAIN_UNLOCK_FIELD))
	return prev.size() >= need and _special_cleared(sp, prev[need - 1]) and _chain_tab_open(sp, String(DB.DIFFICULTIES[at - 1]))


func _field_slot(q: Dictionary, name_text: String, cleared: bool, playable: bool, is_new: bool, start: Callable) -> Control:
	var s := Layout.instance("R_fieldSlot")
	s.text("ID_LABEL_1", "Rank")
	var best := float(Save.data.best_times.get(String(q.key), 0.0))
	var rt := s.text("ID_rankText2", ("%d:%02d" % [int(best) / 60, int(best) % 60]) if best > 0.0 else "No Record")
	rt.add_theme_color_override("font_color", Color("ffe14a") if best <= 0.0 else UI.CREAM)
	rt.add_theme_font_size_override("font_size", 16)
	var drops: bool = q.get("drops", true)
	s.show("ID_rewardCube", drops)
	if drops:
		s.on("ID_rewardCube", _show_drops.bind(q))
	s.text("ID_LABEL_1_1", "Monster")
	var red := float(q.get("red_cube_chance", 0.0)) > 0.0
	s.show("ID_IMAGE_red", red)
	s.show("ID_IMAGE_3", not red)
	var gems := int(q.get("gems", 0))
	s.show("ID_IMAGE_2", gems == 0)
	s.text("ID_ePoint", str(int(q.energy)))
	if int(q.get("fp", 0)) > 0:
		s.text("ID_ePoint", str(int(q.fp)))
		s.set_image("ID_IMAGE_2", UI.tex("betaUI00/I_fPoint_02.png"))
	s.show("ID_IMAGE_crystal", gems > 0)
	s.text("ID_cPoint_1", str(gems))
	s.show("ID_IMAGE_1", false)
	s.show("ID_penalty", false)
	s.text("ID_fieldName", name_text)
	s.show("ID_new", is_new)
	var where := String(q.get("island_id", q.get("special_id", "")))
	var strip := "res://assets/fields/%s_%d.png" % [where, int(q.get("stage_index", -2)) + 1]
	if q.get("bg", "") != "":
		strip = "res://assets/fields/%s.png" % q.bg
	var backdrop := StageBuilder.stage_backdrop(where, int(q.get("stage_index", -1)))
	if backdrop != "" and String(q.get("kind", "")) == "story":
		strip = "res://assets/fields/%s.png" % backdrop
	if not ResourceLoader.exists(strip):
		strip = "res://assets/fields/%s.png" % where
	if ResourceLoader.exists(strip):
		s.set_image("ID_fieldImage", load(strip))
	if _rounded == null:
		var sh := Shader.new()
		sh.code = ROUNDED
		_rounded = ShaderMaterial.new()
		_rounded.shader = sh
	s.node("ID_fieldImage").material = _rounded
	s.show("ID_reward", Events.affects(where, String(q.get("difficulty", ""))))
	Events.tag(s.node("ID_reward"), where, String(q.get("difficulty", "")))
	var boss_card := UI.monster_card(q.boss, 0, 0, Vector2(92, 92))
	boss_card.mouse_filter = MOUSE_FILTER_IGNORE
	s.put("ID_monIcon", boss_card)
	if not playable:
		s.node("ID_slot").modulate = Color(0.6, 0.6, 0.6)
	s.on("ID_slot", start if playable else func(): UI.toast(self, "Clear the previous stage first!"))
	if playable:
		s.sound(["ID_slot"], "stage_select")
	return s.root


func _show_drops(q: Dictionary) -> void:
	tut_notify("drops:%d" % int(q.get("stage_index", q.get("quest_index", 0))))
	var ids: Array = [] if not Array(q.get("drop_pool", [])).is_empty() else [String(q.boss)]
	for e in (q.drop_pool if not Array(q.get("drop_pool", [])).is_empty() else q.enemies):
		if not String(e) in ids:
			ids.append(String(e))
	ids.sort_custom(func(a, b): return int(DB.monster(a).get("stars", 1)) > int(DB.monster(b).get("stars", 1)))
	var d := Layout.load_into(self, "R_d_fieldReward")
	d.root.z_index = 80
	d.node("ID_9PATCH_2").mouse_filter = MOUSE_FILTER_STOP
	var parts := String(q.title).split("  ·  ")
	UI.fit_text(d.text("ID_titleText", parts[parts.size() - 1] if q.kind == "special" else parts[0]), 30, 18)
	var rows := []
	var row: HBoxContainer
	for i in maxi(6, ceili(ids.size() / 3.0) * 3):
		if i % 3 == 0:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			rows.append(row)
		var cell: Control
		if i < ids.size():
			cell = UI.monster_card(String(ids[i]), 1, 0, Vector2(94, 94))
		else:
			cell = UI.image(UI.tex("betaUI00/B_monEmpty_06.png"), Vector2(94, 94))
			cell.custom_minimum_size = Vector2(94, 94)
		cell.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_child(cell)
	d.list_into("ID_arrayPosition", rows, 6)
	var root := d.root
	d.on("ID_btnOk", root.queue_free)


func _start_story(stage_index: int) -> void:
	var q := StageBuilder.story_quest(DB.island(island_id), difficulty, stage_index)
	_launch(q, {"island": island_id, "difficulty": difficulty, "stage": stage_index})


func _start_special(index: int) -> void:
	var sp := DB.special(special_id)
	if not Save.special_available(sp):
		_offer_unlock(special_id)
		return
	_launch(StageBuilder.special_quest(sp, index), {"special": special_id, "difficulty": difficulty})


func _launch(q: Dictionary, story_args: Dictionary) -> void:
	if Save.team_members().is_empty():
		UI.toast(self, "Your squad is empty!")
		return
	if Save.inventory_full() and not tutorial_active():
		UI.inventory_full(self, func(): main.go("squad", {"mode": "train"}))
		return
	tut_notify("stage:%d" % int(story_args.get("stage", q.get("quest_index", 0))))
	var a := story_args.duplicate()
	a["quest"] = q
	main.go("ready", a)


func tutorial_target(name: String) -> Control:
	if name.begins_with("island:"):
		var id := name.trim_prefix("island:")
		var want := "story" if not DB.island(id).is_empty() else "special"
		if tab != want:
			_set_tab(want)
		var entries: Array = DB.islands if tab == "story" else DB.special_islands
		for n in entries.size():
			if String(entries[n].id) == id:
				_scroll_x = maxf(0.0, LAND_STEP * n - LAND_STEP)
				_apply_scroll()
				return strip.node("ID_btnLand%d" % (n + 1))
	for prefix in ["stage:", "drops:"]:
		if name.begins_with(prefix):
			var i := int(name.trim_prefix(prefix))
			for row in _stage_slots:
				if int((row as Control).get_meta("stage", -1)) == i:
					for c in (row as Control).find_children("ID_slot" if prefix == "stage:" else "ID_rewardCube", "", true, false):
						return c
	return null
