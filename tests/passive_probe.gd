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


func _run() -> void:
	var rock := Save.add_monster("sapphiroid", 30)
	var jack := Save.add_monster("jackoblack", 30)
	main.go("squad", {"mode": "train", "uid": int(rock.uid)})
	await _shot("long")
	main.current._sel = int(jack.uid)
	main.current._refresh()
	await _shot("short")
	get_tree().quit()
