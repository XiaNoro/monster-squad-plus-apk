class_name ArenaScreen
extends Screen

const SHOWN_RANKS := 50
const ELEMENT_ORBS := {"fire": "fire", "water": "water", "nature": "natural", "normal": "balance"}

var lay: Layout
var match_lay: Layout
var match_bg: Control
var _rank_tab := "all"
var _rival_idx := -1


func build() -> void:
	UI.brown_background(self)
	lay = Layout.load_into(self, "R_pvpEnterPage")
	add_top_bar("5", "Waiting Room", "hub")
	lay.on("ID_tapAll", _set_rank_tab.bind("all"))
	lay.on("ID_tapFriend", _set_rank_tab.bind("friend"))
	lay.on("ID_btnweekRank", _show_last_week)
	lay.on("ID_btnMyRank", _show_my_rank)
	lay.on("ID_btnRewardView", show_rewards.bind(self))
	lay.on("ID_btnEnter", _enter)
	lay.text("ID_Time", "Challenge rank is reset every Saturday at midnight.\nRank is applied every 30 minutes.")
	var t := lay.node("ID_Time") as Label
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_size_override("font_size", 16)
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_refresh_info)
	add_child(timer)
	_set_rank_tab("all")
	_refresh_info()
	var a := Save.arena_state()
	var last: Dictionary = a.get("last_week", {})
	if not last.is_empty() and not bool(a.get("last_seen", false)):
		a.last_seen = true
		Save.save_game()
		UI.notice(self, "Last Week's Rank", _last_week_text(last))
	if args.has("match"):
		_enter()


static func unlocked() -> bool:
	if Tutorial.is_done("arena_open"):
		return true
	return not Tutorial.enabled() and Save.cleared_stages("desert_isle", "normal") >= 4


static func open_select(screen: Screen) -> void:
	if not unlocked():
		UI.toast(screen, "Defeat the boss of Desert-4 to open the Arena!")
		return
	var d := Layout.load_into(screen, "R_d_selectAnArena")
	d.root.z_index = 80
	d.node("ID_9PATCH_2").mouse_filter = Control.MOUSE_FILTER_STOP
	d.text("ID_LABEL_5", "Arena")
	d.text("ID_LABEL_6", "PvP League")
	d.show("ID_alert1", Save.arena_tokens() >= Arena.MAX_TOKENS)
	d.show("ID_alert2", Save.league_tickets() > 0)
	var root := d.root
	d.on("ID_btnEsc", root.queue_free)
	d.on("ID_btnPVP1", func(): screen.main.go("arena"))
	d.on("ID_btnPVP2", func(): screen.main.go("league"))


func _set_rank_tab(t: String) -> void:
	_rank_tab = t
	lay.select_tab(["ID_tapAll", "ID_tapFriend"], "ID_tapAll" if t == "all" else "ID_tapFriend")
	var rows := []
	for r in _ladder(t):
		rows.append(_rank_slot(r))
	lay.show("ID_NoSelection", rows.is_empty())
	lay.list_into("ID_ID_arrayPosition", rows, 2)


func _ladder(t: String) -> Array:
	var a := Save.arena_state()
	var progress := Arena.week_progress()
	var power := Arena.power_of(Save.team_members())
	var out := []
	if t == "all":
		for r in Arena.rivals(int(a.week)):
			out.append({"name": r.name, "points": Arena.rival_points(r, progress), "leader": Arena.rival_team(r, power)[0], "me": false})
	else:
		for f in Save.data.get("friends", []):
			var h := absi(hash(String(f.name)))
			var pseudo := {"activity": 0.3 + float(h % 70) / 100.0, "skill": float((h / 70) % 100) / 100.0}
			out.append({"name": f.name, "points": Arena.rival_points(pseudo, progress), "leader": {"id": f.monster, "level": int(f.level), "boost": int(f.get("boost", 0))}, "me": false})
	var team := Save.team_members()
	var mine := {"id": team[0].id, "level": int(team[0].level), "boost": int(team[0].boost)} if not team.is_empty() else {"id": "firepaw", "level": 1, "boost": 0}
	out.append({"name": String(Save.data.get("name", "Tamer")), "points": int(a.points), "leader": mine, "me": true})
	out.sort_custom(func(x, y): return int(x.points) > int(y.points))
	var shown := []
	for i in out.size():
		out[i]["rank"] = i + 1
		if i < SHOWN_RANKS or bool(out[i].me):
			shown.append(out[i])
	return shown


