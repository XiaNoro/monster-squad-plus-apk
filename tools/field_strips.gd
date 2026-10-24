# Cuts each story island's stage-strip art (the picture behind "Lake-8", energy and boss card on the field page)
# from 1080p footage frames and writes assets/fields/<island>.png at the R_fieldSlot size. The stage name,
# energy pill and boss card are painted over with neighbouring art; the game draws its own on top.
# Run: godot --headless --path <project> --script res://tools/field_strips.gd -- <island>=<frame.jpg>@<strip top y>[@<left fill share, default 0.47>] ...
extends SceneTree

const X0 := 1177
const X1 := 1816
const H := 164
const OUT := Vector2i(358, 102)

var left_share := 0.47


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/fields/"))
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		var src := kv[1].split("@")
		var img := Image.load_from_file(src[0])
		img.convert(Image.FORMAT_RGBA8)
		var top := int(src[1])
		left_share = float(src[2]) if src.size() > 2 else 0.47
		var strip := img.get_region(Rect2i(X0, top, X1 - X0, H))
		_fill(strip)
		strip.resize(OUT.x, OUT.y, Image.INTERPOLATE_LANCZOS)
		strip.save_png(ProjectSettings.globalize_path("res://assets/fields/%s.png" % kv[0]))
		print("STRIP %s top=%d" % [kv[0], top])
	quit()


func _fill(s: Image) -> void:
	var w := s.get_width()
	var h := s.get_height()
	var card := int(w * 0.71)
	var left := int(w * left_share)
	var src := s.get_region(Rect2i(left, 0, card - left, h))
	var band := src.get_width()
	for y in h:
		for x in range(card, w):
			var k := (x - card) % (2 * band)
			s.set_pixel(x, y, src.get_pixel(band - 1 - k if k < band else k - band, y))
		for x in left:
			var k := (left - 1 - x) % (2 * band)
			s.set_pixel(x, y, src.get_pixel(k if k < band else 2 * band - 1 - k, y))