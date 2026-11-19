class_name Main
extends Control

const SCREENS := {
	"title": "res://scripts/ui/screens/title_screen.gd",
	"starter": "res://scripts/ui/screens/starter_screen.gd",
	"hub": "res://scripts/ui/screens/hub_screen.gd",
	"islands": "res://scripts/ui/screens/islands_screen.gd",
	"squad": "res://scripts/ui/screens/squad_screen.gd",
	"cubes": "res://scripts/ui/screens/cubes_screen.gd",
	"book": "res://scripts/ui/screens/book_screen.gd",
	"battle": "res://scripts/ui/screens/battle_screen.gd",
	"tower": "res://scripts/ui/screens/tower_screen.gd",
	"stones": "res://scripts/ui/screens/stones_screen.gd",
	"pets": "res://scripts/ui/screens/pets_screen.gd",
	"raid": "res://scripts/ui/screens/raid_screen.gd",
	"arena": "res://scripts/ui/screens/arena_screen.gd",
	"missions": "res://scripts/ui/screens/missions_screen.gd",
	"league": "res://scripts/ui/screens/league_screen.gd",
	"layout": "res://scripts/ui/screens/layout_view.gd",
	"ready": "res://scripts/ui/screens/ready_screen.gd",
	"friends": "res://scripts/ui/screens/friends_screen.gd",
	"combine": "res://scripts/ui/screens/combine_screen.gd",
	"visit": "res://scripts/ui/screens/visit_screen.gd",
	"badges": "res://scripts/ui/screens/badges_screen.gd",
}

var current: Control
var current_name := ""
var current_args: Dictionary = {}
var dev_menu: DevMenu
var ticker: ChatTicker


func _ready() -> void:
	theme = UI.get_theme()
	_fit_window()
	get_window().size_changed.connect(_fit_window)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	get_tree().node_added.connect(_on_node_added)
	if not OS.has_feature("mobile"):
		dev_menu = DevMenu.new()
		dev_menu.main = self
		add_child(dev_menu)
	ticker = ChatTicker.new()
	ticker.main = self
	add_child(ticker)
	_resize_timer = Timer.new()
	_resize_timer.one_shot = true
	_resize_timer.wait_time = 0.25
	_resize_timer.timeout.connect(_relayout)
	add_child(_resize_timer)
	_built_width = get_viewport_rect().size.x
	get_viewport().size_changed.connect(_resize_timer.start)
	var start := "title"
	var start_args := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screen="):
			start = arg.trim_prefix("--screen=")
		if arg == "--test-save":
			Save.save_path = "user://test_save.json"
			Save.reset()
			var team := []
			for id in ["firepaw", "dripbal", "leavbal", "pufbal"]:
				team.append(int(Save.add_monster(id, 5).uid))
			Save.set_team(team)
		if arg == "--test-newgame":
			Save.save_path = "user://test_save.json"
			Save.start_new_game()
		if arg == "--test-continue":
			Save.save_path = "user://test_save.json"
			Save.load_game()
		if arg.begins_with("--test-cleared="):
			var cp := arg.trim_prefix("--test-cleared=").split(":")
			Save.data.progress[cp[0]] = {"normal": int(cp[1])}
		if arg.begins_with("--test-tutdone="):
			for cid in arg.trim_prefix("--test-tutdone=").split(","):
				Tutorial.mark_done(cid)
		if arg.begins_with("--test-team="):
			var team := []
			for id in arg.trim_prefix("--test-team=").split(","):
				team.append(int(Save.add_monster(id, 5).uid))
			Save.set_team(team)
		if arg.begins_with("--test-level="):
			for m in Save.team_members():
				m.level = int(arg.trim_prefix("--test-level="))
		if arg == "--test-auto":
			Save.data.auto = true
			Save.data.speed = 2
		if arg == "--test-repeat":
			Save.data.auto = true
			Save.data.auto_repeat = true
		if arg.begins_with("--test-tower="):
			Save.data.tower_floor = maxi(int(Save.data.tower_floor), int(arg.trim_prefix("--test-tower=")) - 1)
			start = "battle"
			start_args = {"quest": SkyTower.floor_quest(int(arg.trim_prefix("--test-tower=")))}
		if arg.begins_with("--test-raid="):
			var parts := arg.trim_prefix("--test-raid=").split(":")
			var pool := DB.ids_where(func(d): return int(d.stars) >= 5 and not d.material)
			for i in 25:
				var m := Save.add_monster(pool[(i * 37) % pool.size()], 30)
				m.boost = 5
			var picked := []
			for m in Save.data.monsters.slice(Save.data.monsters.size() - Raids.PICK):
				picked.append(int(m.uid))
			Save.data.raid = {}
			Save.start_raid(parts[0], picked)
			Save.data.raid.room = int(parts[1])
			start = "battle"
			start_args = {"quest": Raids.room_quest(Raids.raid(parts[0]), int(parts[1])), "party": picked.slice(0, Raids.PARTY)}
		if arg.begins_with("--test-arena="):
			var rv: Dictionary = Arena.rivals(Arena.week_id())[int(arg.trim_prefix("--test-arena="))]
			start = "battle"
			start_args = {"quest": ArenaScreen.arena_quest(rv, Arena.power_of(Save.team_members()))}
		if arg == "--test-league":
			var lpool := DB.ids_where(func(d): return int(d.stars) >= 5 and not d.material)
			var luids := []
			for i in 12:
				var lm := Save.add_monster(lpool[(i * 53) % lpool.size()], 30)
				lm.boost = 5
				luids.append(int(lm.uid))
			Save.league().team = luids
			var lr: Dictionary = Arena.rivals(Arena.week_id() + 7777)[5]
			var mine := LeagueScreen.league_specs(luids)
			var theirs := LeagueScreen.rival_league_team(lr, Arena.power_of(LeagueScreen._owned(luids)) / 3.0)
			start = "battle"
			start_args = {"quest": {"kind": "league", "key": "league", "title": "PvP League test", "rival_name": lr.name, "rival_skill": float(lr.skill), "energy": 0, "level": 30, "boss": theirs[0].id, "enemies": [], "stages": 1, "gold": 0.0, "exp": 0.0, "drops": false, "boss_drop_chance": 0.0, "drop_level": [1, 1], "first_clear_drop": false, "pvp": true, "league_team": mine, "league_enemy": theirs}}
		if arg.begins_with("--layout="):
			start = "layout"
			start_args = {"xml": arg.trim_prefix("--layout=")}
		if arg == "--test-stones":
			for st in [{"type": "bravery", "rank": 0}, {"type": "bravery", "rank": 0}, {"type": "vitality", "rank": 3, "variant": 2}, {"type": "time", "rank": 4, "variant": 1}]:
				Save.add_stone(st)
		if arg.begins_with("--test-special="):
			var parts := arg.trim_prefix("--test-special=").split(":")
			start = "battle"
			start_args = {"quest": StageBuilder.special_quest(DB.special(parts[0]), int(parts[1]))}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-args="):
			var parsed = JSON.parse_string(arg.trim_prefix("--test-args="))
			if parsed is Dictionary:
				start_args = parsed
		if arg.begins_with("--arg="):
			var kv := arg.trim_prefix("--arg=").split(":", true, 1)
			if kv.size() == 2:
				start_args[kv[0]] = kv[1]
	go(start, start_args)
	if "--test-tutauto" in OS.get_cmdline_user_args():
		var bot: Node = load("res://scripts/ui/autoplay.gd").new()
		bot.main = self
		add_child(bot)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-reveal="):
			CubeReveal.play(current, "blue", [arg.trim_prefix("--test-reveal=")], [true], [{"text": "Next Field", "color": "blue"}, {"text": "Again", "color": "green"}, {"text": "Leave", "color": "orange"}])
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-script="):
			var probe: Node = load(arg.trim_prefix("--test-script=")).new()
			add_child(probe)
	if "--dev-menu" in OS.get_cmdline_user_args() and dev_menu != null:
		dev_menu.open()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_screenshot_and_quit(arg.trim_prefix("--shot="))


