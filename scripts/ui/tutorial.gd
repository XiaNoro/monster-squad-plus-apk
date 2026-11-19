class_name Tutorial
extends Control

signal finished
signal _notified(name: String)

const DATA := "res://data/tutorial.json"
const GUIDES := ["firepaw", "mini", "goldbat", "wamiami", "rookie", "g_drank", "shinoblue"]
const CARD_PANELS := {"quest": 1, "clear": 2, "island": 3}
const FIREWORK_SIZE := 260.0
const FIREWORK_GAP := 0.25

static var _data: Dictionary = {}
static var _debug_used := false
static var autoplay: bool = "--test-tutauto" in OS.get_cmdline_user_args()
static var autosay: float = _arg_float("--test-autosay=")


static func _arg_float(prefix: String) -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return float(a.trim_prefix(prefix))
	return 0.0


static func log_step(text: String) -> void:
	if autoplay:
		print("TUT ", text)

var screen: Control
var chapter: Dictionary
var running := false
var _fired: Dictionary = {}
var _stopped := false
var _jump_to := ""
var _skip_events := false
var _focus_layer: Control


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data


static func state() -> Dictionary:
	if not Save.data.has("tutorial"):
		Save.data["tutorial"] = {"enabled": false, "done": []}
	return Save.data.tutorial


static func enabled() -> bool:
	return bool(state().get("enabled", false))


static func is_done(id: String) -> bool:
	return id in state().get("done", [])


static func mark_done(id: String) -> void:
	var s := state()
	if not id in s.done:
		s.done.append(id)
		Save.save_game()


static func begin_new_game() -> void:
	Save.data["tutorial"] = {"enabled": true, "done": [], "new": true}


static func skip_all() -> void:
	var s := state()
	s.enabled = false
	for c in data().get("chapters", []):
		if not String(c.id) in s.done:
			s.done.append(String(c.id))
	Save.save_game()


static func all_done() -> bool:
	for c in data().get("chapters", []):
		if not is_done(String(c.id)):
			return false
	return true


static func _condition(when: String, ctx: Dictionary) -> bool:
	if "&" in when:
		for w in when.split("&"):
			if not _condition(w, ctx):
				return false
		return true
	var parts := when.split(":")
	match parts[0]:
		"new_game":
			return bool(state().get("new", false))
		"after":
			return is_done(parts[1])
		"stage":
			return parts.size() == 4 and String(ctx.get("island", "")) == parts[1] and String(ctx.get("difficulty", "")) == parts[2] and int(ctx.get("stage", -1)) == int(parts[3])
		"cleared":
			return parts.size() == 4 and Save.cleared_stages(parts[1], parts[2]) > int(parts[3])
		"mission_ready":
			return bool(ctx.get("mission_ready", false))
		"mission_done":
			return bool(state().get("mission_done", false))
		"maxed":
			return Save.data.monsters.any(func(m): return int(m.level) >= DB.MAX_LEVEL and String(DB.monster(String(m.id)).get("evolves_into", "")) == "" and not bool(DB.monster(String(m.id)).get("material", false)))
		"special":
			return parts.size() == 2 and String(ctx.get("special", "")) == parts[1]
	return false


static func maybe_start(parent: Control, key: String, ctx: Dictionary = {}) -> Tutorial:
	if not enabled():
		return null
	for c in data().get("chapters", []):
		if String(c.screen) != key or is_done(String(c.id)):
			continue
		if not _condition(String(c.when), ctx):
			continue
		var t := Tutorial.new()
		t.screen = parent
		t.chapter = c
		t.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		t.mouse_filter = MOUSE_FILTER_IGNORE
		t.z_index = 90
		parent.add_child(t)
		if "tutorial" in parent:
			parent.tutorial = t
		t.call_deferred("_run")
		return t
	if all_done():
		state().enabled = false
	return null


static func pending(key: String, ctx: Dictionary = {}) -> bool:
	if not enabled():
		return false
	for c in data().get("chapters", []):
		if String(c.screen) == key and not is_done(String(c.id)) and _condition(String(c.when), ctx):
			return true
	return false


static func speak(parent: Control, who: String, text: String, guide: bool = false) -> Tutorial:
	return play(parent, [{"say": who, "text": text, "guide": guide}])


