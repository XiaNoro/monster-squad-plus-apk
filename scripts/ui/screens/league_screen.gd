class_name LeagueScreen
extends Screen

const SORTS := ["Level", "Grade", "HP", "Attack"]
const SHOWN_RANKS := 50

var lay: Layout
var edit_lay: Layout
var match_lay: Layout
var _sel_slot := -1
var _sort := 0
var _rival: Dictionary = {}
var _paid_entry := false


func build() -> void:
	UI.background(self, UI.tex(LeagueSeasons.bg_path()), 0.3)
	lay = Layout.load_into(self, "R_pvpGroupEnterPage")
	add_top_bar("5", "Waiting Room", "hub")
	lay.text("ID_groupText", "PvP League Team")
	lay.text("ID_monName", "League Match Info")
	lay.text("ID_rankText", "View All Rank")
	lay.on("ID_btnMyRank", _show_ranks)
	lay.on("ID_btnEditTeam", _open_editor)
	lay.on("ID_btnRewardView", show_rewards.bind(self))
	lay.on("ID_btnEnter", _enter)
	lay.show("ID_IMAGE_2", false)
	lay.show("ID_IMAGE_3", false)
	lay.text("ID_pointText", str(Save.LEAGUE_ENTRY))
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_refresh_info)
	add_child(timer)
	_fill_team(lay, "ID_ID_arrayPosition", false)
	_refresh_info()
	var l := Save.league()
	var last: Dictionary = l.get("last_season", {})
	if not last.is_empty() and not bool(l.get("last_seen", false)):
		l.last_seen = true
		Save.save_game()
		UI.notice(self, String(last.get("name", "Last Season")), "Rank %d with %s Points\n+%d Honor, +%d Gems (check your Messages)%s%s" % [int(last.rank), Screen._thousands(int(last.points)), int(last.honor), int(last.get("gems", 0)), ("\n%s %s (Badge List)" % [String(last.badge).capitalize(), String(last.name).trim_suffix(" League") + " Badge"]) if String(last.badge) != "" else "", "\nLeague wing on your monsters' names" if int(last.get("wing", 0)) > 0 else ""])
	if args.has("edit"):
		_open_editor()
	elif args.has("match"):
		_enter()
	elif args.has("ranks"):
		_show_ranks()


func _refresh_info() -> void:
	if not lay.root.visible:
		return
	var l := Save.league()
	var rank := Save.league_rank(l, LeagueSeasons.progress())
	lay.text("ID_rankingText2", ("%d (%.1f%%)" % [rank, 100.0 * rank / float(Arena.RIVALS + 1)]) if int(l.rounds) > 0 else "-")
	lay.text("ID_scoreText2", "%s Points" % Screen._thousands(int(l.points)))
	lay.text("ID_winText2", "%d Wins" % int(l.wins))
	lay.text("ID_reWinText2", "%d Wins" % int(l.streak))
	lay.text("ID_weekText2", "%d Rounds" % int(l.rounds))
	var tickets := Save.league_tickets()
	for i in Save.LEAGUE_TICKETS:
		lay.show("ID_ticket_%02d" % (Save.LEAGUE_TICKETS - i), i < tickets)
	var wait := Save.LEAGUE_TICKET_SECONDS - int(Time.get_unix_time_from_system() - float(l.stamp))
	lay.text("ID_ticketTime2", UI.format_time(maxi(0, wait)) if tickets < Save.LEAGUE_TICKETS else "--:--")


func _team() -> Array:
	return Save.league().team


func _fill_team(l: Layout, id: String, editing: bool, holder: Control = null) -> void:
	var team := _team()
	var rows := []
	var row: HBoxContainer
	for i in LeagueSeasons.team_size():
		if i % 3 == 0:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 0)
			rows.append(row)
		var m := Save.get_owned(int(team[i])) if i < team.size() else {}
		var slot := _group_slot(m, i + 1, editing and i == _sel_slot)
		if editing:
			slot.mouse_filter = MOUSE_FILTER_STOP
			slot.gui_input.connect(_on_slot_input.bind(i))
		row.add_child(slot)
	if holder != null:
		Layout.list_into_node(holder, rows, 0)
	else:
		l.list_into(id, rows, 0)


