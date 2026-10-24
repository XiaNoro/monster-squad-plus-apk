class_name FrameFx
extends TextureRect

const ROOT := "res://assets/apk/sprites/"

static var _cache: Dictionary = {}

var _frames: Array = []
var _fps := 30.0
var _t := 0.0
var loop := false


static func frames(sheet: String) -> Array:
	if not _cache.has(sheet):
		var list := []
		var i := 0
		while ResourceLoader.exists(ROOT + "%s/%s_%03d.png" % [sheet, sheet, i]):
			list.append(load(ROOT + "%s/%s_%03d.png" % [sheet, sheet, i]))
			i += 1
		_cache[sheet] = list
	return _cache[sheet]


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
