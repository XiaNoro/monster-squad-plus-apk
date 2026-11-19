class_name Preloader
extends RefCounted

static var _waiting: Dictionary = {}
static var _held: Dictionary = {}


static func request(paths: Array) -> void:
	for p in paths:
		var path := String(p)
		if path == "" or _held.has(path) or _waiting.has(path) or ResourceLoader.has_cached(path):
			continue
		if ResourceLoader.load_threaded_request(path, "", true) == OK:
			_waiting[path] = true


static func pending() -> int:
	for path in _waiting.keys():
		match ResourceLoader.load_threaded_get_status(path):
			ResourceLoader.THREAD_LOAD_LOADED:
				_held[path] = ResourceLoader.load_threaded_get(path)
				_waiting.erase(path)
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_waiting.erase(path)
	return _waiting.size()


static func left(paths: Array) -> int:
	pending()
	return paths.filter(func(p): return _waiting.has(String(p))).size()


static func wait(tree: SceneTree, limit: float) -> void:
	var end := Time.get_ticks_msec() + int(limit * 1000.0)
	while pending() > 0 and Time.get_ticks_msec() < end:
		await tree.process_frame


static func monster_paths(ids: Array, sprites: bool) -> Array:
	var out := []
	for id in ids:
		var icon := DB.icon_path(String(id))
		if icon != "":
			out.append(icon)
		if sprites or icon == "":
			out.append_array(DB.sprite_paths(String(id)))
	return out
