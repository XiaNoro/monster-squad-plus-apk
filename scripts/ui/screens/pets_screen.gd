class_name PetsScreen
extends Screen

const SORTS := ["Obtained", "Grade", "Element"]
const ELEMENT_ORDER := ["fire", "water", "nature", "normal"]
const STAT_ROWS := [["hp", "ID_HP", "ID_LABEL_HP", "HP:"], ["atk", "ID_ATK", "ID_LABEL_ATK", "ATK:"], ["def", "ID_DEF", "ID_LABEL_DEF", "DEF:"], ["rec", "ID_REC", "ID_LABEL_REC", "REC:"]]
const STAT_NAMES := {"hp": "HP", "atk": "ATK", "def": "DEF", "crit": "Critical Hit"}
const SELL_MAX := 20
const BLUE := Color8(0, 76, 146)
const RED := Color8(178, 7, 7)

var lay: Layout
var uid := -1
var _sort := 0
var _pick := -1
var _gems := true
var _selling := false
var _marked: Array = []


func build() -> void:
	UI.brown_background(self)
	uid = int(args.get("uid", -1))
	lay = Layout.load_into(self, "R_comMain_Pet_Page")
	add_top_bar("2", "Pet", String(args.get("back", "squad")))
	_back_args = args.get("back_args", {})
	lay.on("ID_btnAlign", _next_sort)
	lay.on("ID_petSell", _set_selling.bind(true))
	lay.on("ID_petReturn", _set_selling.bind(false))
	lay.on("ID_btnChange ", _toggle_currency)
	lay.on("ID_btnChangPET", _confirm_equip)
	lay.on("ID_btnSell_1", _confirm_sell)
	lay.text("ID_LABEL_2", "Equip Pet")
	lay.text("ID_sell_title", "Pet Sell")
	lay.text("ID_maxText_1", "/ %d" % SELL_MAX)
	lay.text("ID_maxText", "")
	for row in STAT_ROWS:
		lay.text(row[1], row[3])
	_refresh()


func _monster() -> Dictionary:
	return Save.get_owned(uid) if uid >= 0 else {}


func _sorted(list: Array) -> Array:
	var out := list.duplicate()
	match SORTS[_sort]:
		"Grade":
			out.sort_custom(func(a, b): return int(DB.pet(a.id).stars) > int(DB.pet(b.id).stars) or (int(DB.pet(a.id).stars) == int(DB.pet(b.id).stars) and int(a.uid) < int(b.uid)))
		"Element":
			out.sort_custom(func(a, b): return _element_rank(a) < _element_rank(b) or (_element_rank(a) == _element_rank(b) and int(a.uid) < int(b.uid)))
		_:
			out.sort_custom(func(a, b): return int(a.uid) < int(b.uid))
	return out


func _element_rank(p: Dictionary) -> int:
	var i := ELEMENT_ORDER.find(String(DB.pet(p.id).element))
	return i if i >= 0 else ELEMENT_ORDER.size()


func _refresh() -> void:
	var has_mon := not _monster().is_empty()
	lay.show("ID_petupgrade", has_mon and not _selling)
	lay.show("ID_sell", _selling)
	lay.show("ID_petSell", not _selling)
	lay.show("ID_petReturn", _selling)
	lay.text("ID_LABEL_4", SORTS[_sort])
	var free := _sorted(Save.free_pets())
	lay.text("ID_numText", str(free.size()))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	for pt in free:
		var marked := _marked.has(int(pt.uid))
		var tile := pet_tile(pt, int(pt.uid) == _pick and not _selling, marked)
		tile.mouse_filter = MOUSE_FILTER_STOP
		tile.gui_input.connect(_on_tile.bind(int(pt.uid)))
		grid.add_child(tile)
	if free.is_empty():
		var l := _brown(UI.label("No pets yet.\nHatch Pet Eggs in the Cube Shop.", 19), 19)
		l.custom_minimum_size = Vector2(400, 100)
		grid.add_child(l)
	lay.list_into("ID_ID_arrayPosition", [grid])
	if _selling:
		_refresh_sell()
	elif has_mon:
		_refresh_install()


