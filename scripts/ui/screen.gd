class_name Screen
extends Control

const TOP_VARIANTS := ["ID_top1", "ID_top2", "ID_top3", "ID_top4", "ID_top5", "ID_top_shop", "ID_top7"]

var main: Main
var args: Dictionary = {}
var tutorial: Tutorial
var top: Layout
var _top_node: Control
var _back_target := "hub"
var _back_args: Dictionary = {}
var key_kind := "tower"


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	build()


func build() -> void:
	pass


func tut_notify(name: String) -> void:
	if tutorial != null and is_instance_valid(tutorial):
		tutorial.notify(name)


func tutorial_active() -> bool:
	return tutorial != null and is_instance_valid(tutorial) and tutorial.running


func add_top_bar(variant: String = "2", title: String = "", back_target: String = "hub") -> Layout:
	_back_target = back_target
	if top == null:
		top = Layout.load_into(self, "R_top2")
		top.root.z_index = 40
		var timer := Timer.new()
		timer.wait_time = 1.0
		timer.autostart = true
		timer.timeout.connect(_refresh_top)
		add_child(timer)
		Save.changed.connect(_refresh_top)
		tree_exiting.connect(func(): Save.changed.disconnect(_refresh_top))
	var want := "ID_top_shop" if variant == "top_shop" else "ID_top" + variant
	for v in TOP_VARIANTS:
		top.show(v, v == want)
	_top_node = top.node(want)
	if title != "":
		for c in _top_node.find_children("ID_titleText*", "Label", true, false):
			c.text = title
	if _top_node.has_meta("wired"):
		_refresh_top()
		return top
	_top_node.set_meta("wired", true)
	for c in _top_node.find_children("*", "", true, false):
		var n := String(c.name)
		if n.begins_with("ID_Chatalert") or n.begins_with("ID_alert") or n == "ID_BUTTON_Key":
			c.visible = false
		elif n.begins_with("ID_btnChat"):
			(c as BaseButton).pressed.connect(open_chat)
		elif n.begins_with("ID_btnBack"):
			c.set_meta("sfx", "back")
			(c as BaseButton).pressed.connect(go_back)
		elif n.begins_with("ID_BUTTON_MONEY"):
			(c as BaseButton).pressed.connect(func(): main.go("cubes", {"tab": "gold"}))
		elif n.begins_with("ID_BUTTON_CASH"):
			(c as BaseButton).pressed.connect(func(): main.go("cubes", {"tab": "gem"}))
		elif n.begins_with("ID_BUTTON_ENERGY"):
			(c as BaseButton).pressed.connect(_offer_refill)
		elif n.begins_with("ID_btnOption"):
			(c as BaseButton).pressed.connect(open_options)
		elif n.begins_with("ID_btnInfo"):
			(c as BaseButton).pressed.connect(_show_tip)
		elif n.begins_with("ID_LABEL_ENERGY_TIME"):
			c.visible = false
		elif n.begins_with("ID_titleText") and title != "":
			(c as Label).text = title
	_refresh_top()
	return top


func go_back() -> void:
	main.go(_back_target, _back_args)


func _refresh_top() -> void:
	if _top_node == null:
		return
	var e := Save.energy()
	for c in _top_node.find_children("*", "Label", true, false):
		var n := String(c.name)
		if n.begins_with("ID_goldText"):
			c.text = _thousands(int(Save.data.gold))
		elif n.begins_with("ID_cashText"):
			c.text = _thousands(int(Save.data.gems))
		elif n.begins_with("ID_honorText"):
			c.text = _thousands(int(Save.data.get("honor", 0)))
		elif n.begins_with("ID_LABEL_ENERGY_CURRENT"):
			c.text = _energy_timer() if _timer_phase() else str(e)
		elif n.begins_with("ID_LABEL_ENERGY_MAX"):
			c.text = "/%d" % int(Save.data.energy_cap)
			c.visible = not _timer_phase()
		elif n.begins_with("ID_LABEL_FP_CURRENT"):
			c.text = str(int(Save.data.get("fp", 0)))
		elif n.begins_with("ID_LABEL_FP_MAX"):
			c.text = "/2000"
		elif n == "ID_LABEL_Key_current":
			c.text = str((1 if Save.has_raid_key() else 0) if key_kind == "raid" else Save.tower_tickets())
		elif n == "ID_LABEL_Key_max":
			c.text = "/1" if key_kind == "raid" else "/%d" % SkyTower.MAX_TICKETS


static func _timer_phase() -> bool:
	return int(Time.get_ticks_msec() / 2000) % 2 == 1


static func _energy_timer() -> String:
	if Save.energy() >= int(Save.data.energy_cap):
		return "MAX"
	var s := Save.seconds_to_next_energy()
	return "%02d:%02d" % [s / 60, s % 60]


func add_resource_bar() -> void:
	if top == null:
		add_top_bar()


func add_back_button(target: String = "hub", variant: String = "2") -> void:
	add_top_bar(variant, "", target)


func add_title(text: String) -> void:
	if top == null:
		add_top_bar()
	for c in _top_node.find_children("ID_titleText*", "Label", true, false):
		c.text = text


func _offer_refill() -> void:
	var e := Save.energy()
	if e >= int(Save.data.energy_cap):
		UI.toast(self, "Energy is already full")
		return
	UI.confirm(self, "Notice", "Refill energy to %d for %d gems?" % [int(Save.data.energy_cap), Save.ENERGY_REFILL_GEMS], _refill)


func _refill() -> void:
	if Save.refill_energy():
		Sfx.play("buff_big")
	else:
		UI.toast(self, "Not enough gems", Color("ff8080"))


func _show_tip() -> void:
	UI.notice(self, "Tip", String(DB.tips[randi() % DB.tips.size()]) if not DB.tips.is_empty() else "")


func open_options() -> void:
	OptionsPopup.open(self)


func open_chat() -> void:
	if main != null and main.ticker != null:
		ChatPanel.open(self)


func _confirm_reset() -> void:
	UI.confirm(self, "Really reset?", "All monsters and progress will be lost.", _do_reset)


func _do_reset() -> void:
	Save.reset()
	Save.save_game()
	main.go("title")


static func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func brown_background() -> void:
	var g := Gradient.new()
	g.set_color(0, Color("5e4433"))
	g.set_color(1, Color("3a281b"))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.45)
	gt.fill_to = Vector2(1.1, 1.1)
	var bg := TextureRect.new()
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)
