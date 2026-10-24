class_name DevMenu
extends CanvasLayer

const MAX_RESULTS := 48
const TABS := ["Resources", "Progress", "Battle", "Monsters"]
const TAB_COLORS := {"Resources": "yellow", "Progress": "orange", "Battle": "purple", "Monsters": "green"}
const INK := Color("6b4420")

var main: Main
var _panel: Control
var _search: LineEdit
var _results: GridContainer
var _level: SpinBox
var _boost: SpinBox
var _status: Label
var _dirty := false
var _remove_btn: Button
var _remove_armed := false
var _tab := "Resources"
var _pages := {}
var _tab_buttons := {}
var _refreshers: Array[Callable] = []


func _ready() -> void:
	layer = 100
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_panel = PanelContainer.new()
	_panel.theme = UI.get_theme()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 36
	_panel.offset_right = -36
	_panel.offset_top = 22
	_panel.offset_bottom = -22
	_panel.add_theme_stylebox_override("panel", UI._box("betaUI00/9_Back_01.png", 40, 26))
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	var title := UI.label("Dev Menu", 30, UI.GOLD)
	title.add_theme_color_override("font_outline_color", Color("6a2a00"))
	title.add_theme_constant_override("outline_size", 8)
	head.add_child(title)
	var hint := _ink("F1 to toggle", 16)
	hint.modulate.a = 0.7
	head.add_child(hint)
	_status = _ink("", 18)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.clip_text = true
	head.add_child(_status)
	head.add_child(UI.button("Close", close, "blue", Vector2(120, 50), 20))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	for t in TABS:
		var b := UI.button(t, _show_tab.bind(t), TAB_COLORS[t], Vector2(170, 52), 20)
		tabs.add_child(b)
		_tab_buttons[t] = b

	var body := PanelContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_stylebox_override("panel", UI._box("betaUI00/9_Back_02.png", 15, 22))
	v.add_child(body)
	_pages["Resources"] = _resources_page()
	_pages["Progress"] = _progress_page()
	_pages["Battle"] = _battle_page()
	_pages["Monsters"] = _monsters_page()
	for t in TABS:
		var page: Control = _pages[t]
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if t == "Monsters":
			body.add_child(page)
			continue
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.add_child(page)
		body.add_child(scroll)
		_pages[t] = scroll
	_show_tab(_tab)


func _ink(text: String, size: int) -> Label:
	var l := UI.label(text, size, INK)
	l.add_theme_constant_override("outline_size", 0)
	return l


func _section(parent: Container, title: String) -> HFlowContainer:
	parent.add_child(_ink(title, 22))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	parent.add_child(flow)
	return flow


func _page() -> VBoxContainer:
	var p := VBoxContainer.new()
	p.add_theme_constant_override("separation", 10)
	return p


func _btn(parent: Container, text: String, cb: Callable, color: String, w: float = 190) -> Button:
	var b := UI.button(text, cb, color, Vector2(w, 52), 18)
	parent.add_child(b)
	return b


func _resources_page() -> Control:
	var p := _page()
	var cur := _section(p, "Currency")
	for spec in [["+10k Gold", "gold", 10000], ["+1M Gold", "gold", 1000000], ["+100 Gems", "gems", 100], ["+10k Gems", "gems", 10000], ["+500 Honour", "honor", 500], ["+200 FP", "fp", 200]]:
		_btn(cur, spec[0], _give.bind(spec[1], spec[2]), "yellow", 170)
	var items := _section(p, "Items & Limits")
	_btn(items, "Fill Energy", _give.bind("energy", 0), "green")
	_btn(items, "Refill tickets", _refill_tickets, "orange")
	_btn(items, "Give keys", _give_keys, "orange")
	_btn(items, "Box +100 slots", _give.bind("box", 100), "orange")
	_btn(items, "All Magic Stones", _all_stones, "purple", 220)
	var cubes := _section(p, "Open 10 Cubes (free)")
	for spec in [["Blue ×10", "blue", "blue"], ["Yellow ×10", "yellow", "yellow"], ["Red ×10", "red", "orange"], ["Honour ×10", "honor", "yellow"], ["Pet Egg ×10", "pet", "green"], ["Rare Egg ×10", "pet_rare", "purple"]]:
		_btn(cubes, spec[0], _open_cubes.bind(spec[1]), spec[2], 170)
	return p


