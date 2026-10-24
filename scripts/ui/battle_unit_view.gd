class_name BattleUnitView
extends Control

signal tapped(view: BattleUnitView)

const STATUS_ICONS := {
	"buff_atk": "Buff_attackBuff", "buff_def": "Buff_defenseBuff", "buff_crit": "Buff_criticalBuff",
	"buff_speed": "Buff_speedBuff", "buff_rec": "Buff_healBuff", "buff_crit_dmg": "Buff_criticalBuff",
	"debuff_atk": "Buff_attackDebuff", "debuff_def": "Buff_defenseDebuff", "debuff_speed": "Buff_speedDebuff",
	"debuff_rec": "Buff_healDebuff",
}
const STATUS_TEXT := {"stun": "STUN", "silence": "SILENCE", "provoke": "TAUNT", "reflect": "REFLECT", "immune": "IMMUNE", "time_bomb": "BOMB"}
const DOT_COLORS := {"bleed": Color("ff4a4a"), "poison": Color("b45cff"), "burn": Color("ff9a2a"), "freeze": Color("7fd4ff")}
const MAX_W := 1.4
const MAX_H := 1.3

var unit: BattleUnit
var home: Vector2
var sprite: TextureRect
var hp_bar: Range
var _ind: Layout
var shield_bar: ProgressBar
var badges: HBoxContainer
var target_mark: Label
var ring: ChargeRing
var _shake := 0.0
var _walk := 0.0
var _step := 0.0
var _numbers: Array = []


static func body_size(tex: Texture2D, box: Vector2) -> Vector2:
	if tex == null or tex.get_width() <= 0:
		return box
	var s := tex.get_size()
	return s * minf(sqrt(box.x * box.y / (s.x * s.y)), minf(box.x * MAX_W / s.x, box.y * MAX_H / s.y))


func setup(u: BattleUnit, pos: Vector2, box: Vector2) -> void:
	unit = u
	var tex := DB.battle_sprite(u.monster_id)
	var sprite_size := body_size(tex, box)
	home = Vector2(pos.x - sprite_size.x / 2.0, pos.y + box.y / 2.0 - sprite_size.y)
	position = home
	size = sprite_size
	mouse_filter = MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

	sprite = UI.image(tex)
	sprite.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	sprite.flip_h = u.side == BattleUnit.ENEMY
	sprite.pivot_offset = sprite_size / 2.0
	add_child(sprite)
	UI.add_shadow(self, sprite.texture, Rect2(Vector2.ZERO, sprite_size))

	var kind := "Normal"
	if u.side == BattleUnit.PLAYER:
		kind = "Leader" if u.is_leader else "Friend"
	elif u.is_boss:
		kind = "Boss"
	_ind = Layout.load_into(self, "battleIndicator" + kind, Vector2.ZERO, 0.0)
	var base: Control = _ind.node("ID_IMAGE_HP_BASE")
	_ind.root.position = Vector2(sprite_size.x / 2.0 - base.size.x / 2.0 + (12.0 if u.side == BattleUnit.PLAYER else 0.0), -6.0)
	_ind.show("ID_IMAGE_EXP_BACK", false)
	_ind.show("ID_pvpRank", false)
	hp_bar = _ind.node("ID_PROGRESSBAR_HP") as TextureProgressBar
	hp_bar.max_value = 1.0
	hp_bar.step = 0.0
	_ind.text("ID_LABEL_LEVEL", "Lv.%d" % u.level)
	var frame: Control = _ind.node("ID_IMAGE_TYPE_FRAME")
	var el := UI.image(UI.element_icon(u.element), Vector2(26, 26))
	el.size = Vector2(26, 26)
	el.position = (frame.size - el.size) / 2.0
	frame.add_child(el)
	if u.side == BattleUnit.PLAYER and (u.is_leader or not u.support.is_empty()):
		ring = ChargeRing.new()
		ring.size = frame.size
		ring.mouse_filter = MOUSE_FILTER_IGNORE
		frame.add_child(ring)

	shield_bar = ProgressBar.new()
	shield_bar.show_percentage = false
	shield_bar.max_value = 1.0
	shield_bar.step = 0.0
	shield_bar.size = Vector2(hp_bar.size.x, 5)
	shield_bar.position = hp_bar.position + Vector2(0, hp_bar.size.y)
	shield_bar.mouse_filter = MOUSE_FILTER_IGNORE
	var sfill := StyleBoxFlat.new()
	sfill.bg_color = Color("9fd8ff")
	shield_bar.add_theme_stylebox_override("fill", sfill)
	shield_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	hp_bar.get_parent().add_child(shield_bar)

	badges = HBoxContainer.new()
	badges.add_theme_constant_override("separation", 2)
	badges.position = Vector2(0, sprite_size.y - 8)
	badges.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(badges)

	target_mark = UI.label("▼", 30, Color("ff5050"))
	target_mark.position = Vector2(sprite_size.x / 2.0 - 12, -56)
	target_mark.visible = false
	add_child(target_mark)


