class_name CubesScreen
extends Screen

const CUBES := {
	"blue10": {"name": "10 Blue Cubes", "cost": 2000, "currency": "fp", "count": 10, "weights": {1: 35, 2: 40, 3: 20, 4: 5}, "icon": "betaHud00/H_cube_00.png"},
	"blue": {"name": "Blue Cube", "cost": 200, "currency": "fp", "count": 1, "weights": {1: 35, 2: 40, 3: 20, 4: 5}, "icon": "betaHud00/H_cube_00.png"},
	"yellow": {"name": "Yellow Cube", "cost": 30, "currency": "gems", "count": 1, "weights": {3: 50, 4: 34, 5: 13, 6: 3}, "icon": "betaHud00/H_cube_01.png"},
	"yellow11": {"name": "11 Yellow Cubes", "cost": 300, "currency": "gems", "count": 11, "weights": {3: 50, 4: 34, 5: 13, 6: 3}, "icon": "betaHud00/H_cube_01.png"},
	"red": {"name": "Red Cube", "cost": 60, "currency": "gems", "count": 1, "weights": {4: 55, 5: 35, 6: 10}, "icon": "betaHud00/H_cube_02.png"},
	"red11": {"name": "11 Red Cubes", "cost": 600, "currency": "gems", "count": 11, "weights": {4: 55, 5: 35, 6: 10}, "icon": "betaHud00/H_cube_02.png"},
	"pet": {"name": "Normal Pet Egg", "cost": 10000, "currency": "gold", "count": 1, "pet": "normal", "icon": "betaHud00/H_petcube_01.png"},
	"pet_rare": {"name": "Rare Pet Egg", "cost": 50, "currency": "gems", "count": 1, "pet": "rare", "icon": "betaHud00/H_petcube_02.png"},
	"honor": {"name": "Honour Yellow Cube", "cost": 35, "currency": "honor", "count": 1, "weights": {3: 50, 4: 34, 5: 13, 6: 3}, "icon": "betaHud00/H_cube_01.png"},
}
const CUBE_TEXT := {
	"blue": "Contains ★1~4 Monsters",
	"yellow": "Contains ★3~6 Monsters",
	"red": "Contains ★4~6 Monsters",
	"honor": "Contains ★3~6 Monsters",
	"pet": "1-3 star pet can be earned. 1 star pet: can be equipped when monster Lv is 30+, 2 star pet: can be equipped when monster Lv is 35+, 3 star pet: can be equipped when monster Lv is 40+",
	"pet_rare": "A 4 star pet can be earned. It can be equipped when monster Lv is 45+",
}
const MYSTERY_COST := 50
const HIGHLIGHT_SCALE := Vector2(1.333, 1.212)
const MYSTERY_SIZE := 50
const MYSTERY_MIX := {5: 5, 4: 15, 3: 25}
const MYSTERY_RESET_GOLD := 100
const MYSTERY_FREE_RESET := 30
const MB_BREATHE := 0.015
const MB_SWAY := 0.01
const MB_GLINTS := [Vector2(0.07, 0.2), Vector2(0.9, 0.16), Vector2(0.31, 0.13), Vector2(0.63, 0.46), Vector2(0.96, 0.72)]
const MYSTERY_ROTATION := ["lightning_spirit", "pink_bean", "narkissa", "void_knight", "anubis", "dark_knight", "undine", "garden_spirit"]
const CURRENCY_NAME := {"gold": "Gold", "gems": "Gems", "honor": "Honour", "fp": "Friend Points"}
const TABS := {"hot": "ID_btnRecomT", "cube": "ID_btnCubeT_1", "energy": "ID_btnEnergy", "gem": "ID_btnCrystalT", "gold": "ID_btnGoldlT", "misc": "ID_btnItemT", "honor": "ID_btnHonor"}
const CARD_PRICE := {"gems": ["ID_crystal", "ID_priceText1"], "gold": ["ID_gold", "ID_priceText2"], "fp": ["ID_friendPoint", "ID_priceText3"], "cash": ["ID_cash_d", "ID_priceText5"], "honor": ["ID_honor", "ID_priceText6"]}
const DIALOG_PRICE := {"gems": ["ID_priceCrystal", "ID_priceCrystalText"], "gold": ["ID_priceGold", "ID_priceGoldText"], "fp": ["ID_pricePoint", "ID_pricePointText"], "cash": ["ID_priceCash_D", "ID_priceCash_DText"], "honor": ["ID_priceHonor", "ID_priceHonorText"]}
const GOLD_PACKS := [[10000, 10], [20000, 20], [50000, 50], [90000, 90]]
const GEM_PACKS := [["Gem Bucket(M)", 50, 10], ["Gem Bucket(L)", 100, 20], ["Gem Chest(S)", 200, 50], ["Gem Chest(M)", 500, 125], ["Gem Chest(L)", 1000, 300]]
const ENERGY_PACKS := [[40, 10], [80, 20], [120, 30]]
const GOLD_GEMS := [20, 3, 80000]

var lay: Layout
var _tab := "hot"
var _pools: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _cards: Dictionary = {}
var _no_ask := false
var _box: Layout


