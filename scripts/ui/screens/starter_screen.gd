extends Screen

const STARTERS := ["firepaw", "belle", "pangy"]
const STARTER_SUPPORT := ["dripbal", "leavbal", "pufbal"]


func build() -> void:
	UI.background(self, UI.tex("res://assets/apk/images/Forest_1.png"), 0.35)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 24)
	add_child(v)
	var title := UI.label("Choose your first monster!", 38, UI.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	v.add_child(row)
	for id in STARTERS:
		var def := DB.monster(id)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var card := UI.monster_card(id, 0, 0, Vector2(220, 220))
		col.add_child(card)
		var name_label := UI.label("%s" % def.name, 28)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(name_label)
		var el := UI.label(String(def.element).capitalize(), 20, DB.element_color(def.element))
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(el)
		col.add_child(UI.button("Choose", _choose.bind(id), "yellow", Vector2(180, 60)))
		row.add_child(col)


func _choose(id: String) -> void:
	Save.reset()
	var team := [int(Save.add_monster(id, 1).uid)]
	for s in STARTER_SUPPORT:
		team.append(int(Save.add_monster(s, 1).uid))
	Save.set_team(team)
	main.go("hub")
