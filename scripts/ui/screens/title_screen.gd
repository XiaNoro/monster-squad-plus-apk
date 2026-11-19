extends Screen

const SPLASH_FADE := 0.4
const SPLASH_HOLD := 4.0
const STAGE_MIN := 0.35
const MENU_LAYOUTS := ["R_main", "R_top2", "B_navigation", "R_teamEditPage", "R_comMainPage", "R_islandChoicePage", "R_fieldChoicePage", "R_islandSlot", "R_readyPage", "R_shopPage", "R_d_hotTime", "R_d_buy", "R_d_fieldReward"]
const MENU_FX := ["ui_btn_hottime_1", "c_levelup_1", "u_lightburst_01", "u_particleburst_01", "u_bluebackstripe_01", "u_starburst_02", "u_particleloop_01"]
const LOGO_REGION := Rect2(256, 260, 553, 123)
const LOGO_NEXON_W := 407.0
const LOGO_SCALE := 0.69

var lay: Layout
var _name_edit: LineEdit
var _dialog: Layout
var _ready_to_tap := false
var _booting := false
var _catcher: Control
var _spinner: Spinner
var _stages: Array = []


func build() -> void:
	_preload()
	UI.background(self, UI.tex("betaTitle00/title.png"))
	lay = Layout.load_into(self, "R_logInPage")
	lay.hide_all(["ID_btnGoogle", "ID_btnGameCenter", "ID_btnFacebook", "ID_BUTTON_DS", "ID_9PATCH_1", "ID_btnGuest"])
	var ver := lay.text("ID_LABEL_Version", "Version : %s" % OptionsPopup.version())
	ver.position = Vector2(8, 4)
	ver.add_theme_font_size_override("font_size", 16)
	lay.node("ID_9PATCH_GRAPH").visible = false
	lay.on("ID_btnGuest", _on_login)
	_catcher = Control.new()
	_catcher.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_catcher.mouse_filter = MOUSE_FILTER_STOP
	_catcher.gui_input.connect(_on_tap)
	add_child(_catcher)
	var tw := lay.node("ID_btnGuest1").create_tween().set_loops()
	tw.tween_property(lay.node("ID_btnGuest1"), "modulate:a", 0.55, 0.8)
	tw.tween_property(lay.node("ID_btnGuest1"), "modulate:a", 1.0, 0.8)
	var build := UI.label("Test Build Version %s" % OptionsPopup.version(), 22, Color("ffe23a"))
	build.add_theme_color_override("font_outline_color", Color.BLACK)
	build.add_theme_constant_override("outline_size", 6)
	build.set_anchors_preset(PRESET_BOTTOM_LEFT)
	build.grow_vertical = GROW_DIRECTION_BEGIN
	build.offset_left = 16
	build.offset_right = 16
	build.offset_top = -38
	build.offset_bottom = -38
	build.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(build)
	_spinner = Spinner.new()
	_spinner.size = Vector2(56, 56)
	_spinner.position = Vector2(533, 470) - _spinner.size / 2.0
	_spinner.visible = false
	_spinner.z_index = 60
	add_child(_spinner)
	if args.has("ask"):
		_show_title()
		_ask_name()
	else:
		_splash()


func _splash() -> void:
	var white := ColorRect.new()
	white.color = Color.WHITE
	white.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	white.mouse_filter = MOUSE_FILTER_STOP
	white.z_index = 90
	add_child(white)
	var tex := UI.tex("res://assets/apk/images/Logo_Developer.png")
	var left := AtlasTexture.new()
	left.atlas = tex
	left.region = Rect2(LOGO_REGION.position, Vector2(LOGO_NEXON_W, LOGO_REGION.size.y))
	var right := AtlasTexture.new()
	right.atlas = tex
	right.region = LOGO_REGION
	var gap := 37.0
	var lw := LOGO_NEXON_W * LOGO_SCALE
	var rw := LOGO_REGION.size.x * LOGO_SCALE
	var h := LOGO_REGION.size.y * LOGO_SCALE
	var x := (size.x - (lw + rw + gap * 2.0 + 2.0)) / 2.0
	var y := size.y * 0.48 - h / 2.0
	var a := UI.image(left, Vector2(lw, h), TextureRect.STRETCH_SCALE)
	a.position = Vector2(x, y)
	a.size = Vector2(lw, h)
	white.add_child(a)
	var bar := ColorRect.new()
	bar.color = Color("2b2b2b")
	bar.position = Vector2(x + lw + gap, y + h / 2.0 - 52.0)
	bar.size = Vector2(2, 104)
	white.add_child(bar)
	var b := UI.image(right, Vector2(rw, h), TextureRect.STRETCH_SCALE)
	b.position = Vector2(x + lw + gap * 2.0 + 2.0, y)
	b.size = Vector2(rw, h)
	white.add_child(b)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	black.mouse_filter = MOUSE_FILTER_IGNORE
	black.z_index = 91
	add_child(black)
	var tw := create_tween()
	tw.tween_property(black, "modulate:a", 0.0, SPLASH_FADE)
	tw.tween_interval(SPLASH_HOLD)
	tw.tween_callback(func():
		black.queue_free()
		white.queue_free()
		_show_title())


func _show_title() -> void:
	Sfx.play_music("title")
	lay.node("ID_btnGuest").visible = true
	_ready_to_tap = true


