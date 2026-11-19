# Finds the Sky Tower floor page (green Enter button bottom-right) in footage frames
# (research/videos/frames_hd/<id>/<sec>.jpg) and saves the right panel - team, Floor N, Drop List, Boss -
# to research/videos/frames_hd/panels/<id>_<sec>.png, then finds the Boss icon (left of the red "!") and names it
# against assets/icons. Prints "PANEL <id> <secs> boss: best | 2nd | 3rd".
# A .png argument is taken as a saved panel and only its boss is matched.
# Run: godot --headless --path <project> --script res://tools/tower_panels.gd -- <video id | panel.png> ...
extends SceneTree

var refs := {}


func _init() -> void:
	_load_refs()
	var out := ProjectSettings.globalize_path("res://research/videos/frames_hd/panels/")
	DirAccess.make_dir_recursive_absolute(out)
	for v in OS.get_cmdline_user_args():
		if v.ends_with(".png"):
			var pimg := Image.load_from_file(v)
			pimg.convert(Image.FORMAT_RGBA8)
			print("BOSS %s %s" % [v.get_file(), _boss(pimg, v.get_basename() + "_icon.png")])
			continue
		var dir := ProjectSettings.globalize_path("res://research/videos/%s/" % (v if "/" in v else "frames_hd/" + v))
		var files := DirAccess.get_files_at(dir)
		files.sort()
		var hits := []
		var boss := ""
		for f in files:
			if not f.ends_with(".jpg"):
				continue
			var img := Image.load_from_file(dir + f)
			if _is_panel(img):
				hits.append(f.get_basename())
				var w := img.get_width()
				var h := img.get_height()
				var panel := img.get_region(Rect2i(w / 2, int(h * 0.1), w / 2, int(h * 0.85)))
				panel.save_png(out + "%s_%s.png" % [v.get_file(), f.get_basename()])
				if boss == "":
					boss = _boss(panel, out + "%s_boss.png" % v.get_file())
				if hits.size() >= 2:
					break
		print("PANEL %s %s boss: %s" % [v, ",".join(hits), boss])
	quit()


func _is_panel(img: Image) -> bool:
	var w := img.get_width()
	var h := img.get_height()
	var green := 0
	var brown := 0
	var n := 0
	for y in range(int(h * 0.78), int(h * 0.86), 4):
		for x in range(int(w * 0.76), int(w * 0.95), 4):
			n += 1
			var c := img.get_pixel(x, y)
			if c.h > 0.2 and c.h < 0.32 and c.s > 0.5 and c.v > 0.5:
				green += 1
	for y in range(int(h * 0.5), int(h * 0.56), 4):
		for x in range(int(w * 0.62), int(w * 0.82), 4):
			var c := img.get_pixel(x, y)
			if c.h > 0.05 and c.h < 0.12 and c.s > 0.3 and c.v > 0.25 and c.v < 0.7:
				brown += 1
	return green > n * 0.5 and brown > 20


func _boss(panel: Image, save: String) -> String:
	var w := panel.get_width()
	var h := panel.get_height()
	var sx := 0.0
	var sy := 0.0
	var n := 0
	for y in range(int(h * 0.5), int(h * 0.7)):
		for x in range(int(w * 0.6), w):
			var c := panel.get_pixel(x, y)
			if (c.h < 0.06 or c.h > 0.97) and c.s > 0.75 and c.v > 0.75:
				sx += x
				sy += y
				n += 1
	if n < 20:
		return "?"
	var cx := sx / n
	var cy := sy / n
	var side := h * 0.145
	var best := []
	var best_icon: Image
	for dy in [-0.15, -0.05, 0.05, 0.15]:
		for dx in [-1.2, -1.1, -1.0]:
			var r := Rect2i(int(cx + side * dx), int(cy + side * dy), int(side), int(side)).intersection(Rect2i(Vector2i.ZERO, panel.get_size()))
			var icon := panel.get_region(r)
			var m := _match(icon)
			if best.is_empty() or float(m[0][0]) < float(best[0][0]):
				best = m
				best_icon = icon
	best_icon.save_png(save)
	return " | ".join(best.map(func(s): return "%s (%.0f)" % [s[1], s[0]]))


func _key(img: Image) -> PackedFloat32Array:
	var w := img.get_width()
	var h := img.get_height()
	var core := img.get_region(Rect2i(int(w * 0.22), int(h * 0.3), int(w * 0.56), int(h * 0.5)))
	core.convert(Image.FORMAT_RGB8)
	core.resize(20, 20, Image.INTERPOLATE_BILINEAR)
	var out := PackedFloat32Array()
	for py in 20:
		for px in 20:
			var c := core.get_pixel(px, py)
			out.append_array([c.r, c.g, c.b])
	return out


func _load_refs() -> void:
	var dir := ProjectSettings.globalize_path("res://assets/icons/")
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".import"):
			continue
		var img := Image.load_from_file(dir + f)
		if img != null:
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
			d += (k[i] - r[i]) * (k[i] - r[i])
		scores.append([d, id])
	scores.sort_custom(func(a, b): return a[0] < b[0])
	return scores.slice(0, 3)