static func pet_tile(pt: Dictionary, selected: bool = false, checked: bool = false) -> Control:
	var def := DB.pet(pt.id)
	var tile := Layout.instance("B_petIcon_slide")
	tile.hide_all(["ID_att_F", "ID_monOpacity", "ID_9PATCH_1"])
	tile.show("ID_select", selected)
	tile.show("ID_check", checked)
	tile.set_image("ID_att", UI.tex("betaUI00/" + UI.ELEMENT_FRAMES.get(String(def.element), "M_attBalance_01.png")))
	var rare := String(def.get("cube", "normal")) == "rare"
	tile.show("ID_grade", not rare)
	tile.show("ID_grade_pay", rare)
	for g in 4:
		tile.show("ID_grade%d" % (g + 1), g < int(def.stars))
	var pic := UI.image(DB.pet_texture(String(pt.id)), Vector2(80, 70))
	pic.size = Vector2(80, 70)
	pic.position = Vector2(10, 22)
	var att := tile.node("ID_att")
	att.get_parent().add_child(pic)
	att.get_parent().move_child(pic, att.get_index())
	var sel := tile.node("ID_select")
	sel.get_parent().move_child(sel, -1)
	return tile.root


func _refresh_install() -> void:
	var m := _monster()
	var def := DB.monster(m.id)
	var art: Control = lay.node("ID_ev1")
	for c in art.get_children():
		if c.has_meta("art"):
			c.queue_free()
	var pic := UI.living(DB.battle_sprite(m.id), Vector2(170, 130))
	pic.set_meta("art", true)
	pic.position = Vector2(10, 22)
	art.add_child(pic)
	for g in 6:
		lay.show("ID_mon1Grade%d" % (g + 1), g < int(def.stars))
	lay.text("ID_level", "Lv.%d/%d" % [int(m.level), Save.max_level(m)])
	lay.text("ID_stNum", "+%d" % int(m.boost))
	lay.show("ID_maxLevel", int(m.level) >= Save.max_level(m))
	var equipped := Save.pet_of(m)
	var pt := _picked()
	var shown := pt if not pt.is_empty() else equipped
	var slot: Control = lay.node("ID_petDetail")
	for c in slot.get_children():
		if c.has_meta("art"):
			c.queue_free()
	var pdef := DB.pet(shown.id) if not shown.is_empty() else {}
	var rare := String(pdef.get("cube", "normal")) == "rare"
	for g in 4:
		lay.show("ID_mon1Grade%d_1" % (g + 1), not rare and g < int(pdef.get("stars", 0)))
	lay.show("ID_mon1Grade4_pay", rare)
	lay.show("ID_mon1Sh_1", not shown.is_empty())
	if not shown.is_empty():
		var ppic := UI.living(DB.pet_texture(String(shown.id)), Vector2(130, 100))
		ppic.set_meta("art", true)
		ppic.position = Vector2(30, 34)
		slot.add_child(ppic)
	var cond := _brown(lay.text("ID_TextCondition", ""), 18)
	var info := _brown(lay.text("ID_InfoDetail_1", ""), 18)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cond.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for row in STAT_ROWS:
		lay.text(row[2], "")
	var cost := 0
	if not pt.is_empty():
		var need: int = DB.PET_LEVEL.get(int(pdef.stars), 30)
		cond.text = "Can be equipped on monsters level %d and above" % need
		cond.add_theme_color_override("font_color", UI.BROWN if int(m.level) >= need else RED)
		var old_stats: Dictionary = DB.pet(equipped.id).stats if not equipped.is_empty() else {}
		for row in STAT_ROWS:
			var v := int(pdef.stats.get(row[0], 0))
			var diff := v - int(old_stats.get(row[0], 0))
			var l := lay.text(row[2], "%d(%s%d)" % [v, "+" if diff >= 0 else "", diff])
			l.add_theme_color_override("font_color", BLUE if diff >= 0 else RED)
		info.text = "Add : " + passive_text(pt)
		var c := Save.pet_equip_cost(pt)
		cost = int(c.gems) if _gems else int(c.gold)
	elif not equipped.is_empty():
		cond.text = "Equipped: %s" % String(pdef.name)
		cond.add_theme_color_override("font_color", BLUE)
		for row in STAT_ROWS:
			lay.text(row[2], str(int(pdef.stats.get(row[0], 0)))).add_theme_color_override("font_color", BLUE)
		info.text = "Add : " + passive_text(equipped)
	else:
		cond.text = "No pet equipped. Select a pet from the Pet List."
		cond.add_theme_color_override("font_color", UI.BROWN)
	lay.text("ID_LABEL_5", Screen._thousands(cost))
	lay.show("ID_Crtstal", _gems)
	lay.show("ID_gold", not _gems)
	lay.text("ID_LABEL_2", "Equip Pet" if equipped.is_empty() else "Change Pet")
	lay.node("ID_btnChangPET").modulate = Color.WHITE if not pt.is_empty() else Color(0.55, 0.55, 0.55)