func build() -> void:
	_rng.randomize()
	UI.brown_background(self)
	lay = Layout.load_into(self, "R_shopPage")
	add_top_bar("top_shop", "Store", "hub")
	_build_pools()
	_migrate_starter_cube()
	for t in TABS:
		lay.on(TABS[t], _show_tab.bind(t))
	if Tutorial.enabled() and Tutorial.is_done("store") and not Tutorial.is_done("store_page"):
		Save.data.fp = maxi(int(Save.data.get("fp", 0)), int(CUBES.blue.cost))
		Save.data.gems = maxi(int(Save.data.gems), int(CUBES.yellow.cost))
		Save.save_game()
	var start := String(args.get("tab", "hot"))
	if Tutorial.pending("cubes"):
		start = "cube"
	_show_tab(start if TABS.has(start) else "hot")
	Tutorial.maybe_start(self, "cubes")
	if args.has("buy") and _cards.has(String(args.buy)):
		(_cards[String(args.buy)] as BaseButton).pressed.emit()
	if args.has("dev_open") and CUBES.has(String(args.dev_open)):
		var key := String(args.dev_open)
		Save.data.inventory_cap = maxi(int(Save.data.inventory_cap), Save.data.monsters.size() + 10)
		_open.call_deferred(CUBES[key], 10, key)


func _migrate_starter_cube() -> void:
	if int(Save.data.get("free_cubes", 0)) > 0:
		Save.data.cube_items["yellow"] = int(Save.data.cube_items.get("yellow", 0)) + int(Save.data.free_cubes)
		Save.data.free_cubes = 0
		Save.save_game()


const EVOLVED_FROM_STARS := 3
const CUBE_MATERIALS := ["goldbat"]


func _build_pools() -> void:
	for s in range(1, 7):
		_pools[s] = DB.ids_where(func(m): return int(m.stars) == s and ((not m.material and (m.evolves_from == "" or int(m.stars) >= EVOLVED_FROM_STARS)) or String(m.id) in CUBE_MATERIALS))


func _show_tab(t: String) -> void:
	_tab = t
	lay.select_tab(TABS.values(), TABS[t])
	_update_tab_badges()
	_cards.clear()
	var holder: Control = lay.node("ID_ID_arrayPosition")
	for c in holder.get_children():
		c.queue_free()
	var scroll := ScrollContainer.new()
	scroll.size = holder.size
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	scroll.add_child(row)
	if t == "hot":
		row.add_child(_mystery_slot())
		return
	for it in _items(t):
		row.add_child(_card(it))


func _update_tab_badges() -> void:
	var owned := 0
	for k in Save.data.cube_items:
		owned += maxi(0, int(Save.data.cube_items[k]))
	for i in range(0, 7):
		var id := "ID_btnEvent" if i == 0 else "ID_btnEvent_%d" % i
		lay.show(id, i == 4 and owned > 0)
	lay.text("ID_txtPer_4", "×%d" % owned)
	lay.show("ID_IMAGE_arrow_4", false)


