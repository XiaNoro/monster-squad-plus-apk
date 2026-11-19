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
const BAR_PX := 81.0
const SIZE_PX := BAR_PX * Layout.WIDEN
const IDLE_PERIOD := 1.0
const IDLE_SQUASH := 0.016
const IDLE_BULGE := 0.025
const IDLE_SWAY := 0.012
const IDLE_FLUTTER := 0.012
const DASH := 0.2
const MELEE_REACH := 0.68
const MELEE_HOLD := 0.9
const WARP := preload("res://scripts/ui/body_warp.gdshader")
const WARP_PAD := Vector4(0.35, 0.3, 0.35, 0.0)
const STEP_RATE := 11.0
const WALK_HOP := 7.0
const WALK_LEAN := 0.07
const WALK_LEAN_RATE := 0.35
const WALK_SWAY := 0.025
const WALK_GAIT := 0.08
const STOP_KICK := Vector2(-2.6, -2.4)
const LEAN_K := 170.0
const LEAN_C := 8.5
const LEAN_SCALE := 0.06
const SQ_K := 320.0
const SQ_C := 13.0
const SQ_SCALE := 0.12
const DASH_LEAN := 0.12
const DASH_STRETCH := 1.05
const HIT_KICK := Vector2(-3.2, -3.0)
const CRIT_HARD := 1.6
const KNOCKBACK := 10.0
const CAPTION_SIZE := 17
const CAPTION_DROP := 52.0
const DF_ROOT := "res://assets/apk/sprites/damage_font/"
const DF_KERN := 6.0
const DF := {
	"normal": {"sheet": "DF_normal", "rise": 10.0, "vy": 120.0, "ay": -230.0, "life": 0.8, "fade": 0.1, "start": 0.5, "keys": [[0.1, 1.4], [0.1, 0.6]]},
	"crit": {"sheet": "DF_criticalN", "rise": -10.0, "vy": 20.0, "ay": -30.0, "life": 0.8, "fade": 0.1, "start": 0.1, "keys": [[0.1, 2.0], [0.1, 0.8]]},
	"crit_word": {"rise": 50.0, "vy": 20.0, "ay": -30.0, "life": 0.8, "fade": 0.1, "start": 0.1, "keys": [[0.1, 1.8], [0.1, 0.9]]},
	"heal": {"sheet": "DF_heal", "rise": 0.0, "vy": 50.0, "ay": -70.0, "life": 1.0, "fade": 0.2, "start": 0.5, "keys": [[0.8, 0.7]]},
	"dot": {"sheet": "DF_poison", "rise": 10.0, "vy": 50.0, "ay": -50.0, "life": 0.8, "fade": 0.1, "start": 0.5, "keys": [[0.1, 0.8], [0.7, 0.55]]},
	"burn": {"sheet": "figure01small", "rise": 10.0, "vy": 50.0, "ay": -50.0, "life": 0.8, "fade": 0.1, "start": 1.1, "keys": [[0.1, 1.8], [0.7, 1.3]]},
}

var _loops: Dictionary = {}
var unit: BattleUnit
var home: Vector2
var sprite: TextureRect
var hp_bar: Range
var incoming := 0.0
var _ind: Layout
var shield_bar: ProgressBar
var badges: HBoxContainer
var target_mark: Control
var ring: ChargeRing
var _walk := 0.0
var _step := 0.0
var _art_at := Vector2.ZERO
var _warp: ShaderMaterial
var _walk_lean := 0.0
var _lean := 0.0
var _lean_v := 0.0
var _sq := 0.0
var _sq_v := 0.0
var _pose_lean := 0.0
var _pose_sy := 1.0
var _knock := 0.0
var _hit_tw: Tween
var _death: Tween
var _lunge: Tween
var _cast: Tween
var _idle := randf() * IDLE_PERIOD


static func body_size(tex: Texture2D, box: Vector2) -> Vector2:
	if tex == null or tex.get_width() <= 0:
		return box
	var s := tex.get_size()
	return s * minf(sqrt(box.x * box.y / (s.x * s.y)), minf(box.x * MAX_W / s.x, box.y * MAX_H / s.y))


static func role_of(u: BattleUnit) -> String:
	if u.is_leader:
		return "leader"
	if u.side == BattleUnit.PLAYER:
		return "ally"
	return "boss" if u.is_boss else "enemy"


