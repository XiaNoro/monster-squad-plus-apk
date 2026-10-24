class_name BoostScene
extends Node

const RESULT_AT := 7.3
const GLOW := "res://assets/apk/sprites/c_extraglow_%s_1/c_extraglow_%s_1_%03d.png"

var lay: Layout
var success := false
var finished: Callable
var _skip := false
var _sound: AudioStreamPlayer
var _stage: Control


static func play(d: Layout, hero_id: String, mat_id: String, ok: bool, then: Callable) -> BoostScene:
	var s := BoostScene.new()
	s.lay = d
	s.success = ok
	s.finished = then
	d.root.add_child(s)
	s._sound = Sfx.play("boost_success" if ok else "boost_fail")
	d.hide_all(["ID_base", "ID_monStat", "ID_monMatl", "ID_ev1", "ID_btnOk", "ID_btnEsc"])
	var back: Control = d.node("ID_baseback")
	s._stage = Control.new()
	s._stage.size = back.size
	s._stage.clip_contents = true
	s._stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(s._stage)
	d.node("ID_9PATCH_2").gui_input.connect(s._on_tap)
	s._run(hero_id, mat_id)
	return s


func _on_tap(e: InputEvent) -> void:
	if UI.pressed(e):
		_skip = true


func _wait(t: float) -> void:
	var left := t
	while left > 0.0 and not _skip:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _sprite(id: String, box: Vector2, feet: Vector2, flip: bool) -> TextureRect:
	var tex := DB.battle_sprite(id)
	var size := box
	if tex != null and tex.get_width() > 0:
		size = tex.get_size() * minf(box.x / tex.get_width(), box.y / tex.get_height())
	var r := UI.image(tex, size)
	r.size = size
	r.position = feet - Vector2(size.x / 2.0, size.y)
	r.pivot_offset = Vector2(size.x / 2.0, size.y)
	r.flip_h = flip
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(r)
	return r


