class_name Mail
extends RefCounted

const MAX := 50
const FRIEND_GIFTS := 5
const TEAM := "Monster Squad Team"
const ITEM_ICONS := {"gems": "I_crystal_02.png", "gold": "I_money_02.png", "energy": "I_energy_02.png", "fp": "I_fPoint_02.png", "honor": "I_honor_02.png"}


static func inbox() -> Array:
	if not Save.data.has("mail"):
		Save.data["mail"] = []
	for m in Save.data.mail:
		if String(m.from) == "Team Monster":
			m.from = TEAM
	return Save.data.mail


static func item_texture(r: Dictionary) -> Texture2D:
	if r.has("cube"):
		return Layout.texture(Layout.CUBE_ICONS.get(String(r.cube), "I_cube_02.png"))
	for k in ITEM_ICONS:
		if r.has(k):
			return Layout.texture(ITEM_ICONS[k])
	return null


static func count(r: Dictionary) -> int:
	for k in ITEM_ICONS:
		if r.has(k):
			return int(r[k])
	return 1


static func send(from: String, reward: Dictionary, text: String, team: bool = false) -> void:
	var box := inbox()
	var next := int(Save.data.get("mail_next", 1))
	Save.data["mail_next"] = next + 1
	box.push_front({"id": next, "from": from, "team": team, "text": text, "reward": reward, "sent": Time.get_unix_time_from_system()})
	while box.size() > MAX:
		box.pop_back()


static func refresh() -> void:
	var changed := false
	if not bool(Save.data.get("mail_welcome", false)):
		Save.data["mail_welcome"] = true
		send(TEAM, {"gems": 30}, "Welcome to Monster Squad+! A gift to start your journey.", true)
		send(TEAM, {"cube": "blue"}, "Here's a Blue Cube. Open it in the Cube Shop!", true)
		changed = true
	var today := Time.get_date_string_from_system()
	if str(Save.data.get("mail_day", "")) != today:
		Save.data["mail_day"] = today
		var xia := String(Friends.TEST_FRIEND.name)
		var friends: Array = Save.data.friends.filter(func(f): return String(f.name) != xia)
		friends.shuffle()
		for f in friends.slice(0, FRIEND_GIFTS - 1):
			send(String(f.name), {"fp": Friends.FP_FRIEND}, "Sent you Friend Points!")
		if Friends.is_friend(xia):
			send(xia, {"fp": Friends.FP_FRIEND}, "Sent you Friend Points!")
		changed = true
	if changed:
		Save.save_game()


static func unread() -> int:
	return inbox().size()


static func claim(id: int) -> Dictionary:
	var box := inbox()
	for i in box.size():
		if int(box[i].id) == id:
			var r: Dictionary = box[i].reward
			box.remove_at(i)
			_grant(r)
			Save.save_game()
			return r
	return {}


static func claim_all() -> Array:
	var got := []
	for m in inbox().duplicate():
		if _monster_blocked(m.reward):
			continue
		got.append(claim(int(m.id)))
	return got


static func _monster_blocked(r: Dictionary) -> bool:
	return r.has("monster") and Save.inventory_full()


static func can_claim(m: Dictionary) -> bool:
	return not _monster_blocked(m.reward)


static func _grant(r: Dictionary) -> void:
	Save.grant(r)
	if r.has("fp"):
		Save.data.fp = mini(Friends.FP_CAP, int(Save.data.get("fp", 0)) + int(r.fp))
	if r.has("honor"):
		Save.data.honor = int(Save.data.get("honor", 0)) + int(r.honor)
	if r.has("monster"):
		Save.add_monster(String(r.monster), int(r.get("level", 1)))


static func icon(r: Dictionary, size: Vector2) -> Control:
	var c: Control
	if r.has("monster"):
		c = UI.monster_card(String(r.monster), int(r.get("level", 1)), 0, size)
	else:
		c = Layout.reward_icon(r)
		var k := minf(size.x / c.size.x, size.y / c.size.y)
		c.scale = Vector2(k, k)
		c.position = (size - c.size * k) / 2.0
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func text(r: Dictionary) -> String:
	if r.has("monster"):
		return "%s Lv.%d" % [DB.monster(String(r.monster)).name, int(r.get("level", 1))]
	if r.has("fp"):
		return "%d Friend Points" % int(r.fp)
	if r.has("honor"):
		return "%d Honour" % int(r.honor)
	return Missions.reward_text(r)


static func age(m: Dictionary) -> String:
	var s := int(Time.get_unix_time_from_system() - float(m.sent))
	if s < 3600:
		return "%dm ago" % maxi(1, s / 60)
	if s < 86400:
		return "%dh ago" % (s / 3600)
	return "%dd ago" % (s / 86400)
