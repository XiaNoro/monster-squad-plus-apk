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
		foods.append(int(Save.add_monster("dripbal", 10).uid))
	var f := Save.feed(int(target.uid), foods)
	check(f.ok and int(Save.get_owned(int(target.uid)).level) > 1, "feeding raises level (+%d exp)" % int(f.get("exp", 0)))

	print("awaken")
	var six := Save.add_monster("pink_bean", 30)
	var same := Save.add_monster("pink_bean", 30)
	var other_el := Save.add_monster("aquabella", 30)
	check(not Save.awaken_preview(int(six.uid), int(other_el.uid)).ok, "different element rejected")
	var ap := Save.awaken_preview(int(six.uid), int(same.uid))
	var gain := 4 if Events.active("awaken_bonus") else 3
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
	Save.track("quest", 4)
	var m: Dictionary = Missions.DAILY[0]
	var g0 := int(Save.data.gold)
	check(Save.claim_mission("daily", m) and int(Save.data.gold) == g0 + 3000, "daily '4 Quests' pays 3,000 gold")
	check(not Save.claim_mission("daily", m), "can't claim twice")
	check(Save.attendance_ready(), "attendance ready")
	var ar := Save.claim_attendance()
	check(ar.get("cube", "") == "yellow" and int(Save.data.cube_items.get("yellow", 0)) == 1, "day 1 = Yellow Cube into cube items")
	check(not Save.attendance_ready(), "one stamp per day")

	print("\n%s (%d failures)" % ["ALL PASSED" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures > 0 else 0)
