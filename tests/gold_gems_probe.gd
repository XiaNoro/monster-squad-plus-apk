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


func _close_dialogs(scr: Node) -> void:
	for c in scr.get_children():
		if c is Control and (c as Control).z_index >= 80:
			c.queue_free()


func _run() -> void:
	Save.data.gold = 200000
	Save.data.gems = 0
	Save.data.erase("gold_gems_day")
	main.go("cubes", {})
	var scr: Node = main.current
	scr._show_tab("gem")
	await _shot("gem_tab", 1.5)
	var item: Dictionary = scr._items("gem")[0]
	scr._purchase(item)
	var ok1: bool = int(Save.data.gems) == 23 and int(Save.data.gold) == 120000
	await _shot("bought", 1.0)
	_close_dialogs(scr)
	scr._purchase(scr._items("gem")[0])
	var ok2: bool = int(Save.data.gems) == 23 and int(Save.data.gold) == 120000
	await _shot("blocked", 1.0)
	_close_dialogs(scr)
	Save.data.gold_gems_day = "2000-01-01"
	scr._purchase(scr._items("gem")[0])
	var ok3: bool = int(Save.data.gems) == 46 and int(Save.data.gold) == 40000
	print("PROBE first buy %s, second blocked %s, next day %s" % [ok1, ok2, ok3])
	get_tree().quit()