func _screenshot_and_quit(spec: String) -> void:
	var parts := spec.split("@")
	var delay := float(parts[1]) if parts.size() > 1 else 2.0
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(parts[0])
	get_tree().quit()


const CLOSE_BUTTON := "^ID_(btn|BUTTON_?)(Esc|Cancel|No|Close)(_\\d+)?$"
const OK_BUTTON := "^ID_btnOk(_\\d+)?$"


func _on_node_added(n: Node) -> void:
	if n is ScrollContainer:
		var sc := n as ScrollContainer
		sc.scroll_deadzone = 16
		if sc.mouse_filter == MOUSE_FILTER_PASS:
			sc.mouse_filter = MOUSE_FILTER_STOP
	elif n is Control:
		_let_scroll.call_deferred(n)


func _let_scroll(n: Variant) -> void:
	if not is_instance_valid(n) or not n is Control:
		return
	var c := n as Control
	if c.mouse_filter != MOUSE_FILTER_STOP:
		return
	var p := c.get_parent()
	while p != null and p != self:
		if p is ScrollContainer:
			c.mouse_filter = MOUSE_FILTER_PASS
			return
		p = p.get_parent()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()


func _unhandled_key_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		back()


func back() -> void:
	if is_instance_valid(_busy):
		return
	if dev_menu != null and dev_menu.visible:
		dev_menu.close()
		return
	if current == null or not current is Screen or (current as Screen).tutorial_active():
		return
	var top: Control = null
	var top_z := 43
	for c in current.find_children("*", "Control", true, false):
		if c is Label or not (c as Control).is_visible_in_tree():
			continue
		if (c as Control).z_index >= top_z:
			top_z = (c as Control).z_index
			top = c
	if top != null:
		for pat in [CLOSE_BUTTON, OK_BUTTON]:
			var b := _find_button(top, pat)
			if b != null:
				b.pressed.emit()
				return
		return
	if current_name == "battle":
		var pause := _find_button(current, "^ID_BUTTON_PAUSE$")
		if pause != null:
			pause.pressed.emit()
		return
	var back_btn := _find_button(current, "^ID_btnBack")
	if back_btn != null:
		back_btn.pressed.emit()


