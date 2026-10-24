# Rebuilds an island's battle background from a footage frame taken while the enemy side was empty:
# keeps the clean right part of the game area, replaces the HUD bands at its top and bottom with mirrored
# neighbouring rows, then mirrors it across to cover the allies' side. Writes assets/battle_bg/<id>.png.
# Run: godot --headless --path <project> --script res://tools/battle_bg.gd -- <frame> <id> <game top> <game bottom> <clean x> <top hud h> <bottom hud h> [<top hud starts at x>]
extends SceneTree


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file(a[0])
	img.convert(Image.FORMAT_RGBA8)
	var top := int(a[2])
	var bottom := int(a[3])
	var cx := int(a[4])
	var th := int(a[5])
	var bh := int(a[6])
	var tx := maxi(0, int(a[7]) - cx) if a.size() > 7 else 0
	var w := img.get_width() - cx
	var h := bottom - top
	var half := img.get_region(Rect2i(cx, top, w, h))
	for y in th:
		for x in range(tx, w):
			half.set_pixel(x, y, half.get_pixel(x, 2 * th - 1 - y))
	for y in range(h - bh, h):
		for x in w:
			half.set_pixel(x, y, half.get_pixel(x, 2 * (h - bh) - 1 - y))
	var out := Image.create(w * 2, h, false, Image.FORMAT_RGBA8)
	var mirrored := half.duplicate()
	mirrored.flip_x()
	out.blit_rect(mirrored, Rect2i(Vector2i.ZERO, half.get_size()), Vector2i.ZERO)
	out.blit_rect(half, Rect2i(Vector2i.ZERO, half.get_size()), Vector2i(w, 0))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/battle_bg/"))
	out.save_png(ProjectSettings.globalize_path("res://assets/battle_bg/%s.png" % a[1]))
	print("BG %s %dx%d" % [a[1], out.get_width(), out.get_height()])
	quit()
