class_name ChatTicker
extends Control

signal posted(channel: int, msg: Dictionary)

const DATA := "res://data/chat.json"
const MARGIN := 24.0
const SKIP_SCREENS := ["battle", "title", "starter", "layout"]
const CHANNELS := 20
const HISTORY := 60
const SEED_LINES := 24
const PILL_SIZE := Vector2(112, 30)
const PILL_TEXT := Color("1f3b0c")
const THREAD_CHANCE := 0.12
const SLOT := "\\{(\\w+)\\}"

static var _data: Dictionary = {}

var main: Main
var channel := 1
var history: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _timer: Timer
var _pool: Dictionary = {}
var _slot_rx := RegEx.create_from_string(SLOT)


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		if parsed is Dictionary:
			_data = parsed
	return _data


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


func messages(ch: int) -> Array:
	if not history.has(ch):
		var lines := []
		while lines.size() < SEED_LINES:
			if _rng.randf() < THREAD_CHANCE:
				lines.append_array(thread())
			else:
				var m := fake()
				if not m.is_empty():
					lines.append(m)
		history[ch] = lines
	return history[ch]


func post(msg: Dictionary, ch: int = -1) -> void:
	if ch < 0:
		ch = channel
	var lines := messages(ch)
	lines.append(msg)
	while lines.size() > HISTORY:
		lines.pop_front()
	posted.emit(ch, msg)
	if bool(msg.get("ask", false)) and _rng.randf() < 0.65:
		_answer(msg, ch)


func chatter(ch: int = -1) -> void:
	if ch < 0:
		ch = channel
	if _rng.randf() < THREAD_CHANCE:
		play_thread(ch)
	else:
		var m := fake()
		if not m.is_empty():
			post(m, ch)


func play_thread(ch: int) -> void:
	for msg in thread():
		post(msg, ch)
		await get_tree().create_timer(_rng.randf_range(1.5, 4.0)).timeout


func thread() -> Array:
	var list: Array = data().get("threads", []).filter(func(t): return not t.has("needs") or not Events.today().is_empty())
	if list.is_empty():
		return []
	var t: Dictionary = list[_rng.randi() % list.size()]
	var ctx := {"_m": String(t.get("m", ""))}
	var who := {}
	var out := []
	for l in t.lines:
		var role := String(l[0])
		if not who.has(role):
			who[role] = _player_name(who.values())
		ctx["player"] = _other(who, role)
		var msg := say(who[role], String(l[1]), ctx)
		if not msg.is_empty():
			out.append(msg)
	return out


func _other(who: Dictionary, role: String) -> String:
	for r in who:
		if r != role:
			return who[r]
	return _player_name()


func say(who: String, template: String, ctx: Dictionary = {}) -> Dictionary:
	var text := fill(template, ctx)
	if text == "":
		return {}
	var msg := {"who": who, "text": style(text, who)}
	if "{m}" in text:
		msg.id = ctx.m
	return msg


func fill(template: String, ctx: Dictionary) -> String:
	var text := template
	for depth in 4:
		var found := _slot_rx.search_all(text)
		if found.is_empty():
			break
		for r in found:
			var key := r.get_string(1)
			if key == "m":
				if not ctx.has("m"):
					ctx.m = _monster_for(String(ctx.get("_m", "")))
				if String(ctx.m) == "":
					return ""
				continue
			var v := _slot(key, ctx)
			if v == "":
				return ""
			text = text.replace(r.get_string(), v)
	return text