func _items(t: String) -> Array:
	var out := []
	match t:
		"cube":
			for key in ["blue", "yellow", "red", "honor", "pet", "pet_rare"]:
				var n := int(Save.data.cube_items.get(key, 0))
				if n > 0:
					out.append({"id": "own:" + key, "name": String(CUBES[key].name), "icon": UI.tex(CUBES[key].icon), "count": "×%d" % n, "badge": "new",
						"desc": "Open a %s you have earned.\n%s" % [CUBES[key].name, CUBE_TEXT.get(key, "")], "currency": "", "price": 0,
						"check": _cube_room.bind(key, 1), "buy": _open_owned.bind(key), "action": "Open"})
			for key in ["blue10", "blue", "yellow", "yellow11", "red", "red11", "pet", "pet_rare"]:
				out.append(_cube_item(key))
		"energy":
			for p in ENERGY_PACKS:
				out.append({"id": "energy_%d" % int(p[0]), "name": "%d Energy" % int(p[0]), "icon": UI.tex("betaUI00/I_energy_02.png"), "count": "+%d" % int(p[0]),
					"desc": "Adds %d energy. Energy can go over the maximum." % int(p[0]), "currency": "gems", "price": int(p[1]), "buy": _add_energy.bind(int(p[0]))})
		"gem":
			out.append({"id": "gold_gems", "name": "Gem Bucket(S)", "icon": UI.tex("betaUI00/I_crystal_03.png"), "count": "%d+%d" % [GOLD_GEMS[0], GOLD_GEMS[1]], "daily": true,
				"desc": "%d gems + %d bonus gems for gold.\nOnce a day." % [GOLD_GEMS[0], GOLD_GEMS[1]], "currency": "gold", "price": GOLD_GEMS[2],
				"check": _gold_gems_room, "buy": _buy_gold_gems})
			for p in GEM_PACKS:
				out.append({"id": "gems_%d" % int(p[1]), "name": String(p[0]), "icon": UI.tex("betaUI00/I_crystal_03.png"), "count": "%d+%d" % [int(p[1]), int(p[2])],
					"desc": "%d gems + %d bonus gems." % [int(p[1]), int(p[2])], "currency": "cash", "price": 0, "price_text": "Off", "buy": _no_cash})
		"gold":
			for p in GOLD_PACKS:
				out.append({"id": "gold_%d" % int(p[0]), "name": "%s Gold" % Screen._thousands(int(p[0])), "icon": UI.tex("betaUI00/I_money_03.png"), "count": Screen._thousands(int(p[0])),
					"desc": "Exchange %d gems for %s gold." % [int(p[1]), Screen._thousands(int(p[0]))], "currency": "gems", "price": int(p[1]), "buy": _add_gold.bind(int(p[0]))})
		"misc":
			out.append({"id": "slots", "name": "12 Inventory Slots", "icon": UI.tex("betaUI00/I_mon_01.png"), "count": "+12",
				"desc": "Expand your inventory by 12 slots and collect more Monsters.", "currency": "gems", "price": slot_price(), "buy": _add_slots.bind(12)})
			for spec in [["exp", "EXP Boost (1 hour)", 3600, 25], ["exp", "EXP Boost (1 Day)", 86400, 60], ["drop", "Drop Boost (1 hour)", 3600, 25], ["drop", "Drop Boost (1 Day)", 86400, 60]]:
				var kind := String(spec[0])
				out.append({"id": "%s_%d" % [kind, int(spec[2])], "name": String(spec[1]), "icon": UI.tex("betaUI00/I_exp_02.png" if kind == "exp" else "betaUI00/I_cubeR_02.png"),
					"count": "Double", "timer": kind, "currency": "gems", "price": int(spec[3]), "buy": _add_boost.bind(kind, int(spec[2])),
					"desc": ("Quest EXP is doubled" if kind == "exp" else "Cube drops from quests are doubled") + " for %s. Buying more adds time." % ("1 hour" if int(spec[2]) == 3600 else "1 day")})
		"honor":
			var five := honour_special(5, false)
			var mat := honour_special(5, true)
			var four := honour_special(4, false)
			out.append({"id": "special5", "name": "Special Monster(★5)", "icon": UI.tex("res://assets/shop/honor_gift.png"), "monster": five, "weekly": true,
				"desc": "%s\n100%% Chance to get Limited Monster!\nIt can evolve to max ★6" % DB.monster(five).name, "currency": "honor", "price": 300, "check": _cube_room.bind("", 1), "buy": _get_monster.bind(five)})
			out.append({"id": "material5", "name": "Special Material(★5)", "icon": UI.tex("res://assets/shop/honor_gift.png"), "monster": mat, "weekly": true,
				"desc": "%s\nAn evolution material monster." % DB.monster(mat).name, "currency": "honor", "price": 100, "check": _cube_room.bind("", 1), "buy": _get_monster.bind(mat)})
			out.append({"id": "special4", "name": "Special Monster(★4)", "icon": UI.tex("res://assets/shop/honor_gift.png"), "monster": four, "weekly": true,
				"desc": "%s\n100%% Chance to get this monster!" % DB.monster(four).name, "currency": "honor", "price": 50, "check": _cube_room.bind("", 1), "buy": _get_monster.bind(four)})
			var awaken := honour_special(6, true)
			out.append({"id": "awaken6", "name": "Awaken Material", "icon": UI.tex("res://assets/shop/honor_gift.png"), "monster": awaken, "weekly": true,
				"desc": "%s\nA ★6 %s material for Awakening ★6 monsters." % [DB.monster(awaken).name, String(DB.monster(awaken).element).capitalize()], "currency": "honor", "price": 500, "check": _cube_room.bind("", 1), "buy": _get_monster.bind(awaken)})
			out.append(_cube_item("honor"))
			for e in [["fire", "fire_kong"], ["water", "water_kong"], ["nature", "grass_kong"]]:
				out.append({"id": "evo_" + String(e[0]), "name": "Evolve Material", "icon": UI.tex("res://assets/shop/honor_gift.png"), "element": e[0],
					"desc": "%s\nA %s evolution material." % [DB.monster(e[1]).name, String(e[0]).capitalize()], "currency": "honor", "price": 35, "check": _cube_room.bind("", 1), "buy": _get_monster.bind(e[1])})
	return out


func _cube_item(key: String) -> Dictionary:
	var c: Dictionary = CUBES[key]
	var base := key.trim_suffix("10").trim_suffix("11")
	var n := int(c.count)
	return {"id": key, "name": String(c.name), "icon": UI.tex(c.icon), "count": "×%d" % n if n > 1 else "", "badge": "hot" if n > 1 else "",
		"desc": ("%s\n" % c.name if n > 1 else "") + String(CUBE_TEXT.get(base, "")), "currency": String(c.currency), "price": int(c.cost),
		"check": _cube_room.bind(key, n), "buy": _buy_cube.bind(key)}


func _card(it: Dictionary) -> Control:
	var s := Layout.instance("R_shopSlot")
	s.text("ID_Name", String(it.name))
	s.hide_all(["ID_recomBack", "ID_timeBar", "ID_gift", "ID_eventTime"])
	for b in ["ID_sale", "ID_new", "ID_hot"]:
		s.show(b, b == "ID_" + String(it.get("badge", "")))
	s.put("ID_itemImage", _item_art(it, Vector2(196, 204)), Vector2(196, 204))
	var cur := String(it.currency)
	s.show("ID_cash_w", false)
	for k in CARD_PRICE:
		s.show(CARD_PRICE[k][0], k == cur)
	if CARD_PRICE.has(cur):
		var pl := s.text(CARD_PRICE[cur][1], String(it.get("price_text", Screen._thousands(int(it.price)))))
		if cur == "cash":
			s.show("ID_IMAGE_5_1", false)
			pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pl.position.x = 0
			pl.size.x = s.node("ID_cash_d").size.x
	elif it.has("action"):
		var l := UI.label(String(it.action), 26)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		s.put("ID_buy", l, s.node("ID_buy").size)
	var timer := ""
	if it.has("timer") and Save.item_boost_left(String(it.timer)) > 0:
		timer = "Active: %s left" % _duration(Save.item_boost_left(String(it.timer)))
	elif it.get("weekly", false):
		timer = "Closes in %d day(s)" % _days_to_week_end()
	elif it.get("daily", false):
		timer = "Bought today" if _gold_gems_room() != "" else "Once a day"
	if timer != "":
		s.show("ID_eventTime")
		s.text("ID_timeText", timer)
	var btn := s.node("ID_btnSlot") as BaseButton
	btn.pressed.connect(_confirm.bind(it))
	_cards[String(it.id)] = btn
	if String(it.get("badge", "")) != "":
		_highlight(s.node("ID_frameSize"))
	return s.root


