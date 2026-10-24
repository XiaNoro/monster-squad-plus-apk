# Finds the "Stage N" enemy popups in raid footage frames (research/videos/frames_raid/<video>/<sec>.jpg,
# 854x480 with the game in the left 75%) and matches each enemy icon against assets/icons by its centre art.
# Writes popup crops to research/videos/frames_raid/popups and prints "video sec slot: best (score) | 2nd | 3rd".
# With <video>/<sec>:<4|5|boss> it matches the slots of that popup layout instead of guessing them.
# Run: godot --headless --path <project> --script res://tools/raid_scan.gd -- <video id | video/sec:layout> ...
extends SceneTree

const ROOT := "res://research/videos/frames_raid/"
const S := 854.0 / 1280.0
const SIDE := 20

var refs: Dictionary = {}


func _init() -> void:
	_load_refs()
	var out := ProjectSettings.globalize_path(ROOT + "popups/")
	DirAccess.make_dir_recursive_absolute(out)
	for v in OS.get_cmdline_user_args():
		if v.contains(":"):
			_named(v)
			continue
		var dir := ProjectSettings.globalize_path(ROOT + v + "/")
		var files := DirAccess.get_files_at(dir)
		files.sort()
		for f in files:
			if not f.ends_with(".jpg"):
				continue
			var img := Image.load_from_file(dir + f)
			if not _is_popup(img):
				continue
			var sec := int(f.get_basename())
			img.get_region(_r(230, 190, 520, 340)).save_png(out + "%s_%04d.png" % [v, sec])
			for slot in _slots(img):
				var icon := img.get_region(slot)
				var best := _match(icon)
				print("%s %d:%02d x%d: %s" % [v, sec / 60, sec % 60, slot.position.x, " | ".join(best)])
	quit()


func _r(x: float, y: float, w: float, h: float) -> Rect2i:
	return Rect2i(int(x * S), int(y * S), int(w * S), int(h * S))


func _is_popup(img: Image) -> bool:
	for pair in [[_r(660, 205, 40, 30), _r(420, 445, 150, 30)], [_r(600, 195, 36, 26), _r(400, 462, 150, 26)]]:
		var x := _avg(img, pair[0])
		var go := _avg(img, pair[1])
		if x.h > 0.03 and x.h < 0.12 and x.s > 0.55 and x.v > 0.75 and go.h > 0.2 and go.h < 0.36 and go.s > 0.5 and go.v > 0.5:
			return true
	return false


func _avg(img: Image, r: Rect2i) -> Color:
	var c := Color(0, 0, 0)
	var n := 0
	for y in range(r.position.y, r.end.y, 2):
		for x in range(r.position.x, r.end.x, 2):
			c += img.get_pixel(x, y)
			n += 1
	return c / float(maxi(n, 1))


func _slots(img: Image) -> Array:
	var out := []
	var y := 300.0
	var xs := []
	var x := 240.0
	while x < 700.0:
		var c := _avg(img, _r(x + 30, y + 45, 20, 20))
		var paper := c.h > 0.07 and c.h < 0.13 and c.s > 0.2 and c.s < 0.45 and c.v > 0.75
		if not paper:
			var left := x
			while left > 236.0 and not _is_paper(_avg(img, _r(left - 4, y + 40, 4, 20))):
				left -= 2.0
			xs.append(left)
			x = left + 96.0
		else:
			x += 8.0
	for lx in xs:
		out.append(_r(lx, y, 80, 80))
	return out


func _is_paper(c: Color) -> bool:
	return c.h > 0.07 and c.h < 0.13 and c.s > 0.2 and c.s < 0.45 and c.v > 0.75


func _key(img: Image) -> PackedFloat32Array:
	var w := img.get_width()
	var h := img.get_height()
	var core := img.get_region(Rect2i(int(w * 0.22), int(h * 0.3), int(w * 0.56), int(h * 0.5)))
	core.convert(Image.FORMAT_RGB8)
	core.resize(SIDE, SIDE, Image.INTERPOLATE_BILINEAR)
	var out := PackedFloat32Array()
	for py in SIDE:
		for px in SIDE:
			var c := core.get_pixel(px, py)
			out.append(c.r)
			out.append(c.g)
			out.append(c.b)
	return out


func _load_refs() -> void:
	var dir := ProjectSettings.globalize_path("res://assets/icons/")
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".import"):
			continue
		var img := Image.load_from_file(dir + f)
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		refs[f.get_basename()] = _key(img)


func _match(icon: Image) -> Array:
	icon.convert(Image.FORMAT_RGBA8)
	var k := _key(icon)
	var scores := []
	for id in refs:
		var r: PackedFloat32Array = refs[id]
		var d := 0.0
		for i in k.size():
			var e := k[i] - r[i]
			d += e * e
		scores.append([d, id])
	scores.sort_custom(func(a, b): return a[0] < b[0])
	var out := []
	for i in 3:
		out.append("%s (%.1f)" % [scores[i][1], scores[i][0]])
	return out


func _named(spec: String) -> void:
	var parts := spec.split(":")
	var img := Image.load_from_file(ProjectSettings.globalize_path(ROOT + parts[0] + ".jpg"))
	if img == null:
		print("missing ", spec)
		return
	var slots := []
	match parts[1]:
		"4":
			for k in 4:
				slots.append(Vector2(193 + k * 69.6, 199))
		"5":
			for k in 5:
				slots.append(Vector2(170 + k * 64.7, 199))
		"3":
			for k in 3:
				slots.append(Vector2(228 + k * 69.6, 199))
		_:
			slots.append(Vector2(292, 209))
	var names := []
	for s in slots:
		var r := Rect2i(int(s.x), int(s.y), 56, 56)
		names.append(_match(img.get_region(r))[0])
	print("%s: %s" % [spec, ", ".join(names)])