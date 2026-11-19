class_name UI
extends RefCounted

const SPRITES := "res://assets/apk/sprites/"
const FONT := "res://assets/apk/fonts/NanumBarunGothicBold.ttf"
const BUTTON_FILES := {"orange": "01", "blue": "02", "purple": "03", "yellow": "04", "green": "06"}
const GOLD := Color("ffdc55")
const CREAM := Color("fff4d6")
const BROWN := Color("4a2a0a")

const TAP_SLOP := 18.0
const HOLD_TIME := 0.45
const IDLE_PAD := Vector2(0.1, 0.08)
const IDLE_SHADER := """shader_type canvas_item;
uniform vec2 pad;
uniform float phase;
uniform float breath = 0.03;
uniform float sway = 0.04;
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	vec2 uv = vec2((UV.x - pad.x) / (1.0 - 2.0 * pad.x), (UV.y - pad.y) / (1.0 - pad.y));
	float t = TIME + phase;
	float b = sin(t * 4.2);
	float h = (1.0 - uv.y) / (1.0 + breath * b);
	uv.y = 1.0 - h;
	uv.x = 0.5 + (uv.x - 0.5) / (1.0 - breath * 0.5 * b) - sway * h * h * sin(t * 2.3);
	vec4 c = texture(TEXTURE, uv);
	c.a *= step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	COLOR = c * tint;
}
"""

static var _theme: Theme
static var _idle_shader: Shader
static var _tex_cache: Dictionary = {}
static var _down := Vector2.INF
static var _hold_id := 0
static var _hold_at := Vector2.INF
static var _held := false


static func pressed(e: InputEvent) -> bool:
	return e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT


static func right_pressed(e: InputEvent) -> bool:
	return e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT


static func tapped(e: InputEvent) -> bool:
	if not (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
		return false
	if e.pressed:
		_down = e.global_position
		_held = false
		return false
	var ok: bool = not _held and _down != Vector2.INF and e.global_position.distance_to(_down) < TAP_SLOP
	_down = Vector2.INF
	return ok


static func hold(e: InputEvent, cb: Callable) -> void:
	if e is InputEventMouseMotion:
		if _hold_at != Vector2.INF and e.global_position.distance_to(_hold_at) > TAP_SLOP:
			_hold_at = Vector2.INF
		return
	if not (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if not e.pressed:
		_hold_at = Vector2.INF
		return
	_held = false
	_hold_id += 1
	var id := _hold_id
	var at: Vector2 = e.global_position
	_hold_at = at
	(Engine.get_main_loop() as SceneTree).create_timer(HOLD_TIME).timeout.connect(func():
		if id != _hold_id or _hold_at != at:
			return
		_held = true
		cb.call())


static func was_held() -> bool:
	return _held


static func tip(c: Control, text: String) -> void:
	c.tooltip_text = text
	if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.gui_input.connect(func(e: InputEvent):
		if tapped(e) and c.is_inside_tree():
			var top := c.get_tree().current_scene as Control
			toast(top if top else c, text))


static func tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		var full := path if path.begins_with("res://") else SPRITES + path
		_tex_cache[path] = load(full) if ResourceLoader.exists(full) else null
	return _tex_cache[path]


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = load(FONT)
	t.default_font_size = 20
	for st in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(st, "Button", _button_box("01", st))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", CREAM)
	t.set_color("font_disabled_color", "Button", Color(0.85, 0.85, 0.85))
	t.set_color("font_outline_color", "Button", BROWN)
	t.set_constant("outline_size", "Button", 7)
	t.set_color("font_outline_color", "Label", Color(0.16, 0.08, 0.0))
	t.set_constant("outline_size", "Label", 6)
	t.set_color("font_color", "Label", CREAM)
	var tip := StyleBoxFlat.new()
	tip.bg_color = Color(0.16, 0.09, 0.04, 0.94)
	tip.border_color = Color("e0a84a")
	tip.set_border_width_all(2)
	tip.set_corner_radius_all(8)
	tip.set_content_margin_all(10)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", Color("ffe9a8"))
	t.set_font_size("font_size", "TooltipLabel", 18)
	var wood := _box("betaUI00/9_Back_07.png", 22, 18)
	t.set_stylebox("panel", "PanelContainer", wood)
	t.set_stylebox("panel", "Panel", wood)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.12, 0.06, 0.02, 0.85)
	bar_bg.set_corner_radius_all(4)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("5ad13a")
	bar_fill.set_corner_radius_all(4)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.2, 0.1, 0.03, 0.35)
	track.set_corner_radius_all(4)
	track.set_content_margin_all(4)
	for sb in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb, track)
		t.set_stylebox("scroll_focus", sb, track)
		for st in ["grabber", "grabber_highlight", "grabber_pressed"]:
			var g := StyleBoxFlat.new()
			g.bg_color = {"grabber": Color("f58a12"), "grabber_highlight": Color("ffa233"), "grabber_pressed": Color("d96f00")}[st]
			g.border_color = Color("b85800")
			g.set_border_width_all(1)
			g.set_corner_radius_all(4)
			t.set_stylebox(st, sb, g)
	t.set_constant("separation", "HBoxContainer", 10)
	t.set_constant("separation", "VBoxContainer", 10)
	_theme = t
	return t