func _rank_slot(r: Dictionary) -> Control:
	var s := Layout.instance("R_pvpRankSlot")
	var card := UI.monster_card(String(r.leader.id), int(r.leader.level), int(r.leader.boost), Vector2(92, 92))
	card.mouse_filter = MOUSE_FILTER_IGNORE
	s.put("ID_leaderIcon", card)
	s.text("ID_friendName", String(r.name))
	s.text("ID_friendScore", "(%d) (%s Pts)" % [int(r.rank), Screen._thousands(int(r.points))])
	s.show("ID_btnInvite", not bool(r.me))
	if not bool(r.me):
		var player := {"name": String(r.name), "monster": String(r.leader.id), "level": int(r.leader.level), "boost": int(r.leader.boost)}
		var a := {"player": player, "back": "arena", "rank": int(r.rank)}
		if r.has("team"):
			a["team"] = r.team
		s.on("ID_btnInvite", func(): main.go("visit", a))
	s.show("ID_myIcon", bool(r.me))
	var rk := int(r.rank)
	s.show("ID_rank1st", rk == 1)
	s.show("ID_rank2nd", rk == 2)
	s.show("ID_rank3rd", rk == 3)
	(s.node("ID_friendName") as Label).position.x = 46.0 if rk <= 3 else 16.0
	(s.node("ID_friendScore") as Label).position.x = 46.0 if rk <= 3 else 16.0
	return s.root


func _refresh_info() -> void:
	var a := Save.arena_state()
	var rank := Save.arena_rank(a, Arena.week_progress())
	var played := int(a.wins) + int(a.losses)
	lay.text("ID_rankingText2", ("Rank %d (%.1f%%)" % [rank, 100.0 * rank / float(Arena.RIVALS + 1)]) if played > 0 else "-")
	lay.text("ID_scoreText2", "%s Points" % Screen._thousands(int(a.points)))
	lay.text("ID_winText2", "%d Wins" % int(a.wins))
	lay.text("ID_reWinText2", "%d Wins" % int(a.get("streak", 0)))
	lay.text("ID_weekText2", "%d Rounds" % played)
	var tokens := Save.arena_tokens()
	for i in Arena.MAX_TOKENS:
		lay.show("ID_ticket_%02d" % (i + 1), i < tokens)
	var wait := Save.seconds_to_next_token()
	lay.text("ID_ticketTime2", UI.format_time(wait) if wait > 0 else "--:--")
	var use_gem := tokens <= 0
	lay.show("ID_IMAGE_1", not use_gem)
	lay.show("ID_IMAGE_2", use_gem)
	lay.text("ID_pointText", str(Arena.GEM_ENTRY if use_gem else 1))


func _show_last_week() -> void:
	var last: Dictionary = Save.arena_state().get("last_week", {})
	if last.is_empty():
		UI.notice(self, "Last Week's Rank", "You didn't take part in the arena last week.")
	else:
		UI.notice(self, "Last Week's Rank", _last_week_text(last))


static func _last_week_text(last: Dictionary) -> String:
	var lucky: Array = last.get("lucky", [])
	return "Rank %d with %s Points\n+%d Honor   +%d Gems%s" % [int(last.rank), Screen._thousands(int(last.points)), int(last.honor), int(last.gems), "" if lucky.is_empty() else "\nLucky Chest %s! (check your Messages)" % ", ".join(lucky)]


func _show_my_rank() -> void:
	if _rank_tab != "all":
		_set_rank_tab("all")
	var list := lay.node("ID_ID_arrayPosition")
	for sc in list.find_children("*", "ScrollContainer", false, false):
		var a := Save.arena_state()
		var rank := Save.arena_rank(a, Arena.week_progress())
		var row := mini(rank, SHOWN_RANKS + 1) - 1
		(sc as ScrollContainer).scroll_vertical = maxi(0, row * 102 - 120)


