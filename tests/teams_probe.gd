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
	main.go("squad", {})
	await _shot("team1")
	main.current._switch_team(4)
	await _shot("team5")
	main.current._switch_team(0)
	main.go("arena", {})
	await get_tree().process_frame
	main.current._show_match()
	await _shot("arena")
	get_tree().quit()
