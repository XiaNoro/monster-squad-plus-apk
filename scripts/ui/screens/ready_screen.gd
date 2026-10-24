class_name ReadyScreen
extends Screen

const SPOTS := ["ID_leaderS", "ID_surportASh", "ID_surportBSh", "ID_surportCSh", "ID_surportDSh"]
const LV_LABELS := ["ID_Lv_1", "ID_Lv_2", "ID_Lv_3", "ID_Lv_4", "ID_Lv_5"]
const SORTS := ["Rank", "Level", "Name"]

var lay: Layout
var quest: Dictionary
var _picked: Dictionary = {}
var _sort := 0
var _slots: Array = []
var _field_items: Array = []


func build() -> void:
	quest = args.get("quest", {})
	if quest.is_empty():
		var isl := DB.island(String(args.get("island", DB.islands[0].id)))
		args["island"] = isl.id
		quest = StageBuilder.story_quest(isl, String(args.get("difficulty", "normal")), int(args.get("stage", 0)))
	UI.brown_background(self)
	lay = Layout.load_into(self, "R_readyPage")
	var title := String(quest.get("title", "Ready"))
	if title.ends_with("  ·  Normal"):
		title = title.trim_suffix("  ·  Normal")
	add_top_bar("2", title, "islands")
	_back_args = _return_args()
	lay.on("ID_btnStart", _go)
	lay.sound(["ID_btnStart"], "battle_start")
	lay.on("ID_btnTeam", _team)
	lay.on("ID_btnAlign", _next_sort)
	lay.show("ID_hotTime", false)
	lay.text("ID_textTeam", "Team")
	var cost_gems := int(quest.get("gems", 0))
	lay.show("ID_IMAGE_3", false)
	lay.show("ID_fpointText", false)
	lay.show("ID_IMAGE_crystal", cost_gems > 0)
	lay.show("ID_cpointText", cost_gems > 0)
	lay.show("ID_IMAGE_1", cost_gems == 0)
	lay.show("ID_pointText", cost_gems == 0)
	lay.text("ID_pointText", str(int(quest.get("energy", 0))))
	if int(quest.get("fp", 0)) > 0:
		lay.text("ID_pointText", str(int(quest.fp)))
		lay.set_image("ID_IMAGE_1", UI.tex("betaUI00/I_fPoint_02.png"))
	lay.text("ID_cpointText", str(cost_gems))
	Friends.process_requests()
	_refresh()
	Tutorial.maybe_start(self, "ready")


func _return_args() -> Dictionary:
	if quest.get("kind", "") == "special":
		return {"tab": "special", "special": quest.get("special_id", "")}
	return {"island": args.get("island", ""), "difficulty": args.get("difficulty", "normal")}


func _refresh() -> void:
	_fill_field()
	_fill_effects()
	_fill_friends()


func _fill_field() -> void:
	for c in _field_items:
		if is_instance_valid(c):
			c.queue_free()
	_field_items.clear()
	var members := Save.team_members()
	var units: Array = []
	for m in members:
		units.append({"id": m.id, "level": int(m.level)})
	while units.size() < 4:
		units.append({})
	units = units.slice(0, 4)
	units.append({"id": _picked.monster, "level": int(_picked.level)} if not _picked.is_empty() else {})
	for i in SPOTS.size():
		var spot: Control = lay.node(SPOTS[i])
		lay.text(LV_LABELS[i], "")
		spot.visible = not units[i].is_empty()
		if units[i].is_empty():
			continue
		var tex := DB.battle_sprite(units[i].id)
		var box := Vector2(150, 130) if i == 0 else Vector2(120, 105)
		var size := box
		if tex.get_width() > 0:
			size = tex.get_size() * minf(box.x / tex.get_width(), box.y / tex.get_height())
		var pic := UI.living(tex, size)
		pic.position = Vector2(spot.size.x / 2.0 - size.x / 2.0, spot.size.y * 0.6 - size.y)
		spot.add_child(pic)
		_field_items.append(pic)
		lay.text(LV_LABELS[i], "Lv.%02d" % int(units[i].level))
	lay.show("ID_LABEL_1", true)
	lay.node("ID_LABEL_1").add_theme_color_override("font_color", UI.GOLD)
	lay.show("ID_friendPic", not _picked.is_empty())
	lay.set_image("ID_rankImage", Layout.texture("T_rank%s_01.png" % Arena.team_rank(members)))
	var kind := Arena.team_type(members)
	lay.show("ID_AttackImage", kind == "attack")
	lay.show("ID_DefenceImage", kind == "defence")
	lay.show("ID_SupportImage", kind == "support")


func _fill_effects() -> void:
	var lines := []
	var members := Save.team_members()
	for k in range(1, members.size()):
		var p := String(DB.monster(members[k].id).passive)
		if p != "":
			lines.append({"text": "- " + p, "friend": false})
	if not _picked.is_empty():
		var fp := String(DB.monster(_picked.monster).passive)
		if fp != "":
			lines.append({"text": "- (Friend) " + fp, "friend": true})
	var ids := ["ID_ef1Text", "ID_ef2Text", "ID_ef3Text", "ID_ef4Text", "ID_ef5Text", "ID_ef6Text", "ID_ef7Text", "ID_ef8Text"]
	for k in ids.size():
		var l := lay.text(ids[k], String(lines[k].text) if k < lines.size() else "")
		if l == null:
			continue
		l.size.x = 440
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", Color("2f7a18") if k < lines.size() and lines[k].friend else UI.BROWN)
	for k in range(4, ids.size()):
		lay.show(ids[k], false)


