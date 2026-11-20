extends Node

var main: Node
var count := 11
var kind := "red"


func _ready() -> void:
	main = get_parent()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cubes="):
			count = maxi(1, int(a.trim_prefix("--cubes=")))
		elif a.begins_with("--kind="):
			kind = a.trim_prefix("--kind=")
	if not CubesScreen.CUBES.has(kind):
		kind = "red"
	_run.call_deferred()


func _run() -> void:
	Save.data.gems = 99999
	Save.data.gold = 9999999
	Save.data.inventory_cap = maxi(int(Save.data.inventory_cap), 400)
	Save.save_game()
	main.go("cubes", {})
	await get_tree().create_timer(0.5).timeout
	main.current._open(CubesScreen.CUBES[kind], count, kind)
