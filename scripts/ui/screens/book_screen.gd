extends Screen

const TABS := {"all": "ID_btnAtt1", "fire": "ID_btnAtt2", "water": "ID_btnAtt3", "nature": "ID_btnAtt4", "normal": "ID_btnAtt5"}
const SORTS := ["All", "Owned", "Missing"]
const COLS := 7

var lay: Layout
var _filter := "all"
var _sort := 0
var _number: Dictionary = {}
var _lv30: Dictionary = {}


func build() -> void:
	brown_background()
	lay = Layout.load_into(self, "B_monBookPage")
	add_top_bar("2", "Index", "hub")
	for f in TABS:
		lay.on(TABS[f], _set_filter.bind(f))
	lay.on("ID_btnAlign", _next_sort)
	var hint := lay.text("ID_exText", "You will get 3~15 Gems in your Mailbox every time you get a monster to Lv. 30 for the first time!")
	UI.fit_text(hint, 18, 13, hint.get_meta("area").x)
	hint.set_deferred("size", hint.get_meta("area"))
	_number_monsters()
	_lv30 = Save.data.get("maxed", {}).duplicate()
	for m in Save.data.monsters:
		if int(m.level) >= DB.MAX_LEVEL:
			_lv30[String(m.id)] = true
	_set_filter("all")
	if args.has("detail"):
		_show_detail(String(args.detail))


func _number_monsters() -> void:
	for id in DB.monsters:
		_number[id] = DB.dex_number(id)


func _set_filter(f: String) -> void:
	_filter = f
	lay.select_tab(TABS.values(), TABS[f])
	_refresh()


func _next_sort() -> void:
	_sort = (_sort + 1) % SORTS.size()
	_refresh()


func _refresh() -> void:
	var ids := DB.ids_where(func(m): return _filter == "all" or m.element == _filter)
	ids.sort_custom(func(a, b): return _number[a] < _number[b])
	var owned := 0
	for id in ids:
		if Save.data.owned.has(id):
			owned += 1
	lay.text("ID_numText", str(owned))
	lay.text("ID_maxText", "/%d" % ids.size())
	lay.text("ID_LABEL_4", SORTS[_sort]).add_theme_font_size_override("font_size", 20)
	match SORTS[_sort]:
		"Owned":
			ids = ids.filter(func(id): return Save.data.owned.has(id))
		"Missing":
			ids = ids.filter(func(id): return not Save.data.owned.has(id))
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for id in ids:
		grid.add_child(_cell(id))
	lay.list_into("ID_ID_arrayPosition", [grid])


func _cell(id: String) -> Control:
	var known: bool = Save.data.owned.has(id)
	var seen: bool = Save.data.seen.has(id)
	var box := Control.new()
	box.custom_minimum_size = Vector2(92, 92)
	box.mouse_filter = MOUSE_FILTER_STOP
	if known or seen:
		var c := UI.monster_card(id, 0, 0, Vector2(92, 92))
		c.mouse_filter = MOUSE_FILTER_IGNORE
		if not known:
			_grey(c)
		box.add_child(c)
		if _lv30.has(id):
			var badge := UI.image(Layout.texture("K_level30_01.png"), Vector2(36, 36))
			badge.size = Vector2(36, 36)
			badge.position = Vector2(56, 56)
			badge.mouse_filter = MOUSE_FILTER_IGNORE
			box.add_child(badge)
	else:
		var back := UI.image(UI.tex("betaUI00/B_monEmpty_03.png"), Vector2(92, 92))
		back.size = Vector2(92, 92)
		box.add_child(back)
	box.tooltip_text = "No.%03d  %s" % [int(_number[id]), String(DB.monster(id).name) if known or seen else "???"]
	box.gui_input.connect(_on_cell.bind(id, known or seen))
	return box


static var _grey_mat: ShaderMaterial


static func _grey(c: CanvasItem) -> void:
	if _grey_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV) * COLOR;\n\tfloat g = dot(c.rgb, vec3(0.299, 0.587, 0.114));\n\tCOLOR = vec4(mix(vec3(g), c.rgb, 0.4) * 0.62, c.a);\n}\n"
		_grey_mat = ShaderMaterial.new()
		_grey_mat.shader = sh
	c.material = _grey_mat
	for k in c.get_children():
		if k is CanvasItem:
			_grey(k)


func _on_cell(e: InputEvent, id: String, visible_entry: bool) -> void:
	if not UI.tapped(e):
		return
	if not visible_entry:
		UI.toast(self, "Not discovered yet")
		return
	_show_detail(id)