func _highlight(frame: Control) -> void:
	var fx := FrameFx.play(frame, "ui_itemShop_01", frame.size / 2.0, frame.size * HIGHLIGHT_SCALE, 15.0)
	if fx == null:
		return
	fx.loop = true
	fx.stretch_mode = TextureRect.STRETCH_SCALE
	fx.z_index = 1
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fx.material = m


func _item_art(it: Dictionary, area: Vector2) -> Control:
	if String(it.get("id", "")) == "slots":
		return slots_art(area)
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size = area
	var icon := UI.image(it.icon, area * 0.62)
	icon.position = (area - area * 0.62) / 2.0 + Vector2(0, 6)
	icon.size = area * 0.62
	box.add_child(icon)
	if it.has("element"):
		var e := UI.image(UI.element_icon(String(it.element)), Vector2(52, 52))
		e.position = Vector2(area.x - 74, 40)
		e.size = Vector2(52, 52)
		box.add_child(e)
	if it.has("monster"):
		var m := UI.image(DB.icon(String(it.monster)), Vector2(78, 78))
		m.position = Vector2(area.x - 92, 36)
		m.size = Vector2(78, 78)
		box.add_child(m)
	var count := String(it.get("count", ""))
	if count != "":
		var l := UI.label(count, 24, UI.GOLD)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.size = Vector2(area.x - 18, 34)
		l.position = Vector2(4, area.y - 70)
		box.add_child(l)
	return box


func _confirm(it: Dictionary) -> void:
	if String(it.id) == "slots":
		offer_slots(self, false, _show_tab.bind(_tab))
		return
	if tutorial_active():
		_purchase(it)
		return
	var d := Layout.load_into(self, "R_d_buy2")
	d.root.z_index = 80
	d.node("ID_9PATCH_2").mouse_filter = Control.MOUSE_FILTER_STOP
	d.text("ID_titleText", "Item purchase")
	d.text("ID_itemName", String(it.name))
	d.show("ID_itemImage", false)
	d.put("ID_9PATCH_3", _item_art(it, Vector2(208, 210)), Vector2(208, 210))
	var free := String(it.currency) == ""
	var texts := {"ID_baseText": "Would you like to open it now?" if free else "Would you like to make a purchase?", "ID_detailText": String(it.get("desc", ""))}
	for id in texts:
		var l := d.node(id) as Label
		var keep := Vector2(320, 64) if id == "ID_baseText" else Vector2(320, 142)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.text = texts[id]
		l.size = keep
		if id == "ID_detailText" and l.text.length() > 120:
			l.add_theme_font_size_override("font_size", 17)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", UI.BROWN)
		l.add_theme_constant_override("outline_size", 0)
	var cur := String(it.currency)
	d.show("ID_priceCash_W", false)
	for k in DIALOG_PRICE:
		d.show(DIALOG_PRICE[k][0], k == cur)
	if DIALOG_PRICE.has(cur):
		var pl := d.text(DIALOG_PRICE[cur][1], String(it.get("price_text", Screen._thousands(int(it.price)))))
		if cur == "cash":
			d.show("ID_priceCash_DImage", false)
			pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pl.position.x = 0
			pl.size.x = d.node("ID_priceCash_D").size.x
	d.text("ID_LABEL_5", "Open" if free else "Purchase")
	var root := d.root
	d.on("ID_btnOk", _confirm_ok.bind(root, it))
	d.on("ID_btnEsc", root.queue_free)


func _confirm_ok(root: Control, it: Dictionary) -> void:
	root.queue_free()
	_purchase(it)


func _purchase(it: Dictionary) -> void:
	var check: Callable = it.get("check", Callable())
	if check.is_valid():
		var err: String = check.call()
		if err != "":
			if err.contains("box is full"):
				offer_slots(self, true, _show_tab.bind(_tab))
			else:
				UI.notice(self, "Notice", err)
			return
	if not _pay(String(it.currency), int(it.price)):
		return
	var buy: Callable = it.buy
	buy.call()
	_show_tab(_tab)


func _pay(currency: String, price: int) -> bool:
	if currency == "" or price <= 0:
		return currency != "cash"
	var have := int(Save.data.get(currency, 0))
	if have < price:
		UI.notice(self, "Notice", "Not enough %s." % CURRENCY_NAME.get(currency, currency))
		return false
	Save.data[currency] = have - price
	Save.save_game()
	return true


func _cube_room(key: String, count: int) -> String:
	if key != "" and CUBES.has(key) and CUBES[key].has("pet"):
		return ""
	if Save.data.monsters.size() + count > int(Save.data.inventory_cap):
		return "Your monster box is full! Sell monsters or buy Inventory Slots in Misc."
	return ""


func _energy_room() -> String:
	return "Energy is already full." if Save.energy() >= int(Save.data.energy_cap) else ""


func _buy_cube(key: String) -> void:
	var c: Dictionary = CUBES[key]
	Save.track("store_cube", int(c.count))
	_open(c, int(c.count), key)


func _open_owned(key: String) -> void:
	Save.data.cube_items[key] = int(Save.data.cube_items.get(key, 0)) - 1
	if int(Save.data.cube_items[key]) <= 0:
		Save.data.cube_items.erase(key)
	_open(CUBES[key], 1, key)


