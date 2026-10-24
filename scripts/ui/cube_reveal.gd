class_name CubeReveal
extends Control

const SERIES := {"blue": "cube", "yellow": "cube02", "red": "cube05", "honor": "cube07", "honor5": "cube07", "black": "cube08", "pet": "petcube01", "pet_rare": "petcube02"}
const RARITY := {1: "common", 2: "uncommon", 3: "rare", 4: "superrare", 5: "epic", 6: "legendary"}
const QUEUE_ICONS := {"blue": "betaHud00/H_cube_00.png", "yellow": "betaHud00/H_cube_01.png", "red": "betaHud00/H_cube_02.png", "honor": "betaHud00/H_cube_01.png", "honor5": "betaHud00/H_cube_01.png", "pet": "betaHud00/H_petcube_01.png", "pet_rare": "betaHud00/H_petcube_02.png"}
const MBLUR := {"blue": "cube_mblur_00", "yellow": "cube_mblur_01", "red": "cube05_mblur_01", "honor": "cube07_mblur_01", "honor5": "cube07_mblur_01", "black": "cube08_mblur_01", "pet": "petcube_mblur_01", "pet_rare": "petcube_mblur_02"}
const BUBBLES := 4
const CUBE_W := 340.0

var cube_kind := "blue"
var items: Array = []
var is_pet := false
var buttons: Array = []
var _skip := false
var _stage: Control
var done := false
var no_cube := false
var evolve_from: Array = []
var backdrop: Texture2D
var _white: ColorRect


static func show_monster(parent: Control, id: String, btns: Array) -> CubeReveal:
	return play(parent, "blue", [id], [true], btns, false, true)


static func evolve(parent: Control, from_ids: Array, into: String, fresh: bool, btns: Array) -> CubeReveal:
	var r := CubeReveal.new()
	r.evolve_from = from_ids
	r.items.append({"id": into, "new": fresh})
	r.buttons = btns
	r.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	r.z_index = 70
	r.mouse_filter = MOUSE_FILTER_STOP
	parent.add_child(r)
	r._run()
	return r


static func play(parent: Control, kind: String, got: Array, new_flags: Array, btns: Array, pets: bool = false, skip_cube: bool = false, bg: Texture2D = null) -> CubeReveal:
	var r := CubeReveal.new()
	r.no_cube = skip_cube
	r.backdrop = bg
	r.cube_kind = kind
	r.is_pet = pets
	for i in got.size():
		r.items.append({"id": got[i], "new": bool(new_flags[i]) if i < new_flags.size() else false})
	r.buttons = btns
	r.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	r.z_index = 70
	r.mouse_filter = MOUSE_FILTER_STOP
	parent.add_child(r)
	r._run()
	return r


func _gui_input(e: InputEvent) -> void:
	if UI.pressed(e):
		_skip = true


func _frames(phase: String) -> Array:
	var dir := "res://assets/apk/sprites/%s_open_%s/" % [SERIES.get(cube_kind, "cube"), phase]
	var out := []
	for i in 20:
		var p := dir + "%s_open_%s_%03d.png" % [SERIES.get(cube_kind, "cube"), phase, i]
		if not ResourceLoader.exists(p):
			break
		out.append(UI.tex(p))
	return out


func _wait(t: float) -> void:
	var left := t
	while left > 0.0 and not _skip:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _rays() -> ColorRect:
	var rays := ColorRect.new()
	rays.color = Color("4f9ee8")
	rays.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	rays.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(rays)
	for k in 7:
		var beam := ColorRect.new()
		beam.color = Color(0.75, 0.9, 1.0, 0.14 + 0.06 * (k % 3))
		beam.size = Vector2(60 + 30 * (k % 3), 2000)
		beam.position = Vector2(k * 180 - 40, -600)
		beam.mouse_filter = MOUSE_FILTER_IGNORE
		rays.add_child(beam)
		var tw := beam.create_tween().set_loops()
		tw.tween_property(beam, "modulate:a", 0.4, 0.6 + 0.1 * k)
		tw.tween_property(beam, "modulate:a", 1.0, 0.6 + 0.1 * k)
	return rays