static func play(parent: Control, steps: Array) -> Tutorial:
	var t := Tutorial.new()
	t.screen = parent
	t.chapter = {"id": "", "steps": steps}
	t.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	t.mouse_filter = MOUSE_FILTER_IGNORE
	t.z_index = 90
	parent.add_child(t)
	t.call_deferred("_run")
	return t


static func boss_line(island_id: String, difficulty: String, stage: int) -> Dictionary:
	var lines: Dictionary = data().get("boss_lines", {})
	return lines.get("%s:%s:%d" % [island_id, difficulty, stage], lines.get("%s:normal:%d" % [island_id, stage], {}))


static func monster_line(id: String) -> String:
	return String(data().get("monster_lines", {}).get(id, ""))


static func record_win(key: String) -> void:
	var s := state()
	if String(s.get("mission", "")) == key and not bool(s.get("mission_done", false)):
		s["mission_done"] = true
		Save.save_game()


static func active_mission() -> String:
	var s := state()
	if enabled() and String(s.get("mission", "")) != "" and not is_done("arena_open"):
		return "%s (%d/1)" % [s.get("mission_text", ""), 1 if bool(s.get("mission_done", false)) else 0]
	return ""


static func island_clear_steps(island_id: String, gems: int) -> Array:
	var info: Dictionary = data().get("island_clear", {}).get(island_id, {})
	var steps: Array = info.get("before", []).duplicate()
	steps.append({"card": "clear", "text": String(info.get("clear_text", "You're a winner!")), "gems": gems})
	steps.append_array(info.get("after", []))
	var order := int(DB.island(island_id).get("order", -1))
	if order >= 0 and order + 1 < DB.islands.size():
		var nxt: Dictionary = DB.islands[order + 1]
		steps.append({"popup": "new_island", "island": nxt.id, "text": String(info.get("next_text", "Investigate %s" % nxt.name))})
	return steps


func notify(name: String) -> void:
	_fired[name] = true
	_notified.emit(name)


func _run() -> void:
	running = true
	var steps: Array = chapter.get("steps", [])
	var cid := String(chapter.get("id", ""))
	var first := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--test-tutstep=") and not _debug_used:
			first = int(a.trim_prefix("--test-tutstep="))
			_debug_used = true
	for i in range(first, steps.size()):
		if _stopped or not is_inside_tree():
			return
		if i == steps.size() - 1 and cid != "":
			mark_done(cid)
		var st: Dictionary = steps[i]
		if _jump_to != "":
			if String(st.get("event", "")) == _jump_to:
				_jump_to = ""
			continue
		log_step("%s #%d %s" % [cid if cid != "" else "line", i, JSON.stringify(st).substr(0, 90)])
		if not st.has("event"):
			_skip_events = false
		if st.has("say"):
			await _say(String(st.say), String(st.text), bool(st.get("guide", true)))
		elif st.has("popup"):
			await _card(st, "island")
		elif st.has("card"):
			await _card(st, String(st.card))
		elif st.has("focus"):
			await _focus(String(st.focus))
		elif st.has("event"):
			await _event(String(st.event))
		elif st.has("help"):
			await _help(st)
	if _stopped:
		return
	if cid != "":
		mark_done(cid)
	running = false
	_pause(false)
	finished.emit()
	queue_free()


func _pause(on: bool) -> void:
	if on and get_parent() != null:
		get_parent().move_child(self, -1)
	if screen.has_method("set_tutorial_pause"):
		screen.set_tutorial_pause(on)


func _event(name: String) -> void:
	if _fired.has(name) or _skip_events:
		_fired.erase(name)
		return
	if screen.has_method("tutorial_event_started"):
		screen.tutorial_event_started(name)
	_pause(false)
	while true:
		var got: String = await _notified
		if got == name:
			_fired.erase(name)
			return
		if got == "victory":
			_jump_to = "victory"
			return