func _refill_energy() -> void:
	Save.data.energy = int(Save.data.energy_cap)
	Save.data.energy_stamp = Time.get_unix_time_from_system()
	Save.save_game()
	Sfx.play("buff_big")
	UI.notice(self, "Notice", "Your energy has been restored.")


func _add_energy(n: int) -> void:
	Save.data.energy = Save.energy() + n
	Save.save_game()
	Sfx.play("buff_big")
	UI.notice(self, "Notice", "%d energy added." % n)


func _gold_gems_room() -> String:
	return "You can buy this once a day. Come back tomorrow." if String(Save.data.get("gold_gems_day", "")) == Save._today() else ""


func _buy_gold_gems() -> void:
	Save.data.gold_gems_day = Save._today()
	Save.data.gems = int(Save.data.gems) + GOLD_GEMS[0] + GOLD_GEMS[1]
	Save.save_game()
	Sfx.play("buff_big")
	UI.notice(self, "Notice", "%d gems added." % (GOLD_GEMS[0] + GOLD_GEMS[1]))


func _add_gold(n: int) -> void:
	Save.data.gold = int(Save.data.gold) + n
	Save.save_game()
	Sfx.play("buff_big")
	UI.notice(self, "Notice", "%s gold added." % Screen._thousands(n))


func _add_slots(n: int) -> void:
	Save.data.inventory_cap = int(Save.data.inventory_cap) + n
	Save.save_game()
	Sfx.play("buff_big")
	UI.notice(self, "Notice", "Your monster box now holds %d monsters." % int(Save.data.inventory_cap), _show_tab.bind(_tab))


func _add_boost(kind: String, seconds: int) -> void:
	Save.add_item_boost(kind, seconds)
	Sfx.play("buff_big")
	UI.notice(self, "Notice", "%s Boost is active for %s." % ["EXP" if kind == "exp" else "Drop", _duration(Save.item_boost_left(kind))])


func _no_cash() -> void:
	UI.notice(self, "Notice", "Gem purchases are not available in this offline version. Earn gems from first clears, missions and attendance.")


func _get_monster(id: String) -> void:
	var fresh: bool = not Save.data.owned.has(id)
	Save.add_monster(id, 1)
	Save.save_game()
	CubeReveal.play(self, "honor5", [id], [fresh], [{"text": "OK", "color": "yellow"}])


func _roll(weights: Dictionary) -> String:
	var total := 0
	for k in weights:
		total += int(weights[k])
	var pick := _rng.randi_range(1, total)
	for k in weights:
		pick -= int(weights[k])
		if pick <= 0:
			var pool: Array = _pools.get(int(k), [])
			if not pool.is_empty():
				return pool[_rng.randi() % pool.size()]
	return _pools[1][0]


func _roll_pet(kind: String) -> String:
	var pool := DB.pets.filter(func(p): return (int(p.stars) >= 4) == (kind == "rare"))
	return pool[_rng.randi() % pool.size()].id


func _open(c: Dictionary, count: int, key: String = "blue") -> void:
	var got := []
	var fresh := []
	var is_pet := c.has("pet")
	for i in count:
		if is_pet:
			got.append(Save.add_pet(_roll_pet(c.pet)).id)
			fresh.append(false)
		else:
			var weights: Dictionary = c.weights
			if key == "yellow" and tutorial_active():
				weights = {4: 100}
			var id := _roll(weights)
			fresh.append(not Save.data.owned.has(id))
			Save.add_monster(id, 1)
			got.append(id)
	Save.save_game()
	var kind := key.trim_suffix("11").trim_suffix("10")
	CubeReveal.play(self, kind, got, fresh, [{"text": "OK", "color": "yellow", "cb": _after_reveal}], is_pet)


func _after_reveal() -> void:
	tut_notify("cube_opened")


static func _days_to_week_end() -> int:
	return maxi(1, ceili(Arena.seconds_left_in_week() / 86400.0))


static func _duration(seconds: int) -> String:
	if seconds >= 3600:
		return "%dh %02dm" % [floori(seconds / 3600.0), floori((seconds % 3600) / 60.0)]
	return "%dm" % maxi(1, floori(seconds / 60.0))


static func honour_special(stars: int, material: bool) -> String:
	var pool := DB.ids_where(func(m): return int(m.stars) == stars and bool(m.material) == material and (material or String(m.evolves_into) != ""))
	pool.sort()
	if pool.is_empty():
		return MYSTERY_ROTATION[0]
	return pool[(Arena.week_id() * 7 + stars * 3 + (1 if material else 0)) % pool.size()]


const SLOT_GEMS := 18
const SLOT_RAISE := 6
const SLOT_MAX_GEMS := 90
const SLOT_STEP := 12


static func slot_price() -> int:
	var bought := maxi(0, (int(Save.data.inventory_cap) - Save.START_INVENTORY) / SLOT_STEP)
	return mini(SLOT_MAX_GEMS, SLOT_GEMS + SLOT_RAISE * bought)


static func slots_art(area: Vector2) -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size = area
	var t := minf(area.x, area.y) * 0.36
	var origin := (area - Vector2(t * 2.0 + 6.0, t * 2.0 + 6.0)) / 2.0
	for k in 4:
		var tile := UI.image(UI.tex("betaUI00/B_monEmpty_01.png"), Vector2(t, t))
		tile.size = Vector2(t, t)
		tile.position = origin + Vector2((k % 2) * (t + 6.0), floorf(k / 2.0) * (t + 6.0))
		box.add_child(tile)
	var arrow := UI.image(UI.tex("betaUI00/I_arrow_03.png"), Vector2(t * 0.6, t * 0.7))
	arrow.size = Vector2(t * 0.6, t * 0.7)
	arrow.pivot_offset = arrow.size / 2.0
	arrow.rotation = PI
	arrow.modulate = Color(1.0, 0.25, 0.2)
	arrow.position = origin + Vector2(t * 2.0 + 6.0 - arrow.size.x * 0.75, t * 2.0 + 6.0 - arrow.size.y * 0.9)
	box.add_child(arrow)
	return box


