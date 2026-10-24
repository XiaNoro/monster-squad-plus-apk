# Builds assets/stone_icons/<type>.png from 4x-upscaled Drop List crops of the 2015 Sky Tower footage
# (research/videos/frames_tower/icons/up), or with -- --src=<dir> any crops of the same slot layout (e.g. the 1080p
# M.Stone list in icons/hd_up): removes the slot background, frame, rank badges and the stack count.
# Run: godot --headless --path <project> --script res://tools/stone_icons.gd
extends SceneTree

var SRC := "res://research/videos/frames_tower/icons/up/"
const DST := "res://assets/stone_icons/"
const OUT := 192


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--src="):
			SRC = a.trim_prefix("--src=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DST))
	for f in DirAccess.get_files_at(SRC):
		if not f.ends_with(".png"):
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + f))
		img.convert(Image.FORMAT_RGBA8)
		_mask(img)
		img = _trim(img)
		var s := float(OUT) / maxf(img.get_width(), img.get_height())
		img.resize(maxi(1, int(img.get_width() * s)), maxi(1, int(img.get_height() * s)), Image.INTERPOLATE_LANCZOS)
		var out := Image.create(OUT, OUT, false, Image.FORMAT_RGBA8)
		out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((OUT - img.get_width()) / 2, (OUT - img.get_height()) / 2))
		out.save_png(ProjectSettings.globalize_path(DST + f))
		print("ICON ", f)
	quit()


func _is_bg(c: Color, edge: bool) -> bool:
	if edge:
		return c.s < 0.35
	return c.s < 0.3 and c.v < 0.5


func _mask(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var band := int(w * 0.09)
	var badge := Vector2(w * 0.11, h * 0.11)
	for y in h:
		for x in w:
			var d := Vector2(x, y).distance_to(badge)
			var c0 := img.get_pixel(x, y)
			if d < w * 0.17 or (d < w * 0.23 and c0.h > 0.5 and c0.h < 0.7 and c0.v < 0.55) or (d < w * 0.27 and (c0.h > 0.7 or c0.h < 0.02) and c0.s > 0.35 and x < w * 0.4 and y < h * 0.4):
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif x > w * 0.75 and y < h * 0.32:
				var c := img.get_pixel(x, y)
				if (c.h > 0.36 and c.h < 0.56 and c.s > 0.25) or c.s < 0.3 or (x > w * 0.78 and y < h * 0.32 and c.h > 0.12 and c.h < 0.36 and c.s > 0.4):
					img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif x > w * 0.6 and y > h * 0.7 and c0.s < 0.2:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
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
		var x := p % w
		var y := p / w
		var c := img.get_pixel(x, y)
		var edge := x < band or y < band or x >= w - band or y >= h - band
		if c.a > 0.0 and not _is_bg(c, edge):
			continue
		img.set_pixel(x, y, Color(0, 0, 0, 0))
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx >= 0 and ny >= 0 and nx < w and ny < h and seen[ny * w + nx] == 0:
				stack.append(ny * w + nx)
	_open(img, 6)
	_keep_largest(img)
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var empty := 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if img.get_pixel(x + d.x, y + d.y).a == 0.0:
					empty += 1
			if empty > 0:
				c.a = 1.0 - 0.22 * empty
				img.set_pixel(x, y, c)


func _open(img: Image, r: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var solid := PackedByteArray()
	solid.resize(w * h)
	for p in w * h:
		solid[p] = 1 if img.get_pixel(p % w, p / w).a > 0.0 else 0
	var core := _morph(solid, w, h, r, true)
	var grown := _morph(core, w, h, r, false)
	for p in w * h:
		if solid[p] == 1 and grown[p] == 0:
			img.set_pixel(p % w, p / w, Color(0, 0, 0, 0))


static func _morph(src: PackedByteArray, w: int, h: int, r: int, erode: bool) -> PackedByteArray:
	var tmp := PackedByteArray()
	tmp.resize(w * h)
	for y in h:
		for x in w:
			var v := 1 if erode else 0
			for k in range(-r, r + 1):
				var nx := clampi(x + k, 0, w - 1)
				var s := src[y * w + nx]
				if erode and s == 0:
					v = 0
					break
				if not erode and s == 1:
					v = 1
					break
			tmp[y * w + x] = v
	var out := PackedByteArray()
	out.resize(w * h)
	for y in h:
		for x in w:
			var v := 1 if erode else 0
			for k in range(-r, r + 1):
				var ny := clampi(y + k, 0, h - 1)
				var s := tmp[ny * w + x]
				if erode and s == 0:
					v = 0
					break
				if not erode and s == 1:
					v = 1
					break
			out[y * w + x] = v
	return out


func _keep_largest(img: Image) -> void:
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
		stack.append(start)
		label[start] = id
		while not stack.is_empty():
			var p: int = stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			n += 1
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = p % w + d.x
				var ny: int = p / w + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h:
					var q := ny * w + nx
					if label[q] == -1 and img.get_pixel(nx, ny).a > 0.0:
						label[q] = id
						stack.append(q)
		sizes.append(n)
	if sizes.is_empty():
		return
	var best := 0
	for i in sizes.size():
		if sizes[i] > sizes[best]:
			best = i
	for p in w * h:
		if label[p] != -1 and label[p] != best and sizes[label[p]] < sizes[best] * 0.2:
			img.set_pixel(p % w, p / w, Color(0, 0, 0, 0))


func _trim(img: Image) -> Image:
	var r := img.get_used_rect()
	return img.get_region(r) if r.size.x > 0 else img
