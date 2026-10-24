class_name StonesScreen
extends Screen

const CAT_TABS := {"attack": "ID_tapATK", "defense": "ID_tapDEF", "skill": "ID_tapSK"}
const TYPE_TINT := {"bravery": Color("ff6a4a"), "windfury": Color("9cf06a"), "thunder": Color("ffe24a"), "destruction": Color("ff4aa8"),
	"vitality": Color("ff9a9a"), "steel": Color("b8c8d8"), "blessed": Color("7affc8"), "time": Color("8ab8ff"), "clarity": Color("6ae8ff"), "spirit": Color("c88aff")}
const SORTS := ["Rank", "Type", "Recent"]
const STAT_ROWS := [["hp", "ID_textHp2", "ID_textHp2_1"], ["atk", "ID_textAp2", "ID_textAp2_1"], ["def", "ID_textDp2", "ID_textDp2_1"], ["rec", "ID_textRe2", "ID_textRe2_1"], ["max_mp", "ID_textMana2", "ID_textMana2_1"]]

var lay: Layout
var uid := -1
var _cat := "attack"
var _sort := 0
var _pick := ""
var _slot := 0
var _stone := -1


func build() -> void:
	UI.brown_background(self)
	uid = int(args.get("uid", -1))
	if uid >= 0 and not Save.get_owned(uid).is_empty():
		lay = Layout.load_into(self, "R_comStonePage")
		add_top_bar("2", "Magic Stones", String(args.get("back", "squad")))
		_back_args = args.get("back_args", {"mode": "train", "uid": uid})
		lay.on("ID_btnAlign", _next_sort)
		lay.on("ID_btnAdd", _offer_box)
		lay.on("ID_btnEquip", _confirm_equip)
		lay.on("ID_btnRemove", _confirm_remove)
		lay.on("ID_btnSell", _confirm_destroy)
		lay.text("ID_LABEL_6", "Equip Cost")
		for i in 3:
			var s := lay.node("ID_stone%d" % (i + 1))
			s.mouse_filter = MOUSE_FILTER_STOP
			s.gui_input.connect(_on_slot.bind(i))
		_refresh_equip()
	else:
		lay = Layout.load_into(self, "R_comStonePage_create")
		add_top_bar("2", "Magic Stones", "hub")
		for c in CAT_TABS:
			lay.on(CAT_TABS[c], _set_cat.bind(c))
		lay.on("ID_btnAlign", _next_sort)
		lay.on("ID_btnCreate", _craft)
		_set_cat("attack")


static func stone_icon(st: Dictionary, size: float = 92.0) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(size, size)
	box.size = Vector2(size, size)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := size / 92.0
	var bg := UI.image(UI.tex("betaUI00/B_monEmpty_04.png"), Vector2(size, size))
	bg.size = Vector2(size, size)
	box.add_child(bg)
	var path := "res://assets/stone_icons/%s.png" % String(st.type)
	for r in range(clampi(int(st.rank), 0, 6), MagicStones.RANKS.size()):
		var graded := "res://assets/stone_icons/%s_%s.png" % [String(st.type), MagicStones.RANKS[r]]
		if ResourceLoader.exists(graded):
			path = graded
			break
	var art: Texture2D = load(path) if ResourceLoader.exists(path) else null
	var side: float = [50.0, 56.0, 62.0, 74.0, 76.0, 78.0, 80.0][clampi(int(st.rank), 0, 6)]
	var gem := UI.image(art if art != null else UI.tex("betaUI00/I_stone_01.png"), Vector2(side, side) * s)
	gem.size = Vector2(side, side) * s
	gem.position = (Vector2(92, 92) - Vector2(side, side)) * 0.5 * s
	if art == null:
		gem.self_modulate = TYPE_TINT.get(String(st.type), Color.WHITE)
	box.add_child(gem)
	var frame := UI.image(UI.tex("betaUI00/M_attStone_01.png"), Vector2(size, size))
	frame.size = Vector2(size, size)
	box.add_child(frame)
	var badge := UI.image(MagicStones.badge(int(st.rank)), Vector2(44, 38) * s)
	badge.size = Vector2(44, 38) * s
	badge.position = Vector2(-4, 58) * s
	box.add_child(badge)
	var v := int(st.get("variant", 0))
	if v > 0:
		var l := UI.label(MagicStones.VARIANTS[v], int(18 * s), Color.WHITE)
		l.add_theme_constant_override("outline_size", 4)
		l.position = Vector2(60, 62) * s
		box.add_child(l)
	return box