static func offer_slots(parent: Control, full: bool = false, on_done: Callable = Callable()) -> void:
	var price := slot_price()
	var grow := func() -> bool:
		if int(Save.data.gems) < price:
			return false
		Save.data.gems = int(Save.data.gems) - price
		Save.data.inventory_cap = int(Save.data.inventory_cap) + SLOT_STEP
		Save.save_game()
		return true
	offer_purchase(parent, "%d Inventory Slots" % SLOT_STEP, slots_art(Vector2(208, 210)),
		"Your Monster Box is full!
Would you like to make a purchase?" if full else "Would you like to make a purchase?",
		"Expand your inventory by %d slots and collect more Monsters." % SLOT_STEP, price, grow,
		func() -> String: return "Your monster box now holds %d monsters." % int(Save.data.inventory_cap), on_done)


static func offer_purchase(parent: Control, item: String, art: Control, base: String, detail: String, price: int, apply: Callable, done_text: Callable, on_done: Callable = Callable()) -> void:
	var d := Layout.load_into(parent, "R_d_buy2")
	d.root.z_index = 85
	d.node("ID_9PATCH_2").mouse_filter = Control.MOUSE_FILTER_STOP
	d.text("ID_titleText", "Item purchase")
	d.text("ID_itemName", item)
	d.show("ID_itemImage", false)
	d.put("ID_9PATCH_3", art, Vector2(208, 210))
	var texts := {"ID_baseText": base, "ID_detailText": detail}
	for id in texts:
		var l := d.node(id) as Label
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.text = texts[id]
		l.size = Vector2(320, 64) if id == "ID_baseText" else Vector2(320, 142)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", UI.BROWN)
		l.add_theme_constant_override("outline_size", 0)
	for k in DIALOG_PRICE:
		d.show(DIALOG_PRICE[k][0], k == "gems")
	d.show("ID_priceCash_W", false)
	d.text("ID_priceCrystalText", str(price))
	d.text("ID_LABEL_5", "Purchase")
	var root := d.root
	var buy := func() -> void:
		root.queue_free()
		if not bool(apply.call()):
			UI.notice(parent, "Notice", "Not enough Gems.")
			return
		Sfx.play("buff_big")
		UI.notice(parent, "Notice", String(done_text.call()), on_done)
	d.on("ID_btnOk", buy)
	d.on("ID_btnEsc", root.queue_free)


static func mystery_featured() -> String:
	return MYSTERY_ROTATION[Arena.week_id() % MYSTERY_ROTATION.size()]


func _box_state() -> Dictionary:
	var st: Dictionary = Save.data.get("mystery_box", {})
	if int(st.get("week", -1)) != Arena.week_id() or Array(st.get("banner", [])).size() != 5 or Array(st.get("prizes", [])).size() != MYSTERY_SIZE:
		var banner := [mystery_featured()]
		banner.append_array(_roll_box(banner))
		st = _new_box(banner, mystery_featured(), 0)
		Save.data["mystery_box"] = st
		Save.save_game()
	return st


func _new_box(banner: Array, featured: String, resets: int) -> Dictionary:
	var ids := _roll_box(banner)
	var prizes := [featured]
	prizes.append_array(ids)
	for s in MYSTERY_MIX:
		for i in int(MYSTERY_MIX[s]):
			prizes.append(_roll({s: 1}))
	prizes.shuffle()
	return {"week": Arena.week_id(), "banner": banner, "featured": featured, "ids": ids, "prizes": prizes, "opened": [], "resets": resets}


func _box_opened() -> Array:
	return Array(_box_state().get("opened", []))


func _mystery_box() -> Array:
	return _box_state().ids


func _featured() -> String:
	return String(_box_state().featured)


func _roll_box(avoid: Array) -> Array:
	var ids := []
	while ids.size() < 4:
		var id := _roll({5: 75, 6: 25})
		if not avoid.has(id) and not ids.has(id):
			ids.append(id)
	return ids


func _reset_cost() -> int:
	var st := _box_state()
	if Array(st.opened).size() >= MYSTERY_FREE_RESET:
		return 0
	return MYSTERY_RESET_GOLD * int(pow(2, int(st.get("resets", 0))))


static func _on_stair(b: Control, id: String, grow := Vector2(1.0, 0.72)) -> void:
	var w := b.size.x * 0.9
	var stair := UI.image(UI.tex("betaUI00/K_stairG_01.png"), Vector2(w, w * 0.49))
	stair.size = Vector2(w, w * 0.49)
	stair.position = Vector2((b.size.x - w) / 2.0, b.size.y - stair.size.y)
	stair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stair.add_to_group("mb_art")
	b.add_child(stair)
	var k := w / 200.0
	for i in mini(int(DB.monster(id).get("stars", 0)), 6):
		var star := UI.image(UI.tex("res://assets/ui/plate_star.png"), Vector2(22, 22) * k, TextureRect.STRETCH_SCALE)
		star.size = Vector2(22, 22) * k
		star.position = Vector2(52.1 + 19.4 * i, 72.0) * k - star.size / 2.0
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stair.add_child(star)
	var tex := DB.battle_sprite(id)
	var box := b.size * grow
	var size := box
	if tex != null and tex.get_width() > 0:
		size = tex.get_size() * minf(box.x / tex.get_width(), box.y / tex.get_height())
	var art := UI.idle_art(tex, size)
	art.position += Vector2(b.size.x / 2.0 - size.x / 2.0, stair.position.y + stair.size.y * 0.36 - size.y)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_to_group("mb_art")
	if art.material is ShaderMaterial:
		(art.material as ShaderMaterial).set_shader_parameter("breath", MB_BREATHE)
		(art.material as ShaderMaterial).set_shader_parameter("sway", MB_SWAY)
	b.add_child(art)


