class_name Friends
extends RefCounted

const FP_CAP := 2000
const FP_FRIEND := 10
const FP_GUEST := 0
const MAX_FRIENDS := 50
const GUESTS := 3
const ACCEPT_CHANCE := 0.6
const ANSWER_SECONDS := 120
const INVITE_ENERGY := 5
const TEST_FRIEND := {"name": "XiaNoro", "monster": "prism_kong", "level": 6, "boost": 0}


const DEFAULT_FRIENDS := [TEST_FRIEND, {"name": "Fangz", "monster": "jack_o_paw", "level": 10, "boost": 0}, {"name": "MKEscortYT", "monster": "ultimi", "level": 30, "boost": 5}, {"name": "Alejandro", "monster": "dark_hawk", "level": 30, "boost": 5}, {"name": "Coffie cat", "monster": "narkissa", "level": 30, "boost": 5}]


static func starting_friends() -> Array:
	return DEFAULT_FRIENDS.map(func(f): return f.duplicate())


static func ensure_defaults() -> void:
	for d in DEFAULT_FRIENDS:
		var found := false
		for f in Save.data.friends:
			if String(f.name) == String(d.name):
				f.monster = d.monster
				found = true
		if not found:
			Save.data.friends.append(d.duplicate())


static func day_key() -> int:
	return int((Time.get_unix_time_from_system() - 4 * 3600) / 86400)


static func used_today(f: Dictionary) -> bool:
	return int(Save.data.friend_used.get(String(f.name), -1)) == day_key()


static func fp_sent_today(f: Dictionary) -> bool:
	return int(Save.data.get("fp_sent", {}).get(String(f.name), -1)) == day_key()


static func send_fp(list: Array) -> int:
	if not Save.data.has("fp_sent"):
		Save.data.fp_sent = {}
	var sent := 0
	for f in list:
		if not fp_sent_today(f):
			Save.data.fp_sent[String(f.name)] = day_key()
			sent += 1
	if sent > 0:
		Save.track("send_fp")
		Save.save_game()
	return sent


static func seconds_to_reset() -> int:
	var now := Time.get_unix_time_from_system() - 4 * 3600
	return int(86400 - fmod(now, 86400.0))


static func _player(rng: RandomNumberGenerator) -> Dictionary:
	var lead_lv := 1
	var team := Save.team_members()
	if not team.is_empty():
		lead_lv = int(team[0].level)
	var stars := clampi(2 + int(lead_lv / 8.0) + (1 if rng.randf() < 0.3 else 0), 2, 6)
	var pool := DB.ids_where(func(m): return int(m.stars) == stars and not m.material and m.skills.size() >= 1)
	var name := ""
	for i in rng.randi_range(2, 3):
		name += Arena.SYLLABLES[rng.randi() % Arena.SYLLABLES.size()]
	name = name.capitalize() + (str(rng.randi_range(1, 9999)) if rng.randf() < 0.6 else "")
	return {"name": name, "monster": pool[rng.randi() % pool.size()] if not pool.is_empty() else "firepaw",
		"level": clampi(lead_lv + rng.randi_range(2, 8), 1, DB.MAX_LEVEL), "boost": rng.randi_range(0, mini(5, stars - 1)),
		"login": rng.randi_range(1, 72)}


static func guests() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = day_key() * 7919 + int(Save.data.get("next_uid", 1)) / 25
	var out := []
	for i in GUESTS:
		var p := _player(rng)
		p["guest"] = true
		out.append(p)
	return out


