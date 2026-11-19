class_name SkillFx
extends RefCounted

const LETTER := {"fire": "f", "water": "w", "nature": "n", "normal": "k"}
const FPS := 24.0
const LOOP_FPS := 14.0
const HEAD_LOOPS := ["k_stun", "k_confusion", "k_provoke_1", "k_bomb_1", "k_silence_1"]
const FRONT_LOOPS := ["k_shield"]
const BACK_LOOPS := ["k_thorn_1", "k_immune_1"]

static var _data: Dictionary = {}
static var _sizes: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/skill_fx.json"))
		_data = parsed if parsed is Dictionary else {"skills": {}}
	return _data


static func spec(skill_name: String) -> Dictionary:
	var skills: Dictionary = data().get("skills", {})
	return skills.get(skill_name.strip_edges().trim_suffix(":"), {})


static func sheet(name: String, element: String) -> String:
	var n := name.replace("{e}", LETTER.get(element, "k"))
	return String(data().get("alias", {}).get(n, n))


static func frame_size(name: String) -> Vector2:
	if not _sizes.has(name):
		var list := FrameFx.frames(name)
		_sizes[name] = list[0].get_size() if not list.is_empty() else Vector2.ZERO
	return _sizes[name]


static func play(parent: Node, name: String, at: Vector2, scale: float = 1.0, flip: bool = false, fps: float = FPS, add: bool = false, centered: bool = true) -> FrameFx:
	var box := frame_size(name) * scale
	if box == Vector2.ZERO or parent == null:
		return null
	if centered:
		var off: Array = data().get("offsets", {}).get(name, [0, 0])
		at -= Vector2(float(off[0]) * (-1.0 if flip else 1.0), float(off[1])) * scale
	var fx := FrameFx.play(parent, name, at, box, fps)
	if fx == null:
		return null
	fx.flip_h = flip
	if add:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		fx.material = m
	return fx


