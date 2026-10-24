class_name RaidLock
extends Control

signal opened

const LINK := Vector2(26, 15)
const STEEL := Color("c9ced6")
const STEEL_DARK := Color("6d7480")

var _spread := 0.0


static func make(parent: Control) -> RaidLock:
	var l := RaidLock.new()
	l.mouse_filter = MOUSE_FILTER_IGNORE
	l.size = parent.size
	parent.add_child(l)
	var pad := UI.image(UI.tex("betaUI00/I_lock_03.png"), Vector2(64, 74))
	pad.name = "pad"
	pad.size = Vector2(64, 74)
	pad.self_modulate = Color(1.0, 0.45, 0.4)
	pad.position = l.size * 0.5 - pad.size * 0.5
	pad.pivot_offset = pad.size * 0.5
	pad.mouse_filter = MOUSE_FILTER_IGNORE
	l.add_child(pad)
	var skull := UI.image(UI.tex("betaHud00/H_skull_01.png"), Vector2(34, 34))
	skull.size = Vector2(34, 34)
	skull.position = Vector2(15, 30)
	skull.mouse_filter = MOUSE_FILTER_IGNORE
	pad.add_child(skull)
	return l


func _draw() -> void:
	var c := size * 0.5
	for dir in [Vector2(1, 0.42), Vector2(1, -0.42)]:
		var d: Vector2 = dir.normalized()
		var half := size.x * 0.48
		for side in [-1.0, 1.0]:
			var off: Vector2 = d * side * _spread * 120.0 + Vector2(0, _spread * 60.0)
			var n := int(half / (LINK.x * 0.62))
			for k in n:
				var p: Vector2 = c + d * side * (k + 0.5) * LINK.x * 0.62 + off
				_link(p, d, k % 2 == 0)


func _link(p: Vector2, d: Vector2, flat: bool) -> void:
	var a := 1.0 - _spread
	draw_set_transform(p, d.angle(), Vector2(1.0, 1.0 if flat else 0.45))
	draw_arc(Vector2.ZERO, LINK.x * 0.5, 0.0, TAU, 18, Color(STEEL_DARK, a), 7.0)
	draw_arc(Vector2.ZERO, LINK.x * 0.5, 0.0, TAU, 18, Color(STEEL, a), 4.0)
	draw_set_transform(Vector2.ZERO)


func set_spread(v: float) -> void:
	_spread = v
	queue_redraw()


func open() -> void:
	var pad: Control = get_node("pad")
	var tw := create_tween()
	tw.tween_property(pad, "rotation", 0.25, 0.08)
	tw.tween_property(pad, "rotation", -0.25, 0.08)
	tw.tween_property(pad, "rotation", 0.18, 0.08)
	tw.tween_property(pad, "rotation", 0.0, 0.08)
	tw.tween_callback(Sfx.play.bind("buff_big"))
	tw.tween_callback(_burst)
	tw.tween_property(pad, "scale", Vector2(1.6, 1.6), 0.2)
	tw.parallel().tween_property(pad, "modulate:a", 0.0, 0.25)
	tw.parallel().tween_method(set_spread, 0.0, 1.0, 0.45)
	tw.tween_interval(0.6)
	tw.tween_callback(queue_free)
	tw.tween_callback(opened.emit)


func _burst() -> void:
	var c := size * 0.5
	var glow := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.75, 1.0, 0.95, 0.85)
	sb.set_corner_radius_all(200)
	glow.add_theme_stylebox_override("panel", sb)
	glow.size = Vector2(40, 40)
	glow.position = c - glow.size * 0.5
	glow.pivot_offset = glow.size * 0.5
	glow.mouse_filter = MOUSE_FILTER_IGNORE
	get_parent().add_child(glow)
	var tw := glow.create_tween()
	tw.tween_property(glow, "scale", Vector2(8, 8), 0.5).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(glow, "modulate:a", 0.0, 0.6)
	tw.tween_callback(glow.queue_free)
	for k in 14:
		var star := UI.label("✦", 20 + randi() % 18, Color(1, 1, 1))
		star.add_theme_color_override("font_outline_color", Color("7ff0ff"))
		star.add_theme_constant_override("outline_size", 6)
		star.position = c - Vector2(12, 16)
		star.mouse_filter = MOUSE_FILTER_IGNORE
		get_parent().add_child(star)
		var to := c + Vector2.from_angle(TAU * k / 14.0 + randf() * 0.3) * (110.0 + randf() * 70.0)
		var st := star.create_tween()
		st.tween_property(star, "position", to, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		st.parallel().tween_property(star, "modulate:a", 0.0, 0.8).set_delay(0.25)
		st.tween_callback(star.queue_free)
