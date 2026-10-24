extends Screen

const SPOTS := ["ID_IMAGE_Leader", "ID_IMAGE_monA", "ID_IMAGE_monB", "ID_IMAGE_monC"]
const SHIFT: Array[Vector2] = [Vector2(35, 0), Vector2(44, 34), Vector2(-80, 0), Vector2(-26, 12)]

var lay: Layout
var friend: Dictionary = {}


func build() -> void:
	friend = _find(String(args.get("name", "")))
	if friend.is_empty():
		main.go.call_deferred("friends")
		return
	UI.background(self, UI.tex("res://assets/ui/visit_bg.png"))
	lay = Layout.load_into(self, "R_friendMain")
	add_top_bar("3", "", String(args.get("back", "friends")))
	var members: Array = args.get("team", Friends.team(friend))
	_show_team(members)
	lay.text("ID_nameText", String(friend.name))
	lay.put("ID_photo", HubScreen.profile_pic(String(friend.monster), Vector2(80, 80)))
	var added := Friends.is_friend(String(friend.name))
	lay.show("ID_IMAGE_1", not added)
	if not added:
		lay.on("ID_BUTTON_1", _add)
	HubScreen.show_team_type(lay, Arena.team_type(members))
	var rank := UI.image(Layout.texture("T_rank%s_01.png" % Arena.team_rank(members)), Vector2(120, 60))
	rank.size = Vector2(120, 60)
	lay.put("ID_rankImage", rank)
	var cr := Friends.challenge_rank(friend)
	if args.has("rank"):
		cr = Vector2(int(args.rank), 100.0 * int(args.rank) / float(Arena.RIVALS + 1))
	lay.text("ID_rankingText", "%d(%.1f%%)" % [int(cr.x), cr.y])
	lay.show("ID_disableText", Friends.duel_reward_ready())
	var reward := lay.text("ID_LABEL_7_1", "x10 Rewarded")
	reward.position.x += 26
	var room: float = (lay.node("ID_disableText").size.x - reward.position.x - 14.0)
	var font := reward.get_theme_font("font")
	var fs := int(reward.get_theme_font_size("font_size"))
	while fs > 14 and font.get_string_size(reward.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	reward.add_theme_font_size_override("font_size", fs)
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	reward.size.x = room
	lay.show("ID_pvp", Friends.is_friend(String(friend.name)))
	lay.on("ID_btnPvp", _duel)


func _find(name: String) -> Dictionary:
	if args.has("player"):
		return args.player
	for f in Save.data.get("friends", []):
		if String(f.name) == name:
			return f
	for p in args.get("players", []):
		if String(p.name) == name:
			return p
	return {}


func _show_team(members: Array) -> void:
	for i in HubScreen.front_to_back(self, lay, members.size(), SHIFT):
		var m: Dictionary = members[i]
		var feet := HubScreen.spot_feet(self, lay, i, SHIFT)
		var tex := DB.battle_sprite(m.id)
		var size := HubScreen.team_sprite_size(String(m.id), tex, i == 0)
		var sprite := UI.living(tex, size)
		sprite.position = feet - Vector2(size.x / 2.0, size.y)
		sprite.mouse_filter = MOUSE_FILTER_STOP
		sprite.gui_input.connect(func(e: InputEvent):
			if UI.tapped(e):
				FriendsScreen.show_stats(self, m))
		add_child(sprite)
		move_child(sprite, lay.root.get_index() + 1)
		UI.add_shadow(self, tex, Rect2(sprite.position, size), sprite.get_index())
		var bob := sprite.create_tween().set_loops()
		bob.tween_property(sprite, "position:y", sprite.position.y - 6, 0.9 + 0.1 * i).set_trans(Tween.TRANS_SINE)
		bob.tween_property(sprite, "position:y", sprite.position.y, 0.9 + 0.1 * i).set_trans(Tween.TRANS_SINE)
		HubScreen.monster_tag(self, m, feet + Vector2(0, -size.y - 4), i == 0)


func _add() -> void:
	if Friends.send_request(friend):
		UI.toast(self, "Friend request sent to %s" % friend.name, UI.GOLD)
		lay.show("ID_IMAGE_1", false)


func _duel() -> void:
	if Save.team_members().is_empty():
		UI.notice(self, "Notice", "Your squad is empty!")
		return
	main.go("battle", {"quest": Friends.duel_quest(friend)})