func _on_gui_input(e: InputEvent) -> void:
	if UI.pressed(e):
		tapped.emit(self)


func refresh() -> void:
	hp_bar.value = unit.hp_ratio()
	shield_bar.value = clampf(unit.shield / maxf(1.0, unit.max_hp * 0.3), 0.0, 1.0)
	shield_bar.visible = unit.shield > 0.0
	_refresh_badges()


func set_charge(value: float) -> void:
	if ring != null:
		ring.value = value if unit.alive() else 0.0


func set_targeted(on: bool) -> void:
	target_mark.visible = on and unit.alive()


func _draw() -> void:
	if unit != null and unit.is_leader and unit.side == BattleUnit.PLAYER and unit.alive():
		draw_set_transform(Vector2(size.x / 2.0, size.y - 6.0), 0.0, Vector2(1.0, 0.32))
		draw_arc(Vector2.ZERO, size.x * 0.45, 0, TAU, 48, Color(0.55, 0.95, 0.3, 0.8), 6.0)
		draw_set_transform(Vector2.ZERO)


func _refresh_badges() -> void:
	for c in badges.get_children():
		c.queue_free()
	if not unit.alive():
		return
	var shown := {}
	for s in unit.statuses:
		var key := ""
		if s.type == "buff" or s.type == "debuff":
			key = "%s_%s" % [s.type, s.stat]
		else:
			key = s.type if s.type != "dot" else "dot_" + String(s.kind)
		if shown.has(key):
			continue
		shown[key] = true
		if STATUS_ICONS.has(key):
			badges.add_child(UI.image(UI.tex("betaHud00/%s.png" % STATUS_ICONS[key]), Vector2(24, 24)))
		elif s.type == "dot":
			badges.add_child(_badge_text(String(s.kind).to_upper(), DOT_COLORS.get(s.kind, Color.WHITE)))
		elif STATUS_TEXT.has(s.type):
			badges.add_child(_badge_text(STATUS_TEXT[s.type], Color("ffe080")))


func _badge_text(text: String, color: Color) -> Label:
	var l := UI.label(text, 16, color)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.0))
	return l


func lunge(toward: Vector2) -> void:
	var dir := (toward - (home + size / 2.0)).normalized()
	var tw := create_tween()
	tw.tween_property(self, "position", home + dir * 40.0, 0.09).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "position", home, 0.16).set_trans(Tween.TRANS_QUAD)


func hit(crit: bool) -> void:
	sprite.modulate = Color(1.8, 0.6, 0.6)
	_shake = 0.18 if crit else 0.1
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.2)


func pulse(color: Color) -> void:
	sprite.modulate = color
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.35)


