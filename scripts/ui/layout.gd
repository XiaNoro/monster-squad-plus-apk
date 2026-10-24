class_name Layout
extends RefCounted

const DIR := "res://data/layouts/"
const IMAGE_DIRS := ["betaUI00", "betaHud00", "betaGacha00", "betaLoading00", "betaTitle00", "BW"]
const FONT_REGULAR := "res://assets/apk/fonts/NanumBarunGothic.ttf"
const SCREEN_H := 640.0
const DESIGN_W := 1066.0
const POPUP_CLOSE := ["ID_btnOk", "ID_btnOk_1", "ID_btnEsc", "ID_btnEsc_1"]

static var _paths: Dictionary = {}
static var _xml_cache: Dictionary = {}

var nodes: Dictionary = {}
var all: Array = []
var root: Control


static func load_into(parent: Node, layout_name: String, at: Vector2 = Vector2.ZERO, base_h: float = SCREEN_H, open_sfx: String = "popup_open") -> Layout:
	var lay := Layout.new()
	var tree: Array = parse(layout_name)
	var holder := Control.new()
	holder.name = layout_name
	holder.position = at
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	for n in tree:
		lay._build(n, holder, base_h)
	_order_by_z(holder)
	lay.root = holder
	if base_h == SCREEN_H and at == Vector2.ZERO:
		lay._fit_width(holder)
	if layout_name.begins_with("R_d_") and layout_name != "R_d_tutorial":
		if open_sfx != "":
			Sfx.play(open_sfx)
		for id in POPUP_CLOSE:
			if lay.nodes.has(id):
				lay.nodes[id].set_meta("sfx", "popup_ok")
	return lay


func _fit_width(holder: Control) -> void:
	var vw: float = holder.get_viewport_rect().size.x if holder.is_inside_tree() else float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var off := (vw - DESIGN_W) / 2.0
	if off <= 0.0:
		return
	holder.position.x += off
	_stretch_children(holder, off)


static func _stretch_children(parent: Control, off: float) -> void:
	for c in parent.get_children():
		if not c is Control:
			continue
		if c.size.x >= DESIGN_W - 1.0:
			c.position.x -= off
			c.size.x += 2.0 * off
			for k in c.get_children():
				if k is Control:
					k.position.x += off
		_stretch_children(c, off)


static func parse(layout_name: String) -> Array:
	if _xml_cache.has(layout_name):
		return _xml_cache[layout_name]
	var p := XMLParser.new()
	var out := []
	if p.open(DIR + layout_name + ".xml") != OK:
		push_error("layout missing: " + layout_name)
		return out
	var stack: Array = []
	while p.read() == OK:
		match p.get_node_type():
			XMLParser.NODE_ELEMENT:
				if p.get_node_name() != "ElementNode":
					continue
				var attrs := {}
				for i in p.get_attribute_count():
					attrs[p.get_attribute_name(i)] = p.get_attribute_value(i)
				var node := {"type": attrs.get("type", ""), "id": attrs.get("elementID", ""), "attrs": attrs, "children": []}
				if stack.is_empty():
					out.append(node)
				else:
					stack.back().children.append(node)
				if not p.is_empty():
					stack.append(node)
			XMLParser.NODE_ELEMENT_END:
				if p.get_node_name() == "ElementNode" and not stack.is_empty():
					stack.pop_back()
	_xml_cache[layout_name] = out
	return out


const FALLBACK := {
	"9_frame_07.png": "9_frame_04.png", "9_frame_08.png": "9_Back_13.png", "92_back_23.png": "9_Back_13.png",
	"92_empty_02.png": "9_empty_02.png", "9_Back_14.png": "9_Back_13.png", "I_lock_01.png": "I_lock_03.png",
	"I2_lock_02.png": "I_lock_03.png", "I2_crystal_02.png": "I_crystal_01.png", "I_shadow_04.png": "I_shadow_03.png",
	"K_eventTag_01.png": "K0_eventTag_01.png",
}


