class_name MonsterPopup
extends RefCounted

const ELEMENT_ICONS := {"fire": "A_fire_05.png", "water": "A_water_05.png", "nature": "A_natural_05.png"}

var lay: Layout
var uid: int
var actions: Dictionary
var screen: Control
var info_only := false
var preview: Dictionary = {}


static func info_of(parent: Control, id: String, level: int = 1, z: int = 90) -> MonsterPopup:
	return info(parent, -1, z, {"uid": -1, "id": id, "level": level, "exp": 0, "boost": 0, "locked": false})


static func info(parent: Control, monster_uid: int, z: int = 70, given: Dictionary = {}) -> MonsterPopup:
	var p := MonsterPopup.new()
	p.screen = parent
	p.uid = monster_uid
	p.actions = {}
	p.info_only = true
	p.preview = given
	p.lay = Layout.load_into(parent, "R_d_comMainPage")
	p.lay.root.z_index = z
	p.lay.root.set_meta("popup", p)
	p.lay.node("ID_9PATCH_2").mouse_filter = Control.MOUSE_FILTER_STOP
	p.lay.on("ID_btnEsc", p.close)
	p.lay.on("ID_btnOk", p.close)
	p.lay.sound(["ID_btnOk"], "popup_ok")
	p.lay.on("ID_btnEV", p._show_tree)
	p.lay.text("ID_LABEL_5_1", "OK")
	p.refresh()
	return p


static func open(parent: Control, monster_uid: int, callbacks: Dictionary) -> MonsterPopup:
	var p := MonsterPopup.new()
	p.screen = parent
	p.uid = monster_uid
	p.actions = callbacks
	p.lay = Layout.load_into(parent, "R_d_comMainPage")
	p.lay.root.z_index = 45
	p.lay.root.set_meta("popup", p)
	p.lay.node("ID_9PATCH_2").mouse_filter = Control.MOUSE_FILTER_STOP
	p._wire()
	p.refresh()
	return p


func close() -> void:
	if is_instance_valid(lay.root):
		lay.root.queue_free()


func _wire() -> void:
	lay.on("ID_btnEsc", close)
	lay.show("ID_btnOk", false)
	lay.hide_all(["ID_eventTag_St", "ID_eventTag_Ev"])
	lay.text("ID_LABEL_5", "Boost")
	lay.on("ID_btnComSt", _act.bind("boost"))
	lay.on("ID_btnComEv", _act.bind("fusion"))
	lay.on("ID_btnComStone", _act.bind("stones"))
	lay.on("ID_btnComTrans", _act.bind("awaken"))
	lay.on("ID_btnExpBoost", _act.bind("feed"))
	lay.on("ID_btnPet", _act.bind("pet"))
	lay.on("ID_btnEV", _show_tree)
	var art: Control = lay.node("ID_ev1")
	art.mouse_filter = Control.MOUSE_FILTER_STOP
	art.gui_input.connect(_on_art_input)
	if actions.has("change"):
		var b := UI.button("Change", _act.bind("change"), "blue", Vector2(130, 60), 20)
		var frame: Control = lay.node("ID_detail")
		b.position = Vector2(-138, 14)
		frame.add_child(b)


func _act(what: String) -> void:
	if not actions.has(what):
		return
	if what in ["lock"]:
		actions[what].call(uid)
		refresh()
		return
	close()
	actions[what].call(uid)


func _on_art_input(e: InputEvent) -> void:
	if not UI.tapped(e):
		return
	var m := Save.get_owned(uid)
	var body := UI.label("Lock it to keep it safe from selling and feeding.", 20, UI.BROWN)
	body.add_theme_constant_override("outline_size", 0)
	var buttons := [{"text": "Unlock" if m.locked else "Lock", "color": "yellow", "cb": _act.bind("lock")}]
	if actions.has("sell") and not m.locked:
		buttons.append({"text": "Sell", "color": "orange", "cb": _act.bind("sell")})
	buttons.append({"text": "Cancel", "color": "blue"})
	var d := UI.dialog(screen, String(DB.monster(m.id).name), body, buttons)
	d.z_index = 60


func refresh() -> void:
	if preview.is_empty() and Save.get_owned(uid).is_empty():
		close()
		return
	fill(lay, uid, screen, preview)
	if info_only:
		lay.hide_all(["ID_btnComSt", "ID_btnComEv", "ID_btnComStone", "ID_btnComTrans", "ID_btnExpBoost", "ID_btnPet", "ID_stoneEq", "ID_popup_fusion_lock", "ID_IMAGE_5"])
		var ok: Control = lay.node("ID_btnOk")
		ok.visible = true
		ok.position.x = (lay.node("ID_upgrade").size.x - ok.size.x) / 2.0


