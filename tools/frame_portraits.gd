# Recovers portraits the wiki lacks from walkthrough loading screens (large monster art on brown).
# Input: a JSON list [{id, frame}] (see README). Writes assets/monsters/<id>.png (framed crop) and
# assets/monsters_cut/<id>.png (background removed).
# Run: godot --headless --path <project> --script res://tools/frame_portraits.gd -- <jobs.json>
extends SceneTree

## Monster area on a 854x480 loading screen; pillarboxed recordings use the second rect.
const RECT := Rect2i(100, 120, 320, 280)
const RECT_PILLARBOX := Rect2i(120, 90, 310, 250)
const TOLERANCE := 0.09


func _init() -> void:
	var jobs_path := OS.get_cmdline_user_args()[0]
	var jobs: Variant = JSON.parse_string(FileAccess.get_file_as_string(jobs_path))
	if jobs is Dictionary:
		jobs = [jobs]
	for j in jobs:
		var img := Image.load_from_file(String(j.frame))
		img.convert(Image.FORMAT_RGBA8)
		# Pillarboxed videos have dark bars at the left edge.
		var edge := img.get_pixel(20, 240)
		var rect := RECT_PILLARBOX if edge.v < 0.35 and edge.b > edge.r else RECT
		# Optional per-job overrides: rect [x, y, w, h] and gain (brightens dimmed fade-in frames).
		if j.has("rect"):
			rect = Rect2i(int(j.rect[0]), int(j.rect[1]), int(j.rect[2]), int(j.rect[3]))
		var crop := img.get_region(rect)
		var gain := float(j.get("gain", 1.0))
		if gain != 1.0:
			for y in crop.get_height():
				for x in crop.get_width():
					var c := crop.get_pixel(x, y)
					crop.set_pixel(x, y, Color(minf(1.0, c.r * gain), minf(1.0, c.g * gain), minf(1.0, c.b * gain), c.a))
		crop.save_png(ProjectSettings.globalize_path("res://assets/monsters/%s.png" % j.id))
		var cut: Image = crop.duplicate()
		_knock_out(cut)
		_keep_large_parts(cut)
		var used := cut.get_used_rect()
		if used.size.x > 8:
			cut = cut.get_region(used.grow(2).intersection(Rect2i(Vector2i.ZERO, cut.get_size())))
		cut.save_png(ProjectSettings.globalize_path("res://assets/monsters_cut/%s.png" % j.id))
		print("portrait ", j.id)
	quit()


func _knock_out(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var refs: Array[Color] = []
	for y in range(0, h, 8):
		refs.append(img.get_pixel(1, y))
		refs.append(img.get_pixel(w - 2, y))
	for x in range(0, w, 8):
		refs.append(img.get_pixel(x, 1))
	var visited := PackedByteArray()
	visited.resize(w * h)
	var stack: Array[Vector2i] = []
	for x in w:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in h:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or visited[p.y * w + p.x] == 1:
			continue
		visited[p.y * w + p.x] = 1
		var c := img.get_pixelv(p)
		var bg := false
		for r in refs:
			if absf(c.r - r.r) + absf(c.g - r.g) + absf(c.b - r.b) < TOLERANCE * 3.0:
				bg = true
				break
		if not bg:
			continue
		img.set_pixelv(p, Color(0, 0, 0, 0))
		stack.append(p + Vector2i.RIGHT)
		stack.append(p + Vector2i.LEFT)
		stack.append(p + Vector2i.DOWN)
		stack.append(p + Vector2i.UP)

## Drop loose UI bits (tip badge, text) that survive background removal: keep parts >= 15% of the biggest.
func _keep_large_parts(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var label := PackedInt32Array()
	label.resize(w * h)
	label.fill(-1)
	var sizes: Array[int] = []
	for start in w * h:
		if label[start] != -1 or img.get_pixel(start % w, start / w).a < 0.1:
			continue
		var id := sizes.size()
		var count := 0
		var stack: Array[int] = [start]
		label[start] = id
		while not stack.is_empty():
			var i: int = stack.pop_back()
			count += 1
			var x := i % w
			for n in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
				if n >= 0 and n < w * h and label[n] == -1 and img.get_pixel(n % w, n / w).a >= 0.1:
					label[n] = id
					stack.append(n)
		sizes.append(count)
	if sizes.is_empty():
		return
	var largest: int = sizes.max()
	for i in w * h:
		if label[i] >= 0 and sizes[label[i]] < largest * 0.15:
			img.set_pixel(i % w, i / w, Color(0, 0, 0, 0))