static func show_rewards(parent: Control) -> void:
	var d := Layout.load_into(parent, "R_d_pvpRewardView")
	d.root.z_index = 80
	d.node("ID_9PATCH_2").mouse_filter = Control.MOUSE_FILTER_STOP
	for i in Arena.RANK_REWARDS.size():
		d.text("ID_rankText_%d" % (i + 1), String(Arena.RANK_REWARDS[i][0]))
		d.text("ID_honorText_%d" % (i + 1), "%d Points" % int(Arena.RANK_REWARDS[i][2]))
	for i in Arena.ROUND_REWARDS.size():
		d.text("ID_roundText_%d" % (i + 1), String(Arena.ROUND_REWARDS[i][0]))
		d.text("ID_crystalText_%d" % (i + 1), str(int(Arena.ROUND_REWARDS[i][2])))
	for id in ["ID_timeText", "ID_imageTitle"]:
		var l := d.node(id) as Label
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.set_deferred("size", l.get_meta("area"))
	d.text("ID_timeText", "Rewards can be received once a week. Calculation will be made Saturday 00:00 and is sent straight away.")
	for i in Arena.LUCKY_REWARDS.size():
		var t: Array = Arena.LUCKY_REWARDS[i]
		d.text("ID_win%dText" % (i + 1), String(t[0]))
		d.text("ID_win%dTextReward" % (i + 1), Screen._thousands(int(t[2])))
	for i in 2:
		var slot: Control = d.node("ID_ID_arrayPosition_%d" % (i + 1))
		var pic := UI.image(UI.tex("res://assets/ui/arena_%s_banner.png" % ["gems", "lucky"][i]), slot.size, TextureRect.STRETCH_SCALE)
		pic.size = slot.size
		slot.add_child(pic)
		d.show("ID_imageText_%d" % (i + 1), false)
	var pic := UI.image(UI.tex("betaUI00/I_honor_02.png"), Vector2(180, 180))
	pic.size = Vector2(180, 180)
	pic.position = Vector2(151, 98)
	d.node("ID_imageBack").add_child(pic)
	var page := func(n: int) -> void:
		d.show("ID_page_1", n == 1)
		d.show("ID_page_2", n == 2)
		d.show("ID_btnPage1", n == 2)
		d.show("ID_btnPage2", n == 1)
	page.call(1)
	d.on("ID_btnPage1", page.bind(1))
	d.on("ID_btnPage2", page.bind(2))
	var root := d.root
	d.on("ID_btnEsc", root.queue_free)


func _enter() -> void:
	if Save.team_members().is_empty():
		UI.notice(self, "Notice", "Your squad is empty!")
		return
	if Save.arena_tokens() <= 0 and int(Save.data.gems) >= Arena.GEM_ENTRY:
		UI.notice(self, "Notice", "%d gem (Solo) / %s Gold (League) will be used as you have no tickets." % [Arena.GEM_ENTRY, Screen._thousands(Save.LEAGUE_GOLD_ENTRY)], _spend_and_match)
		return
	_spend_and_match()


func _spend_and_match() -> void:
	if not Save.spend_arena_entry():
		UI.notice(self, "Notice", "Not enough Entry Tickets.\n(A ticket recharges every %d minutes.)" % (Arena.TOKEN_SECONDS / 60))
		return
	var a := Save.arena_state()
	_rival_idx = Arena.pick_rival(int(a.week), Save.arena_rank(a, Arena.week_progress()), int(a.entries) * 31 + int(a.wins) + int(Time.get_unix_time_from_system()) % 997)
	_show_match()


func _show_match() -> void:
	lay.root.visible = false
	if match_lay != null:
		match_lay.root.queue_free()
	if match_bg == null:
		UI.background(self, UI.tex(LeagueSeasons.bg_path()))
		match_bg = get_child(get_child_count() - 1)
		move_child(match_bg, 1)
	match_lay = Layout.load_into(self, "R_pvpStartPage")
	move_child(match_lay.root, top.root.get_index())
	_back_target = "arena"
	var a := Save.arena_state()
	var r: Dictionary = Arena.rivals(int(a.week))[_rival_idx]
	var mine := Save.team_members()
	var theirs := Arena.rival_team(r, Arena.power_of(mine))
	_fill_side(match_lay, "1", String(Save.data.get("name", "Tamer")), mine)
	_fill_side(match_lay, "2", String(r.name), theirs)
	match_lay.text("ID_LABEL_5", "All Stats Raised")
	var tabs := []
	for i in range(1, 6):
		match_lay.show("ID_btn%dteam" % i, i <= Save.TEAM_PRESETS)
		if i <= Save.TEAM_PRESETS:
			tabs.append("ID_btn%dteam" % i)
			match_lay.on("ID_btn%dteam" % i, _arena_team.bind(i - 1))
	match_lay.select_tab(tabs, "ID_btn%dteam" % (int(Save.data.team_index) + 1))
	match_lay.on("ID_btnPvpStart", _start_match)


func _arena_team(index: int) -> void:
	if index == int(Save.data.team_index):
		return
	var preset: Array = Save.data.teams[index]
	if not preset.any(func(u): return not Save.get_owned(int(u)).is_empty()):
		UI.toast(self, "Team %d is empty" % (index + 1))
		return
	Save.switch_team(index)
	Sfx.play("click")
	_show_match()


