# Cleans leftovers of the card overlays (grade stars at the top, the "Lv." label at the bottom) that
# cutout_portraits.gd missed on cards whose label sits bottom-centre. Reads the untouched cutouts from
# research/backup_monsters_cut and writes assets/monsters_cut.
# Run: godot --headless --path <project> --script res://tools/clean_cutouts.gd [-- --only=id]
extends SceneTree

const DIR := "res://assets/monsters_cut/"
const SRC := "res://research/backup_monsters_cut/"
const EDGE_BOTTOM := 0.24
const EDGE_TOP := 0.2
const TEXT_STRIP := 0.16
const SMALL := 0.08


func _init() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
	var changed := 0
	var total := 0
	for f in DirAccess.get_files_at(SRC):
		if not f.ends_with(".png") or (only != "" and not f.get_basename() in only.split(",")):
			continue
		total += 1
		var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + f))
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		var removed := _drop_pieces(img, 0.85, false)
		removed += _erase_label(img)
		removed += _drop_pieces(img, 0.1, true)
		if removed > 0:
			changed += 1
			print("CLEAN %s %d" % [f.get_basename(), removed])
		img.save_png(ProjectSettings.globalize_path(DIR + f))
	print("done: %d of %d images cleaned" % [changed, total])
	quit()


func _is_glyph(c: Color) -> bool:
	return c.a > 0.1 and c.h > 0.03 and c.h < 0.17 and c.s > 0.55 and c.v > 0.22


func _erase_label(img: Image) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var top := int(h * (1.0 - TEXT_STRIP))
	var label := PackedInt32Array()
	label.resize(w * h)
	label.fill(-1)
	var n := 0
	var stack := PackedInt32Array()
	for y in range(top, h):
		for x in w:
			var start := y * w + x
			if label[start] != -1 or img.get_pixel(x, y).a < 0.1:
				continue
			label[start] = start
			stack.clear()
			stack.append(start)
			var members := PackedInt32Array()
			var glyph := 0
			while not stack.is_empty():
				var p: int = stack[stack.size() - 1]
				stack.remove_at(stack.size() - 1)
				members.append(p)
				if _is_glyph(img.get_pixel(p % w, p / w)):
					glyph += 1
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var nx: int = p % w + dx
						var ny: int = p / w + dy
						if nx < 0 or nx >= w or ny < top or ny >= h:
							continue
						var q := ny * w + nx
						if label[q] == -1 and img.get_pixel(nx, ny).a >= 0.1:
							label[q] = start
							stack.append(q)
			if members.size() < w * h * 0.02 and glyph > members.size() * 0.5:
				for p in members:
					img.set_pixel(p % w, p / w, Color(0, 0, 0, 0))
				n += members.size()
	return n


func _drop_pieces(img: Image, alpha: float, diagonal: bool) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var label := PackedInt32Array()
	label.resize(w * h)
	label.fill(-1)
	var comps: Array = []
	var stack := PackedInt32Array()
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	if diagonal:
		dirs += [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	for start in w * h:
		if label[start] != -1 or img.get_pixel(start % w, start / w).a < alpha:
			continue
		var id := comps.size()
		var info := {"area": 0, "y0": h, "y1": 0, "pixels": PackedInt32Array()}
		stack.clear()
		stack.append(start)
		label[start] = id
		while not stack.is_empty():
			var p: int = stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			var px := p % w
			var py := p / w
			info.area += 1
			info.pixels.append(p)
			info.y0 = mini(info.y0, py)
			info.y1 = maxi(info.y1, py)
			for d in dirs:
				var nx: int = px + d.x
				var ny: int = py + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var q := ny * w + nx
				if label[q] == -1 and img.get_pixel(nx, ny).a >= alpha:
					label[q] = id
					stack.append(q)
		comps.append(info)
	if comps.size() < 2:
		return 0
	var biggest := 0
	for c in comps:
		biggest = maxi(biggest, int(c.area))
	var removed := 0
	for c in comps:
		if int(c.area) >= biggest * SMALL:
			continue
		var in_bottom := float(c.y0) >= h * (1.0 - EDGE_BOTTOM)
		var in_top := float(c.y1) <= h * EDGE_TOP
		if not (in_bottom or in_top):
			continue
		for p in c.pixels:
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var x: int = p % w + dx
					var y: int = p / w + dy
					if x >= 0 and y >= 0 and x < w and y < h and (img.get_pixel(x, y).a < alpha or (dx == 0 and dy == 0)):
						img.set_pixel(x, y, Color(0, 0, 0, 0))
		removed += int(c.area)
	return removed