func _find_button(root: Node, pattern: String) -> BaseButton:
	var re := RegEx.create_from_string(pattern)
	var found: BaseButton = null
	for b in root.find_children("*", "BaseButton", true, false):
		if re.search(String(b.name)) != null and (b as BaseButton).is_visible_in_tree() and not (b as BaseButton).disabled:
			found = b
	return found


var _resize_timer: Timer
var _built_width := 0.0


func _fit_window() -> void:
	var win := Vector2(get_window().size)
	if win.y <= 0.0:
		return
	var aspect := win.x / win.y
	var want := Vector2i(roundi(maxf(Layout.DESIGN_W, Layout.SCREEN_H * aspect / Layout.WIDEN)), int(Layout.SCREEN_H))
	var mode := Window.CONTENT_SCALE_ASPECT_IGNORE if aspect >= Layout.DESIGN_W / Layout.SCREEN_H else Window.CONTENT_SCALE_ASPECT_EXPAND
	if get_window().content_scale_size != want or get_window().content_scale_aspect != mode:
		get_window().content_scale_size = want
		get_window().content_scale_aspect = mode


func _relayout() -> void:
	var w := get_viewport_rect().size.x
	if absf(w - _built_width) < 1.0:
		return
	if current == null or current_name == "battle" or (current as Screen).tutorial_active():
		_resize_timer.start()
		return
	go(current_name, current_args)


const SLIDE_TIME := 0.2
const BUSY_DIM := 0.5
const BUSY_TURN := 0.9
const NO_SLIDE := ["battle", "title", "layout"]

var _history: Array = []
var _busy: Control


func busy(seconds: float, linger: float = 0.0) -> void:
	if is_instance_valid(_busy):
		_busy.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, BUSY_DIM)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 95
	var sp := TextureRect.new()
	sp.texture = UI.tex("betaUI00/I_indicator_01.png")
	sp.size = sp.texture.get_size()
	sp.pivot_offset = sp.size / 2.0
	sp.position = (size - sp.size) / 2.0
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(sp)
	add_child(dim)
	create_tween().bind_node(sp).set_loops().tween_property(sp, "rotation", TAU, BUSY_TURN).from(0.0)
	_busy = dim
	await get_tree().create_timer(seconds).timeout
	if not is_instance_valid(dim):
		return
	if linger > 0.0:
		get_tree().create_timer(linger).timeout.connect(dim.queue_free)
	else:
		dim.queue_free()


static func _deep(screen: String, a: Dictionary) -> bool:
	return screen == "islands" and (String(a.get("island", "")) != "" or String(a.get("special", "")) != "")


func go(screen: String, args: Dictionary = {}) -> void:
	var old := current
	var old_name := current_name
	var back := _history.has(screen)
	var same := screen == old_name and _deep(screen, args) == _deep(old_name, current_args)
	if screen == old_name and not same:
		back = _deep(old_name, current_args)
	if back:
		_history = _history.slice(0, _history.find(screen) + 1)
	else:
		_history.append(screen)
	if _history.size() > 12:
		_history = _history.slice(_history.size() - 12)
	current_name = screen
	current_args = args
	_built_width = get_viewport_rect().size.x
	var script: GDScript = load(SCREENS[screen])
	var s: Screen = script.new()
	s.main = self
	s.args = args
	current = s
	if not screen in ["title", "battle"]:
		Sfx.play_music("lobby")
	add_child(s)
	LevelReward.show_pending.call_deferred(s, screen)
	if old == null:
		return
	if same or NO_SLIDE.has(screen) or NO_SLIDE.has(old_name):
		old.queue_free()
		return
	old.process_mode = Node.PROCESS_MODE_DISABLED
	var from := -size.x if back else size.x
	var bar: Control = s.top.root if s.top != null else null
	var bar_x := bar.position.x if bar != null else 0.0
	if bar != null and old is Screen and (old as Screen).top != null:
		(old as Screen).top.root.visible = false
	var screen_id := s.get_instance_id()
	var bar_id := bar.get_instance_id() if bar != null else 0
	var slide := func(x: float):
		var page := instance_from_id(screen_id) as Control
		if page == null:
			return
		page.position.x = x
		if bar_id == 0:
			return
		var top_bar := instance_from_id(bar_id) as Control
		if top_bar != null:
			top_bar.position.x = bar_x - x
	slide.call(from)
	var tw := create_tween().set_parallel()
	tw.tween_method(slide, from, 0.0, SLIDE_TIME)
	tw.tween_property(old, "position:x", -from, SLIDE_TIME)
	tw.chain().tween_callback(old.queue_free)
