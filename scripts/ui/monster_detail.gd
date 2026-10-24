class_name MonsterDetail
extends RefCounted


static func build(id: String, level: int = 1, boost: int = 0) -> Control:
	var def := DB.monster(id)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	var left := VBoxContainer.new()
	root.add_child(left)
	left.add_child(UI.monster_card(id, level, boost, Vector2(190, 190)))
	left.add_child(_text("%s  ·  Class %s" % [String(def.element).capitalize(), def["class"]], 18, DB.element_color(def.element)))
	left.add_child(_text(String(def.rarity).replace("_", " ").capitalize(), 18))
	if def.quote != "":
		var q := _text("“%s”" % def.quote, 15)
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		q.custom_minimum_size.x = 190
		left.add_child(q)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.custom_minimum_size.x = 520
	root.add_child(right)
	var st := DB.stats_at(id, level, boost)
	right.add_child(_text("Lv.%d   HP %d   ATK %d   DEF %d   REC %d   MP %d" % [level, st.hp, st.atk, st.def, st.rec, st.mp], 18))
	right.add_child(_text("Leader skills", 18, Color("8a3a00")))
	for s in def.skills:
		right.add_child(_text("• %s (%d MP): %s" % [s.name, int(s.mp), s.description], 16))
	var sup: Dictionary = def.support_skill
	if sup.name != "":
		right.add_child(_text("Support skill (every %ds)" % int(sup.cooldown), 18, Color("8a3a00")))
		right.add_child(_text("• %s: %s" % [sup.name, sup.description], 16))
	if def.passive != "":
		right.add_child(_text("Passive (as support)", 18, Color("8a3a00")))
		right.add_child(_text("• " + def.passive, 16))
	if def.evolves_into != "":
		var mat := ""
		if def.evolve_material != "":
			mat = " with %d× %s" % [int(def.evolve_quantity), DB.monster(def.evolve_material).get("name", "?")]
		right.add_child(_text("Evolves into %s at Lv.%d%s" % [DB.monster(def.evolves_into).name, DB.MAX_LEVEL, mat], 16, Color("1f5a8a")))
	if def.location != "":
		var loc := _text("Found: " + def.location, 15)
		loc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		right.add_child(loc)
	return root


static func _text(t: String, size: int, color: Color = UI.BROWN) -> Label:
	var l := UI.label(t, size, color)
	l.add_theme_constant_override("outline_size", 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 500 if size <= 18 else 0
	return l
