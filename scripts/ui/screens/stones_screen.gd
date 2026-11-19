class_name StonesScreen
extends Screen

const CAT_TABS := {"attack": "ID_tapATK", "defense": "ID_tapDEF", "skill": "ID_tapSK"}
const TYPE_TINT := {"bravery": Color("ff6a4a"), "windfury": Color("9cf06a"), "thunder": Color("ffe24a"), "destruction": Color("ff4aa8"),
	"vitality": Color("ff9a9a"), "steel": Color("b8c8d8"), "blessed": Color("7affc8"), "time": Color("8ab8ff"), "clarity": Color("6ae8ff"), "spirit": Color("c88aff")}
const SORTS := ["Rank", "Type", "Recent"]
const RANK_FILTERS := ["ALL", "E", "D", "C", "B", "A", "S", "S+"]
const STAT_ROWS := [["hp", "ID_textHp2", "ID_textHp2_1"], ["atk", "ID_textAp2", "ID_textAp2_1"], ["def", "ID_textDp2", "ID_textDp2_1"], ["rec", "ID_textRe2", "ID_textRe2_1"], ["max_mp", "ID_textMana2", "ID_textMana2_1"]]
const LIST_CUT := 58.0
const CRAFT_SELL_SCALE := 0.8

var lay: Layout
var _box: Layout
var uid := -1
var _cat := "attack"
var _sort := 0
var _rank := 0
var _pick := ""
var _slot := 0


func build() -> void:
	UI.brown_background(self)
	uid = int(args.get("uid", -1))
	if uid >= 0 and not Save.get_owned(uid).is_empty():
		lay = Layout.load_into(self, "R_comStonePage")
		_box = lay
		add_top_bar("2", "Magic Stones", String(args.get("back", "squad")))
		_back_args = args.get("back_args", {"mode": "train", "uid": uid})
		lay.on("ID_btnAlign", _next_sort)
		lay.on("ID_btnEquip", _confirm_equip)
		lay.on("ID_btnRemove", _confirm_remove)
		lay.text("ID_LABEL_6", "Equip Cost")
		for i in 3:
			var s := lay.node("ID_stone%d" % (i + 1))
			s.mouse_filter = MOUSE_FILTER_STOP
			s.gui_input.connect(_on_slot.bind(i))
	else:
		lay = Layout.load_into(self, "R_comStonePage_create")
		add_top_bar("2", "Craft M. Stone", String(args.get("back", "hub")))
		_borrow_box()
		for c in CAT_TABS:
			lay.on(CAT_TABS[c], _set_cat.bind(c))
		lay.on("ID_btnAlign", _next_rank)
		lay.on("ID_btnCreate", _craft)
		lay.show("ID_txtUnique", false)
	_box.on("ID_btnAdd", _expand)
	_box.on("ID_btnSell", _open_sell)
	_box.text("ID_LABEL_1", "Sell")
	if uid >= 0:
		_refresh_equip()
	else:
		_set_cat("attack")


func _borrow_box() -> void:
	var donor := Layout.load_into(self, "R_comStonePage", Vector2.ZERO, Layout.SCREEN_H, "")
	_box = donor
	(donor.node("ID_9PATCH_4_1") as Control).reparent(lay.node("ID_stoneList"), false)
	var sell := donor.node("ID_btnSell") as Control
	var matl := lay.node("ID_9PATCH_infoMatl") as Control
	sell.reparent(matl, false)
	sell.scale = Vector2.ONE * CRAFT_SELL_SCALE
	sell.position = Vector2(matl.size.x - sell.size.x * CRAFT_SELL_SCALE - 8.0, -2.0)
	donor.root.queue_free()
	var panel := lay.node("ID_9PATCH_5") as Control
	panel.size.y -= LIST_CUT
	for id in ["ID_slide", "ID_bar", "ID_arrayPosition"]:
		var c := lay.node(id) as Control
		c.size.y -= LIST_CUT


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
		l.position = Vector2(64, 4) * s
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