static func fill(lay: Layout, uid: int, screen: Control, given: Dictionary = {}) -> void:
	var m := given if not given.is_empty() else Save.get_owned(uid)
	var def := DB.monster(m.id)
	var stars := int(def.get("stars", 1))
	var cap := Save.max_level(m)
	lay.text("ID_monName", String(def.name))
	lay.set_image("ID_mon1att", Layout.texture(ELEMENT_ICONS.get(def.get("element", ""), "A_balance_05.png")))

	var art: Control = lay.node("ID_ev1")
	for c in art.get_children():
		if c.has_meta("art"):
			c.queue_free()
	var pic := UI.living(DB.battle_sprite(m.id), Vector2(170, 130))
	pic.set_meta("art", true)
	pic.position = Vector2(10, 22)
	art.add_child(pic)
	art.move_child(pic, 1)
	for g in 6:
		lay.show("ID_mon1Grade%d" % (g + 1), g < stars)
	lay.text("ID_level", "Lv.%d/%d" % [int(m.level), cap])
	lay.text("ID_stNum", "+%d" % int(m.boost))
	lay.show("ID_stNum", int(m.boost) > 0)
	lay.show("ID_maxLevel", int(m.level) >= cap)
	lay.show("ID_IMAGE_5", bool(m.locked))

	var st := DB.stats_at(m.id, int(m.level), int(m.boost))
	var bonus := Save.stone_bonuses(m)
	var pet := Save.pet_spec(m)
	var pet_stats: Dictionary = pet.get("stats", {})
	for row in [["Hp", "hp"], ["Ap", "atk"], ["Dp", "def"], ["Re", "rec"]]:
		var extra := int(bonus.get(row[1], 0)) + int(pet_stats.get(row[1], 0))
		lay.text("ID_text" + row[0], str(int(st[row[1]])))
		lay.text("ID_text%s2" % row[0], ("+%d" % extra) if extra > 0 else "")
	var class_box: Control = lay.node("ID_class")
	for c in class_box.get_children():
		c.queue_free()
	var cl := UI.label("Class %s" % String(def.get("class", "?")), 20, Color("e7a0ff"))
	cl.size = class_box.size
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	class_box.add_child(cl)

	var ids := ["ID_leaderSkill1", "ID_leaderSkill2", "ID_leaderSkill3", "ID_leaderSkill4"]
	for k in ids.size():
		var s: Dictionary = def.skills[k] if k < def.skills.size() else {}
		_skill(lay, screen, ids[k], s.get("icon", ""), ("%s (%d MP): %s" % [s.name, int(s.mp), s.description]) if not s.is_empty() else "")
	var sup: Dictionary = def.support_skill
	_skill(lay, screen, "ID_leaderSkill6", sup.get("icon", "") if String(sup.get("name", "")) != "" else "", "%s (support, every %ds): %s" % [sup.get("name", ""), int(sup.get("cooldown", 0)), sup.get("description", "")])

	for k in MagicStones.MAX_SLOTS:
		var holder: Control = lay.node("ID_stoneEq%d" % (k + 1))
		for c in holder.get_children():
			c.queue_free()
		var stone := Save.stone_in_slot(m, k)
		lay.show("ID_epLock%d" % (k + 1), k >= Save.stone_slots(m))
		if not stone.is_empty():
			var icon := UI.image(MagicStones.badge(int(stone.rank)), Vector2(40, 40))
			icon.size = Vector2(40, 40)
			icon.mouse_filter = Control.MOUSE_FILTER_STOP
			UI.tip(icon, "%s: %s" % [MagicStones.label(stone), MagicStones.describe(stone)])
			holder.add_child(icon)

	var need := DB.exp_to_next(int(m.level), stars)
	var ratio := 1.0 if int(m.level) >= cap or need <= 0 else clampf(float(m.exp) / float(need), 0.0, 1.0)
	var bar: Control = lay.node("ID_expGraph1")
	bar.size.x = 152.0 * ratio
	bar.visible = ratio > 0.02
	lay.text("ID_expText1", "%.1f%%" % (ratio * 100.0))

	lay.text("ID_TextEff1", ("- " + String(def.passive)) if String(def.passive) != "" else "- No passive")
	var pp: Dictionary = pet.get("passive", {})
	var pet_line := ""
	if not pp.is_empty():
		var who := "All" if String(pp.get("element", "all")) in ["all", ""] else String(pp.element).capitalize()
		pet_line = "- [Pet] Increases %s Monsters' %s by %d%%" % [who, {"hp": "HP", "atk": "ATK", "def": "DEF", "crit": "Crit"}.get(pp.stat, pp.stat), roundi(float(pp.pct) * 100.0)]
	lay.text("ID_TextEff1_1", pet_line)

	lay.hide_all(["ID_popup_fusion_lock", "ID_fusion_lock"])
	lay.text("ID_LABEL_6", "Evolve" if String(def.evolves_into) != "" else "Fusion")
	_layout_buttons(lay, stars >= 6)
	_lock_cover(lay.node("ID_btnComEv"), (not Save.is_maxed(m) and not (Save.dev("dev_free_evolve") and String(def.evolves_into) != "")) or (stars >= 6 and String(def.evolves_into) == ""))


