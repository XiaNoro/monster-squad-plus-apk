class_name Arena
extends RefCounted

const MAX_TOKENS := 10
const TOKEN_SECONDS := 600
const GEM_ENTRY := 1
const RIVALS := 99
const WEEK_SECONDS := 604800
const WEEK_OFFSET := 3 * 86400
const ENTRY_GOAL := 51
const ENTRY_GOAL_GEMS := 30
const HONOUR_TIERS := [[0.01, 500], [0.05, 350], [0.10, 250], [0.25, 150], [0.50, 80]]
const WIN_POINTS := 20
const LOSS_POINTS := 12

const SYLLABLES := ["ka", "ro", "mi", "zen", "lu", "tor", "shi", "nyx", "bel", "dra", "po", "kin", "vee", "max", "ryu", "nol", "ash", "tia", "gor", "eon"]


static func week_id(now: float = -1.0) -> int:
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	return int((now - WEEK_OFFSET) / WEEK_SECONDS)


static func seconds_left_in_week() -> int:
	var now := Time.get_unix_time_from_system()
	return int((week_id(now) + 1) * WEEK_SECONDS + WEEK_OFFSET - now)


const RANKS := ["D", "D+", "D++", "C", "C+", "C++", "B", "B+", "B++", "A", "A+", "A++", "S", "S+", "S++", "SS"]


static func team_rank(team: Array) -> String:
	var low := _max_squad_power(1) * 0.25
	var high := _max_squad_power(6)
	var f := clampf(log(maxf(power_of(team), low) / low) / log(high / low), 0.0, 1.0)
	return RANKS[mini(RANKS.size() - 1, int(f * RANKS.size()))]


static func team_type(team: Array) -> String:
	var atk := 0.0
	var hp := 0.0
	var rec := 0.0
	for m in team:
		var st := DB.stats_at(m.id, int(m.level), int(m.boost))
		atk += float(st.atk)
		hp += float(st.hp)
		rec += float(st.rec)
	if hp / 7.5 > atk and hp / 7.5 > rec:
		return "defence"
	if rec > atk * 1.15:
		return "support"
	return "attack"


static func power_of(team: Array) -> float:
	var total := 0.0
	for m in team:
		var st := DB.stats_at(m.id, int(m.level), int(m.boost))
		total += float(st.hp) + 4.0 * float(st.atk) + 2.0 * float(st.rec) + 3.0 * float(st.def)
	return total


static func _name(rng: RandomNumberGenerator) -> String:
	var n := ""
	for i in rng.randi_range(2, 3):
		n += SYLLABLES[rng.randi() % SYLLABLES.size()]
	return n.capitalize() + (str(rng.randi_range(1, 999)) if rng.randf() < 0.5 else "")


static func rivals(week: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 104729 * week + 17
	var out := []
	for i in RIVALS:
		var skill := pow(rng.randf(), 1.6)
		out.append({"name": _name(rng), "skill": skill, "activity": rng.randf_range(0.3, 1.0), "seed": rng.randi()})
	return out


static func rival_points(r: Dictionary, week_progress: float) -> int:
	var games: float = float(r.activity) * 120.0 * week_progress
	var win_rate: float = 0.3 + 0.5 * float(r.skill)
	return maxi(0, int(games * (win_rate * WIN_POINTS - (1.0 - win_rate) * LOSS_POINTS)))


static func week_progress() -> float:
	return clampf(1.0 - float(seconds_left_in_week()) / WEEK_SECONDS, 0.0, 1.0)


static func rival_team(r: Dictionary, player_power: float) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(r.seed)
	var target := player_power * lerpf(0.75, 1.35, float(r.skill))
	var stars := 2
	for s in range(2, 7):
		stars = s
		if _max_squad_power(s) >= target:
			break
	var pool := DB.ids_where(func(m): return int(m.stars) == stars and not m.material and m.skills.size() >= 2)
	var team := []
	for i in 4:
		team.append({"id": pool[rng.randi() % pool.size()], "level": 1, "boost": 0})
	for step in 200:
		if power_of(team) >= target:
			break
		var m: Dictionary = team[step % 4]
		if int(m.level) < DB.MAX_LEVEL:
			m.level = mini(DB.MAX_LEVEL, int(m.level) + 2)
		elif int(m.boost) < DB.MAX_BOOST:
			m.boost = int(m.boost) + 1
	return team


static var _max_power_cache: Dictionary = {}


static func _max_squad_power(stars: int) -> float:
	if not _max_power_cache.has(stars):
		var ids := DB.ids_where(func(m): return int(m.stars) == stars and not m.material)
		var total := 0.0
		var n := mini(40, ids.size())
		for i in n:
			total += power_of([{"id": ids[i], "level": DB.MAX_LEVEL, "boost": DB.MAX_BOOST}])
		_max_power_cache[stars] = 4.0 * total / maxf(1.0, float(n))
	return _max_power_cache[stars]

static func points_for(win: bool, rival_skill: float) -> int:
	if win:
		return int(WIN_POINTS * lerpf(0.7, 1.6, rival_skill))
	return -int(LOSS_POINTS * lerpf(1.3, 0.6, rival_skill))


const RANK_REWARDS := [["1st", 1, 300], ["2nd~10th", 10, 250], ["11th~50th", 50, 200], ["Within 1%", 0.01, 160], ["Within 10%", 0.10, 120], ["Within 20%", 0.20, 80], ["Within 30%", 0.30, 60], ["Within 50%", 0.50, 40]]
const ROUND_REWARDS := [["More than 51 Rounds", 51, 30], ["41~50 Rounds", 41, 20], ["31~40 Rounds", 31, 15], ["21~30 Rounds", 21, 10], ["11~20 Rounds", 11, 5], ["Less than 10 Rounds", 0, 0]]


static func honour_for_rank(rank: int, total: int) -> int:
	for t in RANK_REWARDS:
		var lim: Variant = t[1]
		if lim is int and rank <= int(lim):
			return int(t[2])
		if lim is float and float(rank) / float(total) <= float(lim):
			return int(t[2])
	return 0


static func entry_gems(rounds: int) -> int:
	for t in ROUND_REWARDS:
		if rounds >= int(t[1]):
			return int(t[2])
	return 0


static func pick_rival(week: int, my_rank: int, salt: int) -> int:
	var progress := week_progress()
	var all := rivals(week)
	var order := range(all.size())
	order.sort_custom(func(x, y): return rival_points(all[x], progress) > rival_points(all[y], progress))
	var rng := RandomNumberGenerator.new()
	rng.seed = week * 7919 + salt
	var i := clampi(my_rank - 1 + rng.randi_range(-6, 8), 0, order.size() - 1)
	return order[i]


static func honour_for(percentile: float) -> int:
	for t in HONOUR_TIERS:
		if percentile <= float(t[0]):
			return int(t[1])
	return 0