static func travel(parent: Node, name: String, from: Vector2, to: Vector2, time: float, scale: float = 1.0, target: Control = null) -> void:
	var fx := play(parent, name, from, scale, to.x > from.x)
	if fx == null:
		return
	fx.loop = true
	var half := fx.size / 2.0
	var dir := to - from
	fx.pivot_offset = half
	fx.rotation = atan2(dir.y, absf(dir.x)) * (1.0 if to.x > from.x else -1.0)
	var tw := fx.create_tween()
	if target != null:
		tw.tween_method(func(t: float):
			var end := center(target) if is_instance_valid(target) else to
			fx.position = from.lerp(end, t) - half, 0.0, 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	else:
		tw.tween_property(fx, "position", to - half, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(fx.queue_free)


static func loop(parent: Node, name: String, at: Vector2, scale: float = 1.0, flip: bool = false) -> FrameFx:
	var fx := play(parent, name, at, scale, flip, LOOP_FPS)
	if fx != null:
		fx.loop = true
	return fx


static func flipped(name: String, side: int) -> bool:
	return (side == BattleUnit.PLAYER) != ("quake" in name)


static func center(v: Control) -> Vector2:
	return v.position + v.size / 2.0


static func front(v: BattleUnitView) -> Vector2:
	return center(v) + Vector2(v.size.x * (0.4 if v.unit.side == BattleUnit.PLAYER else -0.4), 0.0)


static func feet(v: Control) -> Vector2:
	return v.position + Vector2(v.size.x / 2.0, v.size.y * 0.92)


static func _scale(v: Control, s: Dictionary) -> float:
	return float(s.get("scale", 1.0)) * clampf(v.size.y / 110.0, 0.8, 1.6)


static func _at(field: Node, name: String, element: String, at: Vector2, scale: float, flip: bool, delay: float, add: bool = false, centered: bool = true, tint: String = "", follow: Control = null) -> void:
	if name == "":
		return
	var n := sheet(name, element)
	var base := follow.position if is_instance_valid(follow) else Vector2.ZERO
	var shown := func():
		if is_instance_valid(field):
			var moved := follow.position - base if is_instance_valid(follow) else Vector2.ZERO
			var fx := play(field, n, at + moved, scale, flip, FPS, add, centered)
			if fx != null:
				fx.follow(follow)
				if tint != "":
					fx.modulate = Color(tint)
	if delay <= 0.0:
		shown.call()
	else:
		field.get_tree().create_timer(delay).timeout.connect(shown)


static func _under(v: BattleUnitView, name: String, element: String, scale: float) -> void:
	if name == "":
		return
	var fx := play(v, sheet(name, element), Vector2(v.size.x / 2.0, v.size.y * 0.92), scale)
	if fx != null:
		fx.z_index = 0
		v.move_child(fx, v.sprite.get_index())


static func cast(field: Node, v: BattleUnitView, skill_name: String, element: String) -> void:
	var s := spec(skill_name)
	var k := _scale(v, s)
	var cast_name := String(s.get("cast", ""))
	var sweep_name := String(s.get("sweep", ""))
	_under(v, String(s.get("aura", "")), element, k)
	_at(field, String(s.get("charge", "")), element, center(v), k, false, 0.0, true, true, "", v)
	_at(field, cast_name, element, front(v), k, flipped(cast_name, v.unit.side), 0.15, true, false, "", v)
	_at(field, sweep_name, element, front(v), k, flipped(sweep_name, v.unit.side), 0.2, true, false, "", v)


static func hit_delay(skill_name: String) -> float:
	var s := spec(skill_name)
	if s.has("travel"):
		return 0.2 + float(s.get("fly", 0.3))
	return float(s.get("delay", 0.35 if (s.has("cast") or s.has("sweep") or s.has("charge")) else 0.1))


static func hit(field: Node, from: BattleUnitView, to: BattleUnitView, skill_name: String, element: String, lead: float = 0.0) -> float:
	var s := spec(skill_name)
	var k := _scale(from, s)
	var wait := hit_delay(skill_name) + lead
	if bool(s.get("lunge", false)):
		var aim := center(to)
		field.get_tree().create_timer(lead + 0.01).timeout.connect(func():
			if is_instance_valid(from):
				from.lunge(aim, true))
	if s.has("travel"):
		var n := sheet(String(s.travel), element)
		var a := front(from)
		var b := center(to)
		var fly := float(s.get("fly", 0.3))
		field.get_tree().create_timer(0.2 + lead).timeout.connect(func():
			if is_instance_valid(field):
				travel(field, n, a, b, fly, k, to))
	var flip := flipped("", from.unit.side)
	_at(field, String(s.get("hit", "h_{e}_base_1")), element, center(to), k, flip, wait, true, true, String(s.get("tint", "")), to)
	_at(field, String(s.get("hit2", "")), element, center(to), k, flip, wait + 0.05, true, true, String(s.get("tint2", "")), to)
	return wait


static func attack(field: Node, from: BattleUnitView, to: BattleUnitView, element: String) -> void:
	var table: Dictionary = data().get("attack", {})
	var list: Array = table.get(element, table.get("normal", ["c_punch_2"]))
	var n := sheet(String(list[absi(hash(from.unit.monster_id)) % list.size()]), element)
	var own := String(data().get("attack_by", {}).get(from.unit.monster_id, ""))
	if own != "":
		_stick(play(field, own, front(from), clampf(from.size.y / 110.0, 0.8, 1.4), flipped(own, from.unit.side), FPS, true), from)
	_stick(play(field, n, center(to), clampf(to.size.y / 110.0, 0.8, 1.4), flipped(n, from.unit.side), FPS, true), to)


static func _stick(fx: FrameFx, v: Control) -> void:
	if fx != null:
		fx.follow(v)


static func battle_paths(ids: Array) -> Array:
	var names := {}
	for t in ["tick", "loops", "apply"]:
		for n in data().get(t, {}).values():
			names[sheet(String(n), "normal")] = true
	for n in ["ui_target_enemy", "ui_target_leader", "u_moneyex_01", "c_levelup_1", "CubeCatch_01", "SBackP_1", "ui_icn_fever_1", "ui_icn_fever_2", "ui_icn_fever_3"]:
		names[n] = true
	var table: Dictionary = data().get("attack", {})
	var sounds := []
	for id in ids:
		var def := DB.monster(String(id))
		var e := String(def.get("element", "normal"))
		var want: Array = table.get(e, table.get("normal", [])).duplicate()
		want.append(data().get("attack_by", {}).get(String(id), ""))
		if ranged(String(id)):
			want.append_array(["c_{e}_launch", "c_{e}_ball", "h_{e}_explosion_1"])
		var skills: Array = def.get("skills", []).duplicate()
		if def.get("support_skill") is Dictionary:
			skills.append(def.support_skill)
		for sk in skills:
			var s := spec(String(sk.get("name", "")))
			want.append(s.get("hit", "h_{e}_base_1"))
			for k in ["aura", "charge", "cast", "sweep", "hit2", "travel", "land", "icon"]:
				want.append(s.get(k, ""))
			sounds.append_array(Sfx.skill_paths(String(sk.get("name", "")), e))
		for n in want:
			if String(n) != "":
				names[sheet(String(n), e)] = true
	var out := []
	for n in names:
		out.append_array(FrameFx.paths(n))
	out.append_array(sounds)
	return out


static func ranged(monster_id: String) -> bool:
	var styles: Dictionary = data().get("styles", {})
	return String(styles.get(monster_id, data().get("default_style", "melee"))) == "ranged"


static func flight(from: BattleUnitView, to: BattleUnitView) -> float:
	return 0.1 + clampf(front(from).distance_to(center(to)) / 900.0, 0.12, 0.4)


static func shoot(field: Node, from: BattleUnitView, to: BattleUnitView, element: String) -> float:
	var k := clampf(from.size.y / 110.0, 0.7, 1.3)
	var a := front(from)
	var b := center(to)
	var fly := flight(from, to) - 0.1
	var launch := sheet("c_{e}_launch", element)
	_stick(play(field, launch, a, k * 0.8, flipped(launch, from.unit.side), FPS, true, false), from)
	var ball := sheet("c_{e}_ball", element)
	field.get_tree().create_timer(0.1).timeout.connect(func():
		if is_instance_valid(field):
			travel(field, ball, a, b, fly, k * 0.8, to))
	var wait := 0.1 + fly
	_at(field, "h_{e}_explosion_1", element, b, k * 0.8, false, wait, true, true, "", to)
	return wait


static func land(field: Node, v: BattleUnitView, skill_name: String, element: String) -> void:
	var s := spec(skill_name)
	var k := clampf(v.size.y / 110.0, 0.8, 1.4)
	_at(field, String(s.get("land", "")), element, feet(v) - Vector2(0, v.size.y * 0.45), k, false, 0.0, true, true, "", v)
	_at(field, String(s.get("icon", "")), element, v.position + Vector2(v.size.x / 2.0, -10.0), 1.0, false, 0.15, false, true, "", v)


static func tick(field: Node, v: BattleUnitView, kind: String) -> void:
	var n := String(data().get("tick", {}).get(kind, ""))
	if n != "":
		_stick(play(field, n, center(v), clampf(v.size.y / 110.0, 0.7, 1.2), false, FPS, true), v)


static func apply(field: Node, v: BattleUnitView, status: String, stat: String) -> void:
	var on: Dictionary = data().get("apply", {})
	var n := String(on.get(status + "_" + stat, on.get(status, "")))
	if n == "":
		return
	if n.begins_with("c_bufficon") or n.begins_with("c_debufficon"):
		_stick(play(field, n, v.position + Vector2(v.size.x / 2.0, -10.0), 1.0), v)
	else:
		_stick(play(field, n, center(v), clampf(v.size.y / 110.0, 0.8, 1.4), false, FPS, true), v)


static func loop_sheets(u: BattleUnit) -> Dictionary:
	var table: Dictionary = data().get("loops", {})
	var out := {}
	for s in u.statuses:
		var key := String(s.type) if s.type != "dot" else "dot_" + String(s.get("kind", ""))
		if table.has(key):
			out[String(table[key])] = true
	if u.shield > 0.0 and table.has("shield"):
		out[String(table.shield)] = true
	return out
