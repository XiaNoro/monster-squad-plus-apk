# Final pass on the battle/hub sprites: peels the card-brown fringe left around the cut, drops stray
# specks, softens the hard cut edge and lightly sharpens the art (no upscaling). Reads the cleaned cuts
# from research/monsters_cut_v2 (copied there from assets/monsters_cut on first run) and writes assets/monsters_cut.
# Run: godot --headless --path <project> --script res://tools/refine_sprites.gd [-- --only=id,id --amount=0.45]
extends SceneTree

const SRC := "res://research/monsters_cut_v2/"
const DST := "res://assets/monsters_cut/"
const PEEL := 2
const SPECK := 0.01

var amount := 0.45


func _init() -> void:
	var only: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
		if a.begins_with("--amount="):
			amount = float(a.trim_prefix("--amount="))
	_backup()
	var n := 0
	for f in DirAccess.get_files_at(SRC):
		if not f.ends_with(".png") or (not only.is_empty() and not f.get_basename() in only):
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + f))
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		var w := img.get_width()
		var h := img.get_height()
		var px := img.get_data()
		var solid := PackedByteArray()
		solid.resize(w * h)
		for i in w * h:
			solid[i] = 1 if px[i * 4 + 3] >= 128 else 0
		_peel(px, solid, w, h)
		_drop_specks(solid, w, h)
		var out := _sharpen(px, solid, w, h)
		_edges(out, solid, w, h)
		img.set_data(w, h, false, Image.FORMAT_RGBA8, out)
		var used := img.get_used_rect()
		if used.size.x > 4 and used.size.y > 4:
			img = img.get_region(used.grow(1).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
		img.save_png(ProjectSettings.globalize_path(DST + f))
		n += 1
	print("refined %d sprites" % n)
	quit()


func _backup() -> void:
	var dir := ProjectSettings.globalize_path(SRC)
	if DirAccess.dir_exists_absolute(dir) and not DirAccess.get_files_at(dir).is_empty():
		return
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(DST):
		if f.ends_with(".png"):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(DST + f), dir + f)


func _col(px: PackedByteArray, i: int) -> Color:
	return Color8(px[i * 4], px[i * 4 + 1], px[i * 4 + 2])


func _is_fringe(c: Color) -> bool:
	return c.h > 0.04 and c.h < 0.12 and c.s > 0.35 and c.s < 0.8 and c.v > 0.3 and c.v < 0.74


func _border(solid: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx < 0 or ny < 0 or nx >= w or ny >= h or solid[ny * w + nx] == 0:
			return true
	return false


func _peel(px: PackedByteArray, solid: PackedByteArray, w: int, h: int) -> void:
	for _pass in PEEL:
		var clear := PackedInt32Array()
		for y in h:
			for x in w:
				var i := y * w + x
				if solid[i] == 1 and _border(solid, w, h, x, y) and _is_fringe(_col(px, i)):
					clear.append(i)
		for i in clear:
			solid[i] = 0


func _drop_specks(solid: PackedByteArray, w: int, h: int) -> void:
	var label := PackedInt32Array()
	label.resize(w * h)
	label.fill(-1)
	var comps: Array[PackedInt32Array] = []
	var stack := PackedInt32Array()
	for start in w * h:
		if solid[start] == 0 or label[start] != -1:
			continue
		var members := PackedInt32Array()
		label[start] = comps.size()
		stack.append(start)
		while not stack.is_empty():
			var p: int = stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			members.append(p)
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = p % w + dx
					var ny: int = p / w + dy
					if nx >= 0 and ny >= 0 and nx < w and ny < h:
						var q := ny * w + nx
						if solid[q] == 1 and label[q] == -1:
							label[q] = comps.size()
							stack.append(q)
		comps.append(members)
	var biggest := 0
	for c in comps:
		biggest = maxi(biggest, c.size())
	for c in comps:
		if c.size() < biggest * SPECK:
			for p in c:
				solid[p] = 0


func _sharpen(px: PackedByteArray, solid: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var out := px.duplicate()
	var k := [1.0, 2.0, 1.0, 2.0, 4.0, 2.0, 1.0, 2.0, 1.0]
	for y in h:
		for x in w:
			var i := y * w + x
			if solid[i] == 0:
				continue
			var acc := Vector3.ZERO
			var wsum := 0.0
			var t := 0
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = x + dx
					var ny: int = y + dy
					var kw: float = k[t]
					t += 1
					if nx < 0 or ny < 0 or nx >= w or ny >= h or solid[ny * w + nx] == 0:
						continue
					var q := (ny * w + nx) * 4
					acc += Vector3(px[q], px[q + 1], px[q + 2]) * kw
					wsum += kw
			var blur := acc / wsum
			for ch in 3:
				var v := float(px[i * 4 + ch])
				out[i * 4 + ch] = clampi(roundi(v + amount * (v - blur[ch])), 0, 255)
			out[i * 4 + 3] = 255
	return out


func _edges(out: PackedByteArray, solid: PackedByteArray, w: int, h: int) -> void:
	var alpha := PackedByteArray()
	alpha.resize(w * h)
	for y in h:
		for x in w:
			var i := y * w + x
			var n := 0
			var sum := Vector3.ZERO
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = x + dx
					var ny: int = y + dy
					if nx >= 0 and ny >= 0 and nx < w and ny < h and solid[ny * w + nx] == 1:
						n += 1
						var q := (ny * w + nx) * 4
						sum += Vector3(out[q], out[q + 1], out[q + 2])
			if solid[i] == 1:
				alpha[i] = 255 if n >= 7 else int(255.0 * clampf(float(n) / 7.0 + 0.15, 0.0, 1.0))
			else:
				alpha[i] = 0
				if n > 0:
					sum /= float(n)
					out[i * 4] = int(sum.x)
					out[i * 4 + 1] = int(sum.y)
					out[i * 4 + 2] = int(sum.z)
	for i in w * h:
		out[i * 4 + 3] = alpha[i]