func _boot(screen: String, screen_args: Dictionary) -> void:
	if _booting:
		return
	_booting = true
	_ready_to_tap = false
	lay.node("ID_btnGuest").visible = false
	lay.node("ID_9PATCH_1").visible = true
	_spinner.visible = true
	_preload()
	lay.text("ID_LABEL_Percent", "Reading save data")
	await get_tree().create_timer(STAGE_MIN).timeout
	for st in _stages:
		await _stage(String(st[0]), st[1])
	lay.text("ID_LABEL_Percent", "Loading menus")
	for page in MENU_LAYOUTS:
		Layout.parse(page)
		await get_tree().process_frame
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.mouse_filter = MOUSE_FILTER_STOP
	dim.z_index = 50
	add_child(dim)
	lay.text("ID_LABEL_Percent", "Starting game")
	await create_tween().tween_property(dim, "color:a", 0.6, 0.25).finished
	main.go(screen, screen_args)


func _preload() -> void:
	var owned := {}
	for m in Save.data.monsters:
		owned[String(m.id)] = true
	var team := []
	for m in Save.team_members():
		team.append(String(m.id))
	var fx := []
	for sheet in MENU_FX:
		fx.append_array(FrameFx.paths(sheet))
	_stages = [
		["Loading monsters", Preloader.monster_paths(owned.keys(), false) + Preloader.monster_paths(team, true)],
		["Loading screens", Main.SCREENS.values()],
		["Loading animations", fx],
		["Loading sounds", Sfx.menu_paths()],
	]
	for st in _stages:
		Preloader.request(st[1])


func _stage(label: String, paths: Array) -> void:
	var start := Time.get_ticks_msec()
	var total := maxi(paths.size(), 1)
	while true:
		var waiting := Preloader.left(paths)
		lay.text("ID_LABEL_Percent", "%s  %d%%" % [label, roundi(100.0 * (total - waiting) / total)])
		var spent := (Time.get_ticks_msec() - start) / 1000.0
		if (waiting == 0 and spent >= STAGE_MIN) or spent > 20.0:
			return
		await get_tree().process_frame


func _on_tap(e: InputEvent) -> void:
	if UI.pressed(e):
		_on_login()


func _unhandled_key_input(e: InputEvent) -> void:
	if e.is_pressed() and not e.is_echo() and (e.is_action("ui_accept") or (e is InputEventKey and e.keycode == KEY_SPACE)):
		_on_login()


func _on_login() -> void:
	if not _ready_to_tap or (_dialog != null and is_instance_valid(_dialog.root)):
		return
	Sfx.play("click")
	if Save.is_new_game():
		_ask_name()
	else:
		_boot("hub", {})


func _ask_name() -> void:
	if _dialog != null and is_instance_valid(_dialog.root):
		return
	_dialog = Layout.load_into(self, "R_d_idInput")
	_dialog.root.z_index = 80
	_dialog.node("ID_9PATCH_2").mouse_filter = MOUSE_FILTER_STOP
	var info := _dialog.node("ID_baseText") as Label
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", UI.BROWN)
	info.add_theme_font_size_override("font_size", 22)
	var box := _dialog.node("ID_9PATCH_3")
	_name_edit = LineEdit.new()
	_name_edit.max_length = 12
	_name_edit.placeholder_text = "Nickname"
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.add_theme_font_size_override("font_size", 28)
	_name_edit.add_theme_color_override("font_color", Color.WHITE)
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "focus", "read_only"]:
		_name_edit.add_theme_stylebox_override(st, empty)
	_name_edit.position = Vector2(10, 4)
	_name_edit.size = box.size - Vector2(20, 8)
	_name_edit.text_submitted.connect(func(_t): _confirm_name())
	box.add_child(_name_edit)
	_name_edit.grab_focus.call_deferred()
	_dialog.on("ID_btnOk", _confirm_name)
	_dialog.on("ID_btnEsc", _close_name)


func _close_name() -> void:
	if _dialog != null:
		_dialog.root.queue_free()
	_dialog = null


func _confirm_name() -> void:
	var n := _name_edit.text.strip_edges()
	var info := _dialog.node("ID_baseText") as Label
	if n.length() < 2 or n.length() > 12:
		info.text = "Please enter a nickname. (Limit 2-12 characters)"
		info.add_theme_color_override("font_color", Color("c0301a"))
		return
	var bad := RegEx.create_from_string("[^A-Za-z0-9_ .\\-]")
	if bad.search(n) != null:
		info.text = "Letters, numbers, spaces and _ . - only."
		info.add_theme_color_override("font_color", Color("c0301a"))
		return
	_close_name()
	_boot("starter", {"name": n})


class Spinner extends Control:
	func _process(delta: float) -> void:
		rotation += delta * TAU * 1.1
		pivot_offset = size / 2.0

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 4.0
		draw_arc(c, r, 0.0, TAU * 0.8, 40, Color(0.35, 0.18, 0.02, 0.8), 8.0, true)
		draw_arc(c, r, 0.0, TAU * 0.8, 40, Color("ffb21e"), 5.0, true)
		draw_arc(c, r - 1.0, TAU * 0.05, TAU * 0.6, 30, Color("ffe08a"), 2.0, true)