func _evolve_intro() -> void:
	var snd := Sfx.play("evolve")
	var rays := _rays()
	var vw := get_viewport_rect().size
	var c := vw / 2.0
	var open := _frames("03")
	var idle := _frames("01")
	var cube := TextureRect.new()
	cube.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cube.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cube.size = Vector2(560, 560)
	cube.position = c - cube.size / 2.0
	cube.pivot_offset = cube.size / 2.0
	cube.mouse_filter = MOUSE_FILTER_IGNORE
	cube.texture = open[open.size() - 1] if not open.is_empty() else null
	cube.scale = Vector2(0.3, 0.3)
	add_child(cube)
	cube.create_tween().tween_property(cube, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var mons: Array[TextureRect] = []
	for k in evolve_from.size():
		var tex := DB.battle_sprite(String(evolve_from[k]))
		var box := Vector2(200, 170)
		var drawn := tex.get_size() * minf(box.x / tex.get_width(), box.y / tex.get_height()) if tex != null and tex.get_width() > 0 else box
		var m := UI.image(tex, drawn)
		m.size = drawn
		m.pivot_offset = drawn / 2.0
		var side := -1.0 if k == 0 else 1.0
		m.position = Vector2(c.x + side * 170.0 - drawn.x / 2.0, c.y - 40.0 - drawn.y / 2.0)
		if k == 0:
			m.flip_h = true
		m.modulate.a = 0.0
		add_child(m)
		mons.append(m)
		m.create_tween().tween_property(m, "modulate:a", 1.0, 0.15)
	await _wait(0.75)
	for k in mons.size():
		var m := mons[k]
		var start := m.position
		var end := c - m.size / 2.0 + Vector2(0, 10)
		var tw := m.create_tween().set_parallel()
		tw.tween_method(func(t: float): m.position = start.lerp(end, t) + Vector2(0, -150.0 * sin(t * PI)), 0.0, 1.0, 0.5 + 0.12 * k).set_trans(Tween.TRANS_SINE)
		tw.tween_property(m, "scale", Vector2(0.35, 0.35), 0.5 + 0.12 * k).set_delay(0.15)
		tw.chain().tween_property(m, "modulate:a", 0.0, 0.12)
	await _wait(0.7)
	_sparkles(c, 10)
	for i in range(open.size() - 1, -1, -1):
		cube.texture = open[i]
		await _wait(0.06)
	var t := 0.0
	var i := 0
	while t < 1.8 and not _skip:
		if not idle.is_empty():
			cube.texture = idle[i % idle.size()]
		i += 1
		if i % 6 == 0:
			_sparkles(c, 3)
		await _wait(0.07)
		t += 0.07
	for f in open:
		cube.texture = f
		await _wait(0.04)
	if _skip and snd != null:
		snd.stop()
	var flash := ColorRect.new()
	flash.color = Color.WHITE
	flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	flash.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(flash)
	flash.create_tween().tween_property(flash, "modulate:a", 0.0, 0.45)
	rays.queue_free()
	cube.queue_free()
	for m in mons:
		m.queue_free()


func _sparkles(at: Vector2, n: int, spread := Vector2(110, 90)) -> void:
	for k in n:
		var sp := UI.image(UI.tex("betaGacha00/star01.png"), Vector2(18, 18))
		sp.size = Vector2(18, 18)
		sp.pivot_offset = Vector2(9, 9)
		sp.mouse_filter = MOUSE_FILTER_IGNORE
		sp.position = at + Vector2(randf_range(-spread.x, spread.x), randf_range(-spread.y, spread.y))
		sp.modulate = Color(1, 1, 1, 0.9)
		add_child(sp)
		var tw := sp.create_tween().set_parallel()
		tw.tween_property(sp, "position:y", sp.position.y - 40.0, 0.6)
		tw.tween_property(sp, "modulate:a", 0.0, 0.6)
		tw.tween_property(sp, "scale", Vector2(0.4, 0.4), 0.6)
		tw.chain().tween_callback(sp.queue_free)


func _run() -> void:
	if not evolve_from.is_empty():
		await _evolve_intro()
		_skip = false
		_scene()
		var h := await _reveal(items[0], true)
		_buttons(h, get_viewport_rect().size.y - 84.0)
		return
	if no_cube:
		Sfx.play("buff_big")
		_scene()
		var h := await _reveal(items[0], false)
		_buttons(h, get_viewport_rect().size.y - 84.0)
		return
	var c := get_viewport_rect().size / 2.0
	var rays := _stripes()
	rays.modulate = Color(0.4, 0.46, 0.7, 0.0)
	rays.create_tween().tween_property(rays, "modulate:a", 1.0, 0.15)
	var whoosh := Sfx.play("cube_open")
	await _wait(0.2)
	var cube := _cube(c)
	await _rise(cube, c)
	await _wait(0.6)
	rays.create_tween().tween_property(rays, "modulate", Color.WHITE, 0.1)
	_flash(0.5, 0.25)
	await _animate(cube, _frames("01"), 0.95, 1, c)
	await _animate(cube, _frames("02"), 0.9, 3, c)
	var quiet := not _skip and whoosh != null
	if not quiet:
		if whoosh != null:
			whoosh.stop()
		Sfx.play("buff_big")
	await _pop(cube, c, 1.0)
	rays.queue_free()
	_scene()
	_fade_white(0.18, 0.35)
	var queue := _queue(items.size() - 1)
	var held: Control = null
	for i in items.size():
		_skip = false
		if i > 0:
			held.create_tween().tween_property(held, "modulate:a", 0.0, 0.2)
			await _cube_from_queue(queue)
			held.queue_free()
		held = await _reveal(items[i], quiet and i == 0)
		if i < items.size() - 1:
			_skip = false
			await _wait(1.1)
	if items.size() == 1:
		_buttons(held, get_viewport_rect().size.y - 84.0)
		return
	_skip = false
	await _wait(0.6)
	held.create_tween().tween_property(held, "modulate:a", 0.0, 0.2)
	await _summary()


func _stripes() -> Control:
	var back := ColorRect.new()
	back.color = Color("2a6fd0")
	back.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	back.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(back)
	var frames := FrameFx.frames("u_bluebackstripe_01")
	if frames.is_empty():
		return back
	var vw := get_viewport_rect().size
	var cols := ceili(vw.x / 256.0) + 1
	for k in cols:
		var st := TextureRect.new()
		st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		st.stretch_mode = TextureRect.STRETCH_SCALE
		st.texture = frames[k % frames.size()]
		st.size = Vector2(256, vw.y)
		st.position = Vector2(k * 256.0 - 40.0, 0)
		st.flip_h = k % 2 == 1
		st.mouse_filter = MOUSE_FILTER_IGNORE
		back.add_child(st)
		var tw := st.create_tween().set_loops()
		for f in frames.size():
			tw.tween_callback(func(): st.texture = frames[(k + f) % frames.size()])
			tw.tween_interval(0.07)
	return back


func _scene() -> void:
	if _stage != null:
		return
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_stage.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_stage)
	move_child(_stage, 0)
	var bg := UI.image(backdrop if backdrop != null else UI.tex("res://assets/apk/images/Forest_1.png"), Vector2.ZERO, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.modulate = Color(0.62, 0.62, 0.62) if backdrop != null else Color(0.3, 0.5, 0.36)
	_stage.add_child(bg)
	var vig := TextureRect.new()
	vig.texture = _vignette_tex()
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	vig.mouse_filter = MOUSE_FILTER_IGNORE
	_stage.add_child(vig)


func _spot(parent: Control, feet: Vector2, w: float, h: float) -> void:
	var cone := UI.image(UI.tex("betaGacha00/MapMask01.png"), Vector2.ZERO, TextureRect.STRETCH_SCALE)
	cone.size = Vector2(w / 0.47, h / 0.35)
	cone.position = Vector2(feet.x - cone.size.x * 0.505, feet.y + h * 0.15 - h - cone.size.y * 0.22)
	cone.modulate = Color(0.3, 0.95, 0.5, 0.42)
	cone.material = _add_mat()
	parent.add_child(cone)
	var glow := TextureRect.new()
	glow.texture = _glow_tex()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.size = Vector2(w * 0.9, w * 0.3)
	glow.position = feet - glow.size / 2.0
	glow.mouse_filter = MOUSE_FILTER_IGNORE
	glow.material = _add_mat()
	glow.modulate.a = 0.7
	parent.add_child(glow)


static var _add: CanvasItemMaterial
static var _vig: GradientTexture2D


static func _add_mat() -> CanvasItemMaterial:
	if _add == null:
		_add = CanvasItemMaterial.new()
		_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add


static func _vignette_tex() -> GradientTexture2D:
	if _vig == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0.02, 0.01, 0.35), Color(0, 0.02, 0.01, 0.88)])
		_vig = GradientTexture2D.new()
		_vig.gradient = g
		_vig.fill = GradientTexture2D.FILL_RADIAL
		_vig.fill_from = Vector2(0.5, 0.6)
		_vig.fill_to = Vector2(1.05, 0.6)
		_vig.width = 256
		_vig.height = 256
	return _vig