static func image_path(image_name: String) -> String:
	if _paths.has(image_name):
		return _paths[image_name]
	if FALLBACK.has(image_name) and image_path_raw(image_name) == "":
		_paths[image_name] = image_path(FALLBACK[image_name])
		return _paths[image_name]
	_paths[image_name] = image_path_raw(image_name)
	return _paths[image_name]


static func image_path_raw(image_name: String) -> String:
	image_name = image_name.get_basename() + "." + image_name.get_extension().to_lower()
	var found := ""
	for d in IMAGE_DIRS:
		var p: String = UI.SPRITES + d + "/" + image_name
		if ResourceLoader.exists(p):
			found = p
			break
	if found == "" and ResourceLoader.exists("res://assets/apk/images/" + image_name):
		found = "res://assets/apk/images/" + image_name
	_paths[image_name] = found
	return found


static func texture(image_name: String) -> Texture2D:
	var p := image_path(image_name)
	return UI.tex(p) if p != "" else null


static func _vec(s: String) -> Vector2:
	var nums := _numbers(s)
	return Vector2(nums[0], nums[1]) if nums.size() >= 2 else Vector2.ZERO


static func _numbers(s: String) -> Array:
	var out := []
	for part in s.replace("{", " ").replace("}", " ").split(",", false):
		if part.strip_edges() != "":
			out.append(float(part))
	return out


static func color(s: String) -> Color:
	var n := _numbers(s)
	if n.size() < 3:
		return Color.WHITE
	return Color8(int(n[0]), int(n[1]), int(n[2]), int(n[3]) if n.size() > 3 else 255)


func _build(n: Dictionary, parent: Control, parent_h: float = SCREEN_H) -> void:
	var a: Dictionary = n.attrs
	var c: Control
	var size := Vector2.ZERO
	var tex := texture(a.get("imageName", "")) if a.has("imageName") else null
	match n.type:
		"Image":
			var r := TextureRect.new()
			r.texture = tex
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c = r
			size = tex.get_size() if tex else Vector2.ZERO
		"Button":
			var b := TextureButton.new()
			b.texture_normal = tex
			b.ignore_texture_size = true
			b.stretch_mode = TextureButton.STRETCH_SCALE
			_press_feedback(b)
			c = b
			size = tex.get_size() if tex else Vector2(40, 40)
		"NinePatch", "NinePatchButton":
			size = _vec(a.get("ninePatchSize", "{0,0}"))
			var np := NinePatchRect.new()
			np.texture = tex
			np.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if tex:
				var ins := _numbers(a.get("ninePatchInset", ""))
				if ins.size() == 4:
					var ts := tex.get_size()
					np.patch_margin_left = int(ins[0])
					np.patch_margin_top = int(ins[1])
					np.patch_margin_right = maxi(0, int(ts.x - ins[0] - ins[2]))
					np.patch_margin_bottom = maxi(0, int(ts.y - ins[1] - ins[3]))
			if n.type == "NinePatchButton":
				var btn := TextureButton.new()
				btn.add_child(np)
				np.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				_press_feedback(btn)
				c = btn
			else:
				c = np
		"Label":
			c = _label(a)
			size = Vector2(float(a.get("areaSizeX", 100)), float(a.get("areaSizeY", 30)))
		"ProgressBar":
			var pb := TextureProgressBar.new()
			pb.texture_progress = tex
			pb.value = float(a.get("value", 100))
			pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pb.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT if a.get("barDirection", "0") == "0" else TextureProgressBar.FILL_BOTTOM_TO_TOP
			c = pb
			size = tex.get_size() if tex else Vector2.ZERO
		_:
			c = Control.new()
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.name = n.id if n.id != "" else n.type
	var sc := Vector2(float(a.get("scaleX", 1)), float(a.get("scaleY", 1)))
	var anchor := Vector2(float(a.get("anchorX", 0)), float(a.get("anchorY", 0)))
	var pos := Vector2(float(a.get("positionX", 0)), float(a.get("positionY", 0)))
	c.size = size
	c.scale = sc
	c.position = Vector2(pos.x - anchor.x * size.x * sc.x, parent_h - (pos.y + (1.0 - anchor.y) * size.y * sc.y))
	c.set_meta("z", int(a.get("z", 0)))
	c.set_meta("layout_type", n.type)
	parent.add_child(c)
	if not nodes.has(n.id):
		nodes[n.id] = c
	all.append(c)
	for child in n.children:
		_build(child, c, size.y)
	_order_by_z(c)