func _show_detail(id: String) -> void:
	var def := DB.monster(id)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.z_index = 45
	dim.mouse_filter = MOUSE_FILTER_STOP
	add_child(dim)
	var d := Layout.load_into(dim, "B_detailPage")
	var known: bool = Save.data.owned.has(id)
	dim.gui_input.connect(_close_detail.bind(dim))
	for p in ["ID_team1", "ID_detailSkill", "ID_detailEvolution"]:
		d.node(p).mouse_filter = MOUSE_FILTER_STOP
	var field: Control = d.node("ID_IMAGE_2")
	var sh: Control = d.node("ID_leaderS")
	var tex := DB.battle_sprite(id)
	var bx := Vector2(260, 230)
	var drawn := bx
	if tex.get_width() > 0:
		drawn = tex.get_size() * minf(bx.x / tex.get_width(), bx.y / tex.get_height())
	var art: Control = UI.living(tex, drawn) if known else UI.image(tex, drawn)
	art.size = drawn
	art.position = Vector2(sh.position.x + sh.size.x / 2.0 - drawn.x / 2.0, sh.position.y + sh.size.y * 0.55 - drawn.y)
	var seen: bool = known or Save.data.seen.has(id)
	if not seen:
		art.modulate = Color(0.05, 0.05, 0.08, 0.9)
	elif not known:
		_grey(art)
	field.add_child(art)
	field.move_child(art, sh.get_index() + 1)
	var stars := int(def.stars)
	for g in 6:
		d.show("ID_detailGrade%d" % (g + 1), g < stars)
	d.set_image("ID_detailAtt", Layout.texture({"fire": "A_fire_04.png", "water": "A_water_04.png", "nature": "A_natural_04.png"}.get(def.element, "A_balance_04.png")))
	d.text("ID_detailLevel_2_1", "")
	var nm := d.text("ID_detailName", "No.%03d  %s" % [int(_number[id]), String(def.name) if seen else "???"])
	nm.position.x -= 100
	nm.size.x += 100
	d.hide_all(["ID_iconExp", "ID_exp", "ID_btnSell"])
	var st := DB.stats_at(id, 1, 0)
	var rows := [["hp", "HP", st.hp], ["ap", "ATK", st.atk], ["dp", "DEF", st.def], ["re", "REC", st.rec],
		["mana", "MP", st.mp], ["mare", "MP Regen", "%d/s" % int(BattleEngine.MP_REGEN)], ["atsp", "Speed", "1.0"], ["cr", "Critical", "5%"]]
	for r in rows:
		d.text("ID_%sLabel" % r[0], r[1]).add_theme_font_size_override("font_size", 16)
		d.text("ID_text" + String(r[0]).capitalize(), str(r[2]) if known else "???")
	d.text("ID_LABEL_5", "Skill Info")
	d.text("ID_LABEL_4", "Evolution")
	d.text("ID_LABEL_11", "Evolution")
	d.text("ID_LABEL_3", "Skill Info")
	d.text("ID_LABEL_7", "Team Effect")
	d.text("ID_LABEL_1", "Leader Skills")
	d.text("ID_LABEL_6", "Support Skill")
	d.text("ID_LABEL_10", "Materials")
	d.text("ID_LABEL_10_1", "Evolution Stages")
	d.hide_all(["ID_btnPride1", "ID_btnPrefer1", "ID_btnPride2", "ID_btnPrefer2", "ID_detailEvolution"])
	var eff := d.text("ID_ef1Text", "- ???" if not known else (("- " + String(def.passive)) if String(def.passive) != "" else "- None"))
	eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eff.add_theme_font_size_override("font_size", 16)
	var skill_ids := ["ID_leaderSkill1", "ID_leaderSkill2", "ID_leaderSkill3", "ID_leaderSkill4", "ID_leaderSkill5"]
	for k in skill_ids.size():
		var s: Dictionary = def.skills[k] if k < def.skills.size() else {}
		d.show("ID_PLock%d" % (k + 1), s.is_empty())
		if not s.is_empty() and known:
			_book_skill(d, skill_ids[k], String(s.icon), "%s (%d MP): %s" % [s.name, int(s.mp), s.description])
	var sup: Dictionary = def.support_skill
	d.show("ID_sLock1", String(sup.get("name", "")) == "")
	if String(sup.get("name", "")) != "" and known:
		_book_skill(d, "ID_surportSkill1", String(sup.icon), "%s (every %ds): %s" % [sup.name, int(sup.cooldown), sup.description])
	d.on("ID_btnEvolution", _flip.bind(d, true))
	d.on("ID_btnSkill", _flip.bind(d, false))
	var chain: Array = def.get("evolution_tree", [])
	for k in 4:
		var has := k < chain.size()
		d.show("ID_lock%d" % (k + 1), not has)
		d.show("ID_step%d" % (k + 1), not has)
		if has:
			var cid := String(chain[k].monster)
			var c := UI.monster_card(cid, 0, 0, Vector2(92, 92), not Save.data.owned.has(cid))
			c.mouse_filter = MOUSE_FILTER_IGNORE
			d.put("ID_monIcon%d" % (k + 1), c)
	var mat := String(def.get("evolve_material", ""))
	if mat != "" and String(def.evolves_into) != "":
		for k in mini(3, maxi(1, int(def.get("evolve_quantity", 1)))):
			var mc := UI.monster_card(mat, 0, 0, Vector2(92, 92), not Save.data.owned.has(mat))
			mc.mouse_filter = MOUSE_FILTER_IGNORE
			d.put("ID_make%d" % (k + 1), mc)


func _book_skill(d: Layout, holder: String, icon_file: String, text: String) -> void:
	var t := DB.skill_icon(icon_file)
	if t == null:
		return
	var r := UI.image(t, Vector2(74, 74))
	r.size = Vector2(74, 74)
	r.mouse_filter = MOUSE_FILTER_STOP
	d.put(holder, r)
	UI.tip(r, text)


func _close_detail(e: InputEvent, dim: Control) -> void:
	if UI.pressed(e):
		dim.queue_free()


func _flip(d: Layout, evolution: bool) -> void:
	d.show("ID_detailSkill", not evolution)
	d.show("ID_detailEvolution", evolution)
