extends Node

var main: Node
var out := ""


func _ready() -> void:
	main = get_parent()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--probe-out="):
			out = a.trim_prefix("--probe-out=")
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _shot(name: String, wait := 0.6) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _tap(c: Control) -> void:
	var p := c.get_global_rect().get_center()
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = p
		e.global_position = p
		c.gui_input.emit(e)


func _run() -> void:
	main.go("squad", {})
	await get_tree().create_timer(1.5).timeout
	var icons: Array = main.current.find_children("*", "TextureRect", true, false).filter(func(n): return String(n.tooltip_text).contains("MP)") or String(n.tooltip_text).contains("every "))
	print("PROBE skill icons: %d" % icons.size())
	if icons.is_empty():
		get_tree().quit()
		return
	icons.sort_custom(func(a, b): return a.get_global_rect().position.x < b.get_global_rect().position.x)
	_tap(icons[0])
	print("PROBE tip open: %s" % is_instance_valid(UI._tip))
	await _shot("tip_left", 0.5)
	_tap(icons[-1])
	await _shot("tip_right", 0.5)
	var panel: Control = UI._tip.get_child(0)
	var r := panel.get_global_rect()
	var view := panel.get_viewport_rect().size
	print("PROBE on screen: %s  rect %s  view %s" % [r.position.x >= 0 and r.end.x <= view.x and r.position.y >= 0 and r.end.y <= view.y, r, view])
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	UI._tip.gui_input.emit(press)
	await get_tree().process_frame
	print("PROBE closed by tap: %s" % (not is_instance_valid(UI._tip) or UI._tip == null))
	UI.show_tip(icons[0], "Very long test description: " + "deals heavy damage to all enemies and lowers their defence for a while, ".repeat(4))
	await _shot("tip_long", 0.5)
	UI.close_tip()
	var pinky := Save.add_monster("cutiepinky", 30) if DB.monsters.has("cutiepinky") else Save.add_monster("firepaw", 30)
	main.go("hub", {})
	await get_tree().create_timer(1.0).timeout
	MonsterPopup.open(main.current, int(pinky.uid), {})
	await get_tree().create_timer(1.0).timeout
	var pop: Array = main.current.find_children("*", "TextureRect", true, false).filter(func(n): return String(n.tooltip_text).contains("MP)"))
	print("PROBE popup skill icons: %d" % pop.size())
	for c in main.current.get_children():
		if c is Control and String(c.name).contains("ttend"):
			c.queue_free()
	if not pop.is_empty():
		var at: Vector2 = pop[0].get_global_rect().get_center()
		var mv := InputEventMouseMotion.new()
		mv.position = at
		mv.global_position = at
		get_viewport().push_input(mv, true)
		await _shot("hover_popup", 1.5)
		for down in [true, false]:
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = down
			e.position = at
			e.global_position = at
			get_viewport().push_input(e, true)
			await get_tree().process_frame
		await _shot("tip_popup", 0.5)
		var pr: Rect2 = UI._tip.get_child(0).get_global_rect()
		print("PROBE popup tip rect %s" % pr)
	get_tree().quit()