func _say(who: String, text: String, guide: bool = true) -> void:
	_pause(true)
	var lay := Layout.load_into(self, "R_d_tutorial")
	var catcher: Control = lay.node("ID_9PATCH_2")
	catcher.mouse_filter = MOUSE_FILTER_STOP
	var band: Control = lay.node("ID_Dialog")
	lay.on("ID_btnSkip", _confirm_skip)
	lay.show("ID_btnSkip", enabled() and not OS.has_feature("mobile"))
	var name_l := lay.text("ID_monNameText", String(DB.monster(who).get("name", who.capitalize())))
	name_l.add_theme_color_override("font_color", Color("fff23a") if who in GUIDES and guide else Color("ff8a2a"))
	var body := lay.text("ID_baseText", text)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 26)
	body.add_theme_color_override("font_color", Color.WHITE)
	var box := Vector2(330, 330)
	var t := DB.battle_sprite(who)
	var drawn := box
	if t != null and t.get_width() > 0:
		drawn = t.get_size() * minf(box.x / t.get_width(), box.y / t.get_height())
	var art := UI.living(t, drawn)
	var qmon: Control = lay.node("ID_qmon")
	art.position = Vector2(qmon.position.x + 40 + (box.x - drawn.x) / 2.0, band.size.y - drawn.y - 4)
	art.pivot_offset = Vector2(drawn.x / 2.0, drawn.y)
	art.scale = Vector2(0.92, 0.92)
	band.add_child(art)
	band.move_child(art, 0)
	art.create_tween().tween_property(art, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)
	var ok: Control = lay.node("ID_IMAGE_OK")
	var bob := ok.create_tween().set_loops()
	bob.tween_property(ok, "modulate:a", 0.55, 0.5)
	bob.tween_property(ok, "modulate:a", 1.0, 0.5)
	await get_tree().create_timer(0.25).timeout
	await _next_press(catcher)
	Sfx.play("click")
	if is_instance_valid(lay.root):
		lay.root.queue_free()


func _confirm_skip() -> void:
	UI.confirm(self, "Notice", "Skip the rest of the tutorial?", _skip_now).z_index = 99


func _skip_now() -> void:
	_stopped = true
	skip_all()
	_pause(false)
	running = false
	finished.emit()
	queue_free()


func _next_press(c: Control) -> InputEvent:
	if autoplay or autosay > 0.0:
		await get_tree().create_timer(0.3 if autoplay else autosay).timeout
		return InputEventMouseButton.new()
	var holder: Array = [null]
	var cb := func(e: InputEvent) -> void:
		if UI.pressed(e):
			holder[0] = e
	c.gui_input.connect(cb)
	while holder[0] == null and is_instance_valid(c):
		await get_tree().process_frame
	if is_instance_valid(c):
		c.gui_input.disconnect(cb)
	return holder[0]


func _fireworks(panel: Control) -> void:
	var rect := panel.get_global_rect()
	var spots := [Vector2(0.08, 0.15), Vector2(0.92, 0.2), Vector2(0.2, 0.85), Vector2(0.85, 0.8)]
	var panel_id := panel.get_instance_id()
	var host_id := get_instance_id()
	var z := panel.z_index + 1
	for k in spots.size():
		get_tree().create_timer(FIREWORK_GAP * k).timeout.connect(func():
			var host := instance_from_id(host_id) as Control
			if host == null or instance_from_id(panel_id) == null:
				return
			var at := rect.position + rect.size * Vector2(spots[k]) - host.get_global_rect().position
			var fx := FrameFx.play(host, "ui_fireworks_1", at, Vector2.ONE * FIREWORK_SIZE, 24.0)
			if fx != null:
				fx.z_index = z
				var m := CanvasItemMaterial.new()
				m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				fx.material = m)


