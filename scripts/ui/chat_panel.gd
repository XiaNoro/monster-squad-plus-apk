class_name ChatPanel
extends Control

const MAX_CHARS := 60

var screen: Screen
var ticker: ChatTicker
var lay: Layout
var input: LineEdit
var list: VBoxContainer
var scroll: ScrollContainer
var picker: Control
var _live: Timer


static func open(parent: Screen) -> ChatPanel:
	if parent.has_meta("chat_open"):
		return null
	var p := ChatPanel.new()
	p.screen = parent
	p.ticker = parent.main.ticker
	parent.set_meta("chat_open", true)
	parent.add_child(p)
	return p


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	z_index = 85
	mouse_filter = MOUSE_FILTER_STOP
	tree_exiting.connect(func():
		if is_instance_valid(screen):
			screen.remove_meta("chat_open"))
	lay = Layout.load_into(self, "R_d_notification")
	lay.node("ID_9PATCH_1").self_modulate.a = 0.88
	lay.node("ID_9PATCH_1").mouse_filter = MOUSE_FILTER_STOP
	lay.show("ID_slide_chat", false)
	lay.on("ID_Btn_chat_esc", queue_free)
	lay.sound(["ID_Btn_chat_esc"], "back")
	lay.on("ID_Btn_send", _send)
	lay.on("ID_Btn_ch", _toggle_picker)
	_build_input()
	_build_list()
	_build_picker()
	_show_channel()
	ticker.posted.connect(_on_posted)
	for b in ticker.get_children():
		if b is PanelContainer:
			b.queue_free()
	_live = Timer.new()
	_live.one_shot = true
	_live.timeout.connect(_chatter)
	add_child(_live)
	_live.start(randf_range(1.5, 4.0))


func _build_input() -> void:
	var hint := lay.node("ID_LABEL_3")
	hint.visible = false
	input = LineEdit.new()
	input.placeholder_text = "chat....."
	input.max_length = MAX_CHARS
	input.flat = true
	input.position = hint.position
	input.size = Vector2(hint.size.x + 20, hint.size.y + 6)
	input.add_theme_font_size_override("font_size", 24)
	input.add_theme_color_override("font_color", Color("fff4d6"))
	input.add_theme_color_override("font_placeholder_color", Color(1.0, 0.87, 0.68, 0.7))
	input.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	input.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	input.text_submitted.connect(func(_t): _send())
	hint.get_parent().add_child(input)


func _build_list() -> void:
	var area := lay.node("ID_areaNotiSlot_chatting")
	scroll = ScrollContainer.new()
	scroll.size = area.size + Vector2(14, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	area.add_child(scroll)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.custom_minimum_size.x = area.size.x - 10
	scroll.add_child(list)


func _build_picker() -> void:
	picker = lay.node("ID_chanel_bg")
	picker.visible = false
	picker.mouse_filter = MOUSE_FILTER_STOP
	var sc := ScrollContainer.new()
	sc.position = Vector2(8, 28)
	sc.size = picker.size - Vector2(16, 56)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	picker.add_child(sc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	sc.add_child(v)
	for ch in range(1, ChatTicker.CHANNELS + 1):
		var slot := Layout.instance("R_d_chanenlSlot")
		slot.text("ID_chanel_txt1", str(ch))
		slot.root.mouse_filter = MOUSE_FILTER_PASS
		slot.root.gui_input.connect(func(e: InputEvent):
			if UI.tapped(e):
				Sfx.play("tab")
				_set_channel(ch))
		v.add_child(slot.root)


func _toggle_picker() -> void:
	picker.visible = not picker.visible


func _set_channel(ch: int) -> void:
	picker.visible = false
	if ch == ticker.channel:
		return
	ticker.channel = ch
	_show_channel()


func _show_channel() -> void:
	lay.text("ID_LABEL_2", "Ch.%d" % ticker.channel)
	for c in list.get_children():
		c.queue_free()
	for m in ticker.messages(ticker.channel):
		list.add_child(ChatTicker.line(m, _preview))
	_to_bottom()


func _on_posted(ch: int, msg: Dictionary) -> void:
	if ch != ticker.channel:
		return
	var follow := scroll.scroll_vertical >= int(scroll.get_v_scroll_bar().max_value - scroll.size.y) - 40
	list.add_child(ChatTicker.line(msg, _preview))
	while list.get_child_count() > ChatTicker.HISTORY:
		var old := list.get_child(0)
		list.remove_child(old)
		old.queue_free()
	if follow:
		_to_bottom()


func _to_bottom() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _chatter() -> void:
	ticker.chatter()
	_live.start(randf_range(2.5, 7.0))


func _send() -> void:
	var t := input.text.strip_edges()
	if t == "":
		return
	input.text = ""
	ticker.post({"who": String(Save.data.get("name", "Tamer")), "text": t, "me": true})
	_to_bottom()
	ticker.reply_to(t)


func _preview(id: String) -> void:
	input.release_focus()
	MonsterPopup.info_of(screen, id, DB.MAX_LEVEL, 95)
