class_name LoadingScreen
extends Control

signal done

const SECONDS := 5.0
const BETWEEN_LEVELS := 3.0


static func go(main: Main, screen: String, args: Dictionary = {}, kind: String = "battle", seconds: float = SECONDS) -> void:
	var l := make(main, kind)
	await main.get_tree().create_timer(_wait(seconds)).timeout
	main.go(screen, args)
	l.fade()


static func cover(main: Main, load_next: Callable, at_least: float = BETWEEN_LEVELS) -> void:
	var l := make(main, "battle")
	var start := Time.get_ticks_msec()
	await main.get_tree().process_frame
	load_next.call()
	await main.get_tree().process_frame
	var left := _wait(at_least) - (Time.get_ticks_msec() - start) / 1000.0
	if left > 0.0:
		await main.get_tree().create_timer(left).timeout
	l.fade()


static func make(parent: Node, kind: String) -> LoadingScreen:
	var l := LoadingScreen.new()
	l.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	l.z_index = 100
	l.mouse_filter = MOUSE_FILTER_STOP
	parent.add_child(l)
	if kind == "pvp":
		l._pvp()
	elif kind.begins_with("island:"):
		l._island(DB.special(kind.trim_prefix("island:")))
	else:
		l._monster()
	return l


static func _wait(seconds: float) -> float:
	return 0.3 if "--test-instawin" in OS.get_cmdline_user_args() else seconds


func fade() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(done.emit)
	tw.tween_callback(queue_free)


func _tip() -> String:
	return String(DB.tips[randi() % DB.tips.size()]) if not DB.tips.is_empty() else ""


func _pvp() -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var art := UI.image(UI.tex("betaLoading00/LO_pvp_01.png"), Vector2.ZERO, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	art.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(art)
	var lay := Layout.load_into(self, "battleLoadingPage3")
	lay.node("ID_IMAGE_pvpLoading").self_modulate.a = 0.0
	lay.hide_all(["ID_9PATCH_graphBack"])
	var tip := lay.text("ID_LABEL_tip", _tip())
	tip.autowrap_mode = TextServer.AUTOWRAP_OFF
	UI.fit_text(tip, 22, 14)
	var wait := lay.text("ID_LABEL_waiting", "Loading...")
	var tw := wait.create_tween().set_loops()
	tw.tween_property(wait, "modulate:a", 0.4, 0.5)
	tw.tween_property(wait, "modulate:a", 1.0, 0.5)


func _island(sp: Dictionary) -> void:
	var bg := ColorRect.new()
	bg.color = Color("6b3f1c")
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var lay := Layout.load_into(self, "battleLoadingPage2")
	lay.hide_all(["ID_9PATCH_frame", "ID_9PATCH_frame_2", "ID_9PATCH_graphBack"])
	var frame: Control = lay.node("ID_imgIslandFrame")
	var sea: Control = lay.node("ID_imgFrame_Sea")
	var art := DB.island_art(String(sp.id))
	if art != null and sea != null:
		var fit := minf((sea.size.x - 40.0) / art.get_width(), (sea.size.y - 40.0) / art.get_height())
		var pic := UI.image(art, art.get_size() * fit)
		pic.size = art.get_size() * fit
		pic.position = sea.position + (sea.size - pic.size) / 2.0 - frame.position
		frame.add_child(pic)
	lay.text("ID_LABEL_4", String(sp.name)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var promo := lay.text("ID_LABEL_4_1", String(sp.get("promo", "")))
	promo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	promo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	promo.add_theme_font_size_override("font_size", 24)
	var tip := lay.text("ID_LABEL_tip", _tip())
	tip.add_theme_font_size_override("font_size", 22)
	tip.autowrap_mode = TextServer.AUTOWRAP_OFF


func _monster() -> void:
	var pool := DB.ids_where(func(m): return not m.material and String(m.quote) != "" and String(m.quote).length() < 70)
	var bg := ColorRect.new()
	bg.color = Color("6b3f1c")
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var lay := Layout.load_into(self, "battleLoadingPage2")
	lay.hide_all(["ID_9PATCH_frame_2", "ID_9PATCH_frame_3", "ID_9PATCH_graphBack"])
	if pool.is_empty():
		return
	var id: String = pool[randi() % pool.size()]
	var def := DB.monster(id)
	var actor: Control = lay.node("ID_9PATCH_actor")
	var tex := DB.battle_sprite(id)
	var box := Vector2(330, 300)
	var drawn := box
	if tex.get_width() > 0:
		drawn = tex.get_size() * minf(box.x / tex.get_width(), box.y / tex.get_height())
	var pic := UI.image(tex, drawn)
	pic.size = drawn
	pic.position = Vector2(actor.size.x / 2.0 - drawn.x / 2.0, actor.size.y - drawn.y - 40)
	actor.add_child(pic)
	for g in 6:
		lay.show("ID_IMAGE_grade%d" % g, g < int(def.stars))
	var stats := DB.stats_at(id, DB.MAX_LEVEL)
	lay.text("ID_LABEL_name", String(def.name)).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lay.text("ID_LABEL_num", str(int(stats.hp))).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lay.text("ID_LABEL_num2", str(int(stats.atk))).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lay.text("ID_LABEL_2", "Attack")
	var ment := lay.text("ID_LABEL_ment", String(def.quote))
	ment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ment.add_theme_font_size_override("font_size", 22)
	var tip := lay.text("ID_LABEL_tip", _tip())
	tip.add_theme_font_size_override("font_size", 22)
	tip.autowrap_mode = TextServer.AUTOWRAP_OFF