static var _glow: GradientTexture2D


static func _glow_tex() -> GradientTexture2D:
	if _glow == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
		g.colors = PackedColorArray([Color(0.75, 1.0, 0.7, 0.75), Color(0.55, 1.0, 0.55, 0.45), Color(0.45, 0.95, 0.5, 0.15), Color(0.4, 0.9, 0.5, 0.0)])
		_glow = GradientTexture2D.new()
		_glow.gradient = g
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 256
		_glow.height = 256
	return _glow


func _queue(n: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", -4)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(row)
	var icon: Texture2D = UI.tex(QUEUE_ICONS.get(cube_kind, "betaHud00/H_cube_00.png"))
	var vw := get_viewport_rect().size
	for k in n:
		var ic := UI.image(icon, Vector2(60, 60))
		ic.custom_minimum_size = Vector2(60, 60)
		ic.modulate.a = 0.0
		var num := UI.label(str(k + 2), 24, Color("ff9d1c"))
		num.add_theme_color_override("font_outline_color", Color("5a1004"))
		num.add_theme_constant_override("outline_size", 6)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num.size = Vector2(60, 30)
		num.position = Vector2(0, 22)
		ic.add_child(num)
		row.add_child(ic)
	row.position = Vector2(vw.x - n * 56.0 - 10.0, 4)
	for k in n:
		var ic: Control = row.get_child(k)
		var tw := ic.create_tween()
		tw.tween_interval(0.9 + 0.07 * k)
		tw.tween_property(ic, "modulate:a", 1.0, 0.15)
	return row


func _cube_from_queue(queue: HBoxContainer) -> void:
	var c := get_viewport_rect().size / 2.0
	var from := c
	if queue.get_child_count() > 0:
		var first: Control = queue.get_child(0)
		from = first.global_position - global_position + first.size / 2.0
		var keep := queue.position.x + first.size.x + queue.get_theme_constant("separation")
		queue.remove_child(first)
		first.queue_free()
		queue.position.x = keep
	var cube := _cube(from)
	cube.scale = Vector2(0.18, 0.18)
	var tw := cube.create_tween().set_parallel()
	tw.tween_property(cube, "position", c - cube.size / 2.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(cube, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _wait(0.42)
	Sfx.play("buff_big")
	await _pop(cube, c, 0.55)
	_fade_white(0.0, 0.22)


func _cube(at: Vector2) -> TextureRect:
	var idle := _frames("01")
	var cube := TextureRect.new()
	cube.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cube.stretch_mode = TextureRect.STRETCH_SCALE
	cube.texture = idle[0] if not idle.is_empty() else null
	var src: Vector2 = cube.texture.get_size() if cube.texture != null else Vector2(480, 320)
	cube.size = src * (CUBE_W / (140.0 if src.x >= 400.0 else 190.0))
	cube.pivot_offset = cube.size / 2.0
	cube.position = at - cube.size / 2.0
	cube.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(cube)
	return cube


func _rise(cube: TextureRect, at: Vector2) -> void:
	cube.visible = false
	var tex := UI.tex("betaGacha00/%s.png" % MBLUR.get(cube_kind, "cube_mblur_00"))
	var blur := UI.image(tex, Vector2.ZERO, TextureRect.STRETCH_SCALE)
	var w := CUBE_W * (0.9 if is_pet else 1.0)
	blur.size = Vector2(w, w * tex.get_height() / tex.get_width()) if tex != null else Vector2(w, w * 1.6)
	blur.position = Vector2(at.x - blur.size.x / 2.0, get_viewport_rect().size.y + 20.0)
	add_child(blur)
	blur.create_tween().tween_property(blur, "position:y", at.y - blur.size.y / 2.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _wait(0.14)
	blur.queue_free()
	cube.visible = true
	cube.scale = Vector2(0.86, 1.16)
	cube.create_tween().tween_property(cube, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _animate(cube: TextureRect, fr: Array, total: float, loops: int, at: Vector2) -> void:
	if fr.is_empty():
		return
	var dt := total / float(fr.size() * loops)
	for l in loops:
		for i in fr.size():
			if _skip:
				return
			cube.texture = fr[i]
			if i % 4 == 0:
				_sparkles(at, 2, Vector2(CUBE_W * 0.6, CUBE_W * 0.45))
			await _wait(dt)


func _pop(cube: TextureRect, at: Vector2, white: float) -> void:
	var swell := cube.create_tween()
	swell.tween_property(cube, "scale", Vector2(1.1, 1.1), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	swell.tween_property(cube, "scale", Vector2(1.18, 1.18), 0.22)
	await _wait(0.14)
	var ring := FrameFx.play(self, "u_starburst_02", at, Vector2(1100, 733), 14)
	if ring != null:
		ring.z_index = 0
		move_child(ring, cube.get_index())
	for f in _frames("03"):
		cube.texture = f
		await _wait(0.045)
	_white = _flash(white, 0.0)
	cube.queue_free()


func _flash(alpha: float, fade: float) -> ColorRect:
	var f := ColorRect.new()
	f.color = Color(1, 1, 1, alpha)
	f.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	f.mouse_filter = MOUSE_FILTER_IGNORE
	f.z_index = 30
	add_child(f)
	if fade > 0.0:
		var tw := f.create_tween()
		tw.tween_property(f, "modulate:a", 0.0, fade)
		tw.tween_callback(f.queue_free)
	return f


func _fade_white(delay: float, t: float) -> void:
	if _white == null:
		return
	var tw := _white.create_tween()
	tw.tween_property(_white, "modulate:a", 0.0, t).set_delay(delay)
	tw.tween_callback(_white.queue_free)
	_white = null


func _info(it: Dictionary) -> Dictionary:
	if is_pet:
		var pdef := DB.pet(it.id)
		return {"stars": int(pdef.get("stars", 1)), "tex": DB.pet_texture(it.id)}
	var def := DB.monster(it.id)
	return {"stars": int(def.get("stars", 1)), "tex": DB.battle_sprite(it.id)}


static func fit(tex: Texture2D, box: Vector2, area: float = 0.0) -> Vector2:
	if tex == null or tex.get_width() <= 0:
		return box
	var s := tex.get_size()
	var k := minf(box.x / s.x, box.y / s.y)
	if area > 0.0:
		k = minf(k, sqrt(area / (s.x * s.y)))
	return s * k


func _monster(parent: Control, it: Dictionary, tex: Texture2D, feet: Vector2, box: Vector2, area: float = 0.0) -> Control:
	var drawn := fit(tex, box, area)
	var mon := Control.new()
	mon.size = drawn
	mon.position = Vector2(feet.x - drawn.x / 2.0, feet.y - drawn.y)
	mon.pivot_offset = Vector2(drawn.x / 2.0, drawn.y)
	mon.mouse_filter = MOUSE_FILTER_IGNORE
	if not is_pet:
		mon.mouse_filter = MOUSE_FILTER_STOP
		mon.gui_input.connect(_on_monster_tap.bind(String(it.id)))
	mon.add_child(UI.idle_art(tex, drawn))
	var shadow := UI.image(UI.tex("betaGacha00/GroundShadow.png"))
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.size = Vector2(drawn.x * 0.8, drawn.x * 0.18)
	shadow.position = feet - Vector2(shadow.size.x / 2.0, shadow.size.y * 0.55)
	parent.add_child(shadow)
	parent.add_child(mon)
	return mon


func _burst(parent: Control, at: Vector2, k: float) -> void:
	FrameFx.play(parent, "u_lightburst_01", at, Vector2(600, 480) * k, 26)
	FrameFx.play(parent, "u_particleburst_01", at - Vector2(0, 40) * k, Vector2(400, 267) * k * 1.3, 24)


func _slam(n: Control, from: float, t: float) -> void:
	n.scale = Vector2(from, from)
	n.modulate.a = 0.35
	var tw := n.create_tween().set_parallel()
	tw.tween_property(n, "scale", Vector2.ONE, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(n, "modulate:a", 1.0, t)


func _badges(parent: Control, it: Dictionary, stars: int, top: Vector2, star: float, title_w: float, animate: bool, step := 0.0) -> void:
	step = step if step > 0.0 else star
	var x0 := top.x - (step * (stars - 1) + star) / 2.0
	for s in stars:
		var st := UI.image(UI.tex("betaGacha00/star01.png"), Vector2(star, star))
		st.size = Vector2(star, star)
		st.position = Vector2(x0 + s * step, top.y)
		st.pivot_offset = Vector2(star, star) / 2.0
		parent.add_child(st)
		if animate:
			var end := st.position
			st.position = end + Vector2(star * 0.7, -star * 0.25)
			st.scale = Vector2(2.3, 2.3)
			st.modulate.a = 0.0
			var tw := st.create_tween().set_parallel()
			tw.tween_property(st, "position", end, 0.14).set_delay(0.07 * s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(st, "scale", Vector2.ONE, 0.14).set_delay(0.07 * s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(st, "modulate:a", 1.0, 0.1).set_delay(0.07 * s)
	if animate:
		Sfx.play("click")
		await _wait(0.07 * stars + 0.12)
	if it.new:
		var nw := UI.image(UI.tex("betaGacha00/new01.png"), Vector2(star * 1.35, star * 1.2))
		nw.size = Vector2(star * 1.35, star * 1.2)
		nw.position = Vector2(x0 - nw.size.x * 1.04, top.y - star * 0.12)
		nw.pivot_offset = nw.size / 2.0
		nw.rotation = deg_to_rad(-12)
		parent.add_child(nw)
		if animate:
			_slam(nw, 2.6, 0.14)
			nw.rotation = deg_to_rad(-30)
			nw.create_tween().tween_property(nw, "rotation", deg_to_rad(-12), 0.14)
			await _wait(0.16)
	var title := UI.image(UI.tex("betaGacha00/%s.png" % RARITY.get(clampi(stars, 1, 6), "common")))
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.size = Vector2(title_w, title_w * 0.21)
	title.position = Vector2(top.x - title_w / 2.0, top.y + star * 0.92)
	title.pivot_offset = title.size / 2.0
	parent.add_child(title)
	if animate:
		_slam(title, 3.2, 0.14)
		Sfx.play("buff")
		await _wait(0.2)


func _reveal(it: Dictionary, quiet: bool) -> Control:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(holder)
	var vw := get_viewport_rect().size
	var feet := Vector2(vw.x / 2.0, 500)
	var info := _info(it)
	_spot(holder, feet, 680, 560)
	var mon := _monster(holder, it, info.tex, feet, Vector2(480, 265), 85000.0)
	mon.scale = Vector2(0.3, 0.3)
	mon.create_tween().tween_property(mon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var ghost := UI.image(info.tex, Vector2.ZERO, TextureRect.STRETCH_SCALE)
	ghost.size = mon.size
	ghost.position = mon.position
	ghost.pivot_offset = mon.size / 2.0
	ghost.modulate = Color(1, 1, 1, 0.0)
	holder.add_child(ghost)
	holder.move_child(ghost, mon.get_index())
	var gt := ghost.create_tween()
	gt.tween_interval(0.18)
	gt.tween_property(ghost, "modulate:a", 0.55, 0.0)
	gt.tween_property(ghost, "scale", Vector2(1.45, 1.45), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	gt.parallel().tween_property(ghost, "modulate:a", 0.0, 0.4)
	gt.tween_callback(ghost.queue_free)
	_burst(holder, feet - Vector2(0, 60), 1.25)
	var loop := FrameFx.play(holder, "u_particleloop_01", feet - Vector2(0, mon.size.y * 0.45), Vector2(mon.size.x + 220, (mon.size.x + 220) * 0.667), 18)
	if loop != null:
		loop.loop = true
		loop.material = _add_mat()
	await _wait(0.5)
	await _badges(holder, it, int(info.stars), Vector2(vw.x / 2.0, 70), 66.0, 400.0, true, 74.0)
	_glint(holder, feet + Vector2(-mon.size.x * 0.22, -mon.size.y * 0.5))
	await _wait(0.45)
	var bubble := UI.image(UI.tex("betaGacha00/bubbleTip_%02d.png" % (absi(hash(it.id)) % BUBBLES + 1)), Vector2.ZERO, TextureRect.STRETCH_SCALE)
	bubble.size = Vector2(200, 98)
	var tip := feet + Vector2(clampf(mon.size.x * 0.5, 90.0, 170.0), -mon.size.y * 0.55)
	bubble.position = Vector2(minf(tip.x - 14.0, vw.x - bubble.size.x - 8.0), tip.y - bubble.size.y)
	bubble.pivot_offset = Vector2(14, bubble.size.y)
	bubble.scale = Vector2(0.2, 0.2)
	bubble.modulate.a = 0.0
	holder.add_child(bubble)
	var pop := bubble.create_tween().set_parallel()
	pop.tween_property(bubble, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(bubble, "modulate:a", 1.0, 0.12)
	return holder


func _glint(parent: Control, at: Vector2) -> void:
	var g := UI.image(UI.tex("betaGacha00/u_Highlight_01.png"), Vector2.ZERO, TextureRect.STRETCH_SCALE)
	g.size = Vector2(170, 170)
	g.position = at - g.size / 2.0
	g.pivot_offset = g.size / 2.0
	g.scale = Vector2.ZERO
	g.material = _add_mat()
	parent.add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "scale", Vector2(1.1, 1.1), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(g, "rotation", deg_to_rad(20), 0.6)
	tw.tween_interval(0.25)
	tw.tween_property(g, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(g.queue_free)


func _summary() -> void:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(holder)
	var vw := get_viewport_rect().size
	var n := items.size()
	var cols := n if n <= 5 else ceili(n / 2.0)
	var rows := ceili(float(n) / cols)
	var slot := minf(240.0, (vw.x - 40.0) / cols)
	var feet_y: Array = [vw.y * 0.6] if rows == 1 else [vw.y * 0.39, vw.y * 0.76]
	var box := Vector2(slot * 0.82, vw.y * (0.2 if rows > 1 else 0.3))
	var starsz := minf(34.0, slot / 6.6)
	await _wait(0.1)
	for i in n:
		var r := i / cols
		var k := i % cols
		var in_row := mini(cols, n - r * cols)
		var feet := Vector2(vw.x / 2.0 - in_row * slot / 2.0 + slot / 2.0 + k * slot, feet_y[r])
		var it: Dictionary = items[i]
		var info := _info(it)
		var light := Control.new()
		light.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		light.mouse_filter = MOUSE_FILTER_IGNORE
		holder.add_child(light)
		holder.move_child(light, 0)
		_spot(light, feet, slot * 1.15, 300)
		light.modulate.a = 0.0
		light.create_tween().tween_property(light, "modulate:a", 1.0, 0.2)
		var mon := _monster(holder, it, info.tex, feet, box, box.x * box.y * 0.8)
		mon.scale = Vector2(0.3, 0.3)
		mon.create_tween().tween_property(mon, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
		_burst(holder, feet - Vector2(0, 50), 0.55)
		await _wait(0.15)
		await _badges(holder, it, int(info.stars), Vector2(feet.x + (starsz * 0.5 if it.new else 0.0), feet.y - box.y - starsz * 2.3), starsz, slot * 0.92, true)
		await _wait(0.08)
	await _wait(0.5)
	_buttons(holder, vw.y - 84.0)


func _buttons(parent: Control, y: float) -> void:
	var vw := get_viewport_rect().size
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size = Vector2(vw.x, 80)
	row.position = Vector2(0, y)
	parent.add_child(row)
	var btns := buttons if not buttons.is_empty() else [{"text": "OK", "color": "yellow"}]
	for b in btns:
		var cb: Callable = b.get("cb", Callable())
		row.add_child(UI.button(String(b.text), _press.bind(cb), String(b.get("color", "orange")), Vector2(220, 76), 26))
	done = true


func _on_monster_tap(e: InputEvent, id: String) -> void:
	if not UI.tapped(e):
		return
	if not done:
		_skip = true
		return
	var uid := -1
	for m in Save.data.monsters:
		if String(m.id) == id:
			uid = maxi(uid, int(m.uid))
	if uid >= 0:
		MonsterPopup.info(self, uid, 10)
	else:
		MonsterPopup.info_of(self, id, 1, 10)


func _press(cb: Callable) -> void:
	queue_free()
	if cb.is_valid():
		cb.call()
