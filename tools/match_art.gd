# Names monsters seen in footage. Crops <x,y,w,h> (pixels) out of an image and compares it with
# assets/icons (mode "icon": a monster card icon, matched on its centre art) or assets/monsters_cut
# (mode "sprite": a monster in battle, matched on a hue/saturation histogram that ignores sky and shadow).
# "element" limits candidates to fire/water/nature/normal. Prints the best matches.
# Run: godot --headless --path <project> --script res://tools/match_art.gd -- <image> <x,y,w,h> <icon|sprite> [element] [top]
extends SceneTree

const SIDE := 20
const HB := 18
const SB := 4


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file(a[0])
	img.convert(Image.FORMAT_RGBA8)
	var r := a[1].split(",")
	var crop := img.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
	var mode := a[2]
	var element := a[3] if a.size() > 3 else ""
	var top := int(a[4]) if a.size() > 4 else 8
	var monsters: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/monsters.json"))
	var scores := []
	var key := _icon_key(crop) if mode == "icon" else _hist(crop, false)
	var dir := ProjectSettings.globalize_path("res://assets/icons/" if mode == "icon" else "res://assets/monsters_cut/")
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".import"):
			continue
		var id := f.get_basename()
		if element != "" and element != "any" and String(monsters.get(id, {}).get("element", "")) != element:
			continue
		var ref := Image.load_from_file(dir + f)
		if ref == null:
			continue
		ref.convert(Image.FORMAT_RGBA8)
		var k := _icon_key(ref) if mode == "icon" else _hist(ref, true)
		var d := 0.0
		for i in k.size():
			d += (key[i] - k[i]) * (key[i] - k[i]) if mode == "icon" else absf(key[i] - k[i])
		scores.append([d, id])
	scores.sort_custom(func(x, y): return x[0] < y[0])
	var out := []
	for i in mini(top, scores.size()):
		out.append("%s (%.2f)" % [scores[i][1], scores[i][0]])
	print("MATCH ", ", ".join(out))
	quit()


func _icon_key(img: Image) -> PackedFloat32Array:
	var w := img.get_width()
	var h := img.get_height()
	var core := img.get_region(Rect2i(int(w * 0.22), int(h * 0.3), int(w * 0.56), int(h * 0.5)))
	core.convert(Image.FORMAT_RGB8)
	core.resize(SIDE, SIDE, Image.INTERPOLATE_BILINEAR)
	var out := PackedFloat32Array()
	for py in SIDE:
		for px in SIDE:
			var c := core.get_pixel(px, py)
			out.append_array([c.r, c.g, c.b])
	return out


func _hist(img: Image, alpha: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(HB * SB + 2)
	var n := 0.0
	var step := maxi(1, int(sqrt(img.get_width() * img.get_height() / 6000.0)))
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var c := img.get_pixel(x, y)
			if alpha and c.a < 0.5:
				continue
			if not alpha and _background(c):
				continue
			n += 1.0
			if c.v < 0.22:
				out[HB * SB] += 1.0
			elif c.s < 0.15:
				out[HB * SB + 1] += 1.0
			else:
				out[mini(HB - 1, int(c.h * HB)) * SB + mini(SB - 1, int((c.s - 0.15) / 0.85 * SB))] += 1.0
	for i in out.size():
		out[i] /= maxf(n, 1.0)
	return out


func _background(c: Color) -> bool:
	return (c.h > 0.5 and c.h < 0.62 and c.s < 0.55 and c.v > 0.6) or (c.s < 0.08 and c.v > 0.85)