func _fill_side(l: Layout, side: String, player: String, team: Array) -> void:
	l.text("ID_nameText_" + side, player)
	if team.is_empty():
		return
	var leader: Dictionary = team[0]
	l.put("ID_photo_" + side, HubScreen.profile_pic(HubScreen.profile_id() if side == "1" else String(leader.id), Vector2(80, 80)))
	var rank := UI.image(Layout.texture("T_rank%s_01.png" % Arena.team_rank(team)), Vector2(96, 48))
	rank.size = Vector2(96, 48)
	l.put("ID_rankImage" + side, rank)
	var kind := Arena.team_type(team)
	l.show("ID_typeAttack" + side, kind == "attack")
	l.show("ID_typeDefence" + side, kind == "defence")
	l.show("ID_typeSupport" + side, kind == "support")
	var def := DB.monster(String(leader.id))
	var holder: Control = l.node("ID_monLeader" + side)
	var art := UI.living(DB.battle_sprite(String(leader.id)), Vector2(230, 170), side == "2")
	art.position = Vector2(-115, -128)
	holder.add_child(art)
	var orb := UI.image(UI.tex("betaUI00/A_%s_03.png" % ELEMENT_ORBS.get(String(def.element), "balance")), Vector2(30, 30))
	orb.size = Vector2(30, 30)
	orb.position = Vector2(-134, -196)
	holder.add_child(orb)
	var crown := UI.image(UI.tex("betaUI00/I_leader_01.png"), Vector2(24, 20))
	crown.size = Vector2(24, 20)
	crown.position = Vector2(-131, -214)
	holder.add_child(crown)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	line.position = Vector2(-102, -195)
	line.add_child(UI.label("Lv.%d" % int(leader.level), 18, Color("ffa22e")))
	line.add_child(UI.label(String(def.name), 18, UI.CREAM))
	holder.add_child(line)
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 0)
	sub.position = Vector2(-136, -167)
	var plus := UI.label("+%d" % int(leader.get("boost", 0)), 18, Color("7cc8ff"))
	plus.custom_minimum_size.x = 30
	sub.add_child(plus)
	for i in int(def.stars):
		var st := UI.image(UI.tex("betaGacha00/star01.png"), Vector2(24, 24))
		st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sub.add_child(st)
	holder.add_child(sub)
	for k in 5:
		if k < def.skills.size():
			var s: Dictionary = def.skills[k]
			var ic := UI.image(DB.skill_icon(String(s.icon)), Vector2(40, 40))
			ic.size = Vector2(40, 40)
			ic.mouse_filter = MOUSE_FILTER_STOP
			UI.tip(ic, "%s (%d MP): %s" % [s.name, int(s.mp), s.description])
			l.put("ID_Skill%d_%s" % [k + 1, side], ic)
	var letters := ["A", "B", "C"]
	var lines := []
	if String(def.passive) != "" and not String(def.passive).contains("Unknown"):
		lines.append("- " + String(def.passive))
	for k in 3:
		var slot := "ID_monIcon%s%s" % [letters[k], side]
		if k + 1 >= team.size():
			continue
		var m: Dictionary = team[k + 1]
		var card := UI.monster_card(String(m.id), int(m.level), int(m.boost), Vector2(92, 92))
		card.mouse_filter = MOUSE_FILTER_IGNORE
		l.put(slot, card)
		var md := DB.monster(String(m.id))
		var sup: Dictionary = md.get("support_skill", {})
		if String(sup.get("name", "")) != "":
			var sk := UI.image(DB.skill_icon(String(sup.icon)), Vector2(40, 40))
			sk.size = Vector2(40, 40)
			l.put("ID_skill%s%s" % [letters[k], side], sk)
		if String(md.passive) != "" and not String(md.passive).contains("Unknown"):
			lines.append("- " + String(md.passive))
	for k in 6:
		var lab := l.text("ID_ef%dText%s" % [k + 1, side], String(lines[k]) if k < lines.size() else "")
		if lab != null:
			UI.fit_text(lab, 17, 12)


func go_back() -> void:
	if match_lay == null:
		super.go_back()
		return
	UI.confirm(self, "Notice", "Leaving now will be considered forfeit, and you will lose Victory Points.", _forfeit)


func _forfeit() -> void:
	Save.record_arena(false, float(Arena.rivals(int(Save.arena_state().week))[_rival_idx].skill))
	main.go("arena")


func _start_match() -> void:
	var a := Save.arena_state()
	var r: Dictionary = Arena.rivals(int(a.week))[_rival_idx]
	main.go("battle", {"quest": arena_quest(r, Arena.power_of(Save.team_members()))})


static func arena_quest(r: Dictionary, power: float) -> Dictionary:
	var team := Arena.rival_team(r, power)
	return {
		"kind": "arena",
		"key": "arena",
		"bg": "arena_cave",
		"title": "Arena  ·  vs %s" % r.name,
		"rival_name": r.name, "rival_skill": float(r.skill),
		"energy": 0, "level": int(team[0].level), "boss": team[0].id, "enemies": [],
		"stages": 1,
		"fixed_waves": [team],
		"gold": 0.0, "exp": 0.0, "drops": false, "boss_drop_chance": 0.0, "drop_level": [1, 1], "first_clear_drop": false,
		"pvp": true,
		"time_limit": 120.0,
	}
