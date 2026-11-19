class_name FriendsScreen
extends Screen

var lay: Layout
var page: Layout
var tab := "friends"
var _refresh_count := 0
var _shown_recommend := false
var _rows: Array = []


func build() -> void:
	UI.brown_background(self)
	lay = Layout.load_into(self, "R_friendBackPage")
	add_top_bar("3", "Friends", "hub")
	lay.on("ID_btnManage", _set_tab.bind("friends"))
	lay.on("ID_btnSearch", _set_tab.bind("find"))
	lay.on("ID_btnManage_1", _set_tab.bind("requests"))
	lay.show("ID_btnInvite", false)
	var accepted := Friends.process_requests()
	for p in accepted:
		UI.toast(self, "%s accepted your friend request!" % p.name, UI.GOLD)
	_set_tab("friends")
	Tutorial.maybe_start(self, "friends")


func _set_tab(t: String) -> void:
	tab = t
	lay.select_tab(["ID_btnManage", "ID_btnSearch", "ID_btnManage_1"], {"friends": "ID_btnManage", "find": "ID_btnSearch", "requests": "ID_btnManage_1"}[t])
	lay.show("ID_newMark", not Save.data.get("friend_requests", []).is_empty())
	if page != null and is_instance_valid(page.root):
		page.root.queue_free()
	var holder: Control = lay.node("ID_pagePosition")
	page = Layout.instance("R_friendSearchPage" if t == "find" else "R_friendManagePage")
	holder.add_child(page.root)
	if t == "find":
		page.on("ID_btnPropose", _recommend)
		page.on("ID_btnSeach", _find)
		page.text("ID_LABEL_1", "No results")
		_fill([] if not _shown_recommend else Friends.recommended(_refresh_count))
	else:
		page.hide_all(["ID_tapCacao"])
		page.show("btn_sendall", t == "friends")
		if t == "friends":
			page.on("btn_sendall", _send_fp.bind(Save.data.friends))
			_update_send_all()
		page.text("ID_LABEL_3", "Game")
		page.text("ID_numTextG", str(Save.data.friends.size()))
		page.text("ID_maxTextG", "/%d" % Friends.MAX_FRIENDS)
		if t == "friends":
			page.text("ID_LABEL_1", "No friends found")
			_fill(Save.data.friends)
		else:
			page.text("ID_LABEL_1", "No requests sent")
			var reqs := []
			for r in Save.data.get("friend_requests", []):
				reqs.append(r.player)
			_fill(reqs)
	tut_notify("tab:" + t)


func _fill(players: Array) -> void:
	_rows.clear()
	var rows := []
	for p in players:
		rows.append(_slot(p))
	page.show("ID_NoSelection", players.is_empty())
	page.list_into("ID_ID_arrayPosition", rows)


func _slot(p: Dictionary) -> Control:
	var s := Layout.instance("R_friendManageSlot")
	s.text("ID_friendName", String(p.name))
	var friend := Friends.is_friend(String(p.name))
	var used := friend and Friends.used_today(p)
	s.text("ID_friendstat", ("Lv.%d %s" % [int(p.level), DB.monster(String(p.monster)).get("name", "")]) + ("   ·  used today" if used else ""))
	var card := UI.monster_card(String(p.monster), int(p.level), int(p.get("boost", 0)), Vector2(92, 92))
	card.gui_input.connect(func(e: InputEvent):
		if UI.tapped(e):
			show_stats(self, {"id": p.monster, "level": p.level, "boost": p.get("boost", 0)}))
	s.node("ID_leaderIcon").add_child(card)
	s.hide_all(["ID_userGame", "ID_userCacao", "ID_userWait", "ID_btnInvite3"])
	s.show("ID_userSearch", tab == "find" and not friend)
	if tab == "find" and not friend:
		s.on("ID_btnPropose3", _request.bind(p, s))
	if tab == "friends":
		s.show("ID_userGame", true)
		s.hide_all(["ID_btnInvite1_1"])
		var send := s.on("ID_btnSendPoint1", _send_fp.bind([p]))
		_grey_send(send, Friends.fp_sent_today(p))
		s.on("ID_btnInvite1", func(): main.go("visit", {"name": String(p.name)}))
		s.on("ID_btnDelete1", _remove.bind(p))
	_rows.append(s)
	return s.root


static func show_stats(parent: Control, m: Dictionary) -> void:
	MonsterPopup.info(parent, -1, 90, {"uid": -1, "id": String(m.id), "level": int(m.level), "exp": 0, "boost": int(m.get("boost", 0)), "locked": false})


func _send_fp(list: Array) -> void:
	if Friends.send_fp(list) == 0:
		UI.notice(self, "Notice", "You already sent Friend Points today.")
		return
	UI.notice(self, "Notice", "Friend Points\nsent successfully.")
	_set_tab(tab)


func _update_send_all() -> void:
	var left: int = Save.data.friends.filter(func(f): return not Friends.fp_sent_today(f)).size()
	page.text("ID_numText1", str(left))
	_grey_send(page.node("btn_sendall") as BaseButton, left == 0)


static func _grey_send(b: BaseButton, sent: bool) -> void:
	if b == null:
		return
	b.disabled = sent
	b.modulate = Color(0.55, 0.55, 0.55) if sent else Color.WHITE


func _recommend() -> void:
	if _shown_recommend:
		_refresh_count += 1
	_shown_recommend = true
	_fill(Friends.recommended(_refresh_count))
	tut_notify("recommend")


func _find() -> void:
	_shown_recommend = false
	_fill([])
	tut_notify("find")


func _request(p: Dictionary, s: Layout) -> void:
	if Friends.send_request(p):
		Sfx.play("buff")
		UI.toast(self, "Friend request sent to %s" % p.name, UI.GOLD)
		s.show("ID_userSearch", false)
	else:
		UI.toast(self, "Request already sent")
	tut_notify("request:0")


func _remove(p: Dictionary) -> void:
	UI.confirm(self, "Notice", "Would you like to delete\n[%s]\nfrom the friends list?" % p.name, _do_remove.bind(p))


func _do_remove(p: Dictionary) -> void:
	Friends.remove_friend(String(p.name))
	_set_tab("friends")


func tutorial_target(name: String) -> Control:
	match name:
		"find":
			return lay.node("ID_btnSearch") if tab != "find" else page.node("ID_btnSeach")
		"recommend":
			return page.node("ID_btnPropose") if tab == "find" else null
		"request:0":
			if not _rows.is_empty():
				return (_rows[0] as Layout).node("ID_btnPropose3")
	return null