func _open_cubes(key: String) -> void:
	visible = false
	_dirty = false
	main.go("cubes", {"tab": "cube", "dev_open": key})


func _progress_page() -> Control:
	var p := _page()
	var prog := _section(p, "Story & Tutorial")
	_btn(prog, "Unlock all islands", _unlock_islands, "orange", 230)
	_btn(prog, "Skip tutorial", _tut.bind(false), "blue")
	_btn(prog, "Replay tutorial", _tut.bind(true), "blue")
	var ev := _section(p, "Events")
	_btn(ev, "Next event day", _event_shift.bind("day"), "green", 210)
	_btn(ev, "Next event week", _event_shift.bind("week"), "green", 220)
	_btn(ev, "Real date", _event_shift.bind("reset"), "blue", 160)
	var msg := _section(p, "Messages")
	_btn(msg, "Send test mail", _test_mail, "purple", 210)
	_btn(msg, "Random message", func():
		close()
		main.ticker.show_message(), "purple", 210)
	return p


func _battle_page() -> Control:
	var p := _page()
	p.add_child(_ink("Battle testing  ·  changes apply to the current battle too", 22))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 50)
	grid.add_theme_constant_override("v_separation", 18)
	p.add_child(grid)
	_switch(grid, "Endless battles", "Your team can't die, no time limit, waves loop forever", "dev_endless", "endless")
	_switch(grid, "Immortal enemies", "Enemies refill instead of dying — same wave forever", "dev_immortal_enemies", "immortal_enemies")
	_switch(grid, "Infinite MP", "Leader skills are always ready", "dev_infinite_mp", "infinite_mp")
	_switch(grid, "Force cube drops", "Every kill drops a cube", "dev_force_drops", "")
	p.add_child(_ink("Boost & Evolve", 22))
	var grid2 := GridContainer.new()
	grid2.columns = 2
	grid2.add_theme_constant_override("h_separation", 50)
	grid2.add_theme_constant_override("v_separation", 18)
	p.add_child(grid2)
	_switch(grid2, "100% boost", "Every boost succeeds", "dev_boost_100", "")
	_switch(grid2, "Free evolve", "Evolve any monster with no level, boost, materials or gold", "dev_free_evolve", "")
	return p


func _switch(parent: Container, title: String, desc: String, key: String, engine_prop: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.custom_minimum_size.x = 470
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(_ink(title, 24))
	var d := _ink(desc, 16)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 280
	d.modulate.a = 0.8
	text.add_child(d)
	row.add_child(text)
	var b := TextureButton.new()
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var knob := UI.image(UI.tex("betaUI00/B_toggle_01.png"))
	knob.size = knob.texture.get_size()
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(knob)
	var l := UI.label("", 26)
	l.size = Vector2(100, 36)
	l.position = Vector2(16, 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_outline_color", Color("502300"))
	l.add_theme_constant_override("outline_size", 6)
	b.add_child(l)
	var refresh := func() -> void:
		var on := bool(Save.data.get(key, false))
		b.texture_normal = UI.tex("betaUI00/B_toggle_02.png" if on else "betaUI00/B_toggle_03.png")
		knob.position = Vector2(88, 2) if on else Vector2(0, 2)
		l.text = "ON" if on else "Off"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if on else HORIZONTAL_ALIGNMENT_RIGHT
		l.add_theme_color_override("font_color", Color.WHITE if on else Color("ebbe69"))
	refresh.call()
	_refreshers.append(refresh)
	b.pressed.connect(func():
		var on := not bool(Save.data.get(key, false))
		Save.data[key] = on
		Save.save_game()
		if engine_prop != "" and main.current != null and "engine" in main.current and main.current.engine != null:
			main.current.engine.set(engine_prop, on)
		refresh.call()
		_status.text = "%s %s" % [title, "on" if on else "off"]
		Sfx.play("click"))
	row.add_child(b)
	parent.add_child(row)


func _monsters_page() -> Control:
	var p := _page()
	var add := HBoxContainer.new()
	add.add_theme_constant_override("separation", 10)
	p.add_child(add)
	_search = LineEdit.new()
	_search.placeholder_text = "Search name, or 6★ / fire / water / nature"
	_search.custom_minimum_size = Vector2(240, 48)
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t): _refresh_results())
	add.add_child(_search)
	add.add_child(_ink("Lv", 22))
	_level = _spin(1, 50, 30)
	add.add_child(_level)
	add.add_child(_ink("Boost +", 22))
	_boost = _spin(0, DB.MAX_BOOST, 0)
	add.add_child(_boost)
	_btn(add, "Give all", _give_all, "green", 140)
	_remove_btn = _btn(add, "Remove all", _remove_all, "purple", 160)
	var hint := _ink("Click a monster to add it to your box", 16)
	hint.modulate.a = 0.75
	p.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	_results = GridContainer.new()
	_results.columns = 9
	_results.add_theme_constant_override("h_separation", 12)
	_results.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_results)
	return p


