class_name FrameFx
extends TextureRect

const ROOT := "res://assets/apk/sprites/"

static var _cache: Dictionary = {}

var _frames: Array = []
var _fps := 30.0
var _t := 0.0
var loop := false
var _anchor: Control
var _anchor_at := Vector2.ZERO


static func frames(sheet: String) -> Array:
	if not _cache.has(sheet):
		var list := []
		for p in paths(sheet):
			list.append(load(p))
		_cache[sheet] = list
	return _cache[sheet]


static func paths(sheet: String) -> Array:
	var list := []
	if _cache.has(sheet):
		return list
	var i := 0
	while ResourceLoader.exists(ROOT + "%s/%s_%03d.png" % [sheet, sheet, i]):
		list.append(ROOT + "%s/%s_%03d.png" % [sheet, sheet, i])
		i += 1
	return list


static func play(parent: Node, sheet: String, center: Vector2, box: Vector2, fps: float = 30.0) -> FrameFx:
	var list := frames(sheet)
	if list.is_empty():
		return null
	var fx := FrameFx.new()
	fx._frames = list
	fx._fps = fps
	fx.expand_mode = EXPAND_IGNORE_SIZE
	fx.stretch_mode = STRETCH_KEEP_ASPECT_CENTERED
	fx.mouse_filter = MOUSE_FILTER_IGNORE
	fx.texture = list[0]
	fx.size = box
	fx.position = center - box / 2.0
	fx.z_index = 18
	parent.add_child(fx)
	return fx


func follow(v: Control) -> void:
	if is_instance_valid(v):
		_anchor = v
		_anchor_at = v.position
		v.item_rect_changed.connect(_track)


func _track() -> void:
	if is_instance_valid(_anchor):
		position += _anchor.position - _anchor_at
		_anchor_at = _anchor.position


func _process(delta: float) -> void:
	_t += delta
	var k := int(_t * _fps)
	if k >= _frames.size():
		if loop:
			_t = 0.0
			k = 0
		else:
			queue_free()
			return
	texture = _frames[k]