func _card(st: Dictionary, kind: String) -> void:
	_pause(true)
	var n: int = CARD_PANELS.get(kind, 3)
	var lay := Layout.load_into(self, "R_d_dailyQuest1")
	for k in range(1, 4):
		lay.show("ID_9PATCH_%d" % k, k == n)
	lay.node("ID_9PATCH_%d" % n).mouse_filter = MOUSE_FILTER_STOP
	var suffix := "_%d" % n
	var body := lay.text("ID_baseText" + suffix, String(st.get("text", "")))
	body.add_theme_color_override("font_color", UI.BROWN)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lay.text({1: "ID_LABEL_5_1", 2: "ID_LABEL_5", 3: "ID_LABEL_5_1_1"}[n], "OK").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if n == 3:
		lay.text("ID_LABEL_3_1", String(st.get("title", "New Island!"))).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lay.text("ID_baseText_3_1", "")
		var frame: Control = lay.node("ID_islandFrame")
		var art := DB.island_art(String(st.get("island", "sprout_island")))
		if art != null:
			var fit := minf((frame.size.x - 16.0) / art.get_width(), (frame.size.y - 16.0) / art.get_height())
			var pic := UI.image(art, art.get_size() * fit)
			pic.size = art.get_size() * fit
			pic.position = (frame.size - pic.size) / 2.0
			frame.add_child(pic)
	else:
		if n == 1:
			lay.text("ID_LABEL_3", String(st.get("title", "New Quest!"))).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var gold := int(st.get("gold", 0))
		var gems := int(st.get("gems", 0))
		var mon := String(st.get("monster", ""))
		lay.text("ID_LABEL_1" + ("_1" if n == 1 else ""), "Reward")
		var reward_name := ("Gem x%d" % gems) if gems > 0 else ("Gold x%d" % gold)
		if mon != "":
			reward_name = String(DB.monster(mon).get("name", mon))
		lay.text("ID_LABEL_2" + ("_1" if n == 1 else ""), reward_name)
		var frame: Control = lay.node("ID_rewardFrame" + suffix)
		var icon: Control
		if mon != "":
			icon = UI.monster_card(mon, 0, 0, Vector2(84, 84))
			icon.size = Vector2(84, 84)
		else:
			icon = UI.image(Layout.texture("I_crystal_02.png" if gems > 0 else "I_money_02.png"))
			icon.size = (icon as TextureRect).texture.get_size() * 1.6 if (icon as TextureRect).texture else Vector2(64, 64)
		icon.position = (frame.size - icon.size) / 2.0
		frame.add_child(icon)
		if bool(st.get("grant", false)):
			Save.data.gold = int(Save.data.gold) + gold
			Save.data.gems = int(Save.data.gems) + gems
			if mon != "":
				Save.add_monster(mon, 1)
			Save.save_game()
		if st.has("mission"):
			var s := state()
			s["mission"] = String(st.mission)
			s["mission_text"] = String(st.get("text", ""))
			s["mission_done"] = false
			Save.save_game()
	Sfx.play("buff_big")
	if kind in ["clear", "island"]:
		_fireworks(lay.node("ID_9PATCH_%d" % n))
	var holder: Array = [false]
	lay.on("ID_btnOk" + suffix, func(): holder[0] = true)
	if autoplay or autosay > 0.0:
		await get_tree().create_timer(0.4 if autoplay else autosay).timeout
		holder[0] = true
	while not holder[0] and is_instance_valid(lay.root):
		await get_tree().process_frame
	if is_instance_valid(lay.root):
		lay.root.queue_free()
	if screen.has_method("_refresh_top"):
		screen.call("_refresh_top")


func _focus(name: String) -> void:
	var target: Control = null
	if screen.has_method("tutorial_target"):
		target = screen.tutorial_target(name)
	if target == null or not is_instance_valid(target):
		log_step("  focus %s: no target" % name)
		return
	_pause(true)
	if autoplay or autosay > 0.0:
		_autotap.call_deferred(target, name)
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(target):
		return
	_scroll_into_view(target)
	await get_tree().process_frame
	var rect := target.get_global_rect()
	var layer := FocusLayer.new()
	layer.hole = rect.grow(6)
	layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(layer)
	_focus_layer = layer
	var arrow := Pointer.new()
	arrow.position = Vector2(rect.get_center().x, rect.position.y)
	layer.add_child(arrow)
	var done: Array = [false]
	_skip_button(layer, rect, func() -> void:
		done[0] = true
		_skip_events = true)
	var on_press := func() -> void: done[0] = true
	if target is BaseButton:
		(target as BaseButton).pressed.connect(on_press, CONNECT_ONE_SHOT)
	var on_note := func(n: String) -> void:
		if n == name:
			done[0] = true
	_notified.connect(on_note)
	while not done[0] and is_instance_valid(layer):
		await get_tree().process_frame
		if is_instance_valid(target):
			layer.hole = target.get_global_rect().grow(6)
			arrow.position = Vector2(layer.hole.get_center().x, layer.hole.position.y)
		else:
			break
	if _notified.is_connected(on_note):
		_notified.disconnect(on_note)
	if is_instance_valid(layer):
		layer.queue_free()


static func _scroll_into_view(target: Control) -> void:
	var p := target.get_parent()
	while p != null:
		if p is ScrollContainer:
			(p as ScrollContainer).ensure_control_visible(target)
		p = p.get_parent()