static func passive_text(pt: Dictionary) -> String:
	var def := DB.pet(pt.id)
	var i := int(pt.get("passive", -1))
	if i < 0 or i >= def.passives.size():
		return ""
	var p: Dictionary = def.passives[i]
	return "[Pet] Increases %s Monsters' %s by %d%%" % [String(p.element).capitalize(), STAT_NAMES.get(String(p.stat), String(p.stat).to_upper()), roundi(float(p.pct) * 100.0)]


func _picked() -> Dictionary:
	for p in Save.free_pets():
		if int(p.uid) == _pick:
			return p
	return {}


func _refresh_sell() -> void:
	var total := 0
	var icons := GridContainer.new()
	icons.columns = 4
	for u in _marked:
		for p in Save.data.pets:
			if int(p.uid) == int(u):
				total += Save.pet_sell_price(p)
				icons.add_child(pet_tile(p))
	lay.text("ID_numberText", "%02d" % _marked.size())
	lay.text("ID_numberText_1", Screen._thousands(total))
	lay.show("ID_PushText", _marked.is_empty())
	lay.text("ID_TextPush", "Select pets to sell")
	var holder: Control = lay.node("ID_sellect_position")
	for c in holder.get_children():
		c.queue_free()
	holder.add_child(icons)


func _on_tile(e: InputEvent, pet_uid: int) -> void:
	if not UI.tapped(e):
		return
	Sfx.play("click")
	if _selling:
		if _marked.has(pet_uid):
			_marked.erase(pet_uid)
		elif _marked.size() < SELL_MAX:
			_marked.append(pet_uid)
	else:
		_pick = -1 if _pick == pet_uid else pet_uid
	_refresh()


func _next_sort() -> void:
	_sort = (_sort + 1) % SORTS.size()
	_refresh()


func _set_selling(on: bool) -> void:
	_selling = on
	_marked.clear()
	_refresh()


func _toggle_currency() -> void:
	_gems = not _gems
	Sfx.play("click")
	_refresh()


func _confirm_equip() -> void:
	var pt := _picked()
	if pt.is_empty():
		UI.notice(self, "Notice", "Select a pet from the Pet List.")
		return
	var m := _monster()
	var need: int = DB.PET_LEVEL.get(int(DB.pet(pt.id).stars), 30)
	if int(m.level) < need:
		UI.notice(self, "Notice", "Can be equipped on monsters level %d and above." % need)
		return
	var text := "Equip Pet?"
	if not Save.pet_of(m).is_empty():
		text += "\nThe equipped %s will disappear." % DB.pet(Save.pet_of(m).id).name
	_ask("Confirm", text, _equip)


func _equip() -> void:
	var r := Save.equip_pet(uid, _pick, _gems)
	if not r.ok:
		UI.notice(self, "Notice", String(r.reason))
		return
	Sfx.play("buff_big")
	_pick = -1
	_refresh()
	UI.notice(self, "Notice", "Pet has been successfully equipped (switched)")


func _confirm_sell() -> void:
	if _marked.is_empty():
		UI.notice(self, "Notice", "Select pets to sell.")
		return
	var total := 0
	for u in _marked:
		for p in Save.data.pets:
			if int(p.uid) == int(u):
				total += Save.pet_sell_price(p)
	_ask("Notice", "Sell %d pets for %s Gold?" % [_marked.size(), Screen._thousands(total)], _sell)


func _sell() -> void:
	var gold := 0
	for u in _marked:
		gold += Save.sell_pet(int(u))
	Save.save_game()
	Sfx.play("buff")
	UI.toast(self, "Sold %d pets for %s gold" % [_marked.size(), Screen._thousands(gold)], UI.GOLD)
	_marked.clear()
	_refresh()


func _brown(l: Label, font: int = 18) -> Label:
	if l == null:
		return l
	l.add_theme_color_override("font_color", UI.BROWN)
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	l.add_theme_font_size_override("font_size", font)
	return l


func _ask(title: String, text: String, cb: Callable) -> void:
	var d := Layout.load_into(self, "R_d_conform_2button")
	d.root.z_index = 80
	d.node("ID_9PATCH_2").mouse_filter = MOUSE_FILTER_STOP
	d.text("ID_titleText", title)
	var l := _brown(d.text("ID_baseText", text), 22)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var root := d.root
	d.on("ID_btnOk", func():
		root.queue_free()
		cb.call())
	d.on("ID_btnEsc", root.queue_free)
