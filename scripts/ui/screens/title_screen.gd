extends Screen

var lay: Layout
var _name_edit: LineEdit
var _dialog: Layout


func build() -> void:
	Sfx.play_music("title")
	UI.background(self, UI.tex("betaTitle00/title.png"))
	lay = Layout.load_into(self, "R_logInPage")
	lay.hide_all(["ID_btnGoogle", "ID_btnGameCenter", "ID_btnFacebook", "ID_BUTTON_DS", "ID_9PATCH_1"])
	lay.text("ID_LABEL_Version", "ver 1.02")
	lay.on("ID_btnGuest", _on_login)
	var catcher := Control.new()
	catcher.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	catcher.mouse_filter = MOUSE_FILTER_STOP
	catcher.gui_input.connect(_on_tap)
	add_child(catcher)
	var tw := lay.node("ID_btnGuest1").create_tween().set_loops()
	tw.tween_property(lay.node("ID_btnGuest1"), "modulate:a", 0.55, 0.8)
	tw.tween_property(lay.node("ID_btnGuest1"), "modulate:a", 1.0, 0.8)
	if not Save.is_new_game():
		var hello := UI.label("Welcome back, %s" % String(Save.data.get("name", "Tamer")), 22, Color.WHITE)
		hello.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
		hello.grow_horizontal = GROW_DIRECTION_BOTH
		hello.grow_vertical = GROW_DIRECTION_BEGIN
		hello.position.y -= 14
		hello.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(hello)
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
	if args.has("ask"):
		_ask_name()


func _on_tap(e: InputEvent) -> void:
	if UI.pressed(e):
		_on_login()


func _unhandled_key_input(e: InputEvent) -> void:
	if e.is_pressed() and not e.is_echo() and (e.is_action("ui_accept") or (e is InputEventKey and e.keycode == KEY_SPACE)):
		_on_login()


func _on_login() -> void:
	if _dialog != null and is_instance_valid(_dialog.root):
		return
	Sfx.play("click")
	if Save.is_new_game():
		_ask_name()
	else:
		main.go("hub")


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
	Save.start_new_game()
	Save.data["name"] = n
	Save.save_game()
	_close_name()
	main.go("hub")