static func _glints(back: Control) -> void:
	for at in MB_GLINTS:
		var g := UI.image(UI.tex("betaGacha00/u_Highlight_01.png"), Vector2(72, 72))
		g.size = Vector2(72, 72)
		g.pivot_offset = g.size / 2.0
		g.position = back.size * (at as Vector2) - g.size / 2.0
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.modulate.a = 0.0
		g.scale = Vector2(0.3, 0.3)
		back.add_child(g)
		var tw := g.create_tween().set_loops()
		tw.tween_interval(randf_range(0.6, 2.6))
		tw.tween_property(g, "modulate:a", 1.0, 0.25)
		tw.parallel().tween_property(g, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(g, "rotation", PI / 4.0, 0.6)
		tw.tween_property(g, "modulate:a", 0.0, 0.35)
		tw.parallel().tween_property(g, "scale", Vector2(0.3, 0.3), 0.35)
		tw.tween_callback(g.set_rotation.bind(0.0))


func _mystery_slot() -> Control:
	var s := Layout.instance("R_shopSlotLT")
	var shown := Array(_box_state().banner)
	var title := s.text("ID_itemName", "Mystery Box")
	var ribbon := UI.image(UI.tex("res://assets/ui/mystery_banner.png"), Vector2(400, 40), TextureRect.STRETCH_SCALE)
	ribbon.size = Vector2(400, 40)
	ribbon.position = Vector2((title.get_parent() as Control).size.x / 2.0 - 200.0, -6)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.z_index = 3
	title.get_parent().add_child(ribbon)
	title.reparent(ribbon, false)
	title.position = Vector2.ZERO
	title.size = ribbon.size
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("ffc93a"))
	title.add_theme_color_override("font_outline_color", Color("5a0a04"))
	title.add_theme_constant_override("outline_size", 6)
	var back := s.node("ID_lotteryBackImage") as NinePatchRect
	back.texture = UI.tex("betaUI00/F_getMonster_01.png")
	back.patch_margin_left = 20
	back.patch_margin_right = 20
	back.patch_margin_top = 20
	back.patch_margin_bottom = 20
	_glints(back)
	s.show("ID_mon3", false)
	for i in 5:
		var b := s.node("ID_9BUTTON_mon5_%d" % (i + 1)) as BaseButton
		var id: String = shown[i]
		_on_stair(b, id, Vector2(1.3, 0.8))
		b.pressed.connect(_details.bind(id))
	s.on("ID_btnViewDetails", _view_details)
	s.on("ID_btnTry", _open_box)
	s.on("ID_btnReset", _reset_box)
	s.text("ID_txtNumG", Screen._thousands(_reset_cost()))
	_cards["mystery"] = s.node("ID_btnTry")
	return s.root


func _details(id: String) -> void:
	MonsterPopup.info_of(self, id, 1, 90)


func _view_details() -> void:
	var d := Layout.load_into(self, "R_d_lotteryTableReward")
	d.root.z_index = 70
	d.node("ID_9PATCH_2").mouse_filter = Control.MOUSE_FILTER_STOP
	var drawn := _box_opened().size()
	d.text("ID_txtNumber", "%d/%d" % [drawn, MYSTERY_SIZE])
	var graph := d.node("ID_totalGraph")
	graph.size.x = maxf(20.0, graph.size.x * drawn / MYSTERY_SIZE)
	graph.visible = drawn > 0
	_on_stair(d.node("ID_9BUTTON_mon1"), _featured())
	d.on("ID_9BUTTON_mon1", func(): _details(_featured()))
	var box := _mystery_box()
	for i in 3:
		var id := String(box[i])
		_on_stair(d.node("ID_9BUTTON_mon2_%d" % (i + 1)), id)
		d.on("ID_9BUTTON_mon2_%d" % (i + 1), _details.bind(id))
	d.on("ID_btnEsc", d.root.queue_free)


func _reset_box() -> void:
	var cost := _reset_cost()
	if not _pay("gold", cost):
		return
	var st := _box_state()
	var others := Array(st.banner).filter(func(id): return id != st.featured)
	var featured := String(others[_rng.randi() % others.size()])
	Save.data["mystery_box"] = _new_box(st.banner, featured, int(st.get("resets", 0)) + (1 if cost > 0 else 0))
	Save.save_game()
	Sfx.play("buff")
	_show_tab("hot")
	if _box != null and is_instance_valid(_box.root):
		var stage := _box.node("ID_9BUTTON_mon1")
		for c in stage.get_children():
			if c.is_in_group("mb_art"):
				c.free()
		_on_stair(stage, featured)
	_fill_box()
	UI.notice(self, "Notice", "Reset Box success.")