func _slot(key: String, ctx: Dictionary) -> String:
	if ctx.has(key):
		return String(ctx[key])
	var v := ""
	match key:
		"island":
			v = String(DB.islands[_rng.randi() % DB.islands.size()].name).to_lower()
		"special":
			v = String(DB.special_islands[_rng.randi() % DB.special_islands.size()].name).to_lower()
		"raid":
			v = String(DB.raids[_rng.randi() % DB.raids.size()].name).to_lower()
		"mode":
			v = ["normal", "hard", "hell"][_rng.randi() % 3]
		"floor":
			v = str(_rng.randi_range(10, 50))
		"n":
			v = str(_rng.randi_range(2, 9))
		"big":
			v = str(_rng.randi_range(2, 50) * 10)
		"stars":
			v = str(_rng.randi_range(4, 6))
		"element":
			v = ["fire", "water", "nature"][_rng.randi() % 3]
		"player":
			v = _player_name()
		"me":
			v = String(Save.data.get("name", "Tamer"))
		"event":
			var today := Events.today()
			if today.is_empty():
				return ""
			v = String(today[_rng.randi() % today.size()].text).to_lower()
		"loc":
			if not ctx.has("m"):
				ctx.m = _monster_for(String(ctx.get("_m", "")))
			v = _location(String(ctx.m))
		_:
			var words: Array = data().get("words", {}).get(key, [])
			if words.is_empty():
				return ""
			return String(words[_rng.randi() % words.size()])
	ctx[key] = v
	return v


func _location(id: String) -> String:
	var loc := String(DB.monster(id).get("location", "")).split("(★")[0].strip_edges().trim_suffix("-").strip_edges()
	return loc if loc.length() <= 40 else ""


func _monster_for(kind: String) -> String:
	match kind:
		"pull":
			return _pick(6 if _rng.randf() < 0.35 else 5, false)
		_:
			return _pick(_rng.randi_range(4, 6), false)


func style(text: String, who: String) -> String:
	var personas: Array = data().get("personas", [["plain"]])
	var tags: Array = personas[absi(hash(who)) % personas.size()]
	var parts := text.split("{m}")
	for i in parts.size():
		var p := parts[i]
		for tag in tags:
			match String(tag):
				"lower":
					p = p.to_lower()
				"caps":
					if _rng.randf() < 0.5:
						p = p.to_upper()
				"typo":
					p = _typo(p)
		parts[i] = p
	var out := "{m}".join(parts)
	for tag in tags:
		match String(tag):
			"lower", "short":
				out = out.rstrip(".")
			"caps":
				if _rng.randf() < 0.5 and not out.ends_with("?"):
					out += "!!"
			"polite":
				out = out.left(1).to_upper() + out.substr(1)
				if not (out.ends_with(".") or out.ends_with("!") or out.ends_with("?") or out.ends_with(")")):
					out += " :)" if _rng.randf() < 0.5 else "."
			"emote":
				if _rng.randf() < 0.5:
					out += [" xD", " :P", " ^^", " :D", " :3"][_rng.randi() % 5]
	return out


func _typo(s: String) -> String:
	if _rng.randf() > 0.4:
		return s
	var words := s.split(" ")
	var long := []
	for i in words.size():
		if words[i].length() >= 4 and words[i].is_valid_identifier():
			long.append(i)
	if long.is_empty():
		return s
	var i: int = long[_rng.randi() % long.size()]
	var w := words[i]
	var k := _rng.randi_range(1, w.length() - 2)
	words[i] = w.substr(0, k) + w[k + 1] + w[k] + w.substr(k + 2)
	return " ".join(words)


func _answer(msg: Dictionary, ch: int) -> void:
	await get_tree().create_timer(_rng.randf_range(2.0, 5.0)).timeout
	var ctx := {"m": String(msg.id)}
	var pool := "answers" if _location(String(msg.id)) != "" and _rng.randf() < 0.6 else "vague"
	var reply := say(_player_name(), _any(data().get(pool, [])), ctx)
	if reply.is_empty():
		return
	reply.erase("id")
	reply.text = "@%s %s" % [msg.who, String(reply.text).replace("{m}", String(DB.monster(String(msg.id)).name))]
	post(reply, ch)


func fake() -> Dictionary:
	var r := _rng.randf()
	if r < 0.1:
		return say(_player_name(), _any(data().get("talk", [])))
	if r < 0.16 and not Events.today().is_empty():
		return say(_player_name(), _any(data().get("event_talk", [])))
	if r < 0.38:
		var ask := _rng.randf() < 0.5
		var msg := say(_player_name(), _any(data().get("ask" if ask else "unbox", [])), {"_m": "ask" if ask else "pull"})
		if msg.has("id"):
			msg.ask = ask
		return msg
	var sources: Array = data().get("sources", ["from Cube"])
	var source: String = sources[_rng.randi() % sources.size()]
	var id := _pick(6 if _rng.randf() < 0.3 else 5, source == "by Evolving")
	if id == "":
		return {}
	return {"who": _player_name(), "id": id, "source": source}