func _pop(tex_path: String, size: Vector2, at: Vector2, parent: Control) -> TextureRect:
	var r := UI.image(UI.tex(tex_path), size)
	r.size = size
	r.position = at - size / 2.0
	r.pivot_offset = Vector2(size.x / 2.0, size.y)
	r.scale = Vector2.ZERO
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	r.create_tween().tween_property(r, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return r


func _heart(at: Vector2) -> void:
	var h := UI.image(UI.tex("betaGacha00/G_Heart_01.png"), Vector2(24, 20))
	h.size = Vector2(24, 20)
	h.position = at + Vector2(randf_range(-14, 14), 0)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(h)
	var tw := h.create_tween().set_parallel()
	tw.tween_property(h, "position:y", h.position.y - 46.0, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(h, "position:x", h.position.x + randf_range(-10, 10), 0.9)
	tw.tween_property(h, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tw.chain().tween_callback(h.queue_free)


func _sparkle(center: Vector2, spread: float, count: int, color: Color) -> void:
	for i in count:
		var s := UI.image(UI.tex("betaGacha00/star01.png"), Vector2(14, 14))
		s.size = Vector2(14, 14)
		s.pivot_offset = Vector2(7, 7)
		s.modulate = color
		s.position = center + Vector2(randf_range(-spread, spread), randf_range(-spread, spread * 0.6))
		s.scale = Vector2.ZERO
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(s)
		var tw := s.create_tween()
		tw.tween_interval(randf_range(0.0, 0.4))
		tw.tween_property(s, "scale", Vector2.ONE * randf_range(0.6, 1.3), 0.15)
		tw.parallel().tween_property(s, "position:y", s.position.y - 24.0, 0.6)
		tw.tween_property(s, "modulate:a", 0.0, 0.3)
		tw.tween_callback(s.queue_free)


func _glow(kind: String, center: Vector2, size: float) -> void:
	var r := TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size = Vector2(size, size)
	r.position = center - r.size / 2.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	r.material = add
	_stage.add_child(r)
	for i in 17:
		var p := GLOW % [kind, kind, i]
		if not ResourceLoader.exists(p) or not is_inside_tree():
			break
		r.texture = UI.tex(p)
		await get_tree().create_timer(0.04).timeout
		if not is_instance_valid(r):
			return
	if is_instance_valid(r):
		r.queue_free()


func _run(hero_id: String, mat_id: String) -> void:
	var w := _stage.size.x
	var t0 := Time.get_ticks_msec()
	await _wait(0.3)
	var hero_shadow := _shadow(Vector2(w * 0.36, 300), 130.0)
	var mat_shadow := _shadow(Vector2(w * 0.76, 290), 70.0)
	var hero := _sprite(hero_id, Vector2(190, 170), Vector2(w * 0.36, 300), false)
	var mat := _sprite(mat_id, Vector2(84, 76), Vector2(w * 0.76, 290), true)
	for r in [hero, mat, hero_shadow, mat_shadow]:
		r.modulate.a = 0.0
		r.create_tween().tween_property(r, "modulate:a", 1.0, 0.15)
	await _wait(0.45)
	var bubble := _pop("betaGacha00/G_Detection_01.png", Vector2(52, 54), Vector2(w * 0.24, hero.position.y - 6), _stage)
	for i in 5:
		_heart(Vector2(w * 0.76, mat.position.y - 10))
		await _wait(0.27)
	await _wait(0.1)
	bubble.queue_free()
	await _wait(0.35)
	var hop := mat.create_tween().set_parallel()
	hop.tween_property(mat, "position", hero.position + hero.size * Vector2(0.5, 0.35) - mat.size / 2.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hop.tween_property(mat, "scale", Vector2(0.4, 0.4), 0.25)
	mat_shadow.create_tween().tween_property(mat_shadow, "modulate:a", 0.0, 0.2)
	await _wait(0.25)
	mat.hide()
	var bump := hero.create_tween()
	bump.tween_property(hero, "scale", Vector2(1.08, 0.94), 0.08)
	bump.tween_property(hero, "scale", Vector2.ONE, 0.12)
	_glow("y", hero.position + hero.size * Vector2(0.5, 0.55), 220.0)
	_sparkle(hero.position + hero.size * Vector2(0.5, 0.5), 80.0, 14, Color(1, 1, 0.8))
	await _wait(0.65)
	var feet := Vector2(w * 0.5, 380.0)
	var grow := hero.create_tween().set_parallel()
	grow.tween_property(hero, "position", feet - Vector2(hero.size.x / 2.0, hero.size.y), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	grow.tween_property(hero, "scale", Vector2(1.55, 1.55), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	grow.tween_property(hero_shadow, "position", feet - hero_shadow.size / 2.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	grow.tween_property(hero_shadow, "scale", Vector2(1.55, 1.55), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _wait(1.6)
	if success:
		await _success_burst(feet)
	else:
		await _fail_burst(feet, feet.y - hero.size.y * 1.55)
	await _wait(RESULT_AT - (Time.get_ticks_msec() - t0) / 1000.0)
	if _skip and _sound != null:
		_sound.stop()
	Sfx.play("popup_ok")
	finished.call()


func _shadow(feet: Vector2, width: float) -> TextureRect:
	var s := UI.image(Layout.texture("I_shadow_02.png"), Vector2(width, width * 0.36), TextureRect.STRETCH_SCALE)
	s.size = Vector2(width, width * 0.36)
	s.position = feet - s.size / 2.0
	s.pivot_offset = s.size / 2.0
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(s)
	return s


func _fail_burst(feet: Vector2, head_y: float) -> void:
	_glow("b", feet - Vector2(30, 40), 180.0)
	await _wait(0.2)
	lay.text("ID_titleText", "Boost")
	_pop("betaGacha00/G_Crying_01.png", Vector2(78, 80), Vector2(feet.x, maxf(48.0, head_y - 30.0)), _stage)


func _success_burst(feet: Vector2) -> void:
	_glow("b", feet - Vector2(0, 110), 300.0)
	_sparkle(feet - Vector2(0, 110), 120.0, 18, Color(0.6, 0.85, 1.0))
	await _wait(0.2)
	var flash := ColorRect.new()
	flash.color = Color.WHITE
	flash.size = _stage.size
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(flash)
	flash.create_tween().tween_property(flash, "modulate:a", 0.0, 0.45)
	lay.show("ID_title", false)
	var ribbon := UI.image(Layout.texture("K_ribon_01.png"), Vector2(480, 82))
	ribbon.size = Vector2(480, 82)
	ribbon.position = Vector2(-6, 6)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lay.node("ID_Dialog").add_child(ribbon)
	var txt := UI.label("Boost Successful", 28, Color("ffe7a0"))
	txt.size = Vector2(480, 56)
	txt.position = Vector2(0, 4)
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ribbon.add_child(txt)
	for i in 6:
		await _wait(0.22)
		_heart(Vector2(_stage.size.x * 0.5 + randf_range(-60, 60), 10))