func die() -> void:
	set_targeted(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(sprite, "scale", Vector2(0.6, 0.6), 0.5)


func revive() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(sprite, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	pulse(Color(1.6, 1.5, 1.1))
	float_text("Revive!", Color("ffe48a"), 24)
	refresh()


func float_text(text: String, color: Color, font_size: int = 26) -> void:
	var l := pop_label(text, font_size, color.lightened(0.45), color.darkened(0.1), 6, false)
	_layer().add_child(l)
	var s := l.get_minimum_size()
	l.position = position + Vector2(size.x / 2.0 - s.x / 2.0 + randf_range(-20, 20), size.y * 0.2)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 60, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.35)
	tw.tween_callback(l.queue_free)


func damage_number(amount: int, crit: bool, icon: Texture2D, hurt: bool) -> void:
	for old in _numbers:
		if is_instance_valid(old):
			_hurry(old)
	_numbers.clear()
	var root := Control.new()
	_numbers.append(root)
	root.mouse_filter = MOUSE_FILTER_IGNORE
	root.z_index = 20
	_layer().add_child(root)
	var fs := 42 if crit else 32
	var top := Color("fff58a")
	var bottom := Color("f2b010")
	if crit:
		top = Color("ffb03a")
		bottom = Color("e62e1a")
	elif hurt:
		top = Color("ffc49a")
		bottom = Color("ff4a26")
	var num := pop_label(str(amount), fs, top, bottom, 10 if crit else 9)
	root.add_child(num)
	var ns := num.get_minimum_size()
	var x := 0.0
	if icon != null:
		var isz := fs * 0.7
		var ic := UI.image(icon, Vector2(isz, isz))
		ic.size = Vector2(isz, isz)
		ic.position = Vector2(0, ns.y - isz * 1.15)
		root.add_child(ic)
		x = isz * 0.75
		root.move_child(ic, -1)
	num.position.x = x
	var box := Vector2(x + ns.x, ns.y)
	if crit:
		var word := pop_label("Critical!", 32, Color("ffbf40"), Color("e62a18"), 9)
		root.add_child(word)
		root.move_child(word, 0)
		var ws := word.get_minimum_size()
		word.position = Vector2((box.x - ws.x) / 2.0, -ws.y * 0.68)
	root.size = box
	root.pivot_offset = box / 2.0
	root.position = position + Vector2(size.x / 2.0 - box.x / 2.0 + randf_range(-16, 16), size.y * 0.12 + randf_range(-8, 8))
	_pop(root, 1.55 if crit else 1.45, 0.5 if crit else 0.35)


func gold_pop(amount: int) -> void:
	var l := pop_label("+%d G" % amount, 30, Color("fff7a8"), Color("ffc414"))
	_layer().add_child(l)
	var s := l.get_minimum_size()
	l.size = s
	l.pivot_offset = s / 2.0
	l.position = position + Vector2(size.x / 2.0 - s.x / 2.0, size.y * 0.12 - 38)
	_pop(l, 1.35, 0.7)
	FrameFx.play(_layer(), "u_moneyex_01", position + Vector2(size.x / 2.0, size.y * 0.35), Vector2(560, 448))


func alert(delay: float) -> void:
	var b := UI.image(UI.tex("res://assets/ui/alert_bubble.png"), Vector2(46, 48))
	b.size = Vector2(46, 48)
	b.pivot_offset = Vector2(23, 48)
	b.position = Vector2(size.x / 2.0 - 34, -62)
	b.scale = Vector2.ZERO
	b.z_index = 15
	add_child(b)
	var tw := b.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(walk.bind(0.3))
	tw.tween_property(b, "scale", Vector2(1.2, 1.2), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2.ONE, 0.08)
	tw.tween_interval(0.9)
	tw.tween_property(b, "modulate:a", 0.0, 0.2)
	tw.tween_callback(b.queue_free)


func _layer() -> Node:
	return get_parent() if get_parent() != null else self


func _pop(n: Control, peak: float, hold: float) -> void:
	n.scale = Vector2(0.3, 0.3)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2(peak, peak), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(hold)
	tw.tween_property(n, "position:y", n.position.y - 14, 0.3)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.3)
	tw.tween_callback(n.queue_free)
	n.set_meta("tween", tw)


func _hurry(n: Control) -> void:
	var old: Tween = n.get_meta("tween", null)
	if old != null and old.is_valid():
		old.kill()
	var tw := n.create_tween()
	tw.tween_property(n, "modulate:a", 0.0, 0.12)
	tw.parallel().tween_property(n, "position:y", n.position.y - 10, 0.12)
	tw.tween_callback(n.queue_free)