func player_got(ids: Array, source: String = "from Cube") -> void:
	var me := String(Save.data.get("name", "Tamer"))
	for id in ids:
		if int(DB.monster(String(id)).get("stars", 0)) < 5:
			continue
		var ch := channel
		post({"who": me, "id": String(id), "source": source}, ch)
		for i in _rng.randi_range(1, 2):
			await get_tree().create_timer(_rng.randf_range(1.5, 4.0)).timeout
			var msg := say(_player_name(), _any(data().get("congrats", [])), {"m": String(id)})
			if not msg.is_empty():
				post(msg, ch)


func _pick(stars: int, evolved: bool) -> String:
	var key := "%d:%s" % [stars, evolved]
	if not _pool.has(key):
		_pool[key] = DB.ids_where(func(m): return int(m.stars) == stars and not m.material and m.skills.size() >= 1 and (not evolved or String(m.get("evolves_from", "")) != ""))
		if (_pool[key] as Array).is_empty() and evolved:
			_pool[key] = DB.ids_where(func(m): return int(m.stars) == stars and not m.material and m.skills.size() >= 1)
	var ids: Array = _pool[key]
	return String(ids[_rng.randi() % ids.size()]) if not ids.is_empty() else ""


func _player_name(avoid: Array = []) -> String:
	var names: Array = data().get("names", [])
	for attempt in 6:
		var n := ""
		if not names.is_empty() and _rng.randf() < 0.35:
			n = String(names[_rng.randi() % names.size()])
		else:
			for i in _rng.randi_range(2, 3):
				n += Arena.SYLLABLES[_rng.randi() % Arena.SYLLABLES.size()]
			n = n.capitalize().replace(" ", "") + (str(_rng.randi_range(1, 999)) if _rng.randf() < 0.5 else "")
		if not n in avoid:
			return n
	return "Tamer%d" % _rng.randi_range(100, 999)


func reply_to(text: String) -> void:
	var t := " " + text.to_lower().strip_edges() + " "
	var ctx := {}
	var pool := ""
	var mentioned := _mentioned_monster(t)
	if mentioned != "":
		ctx.m = mentioned
		pool = "reply_monster"
	else:
		for rule in data().get("reply_rules", []):
			var hit: bool = not (rule.has("starts") or rule.has("contains") or rule.has("ends"))
			for w in rule.get("starts", []):
				hit = hit or t.strip_edges().begins_with(String(w))
			for w in rule.get("contains", []):
				hit = hit or String(w) in t
			for w in rule.get("ends", []):
				hit = hit or t.strip_edges().ends_with(String(w))
			if hit:
				if _rng.randf() < float(rule.get("chance", 1.0)):
					pool = String(rule.pool)
				break
	if pool == "":
		return
	var ch := channel
	var used := []
	for i in (2 if _rng.randf() < 0.35 else 1):
		await get_tree().create_timer(_rng.randf_range(1.5, 4.0)).timeout
		var who := _player_name(used)
		used.append(who)
		var msg := say(who, _any(data().get(pool, [])), ctx.duplicate())
		if not msg.is_empty():
			post(msg, ch)


func _mentioned_monster(t: String) -> String:
	var best := ""
	var best_len := 0
	for id in DB.monsters:
		var n := String(DB.monster(id).name).to_lower()
		if n.length() >= 4 and n.length() > best_len and (" " + n) in t and not DB.monster(id).get("material", false):
			best = id
			best_len = n.length()
	return best


func _any(lines: Array) -> String:
	return String(lines[_rng.randi() % lines.size()]) if not lines.is_empty() else ""


