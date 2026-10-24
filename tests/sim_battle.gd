extends Node

const RUNS := 24
const DT := 0.1


func _ready() -> void:
	print("monsters loaded: %d, islands: %d" % [DB.monsters.size(), DB.islands.size()])
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var all_wins := 0
	var all_runs := 0
	var all_time := 0.0
	for island in DB.islands:
		for diff in ["normal", "hell"]:
			if not island.difficulties.has(diff):
				continue
			var stages: Array = island.difficulties[diff].stages
			var pool := _island_pool(island)
			var line := "%-18s %-6s" % [island.name, diff]
			for si in [0, stages.size() / 2, stages.size() - 1]:
				var lvl := clampi(StageBuilder.enemy_level(int(island.order), si, diff) + 1, 1, DB.MAX_LEVEL)
				var wins := 0
				var total := 0.0
				for r in RUNS:
					var team := []
					for k in 4:
						team.append({"id": pool[rng.randi() % pool.size()], "level": lvl, "boost": 0})
					var eng := BattleEngine.new()
					eng.auto_skills = true
					eng.setup(team, StageBuilder.build_waves(island, diff, si, rng), rng.randi())
					while eng.result == "" and eng.time < 400.0:
						eng.step(DT)
					if eng.result == "win":
						wins += 1
					total += eng.time
				all_wins += wins
				all_runs += RUNS
				all_time += total
				line += "  s%-2d L%-2d %3d%% %4.0fs" % [si + 1, lvl, wins * 100 / RUNS, total / RUNS]
			print(line)
	print("OVERALL win %d%%, avg %.0fs" % [all_wins * 100 / all_runs, all_time / all_runs])
	get_tree().quit()


func _island_pool(island: Dictionary) -> Array:
	var ids := {}
	for diff in island.difficulties:
		for s in island.difficulties[diff].stages:
			for id in s.enemies:
				if not DB.monster(id).material:
					ids[id] = true
	return ids.keys()
