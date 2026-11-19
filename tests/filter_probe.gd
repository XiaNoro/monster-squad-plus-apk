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
	for spec in [["firepaw", 30, 5], ["flame_eldragon", 30, 2], ["dusa", 30, 5], ["jellio", 12, 0], ["pheona", 30, 5], ["burdon", 22, 1], ["chocomew", 30, 5], ["ami", 8, 0]]:
		var m := Save.add_monster(spec[0], spec[1])
		m.boost = spec[2]
	main.go("squad", {"mode": "train"})
	await _shot("list")
	main.current._filter.elements = ["water"]
	main.current._filter.plus5 = true
	main.current._open_filter()
	await _shot("menu")
	main.current._filter.elements = ["fire"]
	main.current._filter.lv30 = true
	main.current._refresh()
	for c in main.current.get_children():
		if c is ColorRect and c.z_index >= 50:
			c.queue_free()
	await _shot("fire_lv30")
	main.current._filter.elements = []
	main.current._filter.lv30 = false
	main.current._filter.plus5 = true
	main.current._filter.search = "a"
	main.current._refresh()
	await _shot("plus5_search")
	main.current._clear_filter()
	for id in ["amiyom", "antlar", "amia", "anubis", "antlad", "anuk", "ami", "antlid"]:
		Save.add_monster(id, 10)
	main.current._filter.family = true
	main.current._open_filter()
	await _shot("menu_family")
	for c in main.current.get_children():
		if c is ColorRect and c.z_index >= 50:
			c.queue_free()
	main.current._refresh()
	await _shot("family")
	main.current._clear_filter()
	main.go("squad", {})
	main.current._filter.search = "zzz"
	main.current._refresh()
	await _shot("team_none")
	main.current._clear_filter()
	get_tree().quit()
