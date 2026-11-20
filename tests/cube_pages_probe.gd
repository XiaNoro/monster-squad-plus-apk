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


func _run() -> void:
	main.go("cubes", {})
	var ids := ["firepaw", "dripbal", "leavbal", "ami", "jellio", "burdon", "dusa", "pheona", "chocomew", "antlad", "anuk"]
	var r := CubeReveal.new()
	for i in ids.size():
		r.items.append({"id": ids[i], "new": i % 3 == 0})
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.z_index = 70
	main.current.add_child(r)
	r._scene()
	r._summary()
	await _shot("page1", 9.0)
	for c in r.get_children():
		for b in c.find_children("*", "Button", true, false):
			if (b as Button).text == "Next":
				(b as Button).pressed.emit()
	await _shot("page2", 3.0)
	get_tree().quit()
