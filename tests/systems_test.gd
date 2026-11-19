extends Node

var failures := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok    ", what)
	else:
		failures += 1
		print("  FAIL  ", what)


func _ready() -> void:
	Save.save_path = "user://systems_test.json"
	Save.reset()
	Save.data.gold = 10_000_000
	Save.data.gems = 1000

	print("exp table")
	check(DB.exp_to_next(1, 1) == 2 and DB.exp_to_next(29, 6) == 373, "wiki values (1★ L1→2 = 2, 6★ L29→30 = 373)")
	var total := 0
	for l in range(1, 30):
		total += DB.exp_to_next(l, 6)
	check(total == 4754, "6★ total to Lv30 = 4754 (got %d)" % total)

	print("boost")
	var t := Save.add_monster("balrog", 30)
	check(DB.boost_chance("balrog", "balrog") == 1.0, "same rank 100%")
	check(is_equal_approx(DB.boost_chance("balrog", "flarepaw"), 0.4), "2 stars lower 40%")
	check(DB.boost_cost("balrog", 0) == 1431 and DB.boost_cost("pink_bean", 4) == 11487, "cost table (5★ +1 = 1,431; 6★ +5 = 11,487)")
	var mat := Save.add_monster("firbal", 1)
	var r := Save.boost(int(t.uid), int(mat.uid))
	check(r.ok and (r.success or int(r.boost_pt) == 2), "low material: success or +2 Boost PT")

	print("feed")
	var target := Save.add_monster("firepaw", 1)
	var foods := []
	for i in 3:
		foods.append(int(Save.add_monster("flarepaw", 10).uid))
	var f := Save.feed(int(target.uid), foods)
	check(f.ok and int(Save.get_owned(int(target.uid)).level) > 1, "feeding raises level (+%d exp)" % int(f.get("exp", 0)))

	print("awaken")
	var six := Save.add_monster("pink_bean", 30)
	var same := Save.add_monster("pink_bean", 30)
	var other_el := Save.add_monster("aquabella", 30)
	check(not Save.awaken_preview(int(six.uid), int(other_el.uid)).ok, "different element rejected")
	var ap := Save.awaken_preview(int(six.uid), int(same.uid))
	var gain := 4 if Events.has("awaken") else 3
	check(ap.ok and int(ap.gain) == gain and int(ap.cost) == 150000, "identical monster: +%d cap for 150,000 gold" % gain)
	Save.awaken(int(six.uid), int(same.uid))
	check(Save.max_level(Save.get_owned(int(six.uid))) == 30 + gain, "cap is now %d" % (30 + gain))
	Save.grant_exp(Save.get_owned(int(six.uid)), 100000)
	check(int(Save.get_owned(int(six.uid)).level) == 30 + gain, "levels past 30 up to the new cap")
	var s30 := DB.stats_at("pink_bean", 30)
	var s33 := DB.stats_at("pink_bean", 33)
	check(int(s33.hp) > int(s30.hp), "stats keep growing past 30 (%d -> %d HP)" % [int(s30.hp), int(s33.hp)])

	print("pets")
	var pet := Save.add_pet("lucerna")
	var low := Save.add_monster("rubyhide", 10)
	check(not Save.equip_pet(int(low.uid), int(pet.uid), false).ok, "level requirement enforced")
	check(Save.equip_pet(int(six.uid), int(pet.uid), false).ok, "equip on a Lv33 monster")
	var spec := Save.pet_spec(Save.get_owned(int(six.uid)))
	check(int(spec.stats.hp) == 430, "pet stats applied (HP +430)")

	print("evolution is free")
	var evo := Save.add_monster("firepaw", 30)
	evo.boost = 5
	var ev_mat := Save.add_monster("rubi", 30)
	ev_mat.boost = 5
	var gold_before := int(Save.data.gold)
	var er := Save.evolve(int(evo.uid))
	check(er.ok and int(Save.data.gold) == gold_before, "evolved without gold (%s)" % er.get("into", er.get("reason", "")))

	print("missions & attendance")
	var m: Dictionary = Missions.DAILY[0]
	Save.track(m.event, int(m.goal))
	var g0 := int(Save.data.gold)
	check(Save.claim_mission("daily", m) and int(Save.data.gold) == g0 + int(m.reward.gold), "daily '%s' pays %d gold" % [m.text, int(m.reward.gold)])
	check(not Save.claim_mission("daily", m), "can't claim twice")
	check(Save.attendance_ready(), "attendance ready")
	var ar := Save.claim_attendance()
	check(ar.get("cube", "") == "yellow" and int(Save.data.cube_items.get("yellow", 0)) == 1, "day 1 = Yellow Cube into cube items")
	check(not Save.attendance_ready(), "one stamp per day")

	print("save and reload")
	var a := Save.add_monster("firepaw", 5)
	var b := Save.add_monster("dripbal", 5)
	var c := Save.add_monster("leavbal", 5)
	Save.data.teams = [[], [], [], [], []]
	Save.data.team_index = 0
	Save.data.team = [int(a.uid), int(b.uid), int(c.uid)]
	Save.data.league = {"team": [int(c.uid), int(a.uid)]}
	Save.save_game()
	Save.load_game()
	check(Save.data.team.all(func(u): return typeof(u) == TYPE_INT), "team ids load as whole numbers")
	check(Save.data.team.find(int(c.uid)) == 2, "team lookup finds a monster after reload")
	check(Array(Save.data.league.team).find(int(a.uid)) == 1, "league team lookup works after reload")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Save.save_path))
	raw.team = [int(a.uid), int(b.uid), int(a.uid)]
	var file := FileAccess.open(Save.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	Save.load_game()
	check(Save.data.team == [int(a.uid), int(b.uid)], "a duplicated team member is dropped on load")
	check(not Save.equip_pet(int(a.uid), int(pet.uid), false).ok or Save.pet_spec(Save.get_owned(int(a.uid))) != {}, "pets still resolve after reload")
	check(not Save.sell(int(b.uid)) > 0, "team members can't be sold after reload")
	raw = JSON.parse_string(FileAccess.get_file_as_string(Save.save_path))
	raw.teams = [raw.team, [], []]
	file = FileAccess.open(Save.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	Save.load_game()
	check(Save.data.teams.size() == Save.TEAM_PRESETS and Save.TEAM_PRESETS == 5, "old 3-team saves grow to 5 team tabs")
	var team_before: Array = Save.data.team.duplicate()
	Save.switch_team(4)
	Save.set_team([int(c.uid)])
	Save.switch_team(0)
	check(Save.data.team == team_before and Save.data.teams[4] == [int(c.uid)], "team 5 keeps its own members")
	Save.switch_team(4)
	check(Save.data.team == [int(c.uid)] and int(Save.data.team_index) == 4, "switching to team 5 loads it")
	Save.switch_team(0)

	var duel := {}
	var dino := {}
	for i in LeagueSeasons.SEASONS.size():
		var s := LeagueSeasons.season(i)
		if LeagueSeasons.team_size(s) == 1:
			duel = s
		if String(s.name) == "Dino Gorge League":
			dino = s
	check(not duel.is_empty() and LeagueSeasons.rule_lines(duel) == ["No Rule!!"], "1 vs 1 league has no rules")
	check(LeagueSeasons.team_size(dino) == Save.LEAGUE_TEAM and LeagueSeasons.rule_lines(dino).size() == 5, "team leagues list boosts and rules")
	var rv: Dictionary = Arena.rivals(1)[0]
	check(LeagueScreen.rival_league_team(rv, 5000.0, 1).size() == 1, "1 vs 1 rival brings one monster")
	var popular := 0
	var unique := true
	for i in 30:
		var team := Arena.rival_team(Arena.rivals(i)[0], 60000.0)
		var ids := {}
		for mm in team:
			ids[mm.id] = true
			if Arena.pick_weights().has(mm.id):
				popular += 1
		unique = unique and ids.size() == team.size()
	check(unique and popular >= 100, "strong rivals field unique, popular footage picks (%d / 120)" % popular)
	check(LeagueScreen.rival_league_team(rv, 5000.0).size() == Save.LEAGUE_TEAM, "team rival brings a full team")

	print("tower floors")
	var drops_known := 0
	for fl in range(1, SkyTower.FLOORS + 1):
		if SkyTower.known(fl).has("drops"):
			drops_known += 1
	var f31 := SkyTower.floor_quest(31)
	check(drops_known == SkyTower.FLOORS and f31.boss == "yakkelder" and f31.enemies.has("yakkadin"), "every floor has a footage Drop List; floor 31 rooms use its footage enemies")

	print("friends")
	Save.data.friends = Friends.starting_friends()
	var fangz: Dictionary = Save.data.friends[1].duplicate()
	Friends.remove_friend(String(fangz.name))
	Friends.ensure_defaults()
	check(not Friends.is_friend(String(fangz.name)) and Save.data.friends.size() == Friends.DEFAULT_FRIENDS.size() - 1, "removed starting friend stays removed after reload")
	Friends.add_friend(fangz)
	Friends.remove_friend(String(fangz.name))
	Friends.add_friend(fangz)
	check(Friends.is_friend(String(fangz.name)) and not String(fangz.name) in Save.data.friends_removed, "re-added friend is a friend again")
	var mew := BattleUnit.create(BattleUnit.PLAYER, 0, "mewer", 30, 0)
	var atk := float(mew.base.atk)
	LeagueSeasons.apply(mew, duel)
	check(is_equal_approx(float(mew.base.atk), atk), "1 vs 1 featured monster gets no stat change")
	var sprout := {}
	for i in LeagueSeasons.SEASONS.size():
		if String(LeagueSeasons.SEASONS[i].name) == "Sprout Island League":
			sprout = LeagueSeasons.season(i)
	var pat := BattleUnit.create(BattleUnit.PLAYER, 0, "patchuus", 30, 0)
	var ulm := BattleUnit.create(BattleUnit.PLAYER, 1, "ulmigrand", 30, 0)
	var rec := float(pat.base.rec)
	var hp := ulm.max_hp
	var ulm_atk := float(ulm.base.atk)
	LeagueSeasons.apply(pat, sprout)
	LeagueSeasons.apply(ulm, sprout)
	check(is_equal_approx(float(pat.base.rec), rec * 5.0), "Sprout league multiplies Patchuus REC by 5")
	check(is_equal_approx(ulm.max_hp, hp * 5.0) and is_equal_approx(ulm.hp, ulm.max_hp), "Sprout league gives 3-star monsters 5x HP at full health")
	check(is_equal_approx(float(ulm.base.atk), ulm_atk + 1000.0), "Sprout league gives Ulmigrand +1000 ATK")
	check(LeagueSeasons.rule_lines(sprout).size() == 7, "Sprout league lists its seven rules")
	check(LeagueSeasons.team_size(sprout) == 8 and LeagueScreen.rival_league_team(rv, 5000.0, 8).size() == 8, "8 vs 8 leagues bring eight monsters")
	check(LeagueSeasons.reward_for(1)[2] == "gold" and LeagueSeasons.reward_for(3)[2] == "silver" and LeagueSeasons.reward_for(10)[2] == "bronze" and LeagueSeasons.reward_for(11)[2] == "", "league badges go to the top three reward rows only")
	Save.data.badges = {}
	var won := Save._settle_league({"season": 7, "points": 999999, "rounds": 10, "wins": 10})
	check(String(won.badge) == "gold" and int(Save.data.badges.get(LeagueSeasons.badge_key(7, "gold"), 0)) == 1, "a league season win adds that league's gold badge")
	check(LeagueSeasons.badges_owned("gold") == 1 and LeagueSeasons.badge_points() == 3, "badge list counts and points follow owned badges")

	var four: Dictionary = DB.special("elemental_island").quests[4]
	var cao: Array = Array(four.rare).filter(func(r): return String(r.id) == "caocao")
	check(Array(four.drops).has("caocao") and cao.size() == 1 and float(cao[0].chance) < 0.01, "Temple of Four Elements can rarely drop CaoCao")
	var spawns := 0
	var trng := RandomNumberGenerator.new()
	trng.seed = 4
	for i in 20000:
		for wave in StageBuilder.waves_for(four, trng):
			for e in wave:
				if String(e.id) == "caocao":
					spawns += 1
	check(spawns > 40 and spawns < 160, "CaoCao shows up in about 0.5%% of temple runs (%d / 20000)" % spawns)

	Save.data.stones = []
	Save.data.stone_cap = MagicStones.START_STONE_CAP
	Save.data.gems = 130
	for i in 3:
		Save.add_stone({"type": "bravery", "rank": 0})
	Save.add_stone({"type": "steel", "rank": 3, "variant": 2})
	var stacks := Save.stone_stacks(Save.free_stones())
	check(stacks.size() == 2 and Array(stacks[0].uids).size() == 3, "stones stack by type, rank and variant")
	var stone_gold := int(Save.data.gold)
	var sold := Save.sell_stones(Array(stacks[0].uids).slice(0, 2))
	check(sold == 2 * MagicStones.SELL_PRICE[0] and int(Save.data.gold) == stone_gold + sold and Save.free_stones().size() == 2, "selling two stones from a stack pays for two")
	check(MagicStones.START_STONE_CAP == 24, "the stone box starts at 24 slots")
	check(Save.expand_stone_box() and int(Save.data.stone_cap) == 36 and int(Save.data.gems) == 70, "Expand Stone Slots costs 60 gems for 12 slots")
	check(Save.expand_stone_box() and int(Save.data.stone_cap) == 48 and not Save.expand_stone_box() and int(Save.data.stone_cap) == 48, "expanding needs 60 gems")

	print("\n%s (%d failures)" % ["ALL PASSED" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures > 0 else 0)
