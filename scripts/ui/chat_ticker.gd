class_name ChatTicker
extends Control

const REAL_NAMES := ["MutsiMutso", "P155monkey", "gatul", "jtindall", "PapaLumba", "XiaNoro", "Fangz", "MKEscortYT", "Alejandro"]
const SOURCES := ["from the Store", "from the Store", "from Cube", "from the Mystery Box"]
const MARGIN := 24.0
const SKIP_SCREENS := ["battle", "title", "starter", "layout"]

var main: Main
var _rng := RandomNumberGenerator.new()
var _timer: Timer
var _pool: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 100
	set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_schedule()


func _schedule() -> void:
	_timer.start(_rng.randf_range(25.0, 70.0))


func _tick() -> void:
	_schedule()
	if main == null or main.current == null or main.current_name in SKIP_SCREENS:
		return
	if (main.current as Screen).tutorial_active() or "--test-script" in " ".join(OS.get_cmdline_user_args()):
		return
	show_message()


func _pick(stars: int) -> String:
	if not _pool.has(stars):
		_pool[stars] = DB.ids_where(func(m): return int(m.stars) == stars and not m.material and m.skills.size() >= 1)
	var ids: Array = _pool[stars]
	return String(ids[_rng.randi() % ids.size()]) if not ids.is_empty() else ""


func _player_name() -> String:
	if _rng.randf() < 0.35:
		return REAL_NAMES[_rng.randi() % REAL_NAMES.size()]
	var n := ""
	for i in _rng.randi_range(2, 3):
		n += Arena.SYLLABLES[_rng.randi() % Arena.SYLLABLES.size()]
	return n.capitalize().replace(" ", "") + (str(_rng.randi_range(1, 999)) if _rng.randf() < 0.5 else "")


func show_message(who: String = "", id: String = "", source: String = "") -> void:
	var stars := 6 if _rng.randf() < 0.3 else 5
	if id == "":
		id = _pick(stars)
	if id == "":
		return
	stars = int(DB.monster(id).get("stars", stars))
	if who == "":
		who = _player_name()
	if source == "":
		source = SOURCES[_rng.randi() % SOURCES.size()]
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.04, 0.78)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	bar.add_theme_stylebox_override("panel", sb)
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_child(row)
	row.add_child(_text("%s Obtained" % who))
	var pill := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("5fb43a")
	ps.border_color = Color("a8e07a")
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(16)
	ps.content_margin_left = 12
	ps.content_margin_right = 12
	ps.content_margin_top = 1
	ps.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", ps)
	pill.mouse_filter = MOUSE_FILTER_IGNORE
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 22)
	inner.mouse_filter = MOUSE_FILTER_IGNORE
	pill.add_child(inner)
	var nm := _text(String(DB.monster(id).name))
	nm.add_theme_color_override("font_color", Color("1d3a10"))
	inner.add_child(nm)
	var st := _text("★%d" % stars)
	st.add_theme_color_override("font_color", Color("1d3a10"))
	inner.add_child(st)
	row.add_child(pill)
	row.add_child(_text(source))
	bar.modulate.a = 0.0
	add_child(bar)
	await get_tree().process_frame
	bar.position = Vector2(get_viewport_rect().size.x - bar.size.x - MARGIN, -bar.size.y)
	var tw := bar.create_tween()
	tw.set_parallel()
	tw.tween_property(bar, "position:y", 64.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(bar, "modulate:a", 1.0, 0.3)
	tw.chain().tween_interval(4.5)
	tw.chain().tween_property(bar, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(bar.queue_free)


func _text(s: String) -> Label:
	var l := UI.label(s, 20, Color.WHITE)
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	return l