func _group_slot(m: Dictionary, n: int, selected: bool) -> Control:
	var s := Layout.instance("R_pvpGroupSlot")
	s.text("ID_Number_1", str(n))
	s.show("ID_monChange", selected)
	s.show("ID_stat", not m.is_empty())
	s.show("ID_skill", not m.is_empty())
	if m.is_empty():
		return s.root
	var card := UI.monster_card(String(m.id), int(m.level), int(m.boost), Vector2(92, 92))
	card.mouse_filter = MOUSE_FILTER_IGNORE
	s.put("ID_monsterIcon", card)
	var def := DB.monster(String(m.id))
	if not def.skills.is_empty():
		var ic := UI.image(DB.skill_icon(String(def.skills[0].icon)), Vector2(40, 40))
		ic.size = Vector2(40, 40)
		s.put("ID_skillImage", ic)
	var st := DB.stats_at(String(m.id), int(m.level), int(m.boost))
	s.text("ID_monHp", str(int(st.hp)))
	s.text("ID_monAp", str(int(st.atk)))
	return s.root


func _open_editor() -> void:
	if Save.data.monsters.size() < LeagueSeasons.team_size():
		UI.notice(self, "Notice", "You need at least %d monsters for the PvP League." % LeagueSeasons.team_size())
		return
	lay.root.visible = false
	if edit_lay == null:
		edit_lay = Layout.load_into(self, "R_pvpGroupEditPage")
		move_child(edit_lay.root, top.root.get_index())
		edit_lay.text("ID_groupText", "PvP League Team")
		edit_lay.on("ID_btnAlign", _cycle_sort)
		edit_lay.on("ID_btnTeamAuto", _team_auto)
	_back_target = "league"
	_refresh_editor()


func _refresh_editor() -> void:
	edit_lay.text("ID_LABEL_4", SORTS[_sort])
	_fill_team(edit_lay, "", true, edit_lay.node("ID_friend").find_child("ID_ID_arrayPosition", true, false))
	var owned: Array = Save.data.monsters.duplicate()
	owned.sort_custom(_sorter())
	var team: Array = _team().slice(0, LeagueSeasons.team_size()).map(func(u): return int(u))
	var cells: Array = [_remove_cell()]
	for m in owned:
		var card := UI.monster_card(String(m.id), int(m.level), int(m.boost), Vector2(96, 96))
		var at := team.find(int(m.uid))
		if at >= 0:
			card.modulate = Color(0.55, 0.55, 0.55)
			var tick := UI.label(str(at + 1), 34, UI.GOLD)
			tick.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
			tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tick.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			card.add_child(tick)
		card.mouse_filter = MOUSE_FILTER_STOP
		card.gui_input.connect(_on_pick.bind(int(m.uid)))
		cells.append(card)
	var rows := []
	var row: HBoxContainer
	for i in cells.size():
		if i % 4 == 0:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			rows.append(row)
		row.add_child(cells[i])
	Layout.list_into_node(edit_lay.node("ID_monster").find_child("ID_ID_arrayPosition", true, false), rows, 4)


func _remove_cell() -> Control:
	var b := TextureButton.new()
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.texture_normal = UI.tex("betaUI00/B_monEmpty_03.png")
	b.custom_minimum_size = Vector2(96, 96)
	var l := UI.label("Remove", 20, Color.WHITE)
	l.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(l)
	b.pressed.connect(_remove_selected)
	return b


func _sorter() -> Callable:
	match SORTS[_sort]:
		"Grade":
			return func(a, b): return DB.compare_grade(a, b) > 0 or (DB.compare_grade(a, b) == 0 and int(a.level) > int(b.level))
		"HP":
			return func(a, b): return int(DB.stats_at(a.id, int(a.level), int(a.boost)).hp) > int(DB.stats_at(b.id, int(b.level), int(b.boost)).hp)
		"Attack":
			return func(a, b): return int(DB.stats_at(a.id, int(a.level), int(a.boost)).atk) > int(DB.stats_at(b.id, int(b.level), int(b.boost)).atk)
	return func(a, b): return int(a.level) > int(b.level) or (int(a.level) == int(b.level) and int(DB.monster(a.id).stars) > int(DB.monster(b.id).stars))


func _cycle_sort() -> void:
	_sort = (_sort + 1) % SORTS.size()
	_refresh_editor()


