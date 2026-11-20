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
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _run() -> void:
	Save.data.inventory_cap = 400
	var ids := ["firepaw", "dripbal", "leavbal", "ami", "jellio", "burdon", "antlad", "anuk"]
	for i in 250:
		Save.add_monster(ids[i % ids.size()], 1 + i % 20)
	main.go("squad", {"mode": "train"})
	await get_tree().process_frame
	main.current._set_selling(true)
	await get_tree().process_frame
	var free_uid := -1
	for m in Save.data.monsters:
		if not Save.in_team(int(m.uid)) and not m.locked:
			free_uid = int(m.uid)
			break
	var t0 := Time.get_ticks_usec()
	main.current._refresh()
	await get_tree().process_frame
	var full := Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	main.current._toggle_sell(free_uid)
	await get_tree().process_frame
	var fast := Time.get_ticks_usec() - t0
	print("full refresh: %d ms, pick: %d ms" % [full / 1000, fast / 1000])
	await _shot("picked")
	main.current._toggle_sell(free_uid)
	await _shot("unpicked")
	get_tree().quit()
