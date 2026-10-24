# Cuts monsters out of the wiki's in-game art-panel screenshots (brown panel, darker shadow ellipse,
# grade stars at the top, "+0" and "Lv.x/30" at the bottom) for use as sprites.
# 1. find the brown panel, trim its rounded border
# 2. flood-fill from the edges through the panel brown AND the darker shadow brown (same hue);
#    the monster's dark outline stops the fill, so brown monsters keep their bodies
# 3. drop pieces that sit only in the star strip or the text strip, and small specks
# 4. remove the brown fringe left by anti-aliasing, then trim
# The game draws its own soft shadow (I_shadow_*) under sprites, so none is kept here.
# Output: res://assets/monsters_cut/<id>.png
# Run: godot --headless --path <project> --script res://tools/cutout_portraits.gd [-- only=id,id]
extends SceneTree

const SRC := "res://assets/monsters"
var DST := "res://assets/monsters_cut"
## Inside the panel: just past the rounded border.
const CROP := Rect2(0.025, 0.03, 0.95, 0.94)
## Strips holding the overlays, as a share of the cropped height.
const STAR_STRIP := 0.2
const TEXT_STRIP := 0.78
const TOLERANCE := 0.075
## Images losing more than this share of pixels were probably eaten into; battle falls back to the card.
const MAX_CLEARED := 0.85


func _init() -> void:
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.trim_prefix("only=").split(",")
		if a.begins_with("dst="):
			DST = a.trim_prefix("dst=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DST))
	var n := 0
	var bad: Array[String] = []
	for f in DirAccess.get_files_at(SRC):
		if not f.ends_with(".webp"):
			continue
		if not only.is_empty() and not f.get_basename() in only:
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(SRC.path_join(f)))
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		var card := _card_bounds(img)
		var r := Rect2i(card.position.x + int(card.size.x * CROP.position.x), card.position.y + int(card.size.y * CROP.position.y), int(card.size.x * CROP.size.x), int(card.size.y * CROP.size.y))
		var cut := img.get_region(r)
		var refs := _panel_colours(cut)
		var cleared := _knock_out_background(cut, refs)
		var out_path := ProjectSettings.globalize_path(DST.path_join(f.get_basename() + ".png"))
		if cleared > MAX_CLEARED:
			bad.append(f.get_basename())
			continue
		_erase_overlays(cut)
		_peel_threads(cut)
		_remove_overlays(cut)
		_defringe(cut, refs)
		var used := cut.get_used_rect()
		if used.size.x > 8 and used.size.y > 8:
			cut = cut.get_region(used.grow(2).intersection(Rect2i(Vector2i.ZERO, cut.get_size())))
		cut.save_png(out_path)
		n += 1
	print("cut %d portraits, %d skipped (kept previous cut or card)" % [n, bad.size()])
	if not bad.is_empty():
		print("skipped: ", ", ".join(bad))
	quit()


## The panel's brown, sampled along the left/right edges at mid height.
func _panel_colours(img: Image) -> Array[Color]:
	var w := img.get_width()
	var h := img.get_height()
	var refs: Array[Color] = []
	# All four edges, keeping only true panel brown (wide art can reach the edges).
	for y in range(0, h, maxi(1, h / 24)):
		for x in [2, w - 3]:
			var c := img.get_pixel(x, y)
			if _is_card_brown(c):
				refs.append(c)
	for x in range(0, w, maxi(1, w / 24)):
		for y in [2, h - 3]:
			var c := img.get_pixel(x, y)
			if _is_card_brown(c):
				refs.append(c)
	if refs.is_empty():
		refs.append(img.get_pixel(2, h / 2))
	return refs