func setup(u: BattleUnit, pos: Vector2, box: Vector2, mult: float = 1.0) -> void:
	unit = u
	var tex := DB.battle_sprite(u.monster_id)
	var tall := DB.sprite_height(u.monster_id, role_of(u)) * SIZE_PX
	var sprite_size := body_size(tex, box)
	if tall > 0.0 and tex != null and tex.get_height() > 0:
		sprite_size = tex.get_size() * (tall / tex.get_height())
	sprite_size *= mult
	home = Vector2(pos.x - sprite_size.x / 2.0, pos.y + box.y / 2.0 - sprite_size.y)
	position = home
	size = sprite_size
	mouse_filter = MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

	sprite = UI.image(tex, Vector2.ZERO, TextureRect.STRETCH_SCALE)
	var pad := Vector2(WARP_PAD.x, WARP_PAD.y) * sprite_size
	var full := Vector2(1.0 + WARP_PAD.x + WARP_PAD.z, 1.0 + WARP_PAD.y + WARP_PAD.w)
	sprite.size = sprite_size * full
	_art_at = -pad
	sprite.position = _art_at
	sprite.flip_h = u.side == BattleUnit.ENEMY
	sprite.pivot_offset = pad + Vector2(sprite_size.x / 2.0, sprite_size.y)
	_warp = ShaderMaterial.new()
	_warp.shader = WARP
	_warp.set_shader_parameter("pad", Vector4(WARP_PAD.x / full.x, WARP_PAD.y / full.y, WARP_PAD.z / full.x, WARP_PAD.w / full.y))
	sprite.material = _warp
	add_child(sprite)
	UI.add_shadow(self, sprite.texture, Rect2(Vector2.ZERO, sprite_size))
	if u.is_leader and u.side == BattleUnit.PLAYER:
		_ground_fx("ui_target_leader", true)
	if u.pet_id != "":
		var side := minf(sprite_size.y * 0.5, 96.0)
		var pet := UI.pet_buddy(u.pet_id, Vector2(side, side), u.side == BattleUnit.PLAYER)
		pet.position = Vector2(-side * 0.55 if u.side == BattleUnit.PLAYER else sprite_size.x - side * 0.45, sprite_size.y * 0.2)
		add_child(pet)

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
	ring = ChargeRing.new()
	ring.size = frame.size
	ring.color = ChargeRing.COLORS.get(u.element, ChargeRing.COLORS.normal)
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

	target_mark = _ground_fx("ui_target_enemy", false)
	target_mark.visible = false


func _ground_fx(sheet: String, on: bool) -> FrameFx:
	var frames := FrameFx.frames(sheet)
	var box: Vector2 = frames[0].get_size() if not frames.is_empty() else Vector2(256, 168)
	var fx := FrameFx.play(self, sheet, Vector2(size.x / 2.0, size.y - 2.0), box, 15.0)
	if fx == null:
		fx = FrameFx.new()
		add_child(fx)
	fx.loop = true
	fx.z_index = 0
	fx.visible = on
	move_child(fx, sprite.get_index())
	return fx


func _on_gui_input(e: InputEvent) -> void:
	if UI.pressed(e):
		tapped.emit(self)


func refresh() -> void:
	hp_bar.value = clampf((unit.hp + incoming) / maxf(1.0, unit.max_hp), 0.0, 1.0)
	shield_bar.value = clampf(unit.shield / maxf(1.0, unit.max_hp * 0.3), 0.0, 1.0)
	shield_bar.visible = unit.shield > 0.0
	_refresh_badges()
	_refresh_loops()


func _refresh_loops() -> void:
	var want := SkillFx.loop_sheets(unit) if unit.alive() else {}
	for k in _loops.keys():
		if not want.has(k) or not is_instance_valid(_loops[k]):
			if is_instance_valid(_loops[k]):
				_loops[k].queue_free()
			_loops.erase(k)
	for k in want:
		if not _loops.has(k):
			var fx: FrameFx
			if String(k) in SkillFx.FRONT_LOOPS:
				var ahead := 1.0 if unit.side == BattleUnit.PLAYER else -1.0
				fx = SkillFx.play(self, k, size / 2.0 + Vector2(size.x * 0.12 * ahead, 0.0), clampf(size.y / 120.0, 0.7, 2.0), ahead > 0.0, SkillFx.LOOP_FPS, false, false)
				if fx != null:
					fx.loop = true
			else:
				var head := String(k) in SkillFx.HEAD_LOOPS
				var at := Vector2(size.x / 2.0, -size.y * 0.05) if head else size / 2.0
				fx = SkillFx.loop(self, k, at, clampf(size.y / 110.0, 0.7, 1.3) * (0.6 if head else 1.0))
			if fx != null:
				if String(k) in SkillFx.BACK_LOOPS:
					fx.z_index = 0
					move_child(fx, sprite.get_index())
				_loops[k] = fx