static func _order_by_z(parent: Node) -> void:
	var kids: Array = parent.get_children().filter(func(k): return k.has_meta("z"))
	var any := false
	for k in kids:
		if int(k.get_meta("z")) != 0:
			any = true
			break
	if not any:
		return
	var sorted := kids.duplicate()
	var idx := {}
	for i in kids.size():
		idx[kids[i]] = i
	sorted.sort_custom(func(x, y): return int(x.get_meta("z")) < int(y.get_meta("z")) or (int(x.get_meta("z")) == int(y.get_meta("z")) and idx[x] < idx[y]))
	var start: int = kids[0].get_index()
	for i in sorted.size():
		parent.move_child(sorted[i], start + i)


func _label(a: Dictionary) -> Label:
	var l := Label.new()
	l.text = String(a.get("labelContent", "")).replace("\\n", "\n")
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = false
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT][clampi(int(a.get("alignment", 0)), 0, 2)]
	l.vertical_alignment = [VERTICAL_ALIGNMENT_TOP, VERTICAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM][clampi(int(a.get("lineAlignment", 0)), 0, 2)]
	if a.get("fontStyle", "1") == "0":
		l.add_theme_font_override("font", load(FONT_REGULAR))
	l.add_theme_font_size_override("font_size", int(a.get("fontSize", 20)))
	l.add_theme_color_override("font_color", color(a.get("fontColor", "{255,255,255}")))
	var fx := int(a.get("effect", 0))
	var fx_color := color(a.get("effectColor", "{0,0,0}"))
	l.add_theme_constant_override("outline_size", 0)
	if fx == 1:
		l.add_theme_constant_override("outline_size", 4)
		l.add_theme_color_override("font_outline_color", fx_color)
	elif fx == 2:
		var off := float(a.get("effectOffset", 2))
		l.add_theme_color_override("font_shadow_color", fx_color)
		l.add_theme_constant_override("shadow_offset_x", int(off))
		l.add_theme_constant_override("shadow_offset_y", int(off))
		l.add_theme_constant_override("shadow_outline_size", 1)
	return l


static func _press_feedback(b: BaseButton) -> void:
	b.button_down.connect(func(): b.modulate = Color(0.75, 0.75, 0.75))
	b.button_up.connect(func(): b.modulate = Color.WHITE)
	b.pressed.connect(func(): Sfx.play(b.get_meta("sfx", "click")))


static func instance(layout_name: String) -> Layout:
	var tree: Array = parse(layout_name)
	var size := Vector2.ZERO
	if not tree.is_empty():
		var a: Dictionary = tree[0].attrs
		size = _vec(a.get("ninePatchSize", "{0,0}"))
		if size == Vector2.ZERO:
			var t := texture(a.get("imageName", ""))
			size = t.get_size() if t else Vector2.ZERO
	var box := Control.new()
	box.custom_minimum_size = size
	box.size = size
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var lay := Layout.new()
	for n in tree:
		lay._build(n, box, size.y)
	_order_by_z(box)
	lay.root = box
	return lay


func list_into(id: String, items: Array, separation: int = 4) -> VBoxContainer:
	return list_into_node(nodes.get(id), items, separation)


static func list_into_node(holder: Control, items: Array, separation: int = 4) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	if holder == null:
		return v
	var keep := 0
	for c in holder.get_children():
		if c.has_meta("list"):
			keep = maxi(keep, (c as ScrollContainer).scroll_vertical)
			c.queue_free()
	var scroll := ScrollContainer.new()
	if keep > 0 and holder.is_inside_tree():
		scroll.modulate.a = 0.0
		holder.get_tree().process_frame.connect(func():
			if is_instance_valid(scroll):
				scroll.scroll_vertical = keep
				scroll.modulate.a = 1.0, CONNECT_ONE_SHOT)
	scroll.set_meta("list", true)
	scroll.size = holder.size + Vector2(14, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)
	scroll.add_child(v)
	for it in items:
		v.add_child(it)
	for c in holder.get_parent().get_children():
		if String(c.name).begins_with("ID_slide"):
			c.visible = false
	return v


