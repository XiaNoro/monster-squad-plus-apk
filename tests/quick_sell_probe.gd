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


func _shot(name: String) -> void:
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _close() -> void:
	for c in main.current.get_children():
		if c is ColorRect and c.z_index >= 50:
			c.queue_free()
	await get_tree().process_frame


func _run() -> void:
	for spec in [["firepaw", 1], ["firepaw", 4], ["dripbal", 1], ["dripbal", 1], ["leavbal", 7], ["sapphiroid", 1], ["mauve_rock", 1], ["ami", 1], ["ami", 3], ["jellio", 30], ["burdon", 1], ["burdon", 2]]:
		Save.add_monster(spec[0], spec[1])
	main.go("squad", {"mode": "train"})
	await get_tree().process_frame
	main.current._set_selling(true)
	await _shot("sell")
	main.current._open_quick_sell()
	await _shot("quick")
	await _close()
	main.current._quick_select()
	await _shot("picked")
	var grid: Control = main.current.lay.node("ID_sellect_position").get_child(0)
	var card: Control = grid.get_child(2)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.global_position = card.get_global_rect().get_center()
		card.gui_input.emit(e)
	await _shot("removed")
	get_tree().quit()