func _pressed(e: InputEvent) -> bool:
	return UI.tapped(e)


func _on_slot_input(e: InputEvent, i: int) -> void:
	if not _pressed(e):
		return
	_sel_slot = -1 if _sel_slot == i else i
	Sfx.play("click")
	_refresh_editor()


func _on_pick(e: InputEvent, uid: int) -> void:
	UI.hold(e, func():
		if is_inside_tree():
			MonsterPopup.info(self, uid))
	if not _pressed(e):
		return
	var l := Save.league()
	var team: Array = l.team.map(func(u): return int(u))
	var size := LeagueSeasons.team_size()
	if uid in team.slice(0, size):
		team.erase(uid)
	elif _sel_slot >= 0 and _sel_slot < team.size():
		team[_sel_slot] = uid
		_sel_slot = -1
	elif size == 1:
		team.erase(uid)
		team.push_front(uid)
	elif team.size() < size:
		team.append(uid)
	else:
		UI.toast(self, "Select a team slot to replace")
		return
	l.team = team
	Save.save_game()
	Sfx.play("click")
	_refresh_editor()


func _remove_selected() -> void:
	var l := Save.league()
	var team: Array = l.team.map(func(u): return int(u))
	if _sel_slot < 0 or _sel_slot >= team.size():
		UI.toast(self, "Select a team slot first")
		return
	team.remove_at(_sel_slot)
	_sel_slot = -1
	l.team = team
	Save.save_game()
	_refresh_editor()


func _team_auto() -> void:
	var owned: Array = Save.data.monsters.duplicate()
	owned.sort_custom(func(a, b): return power_of(a) > power_of(b))
	var picked := []
	var species := {}
	for m in owned:
		if picked.size() >= Save.LEAGUE_TEAM:
			break
		if species.has(m.id):
			continue
		species[m.id] = true
		picked.append(int(m.uid))
	for m in owned:
		if picked.size() >= Save.LEAGUE_TEAM:
			break
		if not int(m.uid) in picked:
			picked.append(int(m.uid))
	Save.league().team = picked
	Save.save_game()
	_sel_slot = -1
	_refresh_editor()


static func power_of(m: Dictionary) -> float:
	var st := DB.stats_at(m.id, int(m.level), int(m.boost))
	return float(st.hp) + 4.0 * float(st.atk) + 2.0 * float(st.rec)


func _ladder() -> Array:
	var l := Save.league()
	var progress := LeagueSeasons.progress()
	var power := per_four(_owned(l.team))
	var out := []
	for r in Arena.rivals(int(l.season) + 7777):
		out.append({"name": r.name, "points": Save.LEAGUE_START_POINTS + Arena.rival_points(r, progress, Save.LEAGUE_SEASON_GAMES), "leader": Arena.rival_team(r, power)[0], "me": false})
	var mine := _owned(l.team)
	var lead: Dictionary = {"id": mine[0].id, "level": int(mine[0].level), "boost": int(mine[0].boost)} if not mine.is_empty() else {"id": "firepaw", "level": 1, "boost": 0}
	out.append({"name": String(Save.data.get("name", "Tamer")), "points": int(l.points), "leader": lead, "me": true})
	out.sort_custom(func(x, y): return int(x.points) > int(y.points) or (int(x.points) == int(y.points) and bool(x.me)))
	for i in out.size():
		out[i]["rank"] = i + 1
	return out