func select_tab(ids: Array, selected: String) -> void:
	sound(ids, "tab")
	for id in ids:
		var b: Control = nodes.get(id)
		if b == null:
			continue
		for np in b.get_children():
			if np is NinePatchRect and np.texture:
				var p: String = np.texture.resource_path
				var want: String = p.replace("_d.png", "_n.png") if id != selected else p.replace("_n.png", "_d.png")
				if want != p and ResourceLoader.exists(want):
					np.texture = UI.tex(want)


const CUBE_ICONS := {"blue": "I_cube_02.png", "yellow": "I_cubeR_02.png", "red": "I_cubeA_02.png", "black": "I_cubeBS_02.png", "honour": "I_cubeS2_02.png", "honour5": "I_cubeS_02.png"}


static func reward_icon(r: Dictionary, done: bool = false) -> Control:
	var lay := instance("B_rewardIcon")
	var kinds := {"gold": ["ID_gold", "ID_textGold"], "gems": ["ID_crystal", "ID_textCrystal"], "energy": ["ID_energy", "ID_textEnergy"], "honor": ["ID_honor", "ID_textHonor"], "fp": ["ID_fPoint", "ID_textFPoint"]}
	var shown := ""
	for k in ["cube", "gems", "energy", "honor", "fp", "gold"]:
		if r.has(k) and (k == "cube" or int(r[k]) > 0):
			shown = k
			break
	for k in kinds:
		lay.show(kinds[k][0], k == shown)
		if k == shown:
			lay.text(kinds[k][1], "×" + Screen._thousands(int(r[k])))
	for c in ["ID_cube", "ID_cubeA", "ID_cubeBS", "ID_cubeR", "ID_cubeS", "ID_cubeS2", "ID_qMon", "ID_markQ"]:
		lay.show(c, false)
	if shown == "cube":
		lay.show("ID_cube")
		lay.set_image("ID_imgCube", texture(CUBE_ICONS.get(String(r.cube), "I_cube_02.png")))
	elif shown == "" and r.has("monster"):
		lay.show("ID_qMon")
		lay.text("ID_textMon", "")
		var frame := lay.node("ID_monFrame")
		var card := UI.monster_card(String(r.monster), 0, 0, frame.size)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(card)
	lay.text("ID_textDone", "")
	lay.show("ID_rewardGet", done)
	return lay.root


func node(id: String) -> Control:
	return nodes.get(id)


func has(id: String) -> bool:
	return nodes.has(id)


func nodes_named(id: String) -> Array:
	return all.filter(func(c): return c.name == id or String(c.name).begins_with(id + "@"))


func on(id: String, cb: Callable) -> BaseButton:
	var b := nodes.get(id) as BaseButton
	if b:
		b.pressed.connect(cb)
	else:
		push_warning("layout: no button " + id)
	return b


func sound(ids: Array, sfx: String) -> void:
	for id in ids:
		if nodes.has(id):
			nodes[id].set_meta("sfx", sfx)


func text(id: String, value: String) -> Label:
	var l := nodes.get(id) as Label
	if l:
		l.text = value
	return l


func show(id: String, visible: bool = true) -> void:
	var c: Control = nodes.get(id)
	if c:
		c.visible = visible


func hide_all(ids: Array) -> void:
	for id in ids:
		show(id, false)


func set_image(id: String, tex: Texture2D) -> void:
	var c: Control = nodes.get(id)
	if c is TextureRect:
		c.texture = tex
	elif c is TextureButton:
		c.texture_normal = tex
	elif c is NinePatchRect:
		c.texture = tex


func put(id: String, child: Control, fill_size: Vector2 = Vector2.ZERO) -> Control:
	var holder: Control = nodes.get(id)
	if holder == null:
		return child
	holder.add_child(child)
	if fill_size != Vector2.ZERO:
		child.size = fill_size
	return child
