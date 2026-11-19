extends Node

const RUNS := 16
const DT := 0.1
const GRID := [1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	for half_atk in [false, true]:
		print("ATK bonus %s" % ("half of HP bonus" if half_atk else "same as HP"))
		print("%-18s %-6s %s" % ["island", "diff", "  ".join(GRID.map(func(m): return "x%.2f" % m))])
		for island in DB.islands:
			for diff in ["normal", "hard", "hell"]:
				if not island.difficulties.has(diff):
					continue
				var stages: Array = island.difficulties[diff].stages
				var pool := _island_pool(island)
				var line := "%-18s %-6s" % [island.name, diff]
				for m in GRID:
					var wins := 0
					var runs := 0
					for si in [0, stages.size() / 2, stages.size() - 1]:
						var quest := StageBuilder.story_quest(island, diff, si)
						quest.hp_mult = m
						quest.atk_mult = 1.0 + (m - 1.0) * 0.5 if half_atk else m
						var lvl := clampi(int(quest.level) + 1, 1, DB.MAX_LEVEL)
						for r in RUNS:
							var team := []
							for k in 4:
								team.append({"id": pool[rng.randi() % pool.size()], "level": lvl, "boost": DB.MAX_BOOST if diff == "hell" else 0})
							var eng := BattleEngine.new()
							eng.auto_skills = true
							eng.setup(team, StageBuilder.waves_for(quest, rng), rng.randi())
							while eng.result == "" and eng.time < 400.0:
								eng.step(DT)
							if eng.result == "win":
								wins += 1
							runs += 1
					line += "  %4d%%" % (wins * 100 / runs)
				print(line)
	get_tree().quit()


func _island_pool(island: Dictionary) -> Array:
	var ids := {}
	for diff in island.difficulties:
		for s in island.difficulties[diff].stages:
			for id in s.enemies:
				if not DB.monster(id).material:
					ids[id] = true
	return ids.keys()