func set_charge(value: float) -> void:
	if ring != null:
		ring.value = value if unit.alive() else 0.0


func set_targeted(on: bool) -> void:
	target_mark.visible = on and unit.alive()


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


func lunge(toward: Vector2, melee: bool = false, target_w: float = 0.0) -> void:
	var gap := toward - (home + size / 2.0)
	if _lunge != null:
		_lunge.kill()
	_lunge = create_tween()
	var reach := gap.normalized() * minf(gap.length() * MELEE_REACH, maxf(0.0, gap.length() - (size.x + target_w) * 0.4)) if melee else gap.normalized() * minf(gap.length() * DASH, size.x)
	var dash := 0.12 if melee else 0.07
	_lunge.tween_property(self, "position", home + reach, dash).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_lunge.parallel().tween_property(self, "_pose_lean", DASH_LEAN, dash)
	_lunge.parallel().tween_property(self, "_pose_sy", DASH_STRETCH, dash)
	_lunge.tween_callback(kick.bind(0.0, -2.2))
	_lunge.tween_property(self, "_pose_lean", DASH_LEAN * 0.25, 0.12)
	_lunge.parallel().tween_property(self, "_pose_sy", 1.0, 0.12)
	_lunge.tween_interval(maxf(0.0, (MELEE_HOLD if melee else 0.5) - 0.12))
	_lunge.tween_property(self, "position", home, 0.08).set_trans(Tween.TRANS_QUAD)
	_lunge.parallel().tween_property(self, "_pose_lean", 0.0, 0.08)
	_lunge.tween_callback(kick.bind(-1.4, -1.2))


func hit(crit: bool) -> void:
	sprite.modulate = Color(1.5, 1.5, 1.5) if crit else Color(1.3, 1.3, 1.3)
	var hard := CRIT_HARD if crit else 1.0
	kick(HIT_KICK.x * hard, HIT_KICK.y * hard)
	if _hit_tw != null:
		_hit_tw.kill()
	_hit_tw = create_tween()
	_hit_tw.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	_hit_tw.parallel().tween_property(self, "_knock", -KNOCKBACK * hard, 0.05).set_ease(Tween.EASE_OUT)
	_hit_tw.tween_property(self, "_knock", 0.0, 0.25).set_trans(Tween.TRANS_SINE)


func cast() -> void:
	if _cast != null:
		_cast.kill()
	_cast = create_tween()
	_cast.tween_property(self, "_pose_sy", 0.88, 0.14).set_ease(Tween.EASE_OUT)
	_cast.parallel().tween_property(self, "_pose_lean", -0.05, 0.14)
	_cast.tween_property(self, "_pose_sy", 1.1, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cast.parallel().tween_property(self, "_pose_lean", 0.07, 0.08)
	_cast.tween_interval(0.25)
	_cast.tween_property(self, "_pose_sy", 1.0, 0.12)
	_cast.parallel().tween_property(self, "_pose_lean", 0.0, 0.12)
	_cast.tween_callback(kick.bind(-1.0, -2.5))


func kick(lean_push: float, squash_push: float) -> void:
	_lean_v += lean_push
	_sq_v += squash_push


func pulse(color: Color) -> void:
	sprite.modulate = color
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.35)


func die() -> void:
	set_targeted(false)
	if _lunge != null:
		_lunge.kill()
	if _cast != null:
		_cast.kill()
	sprite.scale = Vector2.ONE
	var away := 1.0 if unit.side == BattleUnit.ENEMY else -1.0
	var land := position + Vector2(away * size.x * 0.07, 0)
	_walk = 0.0
	_ind.root.visible = false
	badges.visible = false
	kick(-3.5, -3.5)
	_death = create_tween()
	_death.tween_property(self, "position", position + Vector2(away * size.x * 0.04, -size.y * 0.05), 0.1).set_ease(Tween.EASE_OUT)
	_death.parallel().tween_property(sprite, "rotation", away * 0.3, 0.2)
	_death.parallel().tween_property(self, "_pose_sy", 1.06, 0.1)
	_death.parallel().tween_property(self, "_pose_lean", 0.0, 0.1)
	_death.tween_property(self, "position", land, 0.1).set_ease(Tween.EASE_IN)
	_death.parallel().tween_property(self, "_pose_sy", 0.82, 0.1).set_ease(Tween.EASE_IN)
	_death.tween_callback(kick.bind(0.0, -2.0))
	_death.tween_interval(0.6)
	_death.tween_property(self, "modulate:a", 0.0, 0.3)