static func recommended(refresh: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = day_key() * 104729 + refresh * 31
	var out := []
	for i in 6:
		out.append(_player(rng))
	return out


static func is_friend(name: String) -> bool:
	for f in Save.data.friends:
		if String(f.name) == name:
			return true
	return false


static func process_requests() -> Array:
	var accepted := []
	var keep := []
	var now := Time.get_unix_time_from_system()
	for r in Save.data.get("friend_requests", []):
		if now - float(r.sent) < ANSWER_SECONDS:
			keep.append(r)
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(String(r.player.name))
		if rng.randf() < ACCEPT_CHANCE and Save.data.friends.size() < MAX_FRIENDS:
			var p: Dictionary = r.player.duplicate()
			p.erase("guest")
			Save.data.friends.append(p)
			accepted.append(p)
			_invite_gift(String(p.name))
	Save.data["friend_requests"] = keep
	if not accepted.is_empty() or keep.size() != Save.data.friend_requests.size():
		Save.save_game()
	return accepted


static func send_request(p: Dictionary) -> bool:
	if is_friend(String(p.name)):
		return false
	var reqs: Array = Save.data.get("friend_requests", [])
	for r in reqs:
		if String(r.player.name) == String(p.name):
			return false
	reqs.append({"player": p, "sent": Time.get_unix_time_from_system()})
	Save.data["friend_requests"] = reqs
	Save.save_game()
	return true


static func add_friend(p: Dictionary) -> void:
	if is_friend(String(p.name)) or Save.data.friends.size() >= MAX_FRIENDS:
		return
	var f := p.duplicate()
	f.erase("guest")
	Save.data.friends.append(f)
	_invite_gift(String(f.name))
	Save.save_game()


static func _invite_gift(name: String) -> void:
	var x := Events.effect("friend_invite")
	var energy := roundi(INVITE_ENERGY * x)
	Mail.send(name, {"energy": energy}, "Accepted your friend request!" + (" (%dx Friend Invite)" % roundi(x) if x > 1.0 else ""))


static func record_use(f: Dictionary) -> int:
	if f.is_empty():
		return 0
	var fp := 0
	if not bool(f.get("guest", false)):
		Save.data.friend_used[String(f.name)] = day_key()
		fp = roundi(FP_FRIEND * Events.effect("friend_points"))
	else:
		fp = FP_GUEST
	Save.data.fp = mini(FP_CAP, int(Save.data.get("fp", 0)) + fp)
	return fp


static func battle_spec(f: Dictionary) -> Dictionary:
	return {"id": String(f.monster), "level": int(f.level), "boost": int(f.get("boost", 0)), "friend": true}


static func team(f: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(String(f.name))) + 77
	var lead := DB.monster(String(f.monster))
	var stars := clampi(int(lead.get("stars", 3)), 2, 6)
	var pool := DB.ids_where(func(m): return int(m.stars) == stars and not m.material and m.skills.size() >= 2 and m.id != String(f.monster))
	var out := [{"id": String(f.monster), "level": int(f.level), "boost": int(f.get("boost", 0))}]
	for i in 3:
		out.append({"id": pool[rng.randi() % pool.size()], "level": maxi(1, int(f.level) - rng.randi_range(0, 3)), "boost": int(f.get("boost", 0))})
	return out


static func challenge_rank(f: Dictionary) -> Vector2:
	var h := absi(hash(String(f.name) + str(Arena.week_id() - 1)))
	var rank := 1 + h % (Arena.RIVALS + 1)
	return Vector2(rank, 100.0 * rank / float(Arena.RIVALS + 1))


static func duel_reward_ready() -> bool:
	return int(Save.data.get("duel_day", -1)) != day_key()


static func duel_quest(f: Dictionary) -> Dictionary:
	var t := team(f)
	return {
		"kind": "duel",
		"key": "duel",
		"title": "Duel  ·  vs %s" % f.name,
		"rival_name": String(f.name), "friend_name": String(f.name),
		"energy": 0, "level": int(t[0].level), "boss": t[0].id, "enemies": [],
		"stages": 1,
		"fixed_waves": [t],
		"gold": 0.0, "exp": 0.0, "drops": false, "boss_drop_chance": 0.0, "drop_level": [1, 1], "first_clear_drop": false,
		"pvp": true,
		"time_limit": 120.0,
	}


static func finish_duel(won: bool) -> int:
	if not won or not duel_reward_ready():
		return 0
	Save.data.duel_day = day_key()
	var fp := FP_FRIEND
	Save.data.fp = mini(FP_CAP, int(Save.data.get("fp", 0)) + fp)
	Save.save_game()
	return fp