func _show_ranks() -> void:
	var d := Layout.load_into(self, "R_d_pvpRankGr")
	d.root.z_index = 80
	d.node("ID_9PATCH_2").mouse_filter = MOUSE_FILTER_STOP
	var rows := []
	var my_row := 0
	for r in _ladder():
		if int(r.rank) > SHOWN_RANKS and not bool(r.me):
			continue
		if bool(r.me):
			my_row = rows.size()
		var s := Layout.instance("R_pvpRankGrSlot")
		var card := UI.monster_card(String(r.leader.id), int(r.leader.level), int(r.leader.boost), Vector2(92, 92))
		card.mouse_filter = MOUSE_FILTER_IGNORE
		s.put("ID_position", card)
		s.show("ID_btnMList", false)
		var name_l := s.text("ID_txtUserName", String(r.name))
		var score_l := s.text("ID_txtPvpScore", "(%d) %s Points" % [int(r.rank), Screen._thousands(int(r.points))])
		var rk := int(r.rank)
		if rk <= 3:
			var medal := UI.image(Layout.texture("K_rankS_0%d.png" % rk), Vector2(48, 48))
			medal.size = Vector2(48, 48)
			s.put("ID_rankingIcon", medal)
		else:
			name_l.position.x = 14.0
			score_l.position.x = 14.0
		if bool(r.me):
			name_l.add_theme_color_override("font_color", Color("ffe14a"))
		rows.append(s.root)
	var list := d.list_into("ID_arrayPosition", rows, 2)
	var root := d.root
	d.on("ID_btnEsc", root.queue_free)
	await get_tree().process_frame
	if is_instance_valid(list) and list.get_parent() is ScrollContainer:
		(list.get_parent() as ScrollContainer).scroll_vertical = maxi(0, my_row * 106 - 160)


static func show_rewards(parent: Control) -> void:
	var s := LeagueSeasons.season()
	var d := Layout.load_into(parent, "R_d_pvpLegueRewardView")
	d.root.z_index = 80
	d.node("ID_9PATCH_2").mouse_filter = Control.MOUSE_FILTER_STOP
	d.text("ID_titleText", LeagueSeasons.title(s))
	for i in LeagueSeasons.REWARDS.size():
		var row: Array = LeagueSeasons.REWARDS[i]
		d.text("ID_rankText_%d" % (i + 1), String(row[0]))
		d.text("ID_honorText_%d" % (i + 1), Screen._thousands(int(row[2])))
		d.text("ID_jemText_%d" % (i + 1), str(int(row[3])))
		if String(row[4]) != "":
			var badge := UI.image(LeagueSeasons.badge_texture(int(s.id), String(row[4])), Vector2(146, 146))
			d.put("ID_badgeImage_%d" % (i + 1), badge, Vector2(146, 146))
	var t := d.text("ID_timeText", LeagueSeasons.intro(s) + "\n" + LeagueSeasons.end_text(s))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.text("ID_monText", "Boosted League Monsters").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for k in mini(3, (s.boost as Array).size()):
		var holder: Control = d.node("ID_monIcon%d" % (k + 1))
		var card := UI.monster_card(String(s.boost[k]), 1, 0, holder.size)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.put("ID_monIcon%d" % (k + 1), card)
	d.text("ID_ruleText", "\n".join(LeagueSeasons.rule_lines(s))).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.hide_all(["ID_btnPage1", "ID_btnPage2", "ID_page_2"])
	var root := d.root
	d.on("ID_btnEsc", root.queue_free)


func _enter() -> void:
	if _team().size() < LeagueSeasons.team_size():
		UI.notice(self, "Notice", "Register %d monsters with Edit Team first." % LeagueSeasons.team_size())
		return
	if Save.league_tickets() < Save.LEAGUE_ENTRY and int(Save.data.gold) >= Save.LEAGUE_GOLD_ENTRY:
		UI.notice(self, "Notice", "1 gem (Solo) / %s Gold (League) will be used as you have no tickets." % Screen._thousands(Save.LEAGUE_GOLD_ENTRY), _pick_rival.bind(true))
		return
	if Save.league_tickets() < Save.LEAGUE_ENTRY:
		UI.notice(self, "Notice", "Not enough Entry Tickets.\n(A ticket recharges every %d minutes.)" % (Save.LEAGUE_TICKET_SECONDS / 60))
		return
	_pick_rival(false)


func _pick_rival(paid: bool) -> void:
	_paid_entry = paid
	var l := Save.league()
	var rivals := Arena.rivals(int(l.season) + 7777)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(l.season) * 31 + int(l.rounds)
	_rival = rivals[rng.randi() % rivals.size()]
	_show_match()