static func _lock_cover(b: Control, locked: bool) -> void:
	var cover := b.get_node_or_null("lock_cover") as Control
	if cover == null:
		cover = Control.new()
		cover.name = "lock_cover"
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var np := NinePatchRect.new()
		np.texture = Layout.texture("9_Back_13.png")
		np.patch_margin_left = 12
		np.patch_margin_right = 12
		np.patch_margin_top = 12
		np.patch_margin_bottom = 12
		np.scale = Vector2(2, 2)
		np.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.add_child(np)
		var icon := UI.image(Layout.texture("I_lock_04.png"), Vector2(36, 46))
		icon.size = Vector2(36, 46)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.add_child(icon)
		b.add_child(cover)
	cover.visible = locked
	cover.size = b.size
	cover.get_child(0).size = b.size / 2.0
	cover.get_child(1).position = (b.size - Vector2(36, 46)) / 2.0


static func _layout_buttons(lay: Layout, awaken: bool) -> void:
	var ids := ["ID_btnComSt", "ID_btnComEv", "ID_btnComStone"]
	if awaken:
		ids.append("ID_btnComTrans")
	lay.show("ID_btnComTrans", awaken)
	var w := 432.0 / ids.size()
	for k in ids.size():
		var b: Control = lay.node(ids[k])
		b.position.x = 18.0 + w * k
		b.size.x = w
		for c in b.get_children():
			if c is Label:
				c.position.x = 6.0
				c.size.x = w - 12.0
	lay.show("ID_LABEL_6_2", awaken)
	lay.text("ID_LABEL_6_1", "Magic" if awaken else "Stone")
	lay.node("ID_LABEL_6_1").position.y = 16.0 if awaken else 27.0


func _show_tree() -> void:
	show_tree(screen, uid, _evolve_now if actions.has("evolve") else Callable(), preview)


func _evolve_now() -> void:
	close()
	actions["evolve"].call(uid)


static func show_tree(screen: Control, uid: int, evolve: Callable, given: Dictionary = {}) -> void:
	var m := given if not given.is_empty() else Save.get_owned(uid)
	var def := DB.monster(m.id)
	var t := Layout.load_into(screen, "R_d_comEvolution2")
	t.root.z_index = 95 if not given.is_empty() else 75
	t.node("ID_9PATCH_2").mouse_filter = Control.MOUSE_FILTER_STOP
	t.text("ID_titleText", "Evolution Tree")
	t.on("ID_btnEsc", t.root.queue_free)
	var chain: Array = def.get("evolution_tree", [])
	if chain.is_empty():
		chain = [{"monster": m.id, "material": "", "quantity": 0}]
	for k in 5:
		var stage := k * 2 + 1
		var has := k < chain.size()
		t.show("ID_monInfo%d" % stage, true)
		t.show("ID_arrow_%d" % (k + 1), has and k + 1 < chain.size())
		for g in 6:
			t.show("ID_grade%d_%d" % [g + 1, stage], has and g < int(DB.monster(chain[k].monster).get("stars", 1)))
		if has:
			var card := UI.monster_card(String(chain[k].monster), 0, 0, Vector2(92, 92), not Save.data.seen.has(chain[k].monster))
			t.put("ID_monFrame%d" % stage, card)
			if String(chain[k].monster) == m.id:
				t.node("ID_monInfo%d" % stage).modulate = Color(1.15, 1.1, 0.85)
		if k < 4:
			var mat_slot := stage + 1
			var mat := String(chain[k].get("material", "")) if has and k + 1 < chain.size() else ""
			t.show("ID_plus_%d" % (k + 1), mat != "")
			if mat != "":
				var owned: int = Save.data.monsters.filter(func(o): return o.id == mat).size()
				var need := maxi(1, int(chain[k].get("quantity", 1)))
				var mc := UI.monster_card(mat, 0, 0, Vector2(92, 92), not Save.data.seen.has(mat))
				var count := UI.label("%d/%d" % [owned, need], 18, Color("8cff8c") if owned >= need else Color.WHITE)
				count.position = Vector2(4, 66)
				mc.add_child(count)
				t.put("ID_monFrame%d" % mat_slot, mc)
	var prev: Control = t.node("ID_monPreview")
	var art := UI.living(DB.battle_sprite(m.id), Vector2(180, 170))
	art.position = Vector2(0, -20)
	prev.add_child(art)
	if given.is_empty() and evolve.is_valid() and Save.can_evolve(uid).ok:
		var b := UI.button("Evolve!", _evolve_from_tree.bind(t.root, evolve), "yellow", Vector2(170, 60), 22)
		b.position = Vector2(5, 175)
		prev.add_child(b)


static func _evolve_from_tree(tree_root: Control, evolve: Callable) -> void:
	tree_root.queue_free()
	evolve.call()


static func _skill(lay: Layout, screen: Control, holder_id: String, icon_file: String, text: String) -> void:
	var holder: Control = lay.node(holder_id)
	for c in holder.get_children():
		c.queue_free()
	var t := DB.skill_icon(icon_file) if icon_file != "" else null
	if t == null:
		return
	var r := UI.image(t, Vector2(40, 40))
	r.size = Vector2(40, 40)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	UI.tip(r, text)
	holder.add_child(r)