static func _box(path: String, margin: int, content: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex(path)
	sb.set_texture_margin_all(margin)
	sb.set_content_margin_all(content)
	return sb


static func _button_box(file: String, state: String) -> StyleBoxTexture:
	var sb := _box("betaUI00/9_btn_%s.png" % file, 28, 14)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	match state:
		"hover":
			sb.modulate_color = Color(1.12, 1.12, 1.12)
		"pressed":
			sb.modulate_color = Color(0.8, 0.8, 0.8)
		"disabled":
			sb.modulate_color = Color(0.55, 0.55, 0.55)
	return sb


static func button(text: String, cb: Callable, color: String = "orange", min_size: Vector2 = Vector2(150, 64), font_size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	if color != "orange":
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, _button_box(BUTTON_FILES.get(color, "01"), st))
	b.pressed.connect(cb)
	b.pressed.connect(func(): Sfx.play(b.get_meta("sfx", "click")))
	return b


static func label(text: String, size: int = 20, color: Color = CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func image(texture: Texture2D, min_size: Vector2 = Vector2.ZERO, mode: int = TextureRect.STRETCH_KEEP_ASPECT_CENTERED) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = mode
	r.custom_minimum_size = min_size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func idle_material() -> ShaderMaterial:
	if _idle_shader == null:
		_idle_shader = Shader.new()
		_idle_shader.code = IDLE_SHADER
	var m := ShaderMaterial.new()
	m.shader = _idle_shader
	m.set_shader_parameter("pad", Vector2(IDLE_PAD.x / (1.0 + 2.0 * IDLE_PAD.x), IDLE_PAD.y / (1.0 + IDLE_PAD.y)))
	m.set_shader_parameter("phase", randf() * TAU)
	return m


static func idle_art(texture: Texture2D, drawn: Vector2) -> TextureRect:
	var art := image(texture, Vector2.ZERO, TextureRect.STRETCH_SCALE)
	if texture != null and not (texture is AtlasTexture):
		art.size = drawn * Vector2(1.0 + 2.0 * IDLE_PAD.x, 1.0 + IDLE_PAD.y)
		art.position = -drawn * IDLE_PAD
		art.material = idle_material()
	else:
		art.size = drawn
		art.pivot_offset = Vector2(drawn.x / 2.0, drawn.y)
		var breathe := art.create_tween().set_loops()
		breathe.tween_property(art, "scale", Vector2(0.985, 1.03), 0.7).set_trans(Tween.TRANS_SINE)
		breathe.tween_property(art, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)
	return art


static func living(texture: Texture2D, box: Vector2, flip: bool = false) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = box
	holder.size = box
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var drawn := box
	if texture != null and texture.get_width() > 0:
		drawn = texture.get_size() * minf(box.x / texture.get_width(), box.y / texture.get_height())
	var art := idle_art(texture, drawn)
	art.position += (box - drawn) / 2.0
	art.flip_h = flip
	holder.add_child(art)
	return holder


static func pet_buddy(pet_id: String, box: Vector2, flip := false) -> Control:
	var tex := DB.pet_texture(pet_id)
	var holder := Control.new()
	holder.size = box
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var drawn := box
	if tex != null and tex.get_width() > 0:
		drawn = tex.get_size() * minf(box.x / tex.get_width(), box.y / tex.get_height())
	var art := image(tex, drawn)
	art.size = drawn
	art.position = (box - drawn) / 2.0
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.flip_h = flip
	holder.add_child(art)
	var bob := art.create_tween().set_loops()
	bob.tween_property(art, "position:y", art.position.y - box.y * 0.08, 1.1).set_trans(Tween.TRANS_SINE)
	bob.tween_property(art, "position:y", art.position.y, 1.1).set_trans(Tween.TRANS_SINE)
	return holder


static func background(parent: Control, texture: Texture2D, dim: float = 0.0) -> void:
	var bg := image(texture, Vector2.ZERO, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
	if dim > 0.0:
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, dim)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(shade)


static func fit_text(l: Label, max_size: int, min_size: int, width: float = -1.0) -> void:
	l.clip_text = false
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	var w := width if width > 0.0 else l.size.x
	var font := l.get_theme_font("font")
	var s := max_size
	while s > min_size and font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > w:
		s -= 1
	l.add_theme_font_size_override("font_size", s)
	if font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > w:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


static func brown_background(parent: Control) -> void:
	var bg := image(tex("betaUI00/background.png"), Vector2.ZERO, TextureRect.STRETCH_TILE)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)


static func stars(count: int, size: int = 16) -> Label:
	return label("★".repeat(count), size, GOLD)


const ELEMENT_FRAMES := {"fire": "M_attFire_01.png", "water": "M_attWater_01.png", "nature": "M_attNatural_01.png"}


static func monster_card(id: String, level: int = 0, boost: int = 0, size: Vector2 = Vector2(110, 110), dim: bool = false) -> Control:
	var def := DB.monster(id)
	var card := Control.new()
	card.custom_minimum_size = size
	card.size = size
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := Control.new()
	box.size = Vector2(92, 92)
	box.scale = size / 92.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	if dim:
		box.add_child(_fill(tex("betaUI00/B_monEmpty_03.png")))
		return card
	if DB.has_icon(id):
		box.add_child(_fill(DB.icon(id)))
	else:
		var back := _fill(tex("betaUI00/B_monEmpty_06.png"))
		box.add_child(back)
		var pic := _fill(DB.icon(id))
		pic.position = Vector2(6, 10)
		pic.size = Vector2(80, 72)
		box.add_child(pic)
		var frame: String = "M_attStone_01.png" if def.get("material", false) else ELEMENT_FRAMES.get(def.get("element", ""), "M_attBalance_01.png")
		box.add_child(_fill(tex("betaUI00/" + frame)))
		var stars_n := int(def.get("stars", 1))
		for g in stars_n:
			var s := _fill(tex("betaUI00/I_grade_04.png"))
			s.size = Vector2(9, 9)
			s.position = Vector2(46 - stars_n * 4 + g * 8, 6)
			box.add_child(s)
	if level > 0 or boost > 0:
		var text := ("Lv.%d" % level) if level > 0 else ""
		if boost > 0:
			text += (" +%d" % boost)
		var lv := _icon_label(text.strip_edges(), Color.WHITE if boost == 0 else Color("c8f4ff"), HORIZONTAL_ALIGNMENT_LEFT)
		lv.position = Vector2(4, 68)
		box.add_child(lv)
	return card


static func add_shadow(parent: Control, tex_drawn: Texture2D, box: Rect2, index: int = 0) -> TextureRect:
	var drawn := box.size
	if tex_drawn != null and tex_drawn.get_width() > 0:
		var s := minf(box.size.x / tex_drawn.get_width(), box.size.y / tex_drawn.get_height())
		drawn = tex_drawn.get_size() * s
	var feet := Vector2(box.position.x + box.size.x / 2.0, box.position.y + (box.size.y + drawn.y) / 2.0)
	var sh := image(tex("betaUI00/I_shadow_02.png"))
	sh.stretch_mode = TextureRect.STRETCH_SCALE
	sh.size = Vector2(drawn.x * 0.8, drawn.x * 0.2)
	sh.position = feet - Vector2(sh.size.x / 2.0, sh.size.y * 0.6)
	sh.modulate.a = 0.75
	parent.add_child(sh)
	parent.move_child(sh, index)
	return sh


static func _fill(t: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size = Vector2(92, 92)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func _icon_label(text: String, color: Color, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.size = Vector2(58, 22)
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func element_icon(element: String) -> Texture2D:
	return tex({"fire": "betaHud00/IconFire.png", "water": "betaHud00/IconWater.png", "nature": "betaHud00/IconNature.png"}.get(element, "betaHud00/IconVariation.png"))


static func toast(parent: Control, text: String, color: Color = CREAM) -> void:
	var l := label(text, 26, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.position.y = 90
	l.z_index = 100
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


static func _frame(image: String, inset: Rect2i, content: Vector4i) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = Layout.texture(image)
	var ts := sb.texture.get_size()
	sb.texture_margin_left = inset.position.x
	sb.texture_margin_top = inset.position.y
	sb.texture_margin_right = maxi(0, int(ts.x) - inset.position.x - inset.size.x)
	sb.texture_margin_bottom = maxi(0, int(ts.y) - inset.position.y - inset.size.y)
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	return sb


static func dialog(parent: Control, title: String, body: Control, buttons: Array, ribbon := false) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 50
	parent.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var outer := PanelContainer.new()
	outer.add_theme_stylebox_override("panel", _frame("9_Back_19.png", Rect2i(50, 50, 2, 2), Vector4i(12, 12, 12, 16)))
	center.add_child(outer)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0 if ribbon else 4)
	outer.add_child(stack)
	var t := label(title, 32 if ribbon else 30, Color("fff23a") if ribbon else Color8(255, 220, 125))
	t.add_theme_color_override("font_outline_color", Color("6a2a00") if ribbon else Color8(80, 40, 0))
	t.add_theme_constant_override("outline_size", 8 if ribbon else 6)
	if ribbon:
		var r := image(Layout.texture("K_ribon_01.png"), Vector2(0, 76), TextureRect.STRETCH_SCALE)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		t.offset_bottom = -10
		r.add_child(t)
		stack.add_child(r)
	else:
		var tab := PanelContainer.new()
		tab.add_theme_stylebox_override("panel", _frame("9_frame_04.png", Rect2i(32, 0, 2, 56), Vector4i(30, 4, 30, 6)))
		tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		tab.add_child(t)
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", 10)
		pad.add_child(tab)
		stack.add_child(pad)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _frame("9_Back_01.png", Rect2i(84, 126, 2, 2), Vector4i(28, 24, 28, 22)))
	stack.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	panel.add_child(v)
	v.add_child(body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	for b in buttons:
		var cb: Callable = b.get("cb", Callable())
		var on_press := func() -> void:
			overlay.queue_free()
			if cb.is_valid():
				cb.call()
		var btn := button(b.text, on_press, b.get("color", "orange"))
		btn.set_meta("sfx", "popup_ok")
		row.add_child(btn)
	Sfx.play("popup_open")
	return overlay


static func notice(parent: Control, title: String, text: String, cb: Callable = Callable()) -> Control:
	var lay := Layout.load_into(parent, "R_d_conform_1button")
	lay.root.z_index = 80
	lay.node("ID_9PATCH_2").mouse_filter = Control.MOUSE_FILTER_STOP
	lay.text("ID_titleText", title)
	var body := lay.text("ID_baseText", text)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.add_theme_color_override("font_color", BROWN)
	var root := lay.root
	lay.on("ID_btnOk", _notice_ok.bind(root, cb))
	return root


static func ribbon_title(root: Control, title: String) -> void:
	var dlg: Control = root.find_child("ID_Dialog", true, false)
	(root.find_child("ID_title", true, false) as Control).visible = false
	var w := dlg.size.x + 110.0
	var r := image(Layout.texture("K_ribon_01.png"))
	r.size = Vector2(w, 82)
	r.position = Vector2(-55, -26)
	dlg.add_child(r)
	var t := label(title, 32, Color("fff23a"))
	t.add_theme_color_override("font_outline_color", Color("6a2a00"))
	t.add_theme_constant_override("outline_size", 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.size = Vector2(w, 66)
	r.add_child(t)


static func orange_ok(root: Control, text: String) -> void:
	var ok: Control = root.find_child("ID_btnOk", true, false)
	for c in ok.get_children():
		if c is NinePatchRect:
			(c as NinePatchRect).texture = tex("betaUI00/9_btn_01.png")
	for l in ok.find_children("*", "Label", true, false):
		(l as Label).text = text
		l.add_theme_color_override("font_shadow_color", Color("6a2a00"))
		l.add_theme_color_override("font_outline_color", Color("6a2a00"))


static func inventory_full(parent: Control, on_train: Callable) -> Control:
	var root := confirm(parent, "Inventory Full", "Not enough inventory slots.\nBoost or Sell Monsters to free up slots.", on_train)
	for l in root.find_children("ID_LABEL_5", "Label", true, false):
		(l as Label).text = "Go Train"
	return root


static func stone_box_full(parent: Control, on_stones: Callable) -> Control:
	var root := confirm(parent, "Stone Box Full", "Not enough inventory slots.\nEquip or Sell Magic Stones to free up slots.", on_stones)
	for l in root.find_children("ID_LABEL_5", "Label", true, false):
		(l as Label).text = "Go Stones"
	return root


const ONE_TYPE_PER_TEAM := "Can only place one type of
Monster into one team."


static func confirm(parent: Control, title: String, text: String, on_ok: Callable) -> Control:
	var lay := Layout.load_into(parent, "R_d_conform_2button")
	lay.root.z_index = 80
	lay.node("ID_9PATCH_2").mouse_filter = Control.MOUSE_FILTER_STOP
	lay.text("ID_titleText", title)
	var body := lay.text("ID_baseText", text)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.add_theme_color_override("font_color", BROWN)
	var root := lay.root
	lay.on("ID_btnOk", _notice_ok.bind(root, on_ok))
	lay.on("ID_btnEsc", root.queue_free)
	return root


static func _notice_ok(root: Control, cb: Callable) -> void:
	root.queue_free()
	if cb.is_valid():
		cb.call()


static func format_time(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]
