extends Control

const MONSTERS := ["chocomew", "firepaw", "ami", "guardwolf", "archwing", "e_zakum"]
const FLIPPED := ["e_zakum"]
const BODY_H := 150.0
const BODY_W := 185.0
const SEQUENCE := [
	["idle", 1.6], ["attack", 1.3], ["idle", 0.8], ["hit", 1.0], ["crit", 1.0], ["cast", 1.4],
	["idle", 0.6], ["die", 1.7], ["enter", 2.2],
]

var rows: Array = []
var caption: Label
var auto := true
var _step := 0
var _left := 0.0
var _once := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	UI.background(self, load("res://assets/battle_bg/candy_town.png"), 0.15)
	for a in OS.get_cmdline_user_args():
		if a == "--once":
			_once = true
	var w := get_viewport_rect().size
	var col := w.x / MONSTERS.size()
	for r in 2:
		var row := []
		var feet_y := w.y * (0.47 if r == 0 else 0.93)
		var tag := UI.label(["Now", "New"][r], 22, UI.CREAM)
		tag.position = Vector2(10, feet_y - BODY_H - 34)
		add_child(tag)
		for i in MONSTERS.size():
			var b := Body.new()
			b.setup(String(MONSTERS[i]), Vector2(col * (i + 0.5), feet_y), r == 0, String(MONSTERS[i]) in FLIPPED)
			add_child(b)
			row.append(b)
		rows.append(row)
	caption = UI.label("", 26, Color("fff23a"))
	caption.position = Vector2(w.x / 2.0 - 220, 8)
	caption.size = Vector2(440, 34)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(caption)
	var help := UI.label("1 attack  2 hit  3 crit  4 cast  5 die  6 enter  Space auto  click = hit", 16)
	help.position = Vector2(10, w.y - 26)
	add_child(help)
	_play(0)


func _play(i: int) -> void:
	_step = i % SEQUENCE.size()
	var act: String = SEQUENCE[_step][0]
	_left = float(SEQUENCE[_step][1])
	_do(act)


func _do(act: String) -> void:
	caption.text = act.capitalize() + ("" if auto else "  (manual)")
	for row in rows:
		for b in row:
			b.act(act)


func _process(delta: float) -> void:
	if auto:
		_left -= delta
		if _left <= 0.0:
			if _once and _step == SEQUENCE.size() - 1:
				get_tree().quit()
				return
			_play(_step + 1)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var keys := {KEY_1: "attack", KEY_2: "hit", KEY_3: "crit", KEY_4: "cast", KEY_5: "die", KEY_6: "enter"}
		if keys.has(e.keycode):
			auto = false
			_do(keys[e.keycode])
		elif e.keycode == KEY_SPACE:
			auto = not auto
			_play(0)