func _open_box() -> void:
	if _box != null and is_instance_valid(_box.root):
		_box.root.queue_free()
	var d := Layout.load_into(self, "R_d_lotteryTable")
	_box = d
	d.root.z_index = 60
	d.node("ID_9PATCH_2").mouse_filter = Control.MOUSE_FILTER_STOP
	d.text("ID_titleText", "Mystery Box")
	d.text("ID_txtNumC_2", str(MYSTERY_COST))
	d.text("ID_txtNumC_1", str(MYSTERY_COST * 10))
	d.text("ID_txtTry", "Random Pick 1")
	d.text("ID_txtTry10", "Random Pick 10")
	var desc := d.text("ID_txtD", "Mystery box has ★6~★3 Mons. The more you draw, the better chance to get high ★ Mons.")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.show("ID_slide", false)
	_on_stair(d.node("ID_9BUTTON_mon1"), _featured())
	d.on("ID_9BUTTON_mon1", func(): _details(_featured()))
	d.on("ID_btnViewDetails", _view_details)
	d.on("ID_btnReset", _reset_box)
	d.on("ID_btnTry1", _try_draw.bind(1))
	d.on("ID_btnTry10", _try_draw.bind(10))
	d.on("ID_btnEsc", d.root.queue_free)
	_fill_box()


func _fill_box() -> void:
	if _box == null or not is_instance_valid(_box.root):
		return
	_box.text("ID_txtNumG_My", Screen._thousands(int(Save.data.gold)))
	_box.text("ID_txtNumC_My", Screen._thousands(int(Save.data.gems)))
	_box.text("ID_txtNumG", Screen._thousands(_reset_cost()))
	var st := _box_state()
	var opened := Array(st.opened)
	var stage := _box.node("ID_9BUTTON_mon1")
	var old := stage.get_node_or_null("got")
	if old != null:
		old.free()
	if opened.any(func(i): return String(st.prizes[i]) == String(st.featured)):
		var got := UI.image(UI.tex("betaUI00/K_mark_02.png"), Vector2(44, 40))
		got.name = "got"
		got.size = Vector2(44, 40)
		got.position = Vector2(stage.size.x - 34, stage.size.y - 52)
		got.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(got)
	var holder := _box.node("ID_arrayPosition")
	for c in holder.get_children():
		c.queue_free()
	var scroll := ScrollContainer.new()
	scroll.size = holder.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	var side := floorf((holder.size.x - 16.0 - 30.0) / 6.0)
	for i in MYSTERY_SIZE:
		var id := String(st.prizes[i])
		var tile := UI.image(DB.icon(id), Vector2(side, side))
		tile.mouse_filter = Control.MOUSE_FILTER_STOP
		tile.gui_input.connect(func(e: InputEvent):
			if UI.tapped(e):
				_details(id))
		if not opened.has(i):
			tile.modulate = Color(0.42, 0.42, 0.48)
		grid.add_child(tile)
	for i in (6 - MYSTERY_SIZE % 6) % 6:
		grid.add_child(UI.image(UI.tex("betaUI00/B_monEmpty_01.png"), Vector2(side, side)))


func _try_draw(count: int) -> void:
	count = mini(count, MYSTERY_SIZE - _box_opened().size())
	if count <= 0:
		UI.notice(self, "Notice", "The Mystery Box is empty. Reset the box to draw again.")
		return
	if _no_ask or tutorial_active():
		_draw_mystery(count)
		return
	var d := Layout.load_into(self, "R_d_buy2_LT")
	d.root.z_index = 80
	d.node("ID_9PATCH_2").mouse_filter = Control.MOUSE_FILTER_STOP
	d.text("ID_priceText1", str(MYSTERY_COST * count))
	d.show("ID_check", false)
	var lot := d.node("ID_lottery")
	var icon := UI.image(UI.tex("betaUI00/B_monEmpty_03.png"), lot.size)
	icon.size = lot.size
	lot.add_child(icon)
	d.on("ID_btnCheckBox", _toggle_no_ask.bind(d))
	var root := d.root
	d.on("ID_btnOk", _draw_ok.bind(root, count))
	d.on("ID_btnEsc", root.queue_free)


func _toggle_no_ask(d: Layout) -> void:
	_no_ask = not _no_ask
	d.show("ID_check", _no_ask)


func _draw_ok(root: Control, count: int) -> void:
	root.queue_free()
	_draw_mystery(count)


func _draw_mystery(count: int) -> void:
	if _cube_room("", count) != "":
		offer_slots(self, true, _show_tab.bind(_tab))
		return
	if not _pay("gems", MYSTERY_COST * count):
		return
	var st := _box_state()
	var opened := Array(st.get("opened", []))
	var closed := []
	for i in MYSTERY_SIZE:
		if not opened.has(i):
			closed.append(i)
	var got := []
	var fresh := []
	for k in count:
		var i: int = closed.pop_at(_rng.randi() % closed.size())
		opened.append(i)
		var id := String(st.prizes[i])
		fresh.append(not Save.data.owned.has(id))
		Save.add_monster(id, 1)
		got.append(id)
	st["opened"] = opened
	Save.data["mystery_box"] = st
	Save.track("store_cube", count)
	Save.save_game()
	_show_tab("hot")
	_fill_box()
	CubeReveal.play(self, "yellow", got, fresh, [{"text": "OK", "color": "yellow"}])


func tutorial_target(name: String) -> Control:
	if name.begins_with("cube:"):
		if _tab != "cube":
			_show_tab("cube")
		var card: Control = _cards.get(name.trim_prefix("cube:"))
		if card != null:
			_scroll_to.call_deferred(card)
		return card
	if name == "back" and top != null:
		for c in _top_node.find_children("ID_btnBack*", "", true, false):
			return c
	return null


func _scroll_to(card: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(card):
		(lay.node("ID_ID_arrayPosition").get_child(0) as ScrollContainer).ensure_control_visible(card)