static func stone_tile(st: Dictionary, on_press: Callable) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(360, 74)
	b.pressed.connect(on_press)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	h.add_child(stone_icon(st, 64))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(UI.label(MagicStones.label(st), 16, UI.GOLD))
	v.add_child(UI.label(MagicStones.describe(st), 13))
	return b


func _next_sort() -> void:
	_sort = (_sort + 1) % SORTS.size()
	if uid >= 0:
		_refresh_equip()
	else:
		_refresh_craft()


func _sorted(list: Array) -> Array:
	var out := list.duplicate()
	match SORTS[_sort]:
		"Rank":
			out.sort_custom(func(a, b): return int(a.rank) > int(b.rank) or (int(a.rank) == int(b.rank) and String(a.type) < String(b.type)))
		"Type":
			out.sort_custom(func(a, b): return String(a.type) < String(b.type) or (String(a.type) == String(b.type) and int(a.rank) > int(b.rank)))
		_:
			out.sort_custom(func(a, b): return int(a.uid) > int(b.uid))
	return out


func _key(st: Dictionary) -> String:
	return "%s|%d|%d" % [st.type, int(st.rank), int(st.get("variant", 0))]


func _brown(l: Label, font: int = 18) -> Label:
	if l == null:
		return l
	l.add_theme_color_override("font_color", UI.BROWN)
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	l.add_theme_font_size_override("font_size", font)
	return l


func _set_cat(c: String) -> void:
	_cat = c
	_pick = ""
	lay.select_tab(CAT_TABS.values(), CAT_TABS[c])
	_refresh_craft()