func _skip_button(layer: Control, avoid: Rect2, cb: Callable) -> void:
	var vs := get_viewport_rect().size
	var bsize := Vector2(150, 46)
	var b := UI.button("Skip step", cb, "purple", bsize * 2.0, 32)
	b.scale = Vector2(0.5, 0.5)
	b.position = Vector2(vs.x - bsize.x - 16, vs.y - bsize.y - 16)
	if Rect2(b.position, bsize).grow(20).intersects(avoid):
		b.position.y = 16
	b.modulate.a = 0.0
	b.visible = false
	layer.add_child(b)
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(b):
		b.visible = true
		b.create_tween().tween_property(b, "modulate:a", 0.85, 0.4)


func _autotap(target: Control, name: String) -> void:
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(target):
		return
	log_step("  tap " + name)
	if target is BaseButton:
		(target as BaseButton).pressed.emit()
	else:
		var at := target.get_global_rect().get_center()
		for down in [true, false]:
			if not is_instance_valid(target):
				return
			var e := InputEventMouseButton.new()
			e.pressed = down
			e.button_index = MOUSE_BUTTON_LEFT
			e.global_position = at
			target.gui_input.emit(e)


func _help(st: Dictionary) -> void:
	_pause(true)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.mouse_filter = MOUSE_FILTER_STOP
	add_child(dim)
	for n in st.get("notes", []):
		var target: Control = screen.tutorial_target("help:" + String(n.at)) if screen.has_method("tutorial_target") else null
		var at := target.get_global_rect() if target != null else Rect2(400, 300, 10, 10)
		var ring := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = Color("ff9a2a")
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(40)
		ring.add_theme_stylebox_override("panel", sb)
		ring.position = at.position - Vector2(6, 6)
		ring.size = at.size + Vector2(12, 12)
		dim.add_child(ring)
		var l := UI.label(String(n.text), 19, Color("ffd36a"))
		l.position = at.position + Vector2(at.size.x + 14, 0) if at.position.x < 600 else at.position - Vector2(330, -at.size.y)
		dim.add_child(l)
	await get_tree().create_timer(0.3).timeout
	await _next_press(dim)
	dim.queue_free()


class FocusLayer extends Control:
	const SHADER := """
shader_type canvas_item;
uniform vec2 center;
uniform float radius;
uniform vec2 screen_size;
void fragment() {
	vec2 p = UV * screen_size;
	float d = distance(p, center) / radius;
	float lit = 1.0 - smoothstep(0.55, 1.0, d);
	vec3 warm = vec3(1.0, 0.86, 0.45);
	COLOR = vec4(mix(vec3(0.0), warm, lit * 0.35), mix(0.62, 0.0, lit));
}
"""
	var hole := Rect2()
	var _mat: ShaderMaterial

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_STOP
		var sh := Shader.new()
		sh.code = SHADER
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		material = _mat

	func _process(_d: float) -> void:
		var vs := get_viewport_rect().size
		_mat.set_shader_parameter("center", hole.get_center() - global_position)
		_mat.set_shader_parameter("radius", maxf(hole.size.x, hole.size.y) * 0.72 + 30.0)
		_mat.set_shader_parameter("screen_size", size if size.x > 0 else vs)
		queue_redraw()

	func _has_point(p: Vector2) -> bool:
		return not hole.has_point(get_global_transform() * p)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)


class Pointer extends Node2D:
	static var _arrow: Texture2D
	var _t := 0.0
	var scale_px := 1.7

	func _ready() -> void:
		z_index = 5
		if _arrow == null:
			var p := "res://assets/apk/sprites/pointer_01/pointer_01_012.png"
			if ResourceLoader.exists(p):
				var tex: Texture2D = load(p)
				var img := tex.get_image()
				var used := img.get_used_rect()
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(used)
				_arrow = at

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var phase := absf(sin(_t * 4.2))
		var lift := phase * 18.0
		var squash := 1.0 + (1.0 - phase) * 0.12
		if _arrow != null:
			var s := _arrow.get_size() * scale_px
			var sz := Vector2(s.x * squash, s.y / squash)
			draw_texture_rect(_arrow, Rect2(Vector2(-sz.x / 2.0, -sz.y - 4.0 - lift), sz), false)
		else:
			var pts := PackedVector2Array([Vector2(-26, -64 - lift), Vector2(26, -64 - lift), Vector2(0, -6 - lift)])
			draw_colored_polygon(pts, Color("ff8a1a"))