static var _materials: Dictionary = {}
static var _shader: Shader
static var _heavy: FontVariation


static func heavy_font() -> FontVariation:
	if _heavy == null:
		_heavy = FontVariation.new()
		_heavy.base_font = load(UI.FONT)
		_heavy.variation_embolden = 0.9
		_heavy.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.16, 1.0), Vector2.ZERO)
		_heavy.spacing_glyph = 1
	return _heavy


static func pop_label(text: String, font_size: int, top: Color, bottom: Color, outline: int = 8, heavy: bool = true, edge: Color = Color("2c0e00")) -> Label:
	var l := UI.label(text, font_size, Color.WHITE)
	if heavy:
		l.add_theme_font_override("font", heavy_font())
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	l.z_index = 20
	var key := "%s|%s|%s|%d" % [top.to_html(), bottom.to_html(), edge.to_html(), font_size]
	if not _materials.has(key):
		if _shader == null:
			_shader = Shader.new()
			_shader.code = "shader_type canvas_item;\nuniform vec4 top : source_color;\nuniform vec4 bottom : source_color;\nuniform vec4 edge : source_color;\nuniform float y0;\nuniform float y1;\nvarying float ly;\nvoid vertex() { ly = VERTEX.y; }\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV) * COLOR;\n\tvec3 fill = mix(top.rgb, bottom.rgb, clamp((ly - y0) / (y1 - y0), 0.0, 1.0));\n\tCOLOR = vec4(mix(edge.rgb, fill, clamp(c.r, 0.0, 1.0)), c.a);\n}\n"
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter("top", top)
		m.set_shader_parameter("bottom", bottom)
		m.set_shader_parameter("edge", edge)
		m.set_shader_parameter("y0", font_size * 0.3)
		m.set_shader_parameter("y1", font_size * 1.1)
		_materials[key] = m
	l.material = _materials[key]
	return l


static func arc_label(text: String, font_size: int, top: Color, bottom: Color, outline: int, bend: float) -> Control:
	var root := Control.new()
	root.mouse_filter = MOUSE_FILTER_IGNORE
	var letters: Array[Label] = []
	var widths: Array[float] = []
	var total := 0.0
	for ch in text:
		var l := pop_label(ch, font_size, top, bottom, outline)
		l.z_index = 0
		var w := l.get_minimum_size().x + outline * 0.3 if ch != " " else font_size * 0.35
		letters.append(l)
		widths.append(w)
		total += w
	var h := letters[0].get_minimum_size().y
	var half := total / 2.0
	var x := 0.0
	for i in letters.size():
		var l := letters[i]
		var s := l.get_minimum_size()
		var c := (x + widths[i] / 2.0 - half) / half
		l.size = s
		l.pivot_offset = Vector2(s.x / 2.0, s.y)
		l.position = Vector2(x + widths[i] / 2.0 - s.x / 2.0, bend * c * c)
		l.rotation = atan(2.0 * bend * c / half)
		root.add_child(l)
		x += widths[i]
	root.size = Vector2(total, h + bend)
	root.pivot_offset = root.size / 2.0
	return root


var _exp_bar: ProgressBar
var _exp_lv: Label
var _exp_pct: Label
var _lvl_label: Control
var _leveled := false


