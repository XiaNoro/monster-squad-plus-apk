extends Screen

const PER_ROW := 7

var lay: Layout


func build() -> void:
	brown_background()
	lay = Layout.load_into(self, "R_BadgeBookPage")
	add_top_bar("2", " ", "hub")
	for i in LeagueSeasons.GRADES.size():
		lay.text("ID_numText_%d" % (i + 1), str(LeagueSeasons.badges_owned(LeagueSeasons.GRADES[i])))
	lay.text("ID_numText", str(LeagueSeasons.badge_points()))
	var rows := []
	var row: HBoxContainer = null
	var n := 0
	for i in LeagueSeasons.SEASONS.size():
		for grade in LeagueSeasons.GRADES:
			if n % PER_ROW == 0:
				row = HBoxContainer.new()
				row.add_theme_constant_override("separation", 0)
				rows.append(row)
			row.add_child(_slot(i, grade))
			n += 1
	lay.list_into("ID_ID_arrayPosition", rows, 0)


func _count(i: int, grade: String) -> int:
	return int(Save.data.get("badges", {}).get(LeagueSeasons.badge_key(i, grade), 0))


func _slot(i: int, grade: String) -> Control:
	var s := Layout.instance("B_badgeIcon_slide")
	var owned := _count(i, grade)
	for id in ["ID_badgeEmpty", "ID_check", "ID_select", "ID_txtSelect"]:
		s.show(id, false)
	var pic := UI.image(LeagueSeasons.badge_texture(i, grade), Vector2(84, 84))
	pic.size = Vector2(84, 84)
	pic.position = Vector2(8, 12)
	pic.mouse_filter = MOUSE_FILTER_IGNORE
	s.node("ID_backImage").add_child(pic)
	var black: Control = s.node("ID_badgeBlack")
	black.visible = owned == 0
	black.get_parent().move_child(black, -1)
	if owned > 1:
		var c := UI.label("x%d" % owned, 18, Color.WHITE)
		c.position = Vector2(60, 72)
		s.node("ID_backImage").add_child(c)
	var hit := Button.new()
	hit.flat = true
	hit.size = s.root.size
	hit.pressed.connect(_show_badge.bind(i, grade))
	s.root.add_child(hit)
	return s.root


func _show_badge(i: int, grade: String) -> void:
	var d := Layout.load_into(self, "R_d_badgeView")
	d.root.z_index = 80
	d.node("ID_9PATCH_2").mouse_filter = MOUSE_FILTER_STOP
	var owned := _count(i, grade)
	var pic := UI.image(LeagueSeasons.badge_texture(i, grade), Vector2(146, 146))
	if owned == 0:
		pic.modulate = Color(0.35, 0.35, 0.35)
	d.put("ID_badgePostion", pic, Vector2(146, 146))
	var league := String(LeagueSeasons.SEASONS[i].name)
	var title := d.text("ID_badgeName", "%s (%s)" % [LeagueSeasons.badge_name(i), grade.capitalize()])
	UI.fit_text(title, title.get_theme_font_size("font_size"), 13, title.get_meta("area").x)
	var body := "Earned %d time%s in the %s.\n%d Badge Points each." % [owned, "" if owned == 1 else "s", league, int(LeagueSeasons.BADGE_POINTS[grade])] if owned > 0 else "This badge can get in %s (%s)." % [league, LeagueSeasons.badge_rank_text(grade)]
	var l := d.text("ID_baseText", body)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var root := d.root
	d.on("ID_btnOk", root.queue_free)
	d.on("ID_btnEsc", root.queue_free)