static func stone_slot_art(area: Vector2) -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size = area
	var t := minf(area.x, area.y) * 0.62
	var tile := UI.image(UI.tex("betaUI00/B_monEmpty_04.png"), Vector2(t, t))
	tile.size = Vector2(t, t)
	tile.position = (area - tile.size) / 2.0
	box.add_child(tile)
	var arrow := UI.image(UI.tex("betaUI00/I_arrow_03.png"), Vector2(t * 0.42, t * 0.5))
	arrow.size = Vector2(t * 0.42, t * 0.5)
	arrow.pivot_offset = arrow.size / 2.0
	arrow.rotation = PI
	arrow.modulate = Color(1.0, 0.25, 0.35)
	arrow.position = tile.position + tile.size - arrow.size * Vector2(0.75, 0.8)
	box.add_child(arrow)
	return box


static func offer_stone_slots(parent: Control, full: bool = false, on_done: Callable = Callable()) -> void:
	CubesScreen.offer_purchase(parent, "Expand Stone Slots", stone_slot_art(Vector2(208, 210)),
		"Not enough inventory slots.\nWould you like to make a purchase?" if full else "Would you like to make a purchase?",
		"Use a gem to expand your Magic Stone slots.", MagicStones.STONE_SLOT_GEMS, Save.expand_stone_box,
		func() -> String: return "Magic Stone slots expanded.", on_done)


func _refresh() -> void:
	if uid >= 0:
		_refresh_equip()
	else:
		_refresh_craft()


func _refresh_bar() -> void:
	_box.text("ID_numText", str(Save.free_stones().size()))
	_box.text("ID_maxText", "/%d" % int(Save.data.stone_cap))
	var stack := _picked_stack()
	_box.node("ID_btnSell").modulate = Color.WHITE if not stack.is_empty() else Color(0.6, 0.6, 0.6)


func _expand() -> void:
	offer_stone_slots(self, false, _refresh)


func _next_sort() -> void:
	_sort = (_sort + 1) % SORTS.size()
	_refresh()


func _next_rank() -> void:
	_rank = (_rank + 1) % RANK_FILTERS.size()
	_pick = ""
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


func _by_recipe(list: Array) -> Array:
	var order := MagicStones.TYPES.keys()
	var out := list.duplicate()
	out.sort_custom(func(a, b):
		var ta := order.find(a.type)
		var tb := order.find(b.type)
		if ta != tb:
			return ta < tb
		if int(a.rank) != int(b.rank):
			return int(a.rank) < int(b.rank)
		return int(a.get("variant", 0)) < int(b.get("variant", 0)))
	return out


func _picked_stack() -> Dictionary:
	if _pick == "":
		return {}
	for s in Save.stone_stacks(Save.free_stones()):
		if s.key == _pick:
			return s
	return {}


func _picked_uid() -> int:
	var s := _picked_stack()
	return int(s.uids[0]) if not s.is_empty() else -1


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


func _craft_stacks() -> Array:
	var out := []
	for s in Save.stone_stacks(_by_recipe(Save.free_stones())):
		var st: Dictionary = s.stone
		if String(MagicStones.TYPES[st.type].cat) != _cat:
			continue
		if _rank > 0 and int(st.rank) != _rank - 1:
			continue
		out.append(s)
	return out


