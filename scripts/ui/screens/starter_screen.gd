extends Screen

const STARTERS := ["pheona", "jellio", "dusa", "burdon"]
const LOADING := ["Checking for update", "Retrieving Google+ friend information..", "Retrieving user information"]
const SKILL_SLOTS := [1, 2, 3, 4]

var lay: Layout
var _pick := 0
var _confirm: Layout


func build() -> void:
	UI.background(self, UI.tex("betaTitle00/title.png"))
	lay = Layout.load_into(self, "R_d_startMonster")
	lay.text("ID_TextEx", "Choose your first monster!")
	lay.show("ID_waitText", false)
	lay.on("ID_btnEsc", _on_esc)
	lay.on("ID_btnOk", _on_start)
	for i in STARTERS.size():
		var n := i + 1
		lay.on("ID_monsterSlot%d" % n, _select.bind(i))
		lay.on("ID_btnDetail%d" % n, _show_detail.bind(i))
		lay.node("ID_ev%d" % n).mouse_filter = MOUSE_FILTER_IGNORE
		var sel := lay.node("ID_selected%d" % n)
		sel.mouse_filter = MOUSE_FILTER_IGNORE
		sel.get_parent().move_child(sel, -1)
		var detail := lay.node("ID_btnDetail%d" % n)
		detail.get_parent().move_child(detail, -1)
	for k in SKILL_SLOTS + [6]:
		lay.on("ID_leaderSkill%d" % k, _toggle_tip.bind(k))
	_select(0)
	_show_choice()
	_run_loading()


func _select(i: int) -> void:
	_pick = i
	for k in STARTERS.size():
		lay.show("ID_selected%d" % (k + 1), k == i)


func _show_choice() -> void:
	lay.show("ID_choiceMonPage", true)
	lay.show("ID_monDetailPage", false)


func _show_detail(i: int) -> void:
	_select(i)
	lay.show("ID_choiceMonPage", false)
	lay.show("ID_monDetailPage", true)
	for k in STARTERS.size():
		lay.show("ID_mon%d" % (k + 1), k == i)
	var final := _final_form(STARTERS[i])
	var skills: Array = final.get("skills", [])
	for k in SKILL_SLOTS:
		lay.show("ID_leaderSkill%d" % k, k <= skills.size())
		if k <= skills.size():
			_fill_tip(k, skills[k - 1])
	var support: Dictionary = final.get("support_skill", {})
	lay.show("ID_leaderSkill6", not support.is_empty())
	if not support.is_empty():
		_fill_tip(6, support)
	_hide_tips()


func _final_form(id: String) -> Dictionary:
	var m := DB.monster(id)
	for step in 6:
		var next := String(m.get("evolves_into", ""))
		if next == "" or DB.monster(next).is_empty():
			break
		m = DB.monster(next)
	return m


func _fill_tip(k: int, skill: Dictionary) -> void:
	lay.text("ID_skillName%d" % k, String(skill.get("name", "")))
	var d := lay.text("ID_skillDetail%d" % k, String(skill.get("description", "")))
	if d:
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _hide_tips() -> void:
	for k in SKILL_SLOTS + [6]:
		lay.show("ID_skillTip%d" % k, false)


func _toggle_tip(k: int) -> void:
	var tip := lay.node("ID_skillTip%d" % k)
	var was := tip != null and tip.visible
	_hide_tips()
	lay.show("ID_skillTip%d" % k, not was)


func _run_loading() -> void:
	lay.show("ID_btnOk", false)
	lay.show("ID_loadingBar", true)
	var graph := lay.node("ID_loadingGraph")
	var full := graph.size.x
	graph.size.x = 0.0
	var tw := create_tween()
	for i in LOADING.size():
		tw.tween_callback(lay.text.bind("ID_loadingText", LOADING[i]))
		tw.tween_property(graph, "size:x", full * (i + 1) / LOADING.size(), 0.5)
	tw.tween_callback(func():
		lay.show("ID_loadingBar", false)
		lay.show("ID_btnOk", true))


func _on_esc() -> void:
	if lay.node("ID_monDetailPage").visible:
		_show_choice()
	else:
		main.go("title", {"ask": true})


func _on_start() -> void:
	if _confirm != null and is_instance_valid(_confirm.root):
		return
	_confirm = Layout.load_into(self, "R_d_startMonsterPopup")
	_confirm.root.z_index = 80
	_confirm.node("ID_9PATCH_2").mouse_filter = MOUSE_FILTER_STOP
	for k in STARTERS.size():
		_confirm.show("ID_ev%d" % (k + 1), k == _pick)
	_confirm.on("ID_btnOk", _begin)
	_confirm.on("ID_btnEsc", func(): _confirm.root.queue_free())


func _begin() -> void:
	Save.start_new_game(STARTERS[_pick])
	Save.data["name"] = String(args.get("name", "Tamer"))
	Save.save_game()
	main.go("hub")
