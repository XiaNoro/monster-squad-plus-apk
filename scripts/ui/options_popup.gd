class_name OptionsPopup
extends RefCounted

const REDDIT := "https://www.reddit.com/r/MonsterSquadPlus/"
const CONTACT := "https://docs.google.com/forms/d/e/1FAIpQLSeSB7qyAq2aw3BGGt4xrt4R3ALOLHt5Nb8kVqEoc_exFRZ7Vw/viewform?usp=sharing&ouid=101750475954034027843"
const NOTICE := "Monster Squad Plus a Offline Remake by Xia<3,\nProgress is saved on device"
const INK :=Color("6b4420")
const CREDITS := [["Character Art", "For_nut/Coffie Cat"], ["Animations & iOS Build", "MKEscortYT"]]


static func version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", ""))


static func open(screen: Screen) -> void:
	var root := ColorRect.new()
	root.name = "Options"
	root.color = Color(0, 0, 0, 0.6)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.z_index = 48
	screen.add_child(root)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var paper := PanelContainer.new()
	paper.custom_minimum_size = Vector2(980, 590)
	paper.add_theme_stylebox_override("panel", UI._box("betaUI00/9_Back_01.png", 40, 30))
	center.add_child(paper)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	paper.add_child(cols)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 16)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var sound := _panel(left, true)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 50)
	grid.add_theme_constant_override("v_separation", 16)
	sound.add_child(grid)
	_toggle(grid, "BGM", func(): return Sfx.enabled.get("Music", true), func(on: bool): Sfx.set_enabled("Music", on))
	_toggle(grid, "Sound FX", func(): return Sfx.enabled.get("SFX", true), func(on: bool): Sfx.set_enabled("SFX", on))
	_toggle(grid, "Fullscreen", func(): return Sfx.resolution == "fullscreen", func(on: bool): Sfx.set_resolution("fullscreen" if on else "1280x720"))
	var sliders := VBoxContainer.new()
	sliders.add_theme_constant_override("separation", 14)
	sound.add_child(sliders)
	for spec in [["Volume", "Master"], ["Music", "Music"], ["Sound", "SFX"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := _ink(spec[0], 22)
		l.custom_minimum_size.x = 100
		row.add_child(l)
		var s := _slider(spec[1])
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(s)
		sliders.add_child(row)

	var acct := _panel(left, false)
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 20)
	arow.alignment = BoxContainer.ALIGNMENT_CENTER
	acct.add_child(arow)
	arow.add_child(_flat("Reset save", screen._confirm_reset))
	arow.add_child(_flat("Quit", _confirm_quit.bind(screen)))

	var right := _panel(cols, true)
	right.custom_minimum_size.x = 430
	var bgrid := GridContainer.new()
	bgrid.columns = 2
	bgrid.add_theme_constant_override("h_separation", 18)
	bgrid.add_theme_constant_override("v_separation", 14)
	right.add_child(bgrid)
	bgrid.add_child(_big("Notice", func(): UI.notice(screen, "Notice", NOTICE), "orange"))
	bgrid.add_child(_big("Our Reddit\nPage", OS.shell_open.bind(REDDIT), "orange"))
	bgrid.add_child(_big("Contact Us", OS.shell_open.bind(CONTACT), "orange"))
	bgrid.add_child(_big("Help", screen._show_tip, "green"))
	bgrid.add_child(_big("Event", func(): UI.toast(screen, Events.text() if not Events.today().is_empty() else "No event today", UI.GOLD), "green"))
	bgrid.add_child(_big("Credits", _credits.bind(screen), "green"))
	for spec in [["Export Save", _export_save], ["Load Save", _load_save]]:
		var b := _big(spec[0], spec[1].bind(screen), "blue")
		b.custom_minimum_size.y = 64
		b.add_theme_font_size_override("font_size", 24)
		bgrid.add_child(b)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(gap)
	var ver := PanelContainer.new()
	ver.add_theme_stylebox_override("panel", UI._box("betaUI00/9_Back_09.png", 20, 14))
	right.add_child(ver)
	var vl := _ink("Version : %s Test build\nSave : this device" % version(), 22)
	vl.add_theme_color_override("font_color", Color("5a3410"))
	ver.add_child(vl)

	var esc := TextureButton.new()
	esc.texture_normal = UI.tex("betaUI00/K_esc_01.png")
	var esc_back := NinePatchRect.new()
	esc_back.texture = UI.tex("betaUI00/9_btn_05.png")
	esc_back.patch_margin_left = 28
	esc_back.patch_margin_right = 28
	esc_back.patch_margin_top = 28
	esc_back.patch_margin_bottom = 28
	esc_back.show_behind_parent = true
	esc_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	esc.add_child(esc_back)
	esc.ignore_texture_size = true
	esc.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	esc.custom_minimum_size = Vector2(106, 60)
	esc.size = Vector2(106, 60)
	esc_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	esc.name = "ID_btnEsc"
	esc.pressed.connect(root.queue_free)
	Layout._press_feedback(esc)
	root.add_child(esc)
	paper.resized.connect(func(): esc.position = paper.global_position - root.global_position + Vector2(paper.size.x - 80, -22))
	Sfx.play("popup_open")


static func _panel(parent: Container, grow: bool) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI._box("betaUI00/9_Back_02.png", 15, 22))
	if grow:
		p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	return v


static func _ink(text: String, size: int) -> Label:
	var l := UI.label(text, size, INK)
	l.add_theme_constant_override("outline_size", 0)
	return l