func _refresh_craft() -> void:
	lay.text("ID_LABEL_4", RANK_FILTERS[_rank])
	var stacks := _craft_stacks()
	var keys := stacks.map(func(s): return s.key)
	if not _pick in keys:
		_pick = keys[0] if not keys.is_empty() else ""
	var rows := []
	for s in stacks:
		rows.append(_stone_row(s.stone, s.uids.size(), s.key == _pick, _select_group.bind(s.key)))
	if rows.is_empty():
		var what := "" if _rank == 0 else "rank %s " % RANK_FILTERS[_rank]
		var l := _brown(UI.label("No %s%s stones.\nClear Sky Tower floors to find Magic Stones." % [what, _cat], 20), 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(400, 120)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rows.append(l)
	lay.list_into("ID_arrayPosition", rows, 2)
	_fill_craft(_picked_stack())
	_refresh_bar()


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


func _craft_result(st: Dictionary) -> Dictionary:
	if int(st.rank) >= MagicStones.SP:
		return st
	var next := int(st.rank) + 1
	return {"type": st.type, "rank": next, "variant": 0 if next == MagicStones.B else int(st.get("variant", 0))}


func _fill_craft(stack: Dictionary) -> void:
	var holder := lay.node("ID_previewStone")
	for c in holder.get_children():
		if c.has_meta("icon"):
			c.queue_free()
	for k in 4:
		var m := lay.node("ID_Matl%d" % (k + 1))
		for c in m.get_children():
			c.queue_free()
		lay.show("ID_Matl_%d" % (k + 1), false)
	if stack.is_empty():
		lay.text("ID_txtStoneName", "-")
		lay.text("ID_txtStoneDes", "")
		lay.text("ID_txtCondition", "")
		lay.text("ID_goldText", "0")
		lay.node("ID_btnCreate").modulate = Color(0.55, 0.55, 0.55)
		return
	var st: Dictionary = stack.stone
	var have: int = stack.uids.size()
	var top := int(st.rank) >= MagicStones.SP
	var result := _craft_result(st)
	var icon := stone_icon(result, 120)
	icon.set_meta("icon", true)
	icon.position = Vector2(22, 18)
	holder.add_child(icon)
	UI.fit_text(lay.text("ID_txtStoneName", MagicStones.label(result)), 22, 14)
	var lines := "- " + MagicStones.describe(result).replace(",  ", "\n- ")
	if int(result.rank) == MagicStones.B and not top:
		lines += "\n- Pick I, II or III when crafting"
	var des := _brown(lay.text("ID_txtStoneDes", lines), 16)
	des.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lay.text("ID_txtMatl", "Material")
	var req := MagicStones.craft_requirements(st, int(Save.data.tower_floor))
	var need := int(req.get("count", 0))
	var cond := lay.text("ID_txtCondition", "")
	if top:
		cond.text = "Highest rank. It can't be crafted further."
		_brown(cond, 20)
	elif not req.ok:
		cond.text = "Required Skytower's floor : %d" % int(req.get("floor", 0))
		cond.add_theme_color_override("font_color", Color("e0301a"))
	else:
		cond.text = "Can craft: %d" % (have / need if need > 0 else 0)
		_brown(cond, 20)
	if not top:
		need = int(req.get("count", MagicStones.CRAFT_COUNT[int(st.rank) + 1]))
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
	lay.text("ID_goldText", Screen._thousands(int(req.get("cost", 0))) if not top else "-")
	lay.node("ID_btnCreate").modulate = Color.WHITE if req.ok and have >= need else Color(0.55, 0.55, 0.55)


func _craft() -> void:
	var stack := _picked_stack()
	if stack.is_empty():
		return
	var st: Dictionary = stack.stone
	var req := MagicStones.craft_requirements(st, int(Save.data.tower_floor))
	if not req.ok:
		UI.notice(self, "Notice", String(req.reason) + ".")
		return
	if stack.uids.size() < int(req.count):
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
	_refresh_craft()
	UI.notice(self, "Craft", "Crafted %s!" % MagicStones.label(r.stone))


func _open_sell() -> void:
	var stack := _picked_stack()
	if stack.is_empty():
		UI.notice(self, "Notice", "Select a Magic Stone from the list.")
		return
	var st: Dictionary = stack.stone
	var have: int = stack.uids.size()
	var price: int = MagicStones.SELL_PRICE[clampi(int(st.rank), 0, MagicStones.SELL_PRICE.size() - 1)]
	var d := _dialog("R_d_sellStone1")
	d.text("ID_titleText", "Sell M. Stone")
	d.text("ID_LABEL_5", "Sell")
	d.show("ID_stoneSh", false)
	var msg := _brown(d.text("ID_baseText", "Sell this Magic Stone?\n%s" % MagicStones.label(st)), 20)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var info := d.node("ID_stoneInfo") as Control
	var icon := stone_icon(st, 132)
	icon.position = (info.size - icon.size) / 2.0
	info.add_child(icon)
	var state := {"n": 1}
	var num := d.node("ID_txtNum") as Label
	var gold := d.node("ID_priceText") as Label
	var show := func() -> void:
		num.text = "%d / %d" % [int(state.n), have]
		gold.text = Screen._thousands(price * int(state.n))
	show.call()
	var root := d.root
	d.on("ID_btnDown", func() -> void:
		state.n = maxi(1, int(state.n) - 1)
		show.call())
	d.on("ID_btnUp", func() -> void:
		state.n = mini(have, int(state.n) + 1)
		show.call())
	d.on("ID_btnOk", func() -> void:
		root.queue_free()
		var got := Save.sell_stones(stack.uids.slice(0, int(state.n)))
		if got <= 0:
			return
		Sfx.play("coin")
		UI.toast(self, "+%s Gold" % Screen._thousands(got), UI.GOLD)
		_refresh())
	d.on("ID_btnEsc", root.queue_free)


func _refresh_equip() -> void:
	var m := Save.get_owned(uid)
	var def := DB.monster(m.id)
	lay.text("ID_LABEL_4", SORTS[_sort])
	var stacks := Save.stone_stacks(_sorted(Save.free_stones()))
	if not stacks.any(func(s): return s.key == _pick):
		_pick = ""
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for s in stacks:
		var tile := Layout.instance("B_stoneIcon_slide")
		tile.hide_all(["ID_stoneEmpty", "ID_att", "ID_check"])
		tile.show("ID_select", s.key == _pick)
		var icon := stone_icon(s.stone, 92)
		var slot := tile.node("ID_stoneEmpty")
		icon.position = slot.position
		slot.get_parent().add_child(icon)
		slot.get_parent().move_child(icon, slot.get_index() + 1)
		var count: int = s.uids.size()
		tile.show("ID_numStone", count > 1)
		var n := tile.text("ID_numStone", str(count))
		if n:
			n.add_theme_constant_override("outline_size", 5)
			n.add_theme_color_override("font_outline_color", Color("000d2e"))
		tile.root.mouse_filter = MOUSE_FILTER_STOP
		tile.root.gui_input.connect(_on_stone.bind(String(s.key)))
		grid.add_child(tile.root)
	if stacks.is_empty():
		var l := _brown(UI.label("No spare stones.\nClear Sky Tower floors to find some.", 19), 19)
		l.custom_minimum_size = Vector2(400, 100)
		grid.add_child(l)
	lay.list_into("ID_ID_arrayPosition", [grid])
	_refresh_bar()
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
	var sel_uid := _picked_uid()
	var st_sel := Save.get_stone(sel_uid) if sel_uid >= 0 else {}
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


func _on_stone(e: InputEvent, key: String) -> void:
	if not _pressed(e):
		return
	_pick = "" if _pick == key else key
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
	var sel := _picked_uid()
	var st := Save.get_stone(sel) if sel >= 0 else {}
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
	d.on("ID_btnOk", _equip.bind(root, sel))
	d.on("ID_btnEsc", root.queue_free)


func _equip(root: Control, stone_uid: int) -> void:
	root.queue_free()
	var st := Save.get_stone(stone_uid)
	var r := Save.equip_stone(uid, _slot, stone_uid)
	if not r.ok:
		UI.notice(self, "Notice", String(r.reason))
		return
	Sfx.play("buff_big")
	_pick = ""
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
	if Save.stone_box_full():
		UI.notice(self, "Notice", "Not enough inventory slots.\nSell Magic Stones or expand the stone box first.")
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