func show_exp(level: int, pct: float) -> void:
	if _exp_bar == null:
		_ind.root.visible = false
		badges.visible = false
		var w := hp_bar.size.x + 28.0
		var at := Vector2(size.x / 2.0 - w / 2.0 + 18.0, 4.0)
		_exp_bar = ProgressBar.new()
		_exp_bar.show_percentage = false
		_exp_bar.max_value = 100.0
		_exp_bar.step = 0.0
		_exp_bar.size = Vector2(w, 9)
		_exp_bar.position = at
		_exp_bar.mouse_filter = MOUSE_FILTER_IGNORE
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0.18, 0.12, 0.08, 0.85)
		back.set_corner_radius_all(4)
		back.border_color = Color(0.1, 0.05, 0.0)
		back.set_border_width_all(1)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("ff8a1c")
		fill.set_corner_radius_all(4)
		fill.border_color = Color("ffc23a")
		fill.border_width_top = 2
		_exp_bar.add_theme_stylebox_override("background", back)
		_exp_bar.add_theme_stylebox_override("fill", fill)
		add_child(_exp_bar)
		_exp_lv = pop_label("", 19, Color("fff2b0"), Color("ffb428"), 6)
		add_child(_exp_lv)
		_exp_pct = pop_label("", 21, Color("fff7c0"), Color("ffc43a"), 6)
		add_child(_exp_pct)
	_exp_bar.value = clampf(pct, 0.0, 100.0)
	_exp_lv.text = "Lv%d" % level
	var ls := _exp_lv.get_minimum_size()
	_exp_lv.size = ls
	_exp_lv.position = _exp_bar.position + Vector2(-ls.x - 3.0, _exp_bar.size.y / 2.0 - ls.y / 2.0)
	_exp_pct.text = "%.1f%%" % clampf(pct, 0.0, 100.0)
	var ps := _exp_pct.get_minimum_size()
	_exp_pct.size = ps
	_exp_pct.position = _exp_bar.position + Vector2(_exp_bar.size.x / 2.0 - ps.x / 2.0, -ps.y + 3.0)


func level_up() -> void:
	if _lvl_label != null and is_instance_valid(_lvl_label):
		var old: Tween = _lvl_label.get_meta("tween", null)
		if old != null and old.is_valid():
			old.kill()
		_lvl_label.position = _lvl_label.get_meta("home")
		_lvl_label.modulate.a = 1.0
		_pop(_lvl_label, 1.25, 0.9)
		return
	var l := arc_label("LEVEL UP!", 28, Color("fff07a"), Color("ff7a16"), 8, 8.0)
	_lvl_label = l
	_layer().add_child(l)
	var s := l.size
	l.pivot_offset = Vector2(s.x / 2.0, s.y)
	var center := size.x / 2.0
	var above := -10.0
	if _exp_pct != null:
		center = _exp_bar.position.x + _exp_bar.size.x / 2.0
		above = _exp_pct.position.y - 2.0
	l.position = position + Vector2(center - s.x / 2.0, above - s.y)
	l.set_meta("home", l.position)
	l.z_index = 25
	_pop(l, 1.35, 0.9)
	if not _leveled:
		_leveled = true
		FrameFx.play(_layer(), "c_levelup_1", position + Vector2(size.x / 2.0, size.y * 0.35), Vector2(size.x * 1.3, size.y * 1.9), 22)


func walk(duration: float) -> void:
	_walk = maxf(_walk, duration)


func enter_from(offset: Vector2, duration: float) -> void:
	position = home + offset
	walk(duration)
	var tw := create_tween()
	tw.tween_property(self, "position", home, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	var pos := Vector2.ZERO
	if _shake > 0.0:
		_shake -= delta
		if _shake > 0.0:
			pos = Vector2(randf_range(-5, 5), randf_range(-3, 3))
	if _walk > 0.0:
		_walk -= delta
		_step += delta * 11.0
		pos.y -= absf(sin(_step)) * 7.0
		sprite.rotation = sin(_step) * 0.06 if _walk > 0.0 else 0.0
	sprite.position = pos


class ChargeRing extends Control:
	var value := 0.0:
		set(v):
			if not is_equal_approx(v, value):
				value = clampf(v, 0.0, 1.0)
				queue_redraw()
	var _t := 0.0

	func _process(delta: float) -> void:
		if value >= 1.0:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 2.0
		draw_arc(c, r, 0.0, TAU, 40, Color(0.05, 0.03, 0.02, 0.75), 5.0, true)
		if value <= 0.0:
			return
		if value >= 1.0:
			var glow := 0.6 + 0.4 * absf(sin(_t * 5.0))
			draw_arc(c, r, 0.0, TAU, 40, Color(1.0, 0.86, 0.25, glow), 5.0, true)
			draw_arc(c, r + 3.0, 0.0, TAU, 40, Color(1.0, 0.95, 0.6, glow * 0.5), 2.0, true)
		else:
			draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * value, 40, Color(0.45, 0.9, 1.0), 5.0, true)