static func _toggle(parent: Container, title: String, get_on: Callable, set_on: Callable) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(_ink(title, 24))
	var b := TextureButton.new()
	b.texture_normal = UI.tex("betaUI00/B_toggle_02.png")
	var knob := UI.image(UI.tex("betaUI00/B_toggle_01.png"))
	knob.size = knob.texture.get_size()
	b.add_child(knob)
	var l := UI.label("", 30)
	l.size = Vector2(100, 36)
	l.position = Vector2(16, 6)
	l.add_theme_color_override("font_outline_color", Color("502300"))
	l.add_theme_constant_override("outline_size", 6)
	b.add_child(l)
	var refresh := func() -> void:
		var on: bool = get_on.call()
		b.texture_normal = UI.tex("betaUI00/B_toggle_02.png" if on else "betaUI00/B_toggle_03.png")
		knob.position = Vector2(88, 2) if on else Vector2(0, 2)
		l.text = "ON" if on else "Off"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if on else HORIZONTAL_ALIGNMENT_RIGHT
		l.add_theme_color_override("font_color", Color.WHITE if on else Color("ebbe69"))
	refresh.call()
	b.pressed.connect(func():
		set_on.call(not get_on.call())
		refresh.call()
		Sfx.play("click"))
	v.add_child(b)
	parent.add_child(v)


static func _slider(bus: String) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(Sfx.volume.get(bus, 1.0))
	s.custom_minimum_size = Vector2(200, 34)
	s.value_changed.connect(func(v: float): Sfx.set_volume(bus, v))
	if bus != "Music":
		s.drag_ended.connect(func(_changed: bool): Sfx.play("buff"))
	return s


static func _flat(text: String, cb: Callable) -> Button:
	var b := UI.button(text, cb, "orange", Vector2(190, 58), 22)
	for st in ["normal", "hover", "pressed"]:
		var sb := UI._box("betaUI00/9_Back_09.png", 20, 10)
		sb.modulate_color = Color(1.1, 1.1, 1.1) if st == "hover" else (Color(0.85, 0.85, 0.85) if st == "pressed" else Color.WHITE)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color("ffe6b4"))
	b.add_theme_color_override("font_hover_color", Color("ffe6b4"))
	b.add_theme_color_override("font_pressed_color", Color("ffe6b4"))
	b.add_theme_constant_override("outline_size", 0)
	return b


static func _big(text: String, cb: Callable, color: String) -> Button:
	var b := UI.button(text, cb, color, Vector2(196, 96), 26 if not "\n" in text else 23)
	b.add_theme_color_override("font_outline_color", {"orange": Color("6a2a00"), "blue": Color("0c3566")}.get(color, Color("1e4a00")))
	b.add_theme_constant_override("outline_size", 7)
	return b


static func _credits(screen: Screen) -> void:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.custom_minimum_size = Vector2(460, 0)
	for c in CREDITS:
		var role := _ink(c[0], 22)
		role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var who := UI.label(c[1], 30, Color("ffe23a"))
		who.add_theme_color_override("font_outline_color", Color("5a2a00"))
		who.add_theme_constant_override("outline_size", 7)
		who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var pair := VBoxContainer.new()
		pair.add_theme_constant_override("separation", 2)
		pair.add_child(role)
		pair.add_child(who)
		body.add_child(pair)
	var d := UI.dialog(screen, "Credits", body, [{"text": "OK", "color": "yellow"}])
	d.z_index = 60


static func _pick_file(screen: Screen, title: String, mode: FileDialog.FileMode, cb: Callable) -> void:
	var fd := FileDialog.new()
	fd.title = title
	fd.use_native_dialog = true
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = mode
	fd.filters = PackedStringArray(["*.%s ; Monster Squad+ save" % Save.EXPORT_EXT])
	fd.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if mode == FileDialog.FILE_MODE_SAVE_FILE:
		fd.current_file = "MonsterSquadPlus_%s.%s" % [Time.get_date_string_from_system(), Save.EXPORT_EXT]
	fd.file_selected.connect(func(path: String):
		fd.queue_free()
		cb.call(path))
	fd.canceled.connect(fd.queue_free)
	screen.add_child(fd)
	fd.popup_centered_ratio(0.7)


static func _export_save(screen: Screen) -> void:
	_pick_file(screen, "Export Save", FileDialog.FILE_MODE_SAVE_FILE, func(path: String):
		if Save.export_to(path):
			UI.notice(screen, "Export Save", "Save exported to\n" + path)
		else:
			UI.notice(screen, "Export Save", "Couldn't write the save there."))


static func _load_save(screen: Screen) -> void:
	_pick_file(screen, "Load Save", FileDialog.FILE_MODE_OPEN_FILE, func(path: String):
		var saved := Save.read_export(path)
		if saved.is_empty():
			UI.notice(screen, "Load Save", "That file isn't a Monster Squad+ save.")
			return
		UI.confirm(screen, "Load Save", "Load %s's save (%d monsters)?\nYour current progress will be replaced." % [saved.get("name", "Tamer"), saved.monsters.size()], _import.bind(screen, saved)))


static func _import(screen: Screen, saved: Dictionary) -> void:
	Save.import_save(saved)
	screen.main.go("title")


static func _confirm_quit(screen: Screen) -> void:
	UI.confirm(screen, "Quit Game", "Quit Monster Squad+?\nYour progress is saved.", _quit.bind(screen))


static func _quit(screen: Screen) -> void:
	Save.save_game()
	screen.get_tree().quit()