func _knock_out_background(img: Image, refs: Array[Color]) -> float:
	var w := img.get_width()
	var h := img.get_height()
	var ref_v := 0.0
	var ref_h := 0.0
	var ref_s := 0.0
	for c in refs:
		ref_v += c.v
		ref_h += c.h
		ref_s += c.s
	ref_v /= refs.size()
	ref_h /= refs.size()
	ref_s /= refs.size()
	var visited := PackedByteArray()
	visited.resize(w * h)
	var stack: Array[Vector2i] = []
	var cleared := 0
	for x in w:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in h:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var i := p.y * w + p.x
		if visited[i] == 1:
			continue
		visited[i] = 1
		var c := img.get_pixelv(p)
		# The shadow ellipse only lies under the feet; brown capes and fur higher up are spared.
		var low := p.y > h * 0.55
		if not (_is_panel(c, refs) or (low and _is_shadow(c, ref_h, ref_s, ref_v))):
			continue
		img.set_pixelv(p, Color(0, 0, 0, 0))
		stack.append(p + Vector2i.RIGHT)
		stack.append(p + Vector2i.LEFT)
		stack.append(p + Vector2i.DOWN)
		stack.append(p + Vector2i.UP)
		cleared += 1
	return float(cleared) / float(w * h)


func _is_panel(c: Color, refs: Array[Color]) -> bool:
	if c.a < 0.1:
		return true
	for r in refs:
		if absf(c.r - r.r) + absf(c.g - r.g) + absf(c.b - r.b) < TOLERANCE * 3.0:
			return true
	return false


## The shadow ellipse: the panel's hue, a bit darker. Outlines are much darker or grey, so they stop the fill.
func _is_shadow(c: Color, ref_h: float, ref_s: float, ref_v: float) -> bool:
	return absf(c.h - ref_h) < 0.03 and c.s > ref_s - 0.15 and c.s < ref_s + 0.12 and c.v > ref_v * 0.66 and c.v < ref_v + 0.04