class Body extends Control:
	const PAD := Vector4(0.35, 0.3, 0.35, 0.0)
	const BREATH := 1.0
	const LEAN_K := 170.0
	const LEAN_C := 8.5
	const SQ_K := 320.0
	const SQ_C := 13.0
	const WALK_IN := 1.3
	const WALK_DIST := 220.0
	const STEP_RATE := 11.0

	var legacy := false
	var flipped := false
	var art: TextureRect
	var mat: ShaderMaterial
	var body := Vector2.ZERO
	var feet := Vector2.ZERO
	var t := randf() * 5.0
	var pose_lean := 0.0
	var pose_sy := 1.0
	var flash := 0.0
	var offset := Vector2.ZERO
	var lean := 0.0
	var lean_v := 0.0
	var sq := 0.0
	var sq_v := 0.0
	var dead := false
	var walking := 0.0
	var stride := 0.0
	var _tw: Tween

	func setup(id: String, at: Vector2, old: bool, flip: bool) -> void:
		legacy = old
		flipped = flip
		mouse_filter = MOUSE_FILTER_STOP
		var tex := DB.battle_sprite(id)
		var k := minf(BODY_H / tex.get_height(), BODY_W / tex.get_width())
		body = tex.get_size() * k
		feet = at
		size = body
		position = feet - Vector2(body.x / 2.0, body.y)
		UI.add_shadow(self, tex, Rect2(Vector2.ZERO, body))
		art = UI.image(tex, Vector2.ZERO, TextureRect.STRETCH_SCALE)
		art.flip_h = flip
		if legacy:
			art.size = body
			art.pivot_offset = body / 2.0
		else:
			art.size = body * Vector2(1.0 + PAD.x + PAD.z, 1.0 + PAD.y + PAD.w)
			art.position = -body * Vector2(PAD.x, PAD.y)
			art.pivot_offset = Vector2(art.size.x / 2.0, art.size.y)
			mat = ShaderMaterial.new()
			mat.shader = preload("res://scripts/ui/body_warp.gdshader")
			var full := Vector2(art.size.x, art.size.y)
			mat.set_shader_parameter("pad", Vector4(body.x * PAD.x / full.x, body.y * PAD.y / full.y, body.x * PAD.z / full.x, body.y * PAD.w / full.y))
			art.material = mat
		add_child(art)
		gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: act("hit"))

	func fwd() -> float:
		return -1.0 if flipped else 1.0

	func act(what: String) -> void:
		if dead and what != "enter":
			return
		if what == "idle":
			return
		if _tw != null:
			_tw.kill()
		if legacy:
			_legacy(what)
		else:
			_new(what)

	func _legacy(what: String) -> void:
		_tw = create_tween()
		match what:
			"attack":
				_tw.tween_property(self, "offset:x", 60.0 * fwd(), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				_tw.tween_interval(0.5)
				_tw.tween_property(self, "offset:x", 0.0, 0.08).set_trans(Tween.TRANS_QUAD)
			"hit", "crit":
				art.modulate = Color(1.5, 1.5, 1.5) if what == "crit" else Color(1.3, 1.3, 1.3)
				_tw.tween_property(art, "modulate", Color.WHITE, 0.1)
			"cast":
				var l := 0.12 * fwd()
				_tw.tween_property(art, "rotation", -l * 0.5, 0.1).set_ease(Tween.EASE_OUT)
				_tw.tween_property(art, "rotation", l, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				_tw.tween_interval(0.25)
				_tw.tween_property(art, "rotation", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
			"die":
				dead = true
				var away := -fwd()
				_tw.tween_property(self, "offset", Vector2(away * body.x * 0.04, -body.y * 0.05), 0.1).set_ease(Tween.EASE_OUT)
				_tw.parallel().tween_property(art, "rotation", away * 0.3, 0.2)
				_tw.tween_property(self, "offset", Vector2(away * body.x * 0.07, 0), 0.1).set_ease(Tween.EASE_IN)
				_tw.tween_interval(0.6)
				_tw.tween_property(self, "modulate:a", 0.0, 0.3)
			"enter":
				_reset()
				_walk_in()

	func _new(what: String) -> void:
		_tw = create_tween()
		match what:
			"attack":
				_tw.tween_property(self, "pose_lean", -0.07, 0.1).set_ease(Tween.EASE_OUT)
				_tw.parallel().tween_property(self, "pose_sy", 0.92, 0.1).set_ease(Tween.EASE_OUT)
				_tw.tween_property(self, "offset:x", 60.0 * fwd(), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				_tw.parallel().tween_property(self, "pose_lean", 0.12, 0.07)
				_tw.parallel().tween_property(self, "pose_sy", 1.05, 0.07)
				_tw.tween_callback(func(): kick(0.0, -2.2))
				_tw.tween_property(self, "pose_lean", 0.03, 0.12)
				_tw.parallel().tween_property(self, "pose_sy", 1.0, 0.12)
				_tw.tween_interval(0.35)
				_tw.tween_property(self, "offset:x", 0.0, 0.1).set_trans(Tween.TRANS_QUAD)
				_tw.parallel().tween_property(self, "pose_lean", 0.0, 0.1)
				_tw.tween_callback(func(): kick(-1.4, -1.2))
			"hit", "crit":
				var hard := 1.6 if what == "crit" else 1.0
				flash = 0.45 if what == "crit" else 0.3
				kick(-3.2 * hard, -3.0 * hard)
				_tw.tween_property(self, "flash", 0.0, 0.1)
				_tw.parallel().tween_property(self, "offset:x", -10.0 * hard * fwd(), 0.05).set_ease(Tween.EASE_OUT)
				_tw.tween_property(self, "offset:x", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
			"cast":
				_tw.tween_property(self, "pose_sy", 0.88, 0.14).set_ease(Tween.EASE_OUT)
				_tw.parallel().tween_property(self, "pose_lean", -0.05, 0.14)
				_tw.tween_property(self, "pose_sy", 1.1, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				_tw.parallel().tween_property(self, "pose_lean", 0.07, 0.08)
				_tw.tween_interval(0.25)
				_tw.tween_property(self, "pose_sy", 1.0, 0.12)
				_tw.parallel().tween_property(self, "pose_lean", 0.0, 0.12)
				_tw.tween_callback(func(): kick(-1.0, -2.5))
			"die":
				dead = true
				var away := -fwd()
				kick(-3.5, -3.5)
				flash = 0.3
				_tw.tween_property(self, "flash", 0.0, 0.15)
				_tw.parallel().tween_property(self, "offset", Vector2(away * body.x * 0.06, -body.y * 0.1), 0.12).set_ease(Tween.EASE_OUT)
				_tw.parallel().tween_property(art, "rotation", away * 0.35, 0.22)
				_tw.parallel().tween_property(self, "pose_sy", 1.06, 0.12)
				_tw.tween_property(self, "offset", Vector2(away * body.x * 0.1, 0), 0.1).set_ease(Tween.EASE_IN)
				_tw.parallel().tween_property(self, "pose_sy", 0.82, 0.1).set_ease(Tween.EASE_IN)
				_tw.tween_callback(func(): kick(0.0, -2.0))
				_tw.tween_interval(0.5)
				_tw.tween_property(self, "modulate:a", 0.0, 0.3)
			"enter":
				_reset()
				_walk_in()
				_tw.parallel().tween_property(self, "pose_lean", 0.07, 0.2)
				_tw.tween_callback(func(): kick(-2.6, -2.4))
				_tw.parallel().tween_property(self, "pose_lean", 0.0, 0.12)

	func _walk_in() -> void:
		offset = Vector2(-WALK_DIST * fwd(), 0)
		walking = WALK_IN
		stride = 0.0
		_tw.tween_property(self, "offset:x", 0.0, WALK_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	func kick(lean_push: float, sq_push: float) -> void:
		lean_v += lean_push
		sq_v += sq_push

	func _reset() -> void:
		dead = false
		modulate.a = 1.0
		art.rotation = 0.0
		pose_lean = 0.0
		pose_sy = 1.0
		lean = 0.0
		lean_v = 0.0
		sq = 0.0
		sq_v = 0.0
		flash = 0.0
		walking = 0.0

	func _process(delta: float) -> void:
		t += delta
		var breath := sin(t * TAU / BREATH)
		var hop := 0.0
		if walking > 0.0:
			walking -= delta
			stride += delta * STEP_RATE
			hop = absf(sin(stride)) if walking > 0.0 else 0.0
			if legacy:
				art.rotation = sin(stride) * 0.06 if walking > 0.0 else 0.0
		if legacy:
			var s := 1.0 + breath * 0.022 if not dead and walking <= 0.0 else 1.0
			art.scale.y = s
			position = feet - Vector2(body.x / 2.0, body.y) + offset - Vector2(0, (s - 1.0) * body.y / 2.0 + hop * 7.0)
			return
		var steps := 4
		for i in steps:
			var dt := delta / steps
			lean_v += (-LEAN_K * lean - LEAN_C * lean_v) * dt
			lean += lean_v * dt
			sq_v += (-SQ_K * sq - SQ_C * sq_v) * dt
			sq += sq_v * dt
		var calm := 0.0 if dead or walking > 0.0 else 1.0
		var gait := (hop - 0.5) * 0.08 if walking > 0.0 else 0.0
		var y := pose_sy + sq * 0.12 + breath * 0.016 * calm + gait
		mat.set_shader_parameter("sy", y)
		mat.set_shader_parameter("sx", 1.0 / sqrt(maxf(y, 0.5)))
		mat.set_shader_parameter("bulge", breath * 0.025 * calm)
		var sway := sin(stride) * 0.025 if walking > 0.0 else sin(t * TAU / (BREATH * 2.0)) * 0.012 * calm
		mat.set_shader_parameter("lean", pose_lean + lean * 0.06 + sway)
		mat.set_shader_parameter("flutter", 0.012 * calm)
		mat.set_shader_parameter("phase", t * 5.0)
		mat.set_shader_parameter("flash", flash)
		position = feet - Vector2(body.x / 2.0, body.y) + offset - Vector2(0, hop * 6.0)