func _show_match() -> void:
	lay.root.visible = false
	if match_lay != null:
		match_lay.root.queue_free()
	match_lay = Layout.load_into(self, "R_pvpStartPageGr")
	move_child(match_lay.root, top.root.get_index())
	_back_target = "league"
	var l := Save.league()
	var size := LeagueSeasons.team_size()
	var mine := _owned(l.team).slice(0, size)
	var their := rival_league_team(_rival, per_four(mine), size)
	var ladder := _ladder()
	var my_rank := 0
	var their_rank := 0
	var their_points := 0
	for r in ladder:
		if bool(r.me):
			my_rank = int(r.rank)
		elif String(r.name) == String(_rival.name):
			their_rank = int(r.rank)
			their_points = int(r.points)
	match_lay.text("ID_nameText_1", String(Save.data.get("name", "Tamer")))
	match_lay.text("ID_rankingText_1", "Rank %d (%s points)" % [my_rank, Screen._thousands(int(l.points))])
	match_lay.text("ID_nameText_2", String(_rival.name))
	match_lay.text("ID_rankingText_2", "Rank %d (%s points)" % [their_rank, Screen._thousands(their_points)])
	_photo("ID_photo_1", String(mine[0].id))
	_photo("ID_photo_2", String(their[0].id))
	for i in 12:
		if i >= size:
			match_lay.hide_all(["ID_myMon%d" % i, "ID_enemyMon%d" % i])
			continue
		if i < mine.size():
			var c := UI.monster_card(String(mine[i].id), int(mine[i].level), int(mine[i].boost), Vector2(92, 92))
			c.mouse_filter = MOUSE_FILTER_IGNORE
			match_lay.put("ID_myIcon%d" % i, c)
		if i < 4 and i < their.size():
			var e := UI.monster_card(String(their[i].id), int(their[i].level), int(their[i].boost), Vector2(92, 92))
			e.mouse_filter = MOUSE_FILTER_IGNORE
			match_lay.put("ID_enemyIcon%d" % i, e)
		else:
			match_lay.node("ID_enemyMon%d" % i).modulate = Color(0.55, 0.55, 0.55)
			var q := UI.label("?", 44, Color(0.85, 0.85, 0.85))
			q.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			match_lay.put("ID_enemyIcon%d" % i, q)
	match_lay.on("ID_btnPvpStart", _start.bind(league_specs(l.team.slice(0, size)), their))


func _photo(id: String, monster_id: String) -> void:
	var p := UI.monster_card(monster_id, 0, 0, Vector2(80, 80))
	p.mouse_filter = MOUSE_FILTER_IGNORE
	match_lay.put(id, p)


func _start(my_team: Array, their: Array) -> void:
	if _paid_entry:
		if int(Save.data.gold) < Save.LEAGUE_GOLD_ENTRY:
			UI.notice(self, "Notice", "Not enough Gold.")
			return
		Save.data.gold = int(Save.data.gold) - Save.LEAGUE_GOLD_ENTRY
		Save.save_game()
	elif not Save.spend_league_entry():
		UI.notice(self, "Notice", "Not enough Entry Tickets.")
		return
	var season := LeagueSeasons.season()
	main.go("battle", {"quest": {
		"kind": "league", "key": "league", "title": "PvP League  ·  vs %s" % _rival.name,
		"rival_name": _rival.name, "rival_skill": float(_rival.skill),
		"energy": 0, "level": 30, "boss": their[0].id, "enemies": [], "stages": 1,
		"gold": 0.0, "exp": 0.0, "drops": false, "boss_drop_chance": 0.0, "drop_level": [1, 1], "first_clear_drop": false,
		"pvp": true, "league_team": my_team, "league_enemy": their, "season": int(season.id), "bg": String(season.bg),
	}})


static func _owned(uids: Array) -> Array:
	var out := []
	for u in uids:
		var m := Save.get_owned(int(u))
		if not m.is_empty():
			out.append(m)
	return out


static func league_specs(uids: Array) -> Array:
	var out := []
	for m in _owned(uids):
		out.append({"id": m.id, "level": int(m.level), "boost": int(m.boost), "stones": Save.stone_bonuses(m), "pet": Save.pet_spec(m)})
	return out


static func per_four(team: Array) -> float:
	return Arena.power_of(team) * 4.0 / maxf(1.0, team.size())


static func rival_league_team(r: Dictionary, power_per_four: float, size: int = Save.LEAGUE_TEAM) -> Array:
	var out := []
	for k in ceili(size / 4.0):
		var variant := r.duplicate()
		variant.seed = int(r.seed) + k * 101
		out += Arena.rival_team(variant, power_per_four)
	return out.slice(0, size)