func dying() -> bool:
	return _death != null and _death.is_running()


func reset_pose() -> void:
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE
	_pose_lean = 0.0
	_pose_sy = 1.0
	_knock = 0.0
	_lean = 0.0
	_lean_v = 0.0
	_sq = 0.0
	_sq_v = 0.0


func revive() -> void:
	if _death != null:
		_death.kill()
	position = home
	reset_pose()
	_ind.root.visible = true
	badges.visible = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.4)
	kick(0.0, -4.0)
	pulse(Color(1.6, 1.5, 1.1))
	float_text("Revive!", Color("ffe48a"), 24)
	refresh()


func float_text(text: String, color: Color, font_size: int = 26) -> void:
	var l := pop_label(text, font_size, color.lightened(0.45), color.darkened(0.1), 6, false)
	_carry(l)
	var s := l.get_minimum_size()
	l.position = Vector2(size.x / 2.0 - s.x / 2.0 + randf_range(-20, 20), size.y * 0.2)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 60, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.35)
	tw.tween_callback(l.queue_free)


func caption(text: String) -> void:
	var l := UI.label(text, CAPTION_SIZE, Color8(222, 222, 228))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	l.z_index = 20
	_layer().add_child(l)
	var s := l.get_minimum_size()
	l.position = home + Vector2(size.x / 2.0 - s.x / 2.0, size.y + CAPTION_DROP)
	var tw := l.create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


func damage_number(amount: int, kind: String, icon: Texture2D = null) -> void:
	var style: Dictionary = DF[kind]
	var num := df_text(String(style.sheet), str(amount))
	if icon != null:
		var isz := num.size.y * 0.6
		var ic := UI.image(icon, Vector2(isz, isz))
		ic.size = Vector2(isz, isz)
		ic.position = Vector2(-isz * 0.75, num.size.y - isz * 1.1)
		num.add_child(ic)
	var at := Vector2(size.x / 2.0 + randf_range(-16, 16), size.y * 0.12 + randf_range(-8, 8))
	_df_play(num, style, at)
	if kind == "crit":
		var word := TextureRect.new()
		word.texture = load(DF_ROOT + "DF_critical.png")
		word.mouse_filter = MOUSE_FILTER_IGNORE
		word.size = word.texture.get_size()
		_df_play(word, DF.crit_word, at)


static func df_text(sheet: String, text: String) -> Control:
	var root := Control.new()
	root.mouse_filter = MOUSE_FILTER_IGNORE
	var glyphs := _df_glyphs(sheet)
	var x := 0.0
	var h := 0.0
	for ch in text:
		if not ch.is_valid_int():
			continue
		var tex: Texture2D = glyphs[int(ch)]
		var r := TextureRect.new()
		r.texture = tex
		r.mouse_filter = MOUSE_FILTER_IGNORE
		r.position = Vector2(x, 0)
		root.add_child(r)
		x += tex.get_width() - DF_KERN
		h = tex.get_height()
	root.size = Vector2(x + DF_KERN, h)
	return root


static func _df_glyphs(sheet: String) -> Array:
	if not _df_cache.has(sheet):
		var tex: Texture2D = load(DF_ROOT + sheet + ".png")
		var img := tex.get_image()
		var cell := img.get_width() / 10
		var list := []
		for d in 10:
			var x0 := cell
			var x1 := 0
			for x in cell:
				for y in img.get_height():
					if img.get_pixel(d * cell + x, y).a > 0.1:
						x0 = mini(x0, x)
						x1 = maxi(x1, x)
						break
			var a := AtlasTexture.new()
			a.atlas = tex
			a.region = Rect2(d * cell + x0, 0, x1 - x0 + 1, img.get_height())
			list.append(a)
		_df_cache[sheet] = list
	return _df_cache[sheet]