func _refresh_craft() -> void:
	lay.text("ID_LABEL_4", SORTS[_sort])
	var groups := {}
	var order := []
	for st in _sorted(Save.free_stones()):
		if String(MagicStones.TYPES[st.type].cat) != _cat:
			continue
		var k := _key(st)
		if not groups.has(k):
			groups[k] = []
			order.append(k)
		groups[k].append(st)
	if _pick == "" or not groups.has(_pick):
		_pick = order[0] if not order.is_empty() else ""
	var rows := []
	for k in order:
		rows.append(_stone_row(groups[k][0], groups[k].size(), k == _pick, _select_group.bind(k)))
	if rows.is_empty():
		var l := _brown(UI.label("No stones yet.\nClear Sky Tower floors to find Magic Stones.", 20), 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(400, 120)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rows.append(l)
	lay.list_into("ID_arrayPosition", rows, 2)
	_fill_craft(groups.get(_pick, []))


func _stone_row(st: Dictionary, count: int, selected: bool, on_tap: Callable) -> Control:
	var s := Layout.instance("R_comStoneSlot")
	s.text("ID_stoneName", MagicStones.label(st))
	(s.node("ID_stoneName") as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_brown(s.node("ID_stoneName") as Label, 19)
	s.text("ID_numText", "x%d" % count)
	s.put("ID_stoneIcon_70%", stone_icon(st, 64))
	s.show("ID_select", selected)
	s.hide_all(["ID_stoneLock", "ID_tagNew"])
	(s.node("ID_stoneSlot") as BaseButton).pressed.connect(on_tap)
	return s.root


func _select_group(k: String) -> void:
	_pick = k
	Sfx.play("click")
	_refresh_craft()


func _fill_craft(group: Array) -> void:
	var holder := lay.node("ID_previewStone")
	for c in holder.get_children():
		if c.has_meta("icon"):
			c.queue_free()
	for k in 4:
		var m := lay.node("ID_Matl%d" % (k + 1))
		for c in m.get_children():
			c.queue_free()
		lay.show("ID_Matl_%d" % (k + 1), false)
	if group.is_empty():
		lay.text("ID_txtStoneName", "-")
		lay.text("ID_txtStoneDes", "")
		lay.text("ID_txtUnique", "")
		lay.text("ID_txtCondition", "")
		lay.text("ID_goldText", "0")
		lay.node("ID_btnCreate").modulate = Color(0.55, 0.55, 0.55)
		return
	var st: Dictionary = group[0]
	var icon := stone_icon(st, 120)
	icon.set_meta("icon", true)
	icon.position = Vector2(22, 18)
	holder.add_child(icon)
	lay.text("ID_txtStoneName", MagicStones.label(st))
	var des := _brown(lay.text("ID_txtStoneDes", "- " + MagicStones.describe(st).replace(",  ", "\n- ")), 16)
	des.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lay.text("ID_txtUnique", "[%s]" % String(MagicStones.TYPES[st.type].cat).capitalize())
	var req := MagicStones.craft_requirements(st, int(Save.data.tower_floor))
	var ok: bool = req.ok
	if int(st.rank) >= MagicStones.SP:
		lay.text("ID_txtCondition", "Highest rank")
	else:
		lay.text("ID_txtCondition", "Required Skytower's floor : %d" % int(req.get("floor", 0)))
	var need := int(req.get("count", 0))
	var have := group.size()
	var boxes := need if need <= 4 else 1
	for k in 4:
		var show := k < boxes
		lay.show("ID_Matl_%d" % (k + 1), show)
		if not show:
			continue
		var per := 1 if need <= 4 else need
		lay.put("ID_Matl%d" % (k + 1), stone_icon(st, 92))
		var got := (1 if have > k else 0) if need <= 4 else have
		lay.show("ID_txtNumCan_%d" % (k + 1), got >= per)
		lay.show("ID_txtNumCant_%d" % (k + 1), got < per)
		lay.text("ID_txtNumCan_%d" % (k + 1), "%d/%d" % [got, per])
		lay.text("ID_txtNumCant_%d" % (k + 1), "%d/%d" % [got, per])
		(lay.node("ID_txtNumCant_%d" % (k + 1)) as Label).add_theme_color_override("font_color", Color("ff6a5a"))
	lay.text("ID_goldText", Screen._thousands(int(req.get("cost", 0))))
	lay.node("ID_btnCreate").modulate = Color.WHITE if ok and have >= need else Color(0.55, 0.55, 0.55)


func _craft() -> void:
	var groups := Save.free_stones().filter(func(s): return _key(s) == _pick)
	if groups.is_empty():
		return
	var st: Dictionary = groups[0]
	var req := MagicStones.craft_requirements(st, int(Save.data.tower_floor))
	if not req.ok:
		UI.notice(self, "Notice", String(req.reason) + ".")
		return
	if groups.size() < int(req.count):
		UI.notice(self, "Notice", "You need %d of this stone to craft." % int(req.count))
		return
	if int(Save.data.gold) < int(req.cost):
		UI.notice(self, "Notice", "Not enough Gold.")
		return
	if int(req.rank) == MagicStones.B:
		var body := VBoxContainer.new()
		var buttons := []
		for v in range(1, 4):
			var t := {"type": st.type, "rank": MagicStones.B, "variant": v}
			body.add_child(_brown(UI.label("%s:  %s" % [MagicStones.label(t), MagicStones.describe(t)], 18)))
			buttons.append({"text": MagicStones.VARIANTS[v], "color": "yellow", "cb": _do_craft.bind(int(st.uid), v)})
		buttons.append({"text": "Cancel", "color": "blue"})
		UI.dialog(self, "Choose a type", body, buttons)
		return
	_do_craft(int(st.uid), int(st.get("variant", 0)))


func _do_craft(stone_uid: int, variant: int) -> void:
	var r := Save.craft_stone(stone_uid, variant)
	if not r.ok:
		UI.notice(self, "Notice", String(r.reason))
		return
	Sfx.play("buff_big")
	_pick = _key(r.stone)
	_refresh_craft()
	UI.notice(self, "Craft", "Crafted %s!" % MagicStones.label(r.stone))


func _offer_box() -> void:
	UI.notice(self, "Notice", "The stone box holds %d stones. Craft or sell stones to make room." % int(Save.data.stone_cap))


func _refresh_equip() -> void:
	var m := Save.get_owned(uid)
	var def := DB.monster(m.id)
	lay.text("ID_LABEL_4", SORTS[_sort])
	var free := _sorted(Save.free_stones())
	lay.text("ID_numText", str(free.size()))
	lay.text("ID_maxText", "/%d" % int(Save.data.stone_cap))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for st in free:
		var tile := Layout.instance("B_stoneIcon_slide")
		tile.hide_all(["ID_stoneEmpty", "ID_att", "ID_check", "ID_numStone"])
		tile.show("ID_select", int(st.uid) == _stone)
		var icon := stone_icon(st, 92)
		icon.position = Vector2(4, 8)
		tile.root.add_child(icon)
		tile.root.move_child(icon, 1)
		tile.root.mouse_filter = MOUSE_FILTER_STOP
		tile.root.gui_input.connect(_on_stone.bind(int(st.uid)))
		grid.add_child(tile.root)
	if free.is_empty():
		var l := _brown(UI.label("No spare stones.\nClear Sky Tower floors to find some.", 19), 19)
		l.custom_minimum_size = Vector2(400, 100)
		grid.add_child(l)
	lay.list_into("ID_ID_arrayPosition", [grid])
	var art: Control = lay.node("ID_ev2")
	for c in art.get_children():
		if c.has_meta("art"):
			c.queue_free()
	var pic := UI.living(DB.battle_sprite(m.id), Vector2(170, 130))
	pic.set_meta("art", true)
	pic.position = Vector2(10, 22)
	art.add_child(pic)
	for g in 6:
		lay.show("ID_mon2Grade%d" % (g + 1), g < int(def.stars))
	lay.text("ID_level2", "Lv.%d/%d" % [int(m.level), Save.max_level(m)])
	lay.text("ID_stNum2", "+%d" % int(m.boost))
	lay.show("ID_maxLevel2", int(m.level) >= Save.max_level(m))
	var slots := Save.stone_slots(m)
	for i in 3:
		var n := i + 1
		var holder := lay.node("ID_stone%dIcon" % n)
		for c in holder.get_children():
			c.queue_free()
		var st := Save.stone_in_slot(m, i)
		if not st.is_empty():
			holder.add_child(stone_icon(st, 92))
		var locked := i >= slots
		lay.show("ID_LABEL_lock%d" % n, locked)
		if locked:
			var ll := lay.node("ID_LABEL_lock%d" % n) as Label
			ll.text = ""
			for c in ll.get_children():
				if c is Label:
					(c as Label).text = "%d Gems" % MagicStones.THIRD_SLOT_GEMS
		lay.show("ID_stone%dChange" % n, i == _slot and not locked)
	var st_sel := Save.get_stone(_stone) if _stone >= 0 else {}
	var base := DB.stats_at(m.id, int(m.level), int(m.boost))
	var cur := Save.stone_bonuses(m)
	var preview := cur.duplicate()
	if not st_sel.is_empty():
		var old := Save.stone_in_slot(m, _slot)
		var minus := MagicStones.bonuses(old) if not old.is_empty() else {}
		for k in minus:
			preview[k] = float(preview.get(k, 0.0)) - float(minus[k])
		var plus := MagicStones.bonuses(st_sel)
		for k in plus:
			preview[k] = float(preview.get(k, 0.0)) + float(plus[k])
	for row in STAT_ROWS:
		var key: String = row[0]
		lay.text(row[1], str(int(base.get("mp" if key == "max_mp" else key, 0))))
		var add := roundi(float(preview.get(key, 0.0)))
		var l := lay.text(row[2], ("+%d" % add) if add != 0 else "")
		if l:
			l.add_theme_color_override("font_color", Color("2a8a2a") if add >= roundi(float(cur.get(key, 0.0))) else Color("c0301a"))
	var extra := []
	for k in preview:
		if not k in ["hp", "atk", "def", "rec", "max_mp"] and float(preview[k]) != 0.0:
			extra.append("%s %s%d%%" % [MagicStones.STAT_NAMES[k], "-" if k == "cooldown" else "+", roundi(float(preview[k]) * 100.0)])
	lay.text("ID_textMana_2", ", ".join(extra) if not extra.is_empty() else "")
	(lay.node("ID_textMana_2") as Label).clip_text = true
	var lines := []
	for i in slots:
		var s := Save.stone_in_slot(m, i)
		if not s.is_empty():
			lines.append("- " + MagicStones.label(s) + ": " + MagicStones.describe(s))
	if lines.is_empty():
		lines.append("- Select a slot, then a stone from the list.")
	for k in 3:
		var l := _brown(lay.text("ID_ef%dText_1" % (k + 1), String(lines[k]) if k < lines.size() else ""), 15)
		l.clip_text = true
		l.size.x = 320
	var slot_stone := Save.stone_in_slot(m, _slot)
	lay.show("ID_btnRemove", not slot_stone.is_empty())
	var cost: int = MagicStones.EQUIP_COST[int(st_sel.rank)] if not st_sel.is_empty() else 0
	lay.text("ID_goldText", Screen._thousands(cost))
	lay.node("ID_btnEquip").modulate = Color.WHITE if not st_sel.is_empty() else Color(0.55, 0.55, 0.55)
	lay.show("ID_btnSell", not st_sel.is_empty())


func _pressed(e: InputEvent) -> bool:
	return UI.tapped(e)


func _on_slot(e: InputEvent, i: int) -> void:
	if not _pressed(e):
		return
	var m := Save.get_owned(uid)
	if i >= Save.stone_slots(m):
		var d := Layout.load_into(self, "R_d_conform_2button")
		d.root.z_index = 80
		d.node("ID_9PATCH_2").mouse_filter = MOUSE_FILTER_STOP
		d.text("ID_titleText", "Notice")
		var l := _brown(d.text("ID_baseText", "Unlock the 3rd stone slot for %d Gems?" % MagicStones.THIRD_SLOT_GEMS), 24)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var root := d.root
		d.on("ID_btnOk", _unlock.bind(root))
		d.on("ID_btnEsc", root.queue_free)
		return
	_slot = i
	Sfx.play("click")
	_refresh_equip()


func _unlock(root: Control) -> void:
	root.queue_free()
	if not Save.unlock_third_slot(uid):
		UI.notice(self, "Notice", "Not enough Gems.")
		return
	Sfx.play("buff_big")
	_slot = 2
	_refresh_equip()


func _on_stone(e: InputEvent, stone_uid: int) -> void:
	if not _pressed(e):
		return
	_stone = -1 if _stone == stone_uid else stone_uid
	Sfx.play("click")
	_refresh_equip()


func _card_art(d: Layout, m: Dictionary) -> void:
	var def := DB.monster(m.id)
	var pic := UI.living(DB.battle_sprite(m.id), Vector2(170, 130))
	pic.position = Vector2(10, 22)
	d.node("ID_ev1").add_child(pic)
	for g in 6:
		d.show("ID_mon1Grade%d" % (g + 1), g < int(def.stars))
	d.text("ID_level", "Lv.%d/%d" % [int(m.level), Save.max_level(m)])
	d.text("ID_stNum", "+%d" % int(m.boost))
	if d.has("ID_maxLevel"):
		d.show("ID_maxLevel", int(m.level) >= Save.max_level(m))


func _dialog(name: String) -> Layout:
	var d := Layout.load_into(self, name)
	d.root.z_index = 80
	d.node("ID_9PATCH_2").mouse_filter = MOUSE_FILTER_STOP
	return d


func _confirm_equip() -> void:
	var st := Save.get_stone(_stone) if _stone >= 0 else {}
	if st.is_empty():
		UI.notice(self, "Notice", "Select a Magic Stone from the list.")
		return
	var m := Save.get_owned(uid)
	var cost: int = MagicStones.EQUIP_COST[int(st.rank)]
	if int(Save.data.gold) < cost:
		UI.notice(self, "Notice", "Not enough Gold.")
		return
	var d := _dialog("R_d_comStone")
	d.text("ID_titleText", "Equip M. Stone")
	d.text("ID_LABEL_5", "OK")
	_card_art(d, m)
	d.put("ID_stone1", stone_icon(st, 92))
	d.text("ID_LABEL_2", MagicStones.TYPES[st.type].name)
	d.text("ID_probabilityText", "Equip cost %s" % Screen._thousands(cost))
	_brown(d.node("ID_LABEL_2") as Label, 18)
	_brown(d.node("ID_probabilityText") as Label, 16)
	var old := Save.stone_in_slot(m, _slot)
	var text := "Equip %s?" % MagicStones.label(st)
	if not old.is_empty():
		text += "\nThe equipped %s will be destroyed." % MagicStones.label(old)
	var l := _brown(d.text("ID_baseText", text), 21)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var root := d.root
	d.on("ID_btnOk", _equip.bind(root))
	d.on("ID_btnEsc", root.queue_free)


func _equip(root: Control) -> void:
	root.queue_free()
	var st := Save.get_stone(_stone)
	var r := Save.equip_stone(uid, _slot, _stone)
	if not r.ok:
		UI.notice(self, "Notice", String(r.reason))
		return
	Sfx.play("buff_big")
	_stone = -1
	_refresh_equip()
	var d := _dialog("R_d_comStone2")
	d.text("ID_titleText", "Equip M. Stone")
	_brown(d.text("ID_baseText", "The Magic Stone has been equipped.\n%s" % MagicStones.label(st)), 21).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_art(d, Save.get_owned(uid))
	var b := MagicStones.bonuses(st)
	var rows := {"hp": "ID_textHp", "atk": "ID_textAp", "def": "ID_textDp", "rec": "ID_textRe", "max_mp": "ID_textMana"}
	for k in rows:
		d.text(rows[k], ("+%d" % roundi(float(b[k]))) if b.has(k) else "-")
	var extra := []
	for k in b:
		if not rows.has(k):
			extra.append("%s %s%d%%" % [MagicStones.STAT_NAMES[k], "-" if k == "cooldown" else "+", roundi(float(b[k]) * 100.0)])
	d.text("ID_textMana_1", ", ".join(extra))
	(d.node("ID_textMana_1") as Label).clip_text = true
	var root2 := d.root
	d.on("ID_btnOk", root2.queue_free)
	d.on("ID_btnEsc", root2.queue_free)


func _confirm_remove() -> void:
	var m := Save.get_owned(uid)
	var st := Save.stone_in_slot(m, _slot)
	if st.is_empty():
		return
	var cost: int = MagicStones.UNEQUIP_COST[int(st.rank)]
	_ask("Remove %s for %s Gold?\nIt goes back to the stone box." % [MagicStones.label(st), Screen._thousands(cost)], _remove)


func _remove() -> void:
	var r := Save.unequip_stone(uid, _slot)
	if not r.ok:
		UI.notice(self, "Notice", String(r.reason))
		return
	Sfx.play("buff")
	_refresh_equip()


func _confirm_destroy() -> void:
	var st := Save.get_stone(_stone) if _stone >= 0 else {}
	if st.is_empty():
		return
	_ask("Sell %s?\nThe stone will disappear." % MagicStones.label(st), _destroy)


func _destroy() -> void:
	Save.data.stones.erase(Save.get_stone(_stone))
	Save.save_game()
	_stone = -1
	Sfx.play("buff")
	_refresh_equip()


func _ask(text: String, cb: Callable) -> void:
	var d := _dialog("R_d_conform_2button")
	d.text("ID_titleText", "Notice")
	var l := _brown(d.text("ID_baseText", text), 22)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var root := d.root
	d.on("ID_btnOk", _ask_ok.bind(root, cb))
	d.on("ID_btnEsc", root.queue_free)


func _ask_ok(root: Control, cb: Callable) -> void:
	root.queue_free()
	cb.call()