func _entries() -> Array:
	var out := []
	for f in Save.data.friends:
		out.append(f)
	for g in Friends.guests():
		if not Friends.is_friend(String(g.name)):
			out.append(g)
	match SORTS[_sort]:
		"Level":
			out.sort_custom(func(a, b): return int(a.level) > int(b.level))
		"Name":
			out.sort_custom(func(a, b): return String(a.name).to_lower() < String(b.name).to_lower())
		_:
			out.sort_custom(func(a, b): return Arena.power_of([{"id": a.monster, "level": a.level, "boost": a.get("boost", 0)}]) > Arena.power_of([{"id": b.monster, "level": b.level, "boost": b.get("boost", 0)}]))
	out.sort_custom(func(a, b): return int(Friends.used_today(a)) < int(Friends.used_today(b)))
	if not Tutorial.is_done("ready"):
		for k in out.size():
			if String(out[k].name) == String(Friends.TEST_FRIEND.name):
				out.push_front(out.pop_at(k))
				break
	return out


func _fill_friends() -> void:
	_slots.clear()
	var rows := []
	var entries := _entries()
	for f in entries:
		rows.append(_friend_slot(f))
	lay.show("ID_NoSelection", entries.is_empty())
	lay.show("ID_LABEL_FRIEND_DISABLE", false)
	lay.text("ID_LABEL_4", SORTS[_sort]).add_theme_font_size_override("font_size", 17)
	lay.list_into("ID_ID_arrayPosition", rows)


func _friend_slot(f: Dictionary) -> Control:
	var guest := bool(f.get("guest", false))
	var s := Layout.instance("R_readyFriendSlot")
	var suffix := "_1" if guest else ""
	s.show("ID_9BUTTON_frameSize_Guest", guest)
	s.show("ID_9BUTTON_frameSize", not guest)
	var st := DB.stats_at(String(f.monster), int(f.level), int(f.get("boost", 0)))
	s.text("ID_friendName" + suffix, String(f.name))
	s.text("ID_friendstat" + suffix, "HP %d / ATK %d" % [int(st.hp), int(st.atk)])
	var icon_holder: Control = s.node("ID_leaderIcon" + suffix)
	var card := UI.monster_card(String(f.monster), int(f.level), int(f.get("boost", 0)), Vector2(92, 92))
	card.mouse_filter = MOUSE_FILTER_IGNORE
	icon_holder.add_child(card)
	var skill_box: Control = s.node("ID_friendSkill" + suffix)
	var sup: Dictionary = DB.monster(String(f.monster)).get("support_skill", {})
	var sk := DB.skill_icon(String(sup.get("icon", ""))) if String(sup.get("name", "")) != "" else null
	if sk != null:
		var ic := UI.image(sk, Vector2(40, 40))
		ic.size = Vector2(40, 40)
		skill_box.add_child(ic)
		(s.node("ID_friendName" + suffix) as Label).position.x = 58
	var chosen := not _picked.is_empty() and String(_picked.name) == String(f.name)
	s.show("ID_check" + suffix, chosen)
	var used := not guest and Friends.used_today(f)
	s.show("ID_disable" + suffix, used)
	if used:
		s.text("ID_disableText", "Available after 4 AM(UTC)")
	else:
		s.on("ID_btnSlot" + suffix, _pick.bind(f))
	if guest:
		s.on("ID_btnFriend", _add_guest.bind(f))
	_slots.append(s)
	return s.root


func _pick(f: Dictionary) -> void:
	if not _picked.is_empty() and String(_picked.name) == String(f.name):
		_picked = {}
	else:
		_picked = f
		Sfx.play("buff")
	_refresh()
	tut_notify("friend:0")


func _add_guest(f: Dictionary) -> void:
	if Friends.send_request(f):
		UI.toast(self, "Friend request sent to %s" % f.name, UI.GOLD)
	else:
		UI.toast(self, "Request already sent")


func _next_sort() -> void:
	_sort = (_sort + 1) % SORTS.size()
	_fill_friends()


func _team() -> void:
	main.go("squad", {"back": "ready", "back_args": args})


func _go() -> void:
	if Save.team_members().is_empty():
		UI.toast(self, "Your squad is empty!")
		return
	if Save.inventory_full() and not tutorial_active():
		UI.inventory_full(self, func(): main.go("squad", {"mode": "train"}))
		return
	if not Save.pay_quest(quest):
		var need := "Not enough energy (%d needed)" % int(quest.energy)
		if int(quest.get("gems", 0)) > 0:
			need = "Not enough gems (%d needed)" % int(quest.gems)
		elif int(quest.get("fp", 0)) > 0:
			need = "Not enough Friend Points (%d needed)" % int(quest.fp)
		UI.toast(self, need, Color("ff8080"))
		return
	var a := args.duplicate()
	if not _picked.is_empty():
		a["friend"] = _picked
	main.go("battle", a)


func tutorial_target(name: String) -> Control:
	match name:
		"go":
			return lay.node("ID_btnStart")
		"team":
			return lay.node("ID_btnTeam")
		"friend:0":
			if not _slots.is_empty():
				var s: Layout = _slots[0]
				return s.node("ID_btnSlot_1") if s.node("ID_btnSlot_1").is_visible_in_tree() else s.node("ID_btnSlot")
	return null
