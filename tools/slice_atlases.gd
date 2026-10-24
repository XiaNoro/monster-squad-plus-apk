# Slices the APK's TexturePacker (format 2) .plist atlases into individual PNGs.
# Run: godot --headless --path <project> --script res://tools/slice_atlases.gd
extends SceneTree

const SRC_DIR := "res://research/apk_assets"
const OUT_DIR := "res://assets/apk/sprites"


func _init() -> void:
	var entry_rx := RegEx.create_from_string("(?s)<key>([^<]+)</key>\\s*<dict>(.*?)</dict>")
	var atlases := 0
	var frames := 0
	for file in DirAccess.get_files_at(SRC_DIR):
		if not file.ends_with(".plist"):
			continue
		var text := FileAccess.get_file_as_string(SRC_DIR.path_join(file))
		var frames_at := text.find("<key>frames</key>")
		if frames_at < 0:
			continue
		var meta_at := text.find("<key>metadata</key>")
		var tex_name := _string_value(text.substr(maxi(meta_at, 0)), "textureFileName")
		if tex_name == "":
			tex_name = file.get_basename() + ".png"
		var atlas := Image.load_from_file(ProjectSettings.globalize_path(SRC_DIR.path_join(tex_name)))
		if atlas == null:
			push_warning("missing texture for " + file)
			continue
		atlas.convert(Image.FORMAT_RGBA8)

		var out_dir := OUT_DIR.path_join(file.get_basename())
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
		var body := text.substr(frames_at, (meta_at if meta_at > 0 else text.length()) - frames_at)
		# Skip the outer "<key>frames</key><dict>" so entries match frame by frame.
		body = body.substr(body.find("<dict>") + 6)
		for m in entry_rx.search_all(body):
			var name := m.get_string(1)
			var props := m.get_string(2)
			var r := _rect(_string_value(props, "frame"))
			var rotated := _bool_value(props, "rotated")
			var src_rect := _rect(_string_value(props, "sourceColorRect"))
			var src_size := _vec(_string_value(props, "sourceSize"))
			# Rotated frames are stored turned 90° clockwise, with w/h swapped in the atlas.
			var region := Rect2i(r.position, Vector2i(r.size.y, r.size.x) if rotated else r.size)
			var piece := atlas.get_region(region)
			if rotated:
				piece.rotate_90(COUNTERCLOCKWISE)
			if src_size.x > 0 and src_size != piece.get_size():
				var full := Image.create_empty(src_size.x, src_size.y, false, Image.FORMAT_RGBA8)
				full.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), src_rect.position)
				piece = full
			piece.save_png(ProjectSettings.globalize_path(out_dir.path_join(name.get_basename() + ".png")))
			frames += 1
		atlases += 1
	print("atlases: %d, frames: %d" % [atlases, frames])
	quit()


func _string_value(props: String, key: String) -> String:
	var m := RegEx.create_from_string("<key>" + key + "</key>\\s*<string>([^<]*)</string>").search(props)
	return m.get_string(1) if m else ""


func _bool_value(props: String, key: String) -> bool:
	var m := RegEx.create_from_string("<key>" + key + "</key>\\s*<(true|false)\\s*/>").search(props)
	return m != null and m.get_string(1) == "true"


func _rect(s: String) -> Rect2i:
	var n := _nums(s)
	return Rect2i(n[0], n[1], n[2], n[3]) if n.size() >= 4 else Rect2i()


func _vec(s: String) -> Vector2i:
	var n := _nums(s)
	return Vector2i(n[0], n[1]) if n.size() >= 2 else Vector2i.ZERO


func _nums(s: String) -> Array:
	var out := []
	for m in RegEx.create_from_string("-?\\d+").search_all(s):
		out.append(int(m.get_string()))
	return out