## Grade stars (top-left row), the Lv30 badge (top-right), "+N" (bottom-left) and "Lv.x/30"
## (bottom-right) are game overlays: clear their colours inside those boxes, then the dark outline
## rings that were around them.
func _erase_overlays(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var boxes := [
		Rect2i(0, 0, int(w * 0.78), int(h * 0.15)),          # grade stars
		Rect2i(int(w * 0.87), 0, w - int(w * 0.87), int(h * 0.13)),  # Lv30 badge
		Rect2i(0, int(h * 0.84), int(w * 0.24), h - int(h * 0.84)),  # +N
		Rect2i(int(w * 0.5), int(h * 0.84), w - int(w * 0.5), h - int(h * 0.84)),  # Lv.x/30
	]
	var erased := PackedByteArray()
	erased.resize(w * h)
	for k in boxes.size():
		var b: Rect2i = boxes[k]
		for y in range(b.position.y, b.end.y):
			for x in range(b.position.x, b.end.x):
				var c := img.get_pixel(x, y)
				if c.a < 0.1:
					continue
				var hit := false
				match k:
					0:
						hit = c.h > 0.1 and c.h < 0.18 and c.s > 0.55 and c.v > 0.78
					1:
						hit = c.h > 0.04 and c.h < 0.12 and c.s > 0.45 and c.v > 0.35
					2:
						hit = c.h > 0.52 and c.h < 0.7 and c.s > 0.25 and c.v > 0.7
					3:
						hit = c.h > 0.05 and c.h < 0.13 and c.s > 0.7 and c.v > 0.82
				if hit:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
					erased[y * w + x] = 1
	# Outline rings: dark pixels in the boxes within 3px of an erased glyph.
	for k in boxes.size():
		var b: Rect2i = boxes[k]
		for y in range(b.position.y, b.end.y):
			for x in range(b.position.x, b.end.x):
				var c := img.get_pixel(x, y)
				if c.a < 0.1 or c.v > 0.55:
					continue
				var near := false
				for dy in range(-3, 4):
					for dx in range(-3, 4):
						var nx := x + dx
						var ny := y + dy
						if nx >= 0 and ny >= 0 and nx < w and ny < h and erased[ny * w + nx] == 1:
							near = true
							break
					if near:
						break
				if near:
					img.set_pixel(x, y, Color(0, 0, 0, 0))


## Leftover glyph outlines touching the feet are 1-2px threads: peel pixels with few neighbours
## in the text strip a few times (solid art keeps its shape).
func _peel_threads(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for _pass in 3:
		var clear: Array[Vector2i] = []
		for y in range(int(h * TEXT_STRIP), h):
			for x in w:
				if img.get_pixel(x, y).a < 0.1:
					continue
				var n := 0
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						if (dx != 0 or dy != 0) and x + dx >= 0 and y + dy >= 0 and x + dx < w and y + dy < h and img.get_pixel(x + dx, y + dy).a >= 0.1:
							n += 1
				if n <= 2:
					clear.append(Vector2i(x, y))
		for p in clear:
			img.set_pixelv(p, Color(0, 0, 0, 0))


## Drops specks, and pieces lying wholly inside the star strip or the level/boost text strip.
func _remove_overlays(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var label := PackedInt32Array()
	label.resize(w * h)
	label.fill(-1)
	var sizes: Array[int] = []
	var min_y: Array[int] = []
	var max_y: Array[int] = []
	for start in w * h:
		if label[start] != -1 or img.get_pixel(start % w, start / w).a < 0.1:
			continue
		var id := sizes.size()
		var count := 0
		var lo := h
		var hi := 0
		var stack: Array[int] = [start]
		label[start] = id
		while not stack.is_empty():
			var i: int = stack.pop_back()
			count += 1
			var x := i % w
			var y := i / w
			lo = mini(lo, y)
			hi = maxi(hi, y)
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = x + dx
					var ny: int = y + dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var nb := ny * w + nx
					if label[nb] == -1 and img.get_pixel(nx, ny).a >= 0.1:
						label[nb] = id
						stack.append(nb)
		sizes.append(count)
		min_y.append(lo)
		max_y.append(hi)
	if sizes.is_empty():
		return
	var largest: int = sizes.max()
	var star_line := int(h * STAR_STRIP)
	var text_line := int(h * TEXT_STRIP)
	var drop := PackedByteArray()
	drop.resize(sizes.size())
	for id in sizes.size():
		var main := sizes[id] == largest
		var in_stars := max_y[id] <= star_line
		var in_text := min_y[id] >= text_line
		if not main and (sizes[id] < largest * 0.03 or in_stars or in_text):
			drop[id] = 1
	for i in w * h:
		var id := label[i]
		if id >= 0 and drop[id] == 1:
			img.set_pixel(i % w, i / w, Color(0, 0, 0, 0))


## Anti-aliased edge pixels still carry the panel brown; clear the ones that are mostly brown.
func _defringe(img: Image, refs: Array[Color]) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var ref := Color(0, 0, 0)
	for c in refs:
		ref += c
	ref /= float(refs.size())
	var clear: Array[Vector2i] = []
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a < 0.1:
				continue
			var edge := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or img.get_pixelv(q).a < 0.1:
					edge = true
					break
			if edge and absf(c.h - ref.h) < 0.03 and absf(c.s - ref.s) < 0.15 and absf(c.v - ref.v) < 0.18:
				clear.append(Vector2i(x, y))
	for p in clear:
		img.set_pixelv(p, Color(0, 0, 0, 0))


func _card_bounds(img: Image) -> Rect2i:
	var w := img.get_width()
	var h := img.get_height()
	var rows := PackedInt32Array()
	rows.resize(h)
	var cols := PackedInt32Array()
	cols.resize(w)
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			if _is_card_brown(img.get_pixel(x, y)):
				rows[y] += 1
				cols[x] += 1
	var min_row := w / 2 / 4  # a card row is mostly brown (sampled every 2nd pixel)
	var min_col := h / 2 / 4
	var top := 0
	var bottom := h - 1
	var left := 0
	var right := w - 1
	while top < h - 1 and rows[top] < min_row:
		top += 1
	while bottom > top and rows[bottom] < min_row:
		bottom -= 1
	while left < w - 1 and cols[left] < min_col:
		left += 1
	while right > left and cols[right] < min_col:
		right -= 1
	if right - left < w / 3 or bottom - top < h / 3:
		return Rect2i(0, 0, w, h)
	return Rect2i(left, top, right - left + 1, bottom - top + 1)


func _is_card_brown(c: Color) -> bool:
	return c.h > 0.05 and c.h < 0.11 and c.s > 0.4 and c.s < 0.75 and c.v > 0.45 and c.v < 0.72