func _show_tab(t: String) -> void:
	_tab = t
	for k in _pages:
		_pages[k].visible = k == t
	for k in _tab_buttons:
		var b: Button = _tab_buttons[k]
		b.modulate = Color.WHITE if k == t else Color(0.62, 0.62, 0.62)
		b.scale = Vector2.ONE
	if t == "Monsters" and visible:
		_refresh_results()
		_search.grab_focus()


func _spin(lo: int, hi: int, value: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.value = value
	s.custom_minimum_size = Vector2(90, 48)
	return s


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_F1:
			if visible:
				close()
			else:
				open()
			get_viewport().set_input_as_handled()
		elif e.keycode == KEY_ESCAPE and visible:
			close()
			get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	_status.text = ""
	_remove_armed = false
	_set_remove_text("Remove all")
	for r in _refreshers:
		r.call()
	_show_tab(_tab)


func close() -> void:
	visible = false
	if _dirty and main.current_name != "battle":
		main.go(main.current_name, main.current_args)
	_dirty = false


func _give(kind: String, amount: int) -> void:
	match kind:
		"energy":
			Save.data.energy = maxi(int(Save.data.energy), int(Save.data.energy_cap))
		"box":
			Save.data.inventory_cap = int(Save.data.inventory_cap) + amount
		_:
			Save.data[kind] = int(Save.data.get(kind, 0)) + amount
	_saved("Gave %s" % kind)


func _tut(replay: bool) -> void:
	if replay:
		Save.data["tutorial"] = {"enabled": true, "done": [], "new": true}
	else:
		Tutorial.skip_all()
	_saved("Tutorial " + ("will replay" if replay else "skipped"))


func _give_all() -> void:
	var ids := DB.ids_where(func(_d): return true)
	var level := int(_level.value)
	for id in ids:
		var m := Save.add_monster(id, level)
		m.boost = int(_boost.value)
		if level > DB.MAX_LEVEL:
			m.max_level = level
	Save.data.inventory_cap = maxi(int(Save.data.inventory_cap), Save.data.monsters.size())
	_saved("Added all %d monsters Lv.%d +%d" % [ids.size(), level, int(_boost.value)])


func _remove_all() -> void:
	if not _remove_armed:
		_remove_armed = true
		_set_remove_text("Click again")
		_status.text = "Click Remove all again to confirm"
		return
	_remove_armed = false
	_set_remove_text("Remove all")
	var keep := {}
	for u in Save.data.team:
		keep[int(u)] = true
	var gone := 0
	for m in Save.data.monsters.duplicate():
		if not keep.has(int(m.uid)):
			Save.remove_monster(int(m.uid))
			gone += 1
	var l: Dictionary = Save.data.get("league", {})
	if l.has("team"):
		l.team = l.team.filter(func(u): return keep.has(int(u)))
	_saved("Removed %d monsters (team kept)" % gone)


func _set_remove_text(t: String) -> void:
	_remove_btn.text = t


func _all_stones() -> void:
	var n := 0
	for type in MagicStones.TYPES:
		for rank in MagicStones.RANKS.size():
			for variant in ([0] if rank < MagicStones.B else [1, 2, 3]):
				Save.add_stone({"type": type, "rank": rank, "variant": variant})
				n += 1
	Save.data.stone_cap = maxi(int(Save.data.stone_cap), Save.free_stones().size())
	_saved("Added %d magic stones (every type, rank and variant)" % n)


func _event_shift(kind: String) -> void:
	match kind:
		"day":
			Events.shift_days(1)
		"week":
			Events.next_week()
		_:
			Events.reset_shift()
	var now := Events.now()
	var d := Time.get_date_dict_from_unix_time(now)
	_saved("Events: week %d of %d, %s · %s" % [Events.week_index(now) + 1, Events.week_count(), DB.WEEKDAYS[int(d.weekday)], Events.text().replace("\n", ", ")])


func _test_mail() -> void:
	Mail.send(Mail.TEAM, {"gems": 100}, "Test: 100 gems", true)
	Mail.send(Mail.TEAM, {"cube": "red"}, "Test: Red Cube", true)
	Mail.send(Friends.TEST_FRIEND.name, {"fp": Friends.FP_FRIEND}, "Sent you Friend Points!")
	Mail.send(Mail.TEAM, {"monster": "firepaw", "level": 30}, "Test: a monster gift", true)
	_saved("Sent 4 test messages")


func _refill_tickets() -> void:
	Save.data.tower_tickets = SkyTower.MAX_TICKETS
	_saved("Tickets refilled")


func _give_keys() -> void:
	Save.data.raid = {}
	Save.data.tower_tickets = SkyTower.MAX_TICKETS
	_saved("Raid key and tower tickets given")


func _unlock_islands() -> void:
	for island in DB.islands:
		var p: Dictionary = Save.data.progress.get(island.id, {})
		for d in DB.DIFFICULTIES:
			p[d] = island.difficulties[d].stages.size()
		Save.data.progress[island.id] = p
	_saved("All story islands cleared")


func _saved(msg: String) -> void:
	Save.save_game()
	_dirty = true
	_status.text = msg


func _refresh_results() -> void:
	for c in _results.get_children():
		c.queue_free()
	var q := _search.text.strip_edges().to_lower()
	var ids := DB.ids_where(_matches.bind(q))
	ids.sort_custom(_by_stars_then_name)
	for id in ids.slice(0, MAX_RESULTS):
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		var card := UI.monster_card(id, 0, 0, Vector2(96, 96))
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_card.bind(id))
		card.tooltip_text = "Click to add"
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		cell.add_child(card)
		var n := _ink(String(DB.monster(id).name), 14)
		n.custom_minimum_size.x = 96
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.clip_text = true
		cell.add_child(n)
		_results.add_child(cell)
	if ids.size() > MAX_RESULTS:
		_status.text = "%d matches — showing %d, type to narrow" % [ids.size(), MAX_RESULTS]


static func _matches(m: Dictionary, q: String) -> bool:
	if q.length() == 2 and (q.ends_with("*") or q.ends_with("★")):
		return int(m.stars) == int(q.substr(0, 1))
	if q in ["fire", "water", "nature"]:
		return String(m.element) == q
	return q == "" or String(m.name).to_lower().contains(q) or String(m.id).contains(q)


static func _by_stars_then_name(a: String, b: String) -> bool:
	var sa := int(DB.monster(a).stars)
	var sb := int(DB.monster(b).stars)
	if sa != sb:
		return sa > sb
	return String(DB.monster(a).name) < String(DB.monster(b).name)


func _on_card(e: InputEvent, id: String) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	var level := int(_level.value)
	var m := Save.add_monster(id, level)
	m.boost = int(_boost.value)
	if level > DB.MAX_LEVEL:
		m.max_level = level
	_saved("Added %s Lv.%d +%d" % [DB.monster(id).name, level, int(m.boost)])
	Sfx.play("click")