func show_message(who: String = "", id: String = "", source: String = "") -> void:
	var msg := fake()
	if id != "":
		msg = {"who": who, "id": id, "source": source}
	if msg.is_empty():
		return
	if String(msg.who) == "":
		msg.who = _player_name()
	if not msg.has("text") and String(msg.source) == "":
		msg.source = _any(data().get("sources", ["from Cube"]))
	post(msg)
	if msg.has("text") or (main != null and main.current != null and main.current.has_meta("chat_open")):
		return
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.03, 0.72)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	bar.add_theme_stylebox_override("panel", sb)
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_child(line(msg))
	for old in get_children():
		if old is PanelContainer:
			old.queue_free()
	bar.modulate.a = 0.0
	add_child(bar)
	await get_tree().process_frame
	if not is_instance_valid(bar) or bar.is_queued_for_deletion():
		return
	bar.position = Vector2(maxf(MARGIN, size.x - bar.size.x - MARGIN), -bar.size.y)
	var tw := bar.create_tween()
	tw.set_parallel()
	tw.tween_property(bar, "position:y", 64.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(bar, "modulate:a", 1.0, 0.3)
	tw.chain().tween_interval(4.5)
	tw.chain().tween_property(bar, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(bar.queue_free)


static func line(msg: Dictionary, on_pick: Callable = Callable()) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.custom_minimum_size.y = PILL_SIZE.y
	row.mouse_filter = MOUSE_FILTER_IGNORE
	if not msg.has("text"):
		row.add_child(_text("%s Obtained" % msg.who))
		row.add_child(pill(String(msg.id), on_pick))
		row.add_child(_text(String(msg.source)))
		return row
	row.add_theme_constant_override("separation", 6)
	var who := _text("%s :" % msg.who)
	who.add_theme_color_override("font_color", Color("ffd36a") if bool(msg.get("me", false)) else Color("9fd8ff"))
	row.add_child(who)
	if msg.has("id"):
		var parts := String(msg.text).split("{m}")
		for k in parts.size():
			if parts[k].strip_edges() != "":
				row.add_child(_text(parts[k].strip_edges()))
			if k < parts.size() - 1:
				row.add_child(pill(String(msg.id), on_pick))
		return row
	var said := _text(String(msg.text))
	if on_pick.is_valid():
		said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		said.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(said)
	return row


static func pill(id: String, on_pick: Callable = Callable()) -> Control:
	var def := DB.monster(id)
	var p := Control.new()
	p.custom_minimum_size = PILL_SIZE
	p.size = PILL_SIZE
	p.size_flags_vertical = SIZE_SHRINK_CENTER
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var np := NinePatchRect.new()
	np.texture = UI.tex("betaUI00/9_btn_08.png")
	np.patch_margin_left = 28
	np.patch_margin_right = 28
	np.size = PILL_SIZE * 2.0
	np.scale = Vector2(0.5, 0.5)
	np.mouse_filter = MOUSE_FILTER_IGNORE
	p.add_child(np)
	var nm := _text(String(def.get("name", "?")))
	var room := PILL_SIZE.x - 50
	nm.clip_text = true
	nm.position = Vector2(9, 0)
	nm.size = Vector2(room, PILL_SIZE.y)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.add_theme_color_override("font_color", PILL_TEXT)
	p.add_child(nm)
	var font: Font = load(UI.FONT)
	var fs := 15
	while fs > 9 and font.get_string_size(nm.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	nm.add_theme_font_size_override("font_size", fs)
	var st := _text("★%d" % int(def.get("stars", 5)))
	st.position = Vector2(PILL_SIZE.x - 34, 0)
	st.size = Vector2(26, PILL_SIZE.y)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	st.add_theme_font_size_override("font_size", 14)
	st.add_theme_color_override("font_color", PILL_TEXT)
	p.add_child(st)
	if on_pick.is_valid():
		p.mouse_filter = MOUSE_FILTER_PASS
		p.mouse_default_cursor_shape = CURSOR_POINTING_HAND
		p.gui_input.connect(func(e: InputEvent):
			if UI.tapped(e):
				Sfx.play("click")
				on_pick.call(id))
	return p


static func _text(s: String) -> Label:
	var l := UI.label(s, 20, Color.WHITE)
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	return l
