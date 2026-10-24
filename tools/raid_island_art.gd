# Cuts raid island art out of footage frames by flood-filling the ocean from the crop's edges (the art's dark
# outline stops the fill), drops stray pieces and writes assets/islands/<id>.png.
# "strict" only takes the deep ocean blue, for islands that are blue themselves.
# Run: godot --headless --path <project> --script res://tools/raid_island_art.gd -- <frame.png> <id> <x> <y> <w> <h> [strict]
extends SceneTree

var strict := false


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	strict = a.size() > 6 and a[6] == "strict"
	var img := Image.load_from_file(a[0])
	img.convert(Image.FORMAT_RGBA8)
	img = img.get_region(Rect2i(int(a[2]), int(a[3]), int(a[4]), int(a[5])))
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack := PackedInt32Array()
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	while not stack.is_empty():
		var p: int = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		if seen[p] == 1:
			continue
		seen[p] = 1
		var c := img.get_pixel(p % w, p / w)
		if not _water(c):
			continue
		img.set_pixel(p % w, p / w, Color(0, 0, 0, 0))
		for d in [1, -1, w, -w]:
			var q: int = p + d
			if q >= 0 and q < w * h and seen[q] == 0 and not (absi(d) == 1 and q / w != p / w):
				stack.append(q)
	_keep_big(img)
	var used := img.get_used_rect()
	img = img.get_region(used)
	var s := 2.0
	img.resize(int(img.get_width() * s), int(img.get_height() * s), Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path("res://assets/islands/%s.png" % a[1]))
	print("saved ", a[1], " ", img.get_size())
	quit()


func _water(c: Color) -> bool:
	if strict:
		return c.h > 0.565 and c.h < 0.63 and c.s > 0.6 and c.v > 0.45 and c.v < 0.92
	return c.h > 0.52 and c.h < 0.64 and ((c.s > 0.45 and c.v > 0.45) or (c.s > 0.15 and c.v > 0.8))


func _keep_big(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var label := PackedInt32Array()
	label.resize(w * h)
	label.fill(-1)
	var sizes: Array = []
	var stack := PackedInt32Array()
	for start in w * h:
		if label[start] != -1 or img.get_pixel(start % w, start / w).a == 0.0:
			continue
		var id := sizes.size()
		var n := 0
		label[start] = id
		stack.append(start)
		while not stack.is_empty():
			var p: int = stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			n += 1
			for d in [1, -1, w, -w]:
				var q: int = p + d
				if q >= 0 and q < w * h and not (absi(d) == 1 and q / w != p / w) and label[q] == -1 and img.get_pixel(q % w, q / w).a > 0.0:
					label[q] = id
					stack.append(q)
		sizes.append(n)
	var best: int = sizes.max() if not sizes.is_empty() else 0
	for p in w * h:
		if label[p] != -1 and sizes[label[p]] < best * 0.05:
			img.set_pixel(p % w, p / w, Color(0, 0, 0, 0))