static func _df_scale(style: Dictionary, t: float) -> float:
	var s := float(style.start)
	for k in style.keys:
		var d := float(k[0])
		if t < d:
			return lerpf(s, float(k[1]), t / d)
		t -= d
		s = float(k[1])
	return s


func _df_play(n: Control, style: Dictionary, at: Vector2) -> void:
	n.pivot_offset = n.size / 2.0
	n.z_index = 20
	_carry(n)
	var life := float(style.life)
	var fade := float(style.fade)
	var step := func(t: float):
		var s := _df_scale(style, t)
		n.scale = Vector2(s, s)
		n.position = at - n.size / 2.0 - Vector2(0, float(style.rise) + float(style.vy) * t + 0.5 * float(style.ay) * t * t)
		n.modulate.a = clampf((life - t) / fade, 0.0, 1.0)
	step.call(0.0)
	var tw := n.create_tween()
	tw.tween_method(step, 0.0, life, life)
	tw.tween_callback(n.queue_free)


func gold_pop(amount: int) -> void:
	var l := pop_label("+%d G" % amount, 30, Color("fff7a8"), Color("ffc414"))
	_layer().add_child(l)
	var s := l.get_minimum_size()
	l.size = s
	l.pivot_offset = s / 2.0
	l.position = position + Vector2(size.x / 2.0 - s.x / 2.0, size.y * 0.12 - 38)
	_pop(l, 1.35, 0.7)
	FrameFx.play(_layer(), "u_moneyex_01", position + Vector2(size.x / 2.0, size.y * 0.35), Vector2(560, 448))


func warn(seconds: float) -> void:
	var b := UI.image(UI.tex("res://assets/ui/alert_bubble.png"), Vector2(46, 48))
	b.size = Vector2(46, 48)
	b.pivot_offset = Vector2(23, 48)
	b.position = Vector2(size.x / 2.0 - 34, -62)
	b.scale = Vector2.ZERO
	b.z_index = 15
	add_child(b)
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(1.2, 1.2), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2.ONE, 0.08)
	tw.tween_interval(maxf(0.2, seconds - 0.4))
	tw.tween_property(b, "modulate:a", 0.0, 0.2)
	tw.tween_callback(b.queue_free)


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


func _carry(n: Control) -> void:
	var c := Carrier.new()
	c.anchor = self
	c.position = position
	c.mouse_filter = MOUSE_FILTER_IGNORE
	_layer().add_child(c)
	c.add_child(n)
	n.tree_exited.connect(c.queue_free)


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


static var _df_cache: Dictionary = {}
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


var _exp_bar: TextureProgressBar
var _exp_lv: Label
var _exp_pct: Label
var _lvl_label: Control
var _leveled := false


static func _gradient(colors: Array, w: int, h: int, vertical: bool = false) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(range(colors.size()).map(func(i): return float(i) / float(colors.size() - 1)))
	g.colors = PackedColorArray(colors)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = w
	t.height = h
	t.fill_to = Vector2(0, 1) if vertical else Vector2(1, 0)
	return t


func show_exp(level: int, pct: float) -> void:
	if _exp_bar == null:
		_ind.root.visible = false
		badges.visible = false
		var w := hp_bar.size.x + 34.0
		var at := Vector2(size.x / 2.0 - w / 2.0 + 22.0, 6.0)
		var frame := Panel.new()
		var edge := StyleBoxFlat.new()
		edge.bg_color = Color(0.12, 0.07, 0.04, 0.92)
		edge.border_color = Color(0.04, 0.02, 0.0)
		edge.set_border_width_all(2)
		edge.set_corner_radius_all(6)
		frame.add_theme_stylebox_override("panel", edge)
		frame.position = at - Vector2(2, 2)
		frame.size = Vector2(w + 4, 15)
		frame.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(frame)
		_exp_bar = TextureProgressBar.new()
		_exp_bar.max_value = 100.0
		_exp_bar.step = 0.0
		_exp_bar.nine_patch_stretch = true
		_exp_bar.texture_progress = _gradient([Color("d81c14"), Color("f0501a"), Color("ff9a22")], 64, 4)
		_exp_bar.texture_over = _gradient([Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.3)], 4, 16, true)
		_exp_bar.size = Vector2(w, 11)
		_exp_bar.position = at
		_exp_bar.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(_exp_bar)
		_exp_lv = pop_label("", 22, Color("ffd84a"), Color("ff7a12"), 7)
		add_child(_exp_lv)
		_exp_pct = pop_label("", 27, Color("fff27a"), Color("ff9a18"), 8)
		add_child(_exp_pct)
	_exp_bar.value = clampf(pct, 0.0, 100.0)
	_exp_lv.text = "Lv%d" % level
	var ls := _exp_lv.get_minimum_size()
	_exp_lv.size = ls
	_exp_lv.position = _exp_bar.position + Vector2(-ls.x + 4.0, _exp_bar.size.y / 2.0 - ls.y / 2.0 - 2.0)
	_exp_pct.text = "%.1f%%" % clampf(pct, 0.0, 100.0)
	var ps := _exp_pct.get_minimum_size()
	_exp_pct.size = ps
	_exp_pct.position = _exp_bar.position + Vector2(_exp_bar.size.x * 0.55 - ps.x / 2.0, -ps.y + 4.0)


