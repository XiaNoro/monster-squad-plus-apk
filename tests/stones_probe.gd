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


func _close_popups() -> void:
	for c in main.current.get_children():
		if c is Control and (c.z_index >= 50 or String(c.name).begins_with("R_d_")):
			c.queue_free()
	await get_tree().process_frame


func _run() -> void:
	Save.data.gems = 500
	Save.data.gold = 500000
	Save.data.tower_floor = 20
	for st in [["bravery", 0, 0, 5], ["windfury", 0, 0, 2], ["thunder", 1, 0, 3], ["destruction", 2, 0, 4], ["bravery", 4, 2, 1], ["destruction", 6, 1, 1], ["vitality", 3, 2, 2], ["time", 4, 1, 1]]:
		for i in int(st[3]):
			Save.add_stone({"type": st[0], "rank": st[1], "variant": st[2]})
	main.go("stones", {})
	await _shot("craft")
	main.current._next_rank()
	main.current._next_rank()
	await _shot("craft_rank_d")
	main.current._next_rank()
	main.current._next_rank()
	main.current._next_rank()
	main.current._next_rank()
	main.current._next_rank()
	main.current._next_rank()
	main.current._pick = ""
	main.current._refresh_craft()
	main.current._open_sell()
	await _shot("craft_sell")
	await _close_popups()
	main.current._expand()
	await _shot("expand")
	await _close_popups()
	main.go("stones", {"uid": int(Save.data.monsters[0].uid)})
	await _shot("equip")
	var stacks := Save.stone_stacks(Save.free_stones())
	main.current._pick = String(stacks[0].key)
	main.current._refresh_equip()
	await _shot("equip_pick")
	main.current._open_sell()
	await _shot("equip_sell")
	get_tree().quit()