func level_up() -> void:
	if _lvl_label != null and is_instance_valid(_lvl_label):
		var old: Tween = _lvl_label.get_meta("tween") if _lvl_label.has_meta("tween") else null
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
	var gait := 0.0
	var sway := 0.0
	if _walk > 0.0:
		_walk -= delta
		_step += delta * STEP_RATE
		var hop := absf(sin(_step))
		pos.y -= hop * WALK_HOP
		if _walk > 0.0:
			gait = (hop - 0.5) * WALK_GAIT
			sway = sin(_step) * WALK_SWAY
			_walk_lean = move_toward(_walk_lean, WALK_LEAN, WALK_LEAN_RATE * delta)
		else:
			_lean_v += STOP_KICK.x
			_sq_v += STOP_KICK.y
	var calm := 0.0
	var breath := 0.0
	if _walk <= 0.0 and unit != null and unit.alive() and not dying():
		calm = 1.0
		_idle += delta
		breath = sin(_idle * TAU / IDLE_PERIOD)
		sway = sin(_idle * TAU / (IDLE_PERIOD * 2.0)) * IDLE_SWAY
	if _walk <= 0.0:
		_walk_lean = move_toward(_walk_lean, 0.0, WALK_LEAN_RATE * 2.0 * delta)
	var forward := 1.0 if unit == null or unit.side == BattleUnit.PLAYER else -1.0
	sprite.position = _art_at + pos + Vector2(_knock * forward, 0.0)
	_settle(delta)
	var sy := _pose_sy + _sq * SQ_SCALE + gait + breath * IDLE_SQUASH
	_warp.set_shader_parameter("sy", sy)
	_warp.set_shader_parameter("sx", 1.0 / sqrt(maxf(sy, 0.5)))
	_warp.set_shader_parameter("bulge", breath * IDLE_BULGE)
	_warp.set_shader_parameter("lean", _pose_lean + _walk_lean + _lean * LEAN_SCALE + sway)
	_warp.set_shader_parameter("flutter", IDLE_FLUTTER * calm)
	_warp.set_shader_parameter("phase", _idle * 5.0)


func _settle(delta: float) -> void:
	var steps := 4
	var dt := delta / steps
	for i in steps:
		_lean_v += (-LEAN_K * _lean - LEAN_C * _lean_v) * dt
		_lean += _lean_v * dt
		_sq_v += (-SQ_K * _sq - SQ_C * _sq_v) * dt
		_sq += _sq_v * dt


class Carrier extends Control:
	var anchor: Control

	func _enter_tree() -> void:
		if is_instance_valid(anchor) and not anchor.item_rect_changed.is_connected(_track):
			anchor.item_rect_changed.connect(_track)

	func _track() -> void:
		if is_instance_valid(anchor):
			position = anchor.position


class ChargeRing extends Control:
	const COLORS := {"fire": Color("f8301c"), "water": Color("1e8cf0"), "nature": Color("3cc83a"), "normal": Color("d264d7")}
	var color := Color.WHITE
	var value := 0.0:
		set(v):
			if absf(v - value) > 0.004 or (v != value and (v <= 0.0 or v >= 1.0)):
				value = clampf(v, 0.0, 1.0)
				queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 2.0
		draw_arc(c, r, 0.0, TAU, 40, Color(0.05, 0.03, 0.02, 0.75), 5.0, true)
		if value > 0.0:
			draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * value, 40, color, 5.0, true)
