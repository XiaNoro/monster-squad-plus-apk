class_name Missions
extends RefCounted

const DAILY := [
	{"id": "d_explore", "text": "Explore any Islands!", "event": "quest", "goal": 7, "reward": {"gold": 5000}},
	{"id": "d_arena", "text": "Battle at the Arena!", "event": "arena", "goal": 5, "reward": {"energy": 20}},
	{"id": "d_boost", "text": "Boost any Monsters!", "event": "boost", "goal": 5, "reward": {"gold": 5000}},
	{"id": "d_store", "text": "Open a Cube at Store", "event": "store_cube", "goal": 1, "reward": {"energy": 20}},
	{"id": "d_tower", "text": "Claim the Sky Tower.", "event": "tower", "goal": 3, "reward": {"cube": "blue"}},
	{"id": "d_fp", "text": "Send Friend Points.", "event": "send_fp", "goal": 1, "reward": {"gems": 1}},
	{"id": "d_lv30", "text": "Achieve Monster Lv.30.", "event": "reach30", "goal": 1, "reward": {"gold": 10000}},
]
const DAILY_ALL := {"gems": 1, "cube": "blue"}
const WEEKLY := [
	{"id": "w_elemental", "text": "Explore Elemental Island (Special Island)", "event": "special:elemental_island", "goal": 10, "reward": {"cube": "red"}},
	{"id": "w_evolve", "text": "Evolve the monster!", "event": "evolve", "goal": 2, "reward": {"gold": 50000}},
	{"id": "w_fuse", "text": "Fuse the Monster!", "event": "fuse", "goal": 2, "reward": {"gold": 50000}},
	{"id": "w_lv30", "text": "Achieve Lv.30 (Except Material)", "event": "reach30", "goal": 20, "reward": {"gems": 20}},
	{"id": "w_volcano", "text": "Explore Volcano Island", "event": "special:volcano_island", "goal": 7, "reward": {"monster": "ruburak"}},
	{"id": "w_icicle", "text": "Explore Icicle Island", "event": "special:icicle_island", "goal": 7, "reward": {"monster": "sapphburak"}},
	{"id": "w_jungle", "text": "Explore Jungle Island", "event": "special:jungle_island", "goal": 7, "reward": {"monster": "greeburak"}},
	{"id": "w_daily", "text": "Clear Daily Mission", "event": "daily_done", "goal": 40, "reward": {"cube": "yellow"}},
	{"id": "w_ocean1", "text": "Explore Deep Ocean Isle1 (Special Island)", "event": "special:deep_ocean_island", "goal": 10, "reward": {"gold": 20000}},
	{"id": "w_ocean2", "text": "Explore Deep Ocean Isle2 (Special Island)", "event": "special:deep_ocean_island", "goal": 20, "reward": {"cube": "yellow"}},
]
const EVENT := [
	{"id": "ev_magic1", "text": "[Otc] Explore Magic Island1", "event": "special:magic_island", "goal": 10, "reward": {"gold": 15000}},
	{"id": "ev_magic2", "text": "[Otc] Explore Magic Island2", "event": "special:magic_island", "goal": 50, "reward": {"gems": 30}},
	{"id": "ev_magic3", "text": "[Otc] Explore Magic Island3", "event": "special:magic_island", "goal": 100, "reward": {"monster": "blacky"}},
	{"id": "ev_elem1", "text": "[Otc] Explore Elemental Island1", "event": "special:elemental_island", "goal": 10, "reward": {"gold": 15000}},
	{"id": "ev_elem2", "text": "[Otc] Explore Elemental Island2", "event": "special:elemental_island", "goal": 50, "reward": {"gems": 30}},
	{"id": "ev_elem3", "text": "[Otc] Explore Elemental Island3", "event": "special:elemental_island", "goal": 100, "reward": {"gems": 60}},
	{"id": "ev_ocean_n", "text": "[Oct] Explore DeapOcean Island (Normal)", "event": "special:deep_ocean_island:normal", "goal": 100, "reward": {"monster": "mini_coral"}},
	{"id": "ev_ocean_h", "text": "[Oct] Explore DeapOcean Island (Hard)", "event": "special:deep_ocean_island:hard", "goal": 70, "reward": {"monster": "turto_papa"}},
	{"id": "ev_ocean_hell", "text": "[Oct] Explore DeapOcean Island (Hell)", "event": "special:deep_ocean_island:hell", "goal": 50, "reward": {"monster": "chibi_lorel"}},
	{"id": "ev_halloween1", "text": "[Oct] Explore Halloween Island (Normal) 1", "event": "special:halloween_island:normal", "goal": 40, "reward": {"energy": 40}},
	{"id": "ev_halloween2", "text": "[Oct] Explore Halloween Island (Normal) 2", "event": "special:halloween_island:normal", "goal": 60, "reward": {"gold": 20000}},
	{"id": "ev_halloween3", "text": "[Oct] Explore Halloween Island (Normal) 3", "event": "special:halloween_island:normal", "goal": 80, "reward": {"monster": "guardhunt"}},
]
const BEAT_ELEMENT := [10, 50, 100, 250, 500, 1000, 2000]
const BEAT_ELEMENT_REWARDS := [{"gold": 500}, {"gems": 5}, {"gold": 1000}, {"gems": 10}, {"gold": 2000}, {"gems": 20}, {"gems": 40}]
const ENDLESS := [
	{"id": "e_beat", "text": "Beat %s Monsters", "event": "kill", "goals": [10, 50, 100, 250, 500, 1000, 2000], "rewards": [{"gold": 500}, {"gems": 4}, {"gold": 1000}, {"gems": 20}, {"gold": 2000}, {"gems": 80}, {"gems": 200}]},
	{"id": "e_fire", "text": "Beat %s Fire Monsters", "event": "kill_fire", "goals": BEAT_ELEMENT, "rewards": BEAT_ELEMENT_REWARDS},
	{"id": "e_water", "text": "Beat %s Water Monsters", "event": "kill_water", "goals": BEAT_ELEMENT, "rewards": BEAT_ELEMENT_REWARDS},
	{"id": "e_nature", "text": "Beat %s Nature Monsters", "event": "kill_nature", "goals": BEAT_ELEMENT, "rewards": BEAT_ELEMENT_REWARDS},
	{"id": "e_normal", "text": "Beat %s Normal Monsters", "event": "kill_normal", "goals": BEAT_ELEMENT, "rewards": BEAT_ELEMENT_REWARDS},
	{"id": "e_collect3", "text": "[Collect] [★3] %s Monsters", "event": "collect:3", "goals": [4, 12, 30, 75, 150, 400], "rewards": [{"gold": 1000}, {"gold": 2000}, {"gems": 2}, {"gems": 4}, {"gems": 6}, {"gems": 10}]},
	{"id": "e_collect4", "text": "[Collect] [★4] %s Monsters", "event": "collect:4", "goals": [4, 12, 30, 75, 150, 400], "rewards": [{"gold": 2000}, {"gold": 3000}, {"gems": 3}, {"gems": 6}, {"gems": 10}, {"gems": 14}]},
	{"id": "e_collect5", "text": "[Collect] [★5] %s Monsters", "event": "collect:5", "goals": [4, 12, 30, 75, 150], "rewards": [{"gems": 2}, {"gems": 4}, {"gems": 8}, {"gems": 15}, {"gems": 20}]},
	{"id": "e_collect6", "text": "[Collect] [★6] %s Monsters", "event": "collect:6", "goals": [4, 12, 30, 75], "rewards": [{"gems": 20}, {"gems": 40}, {"gems": 80}, {"gems": 160}]},
	{"id": "e_collect", "text": "[Collect] %s Monsters", "event": "collect:0", "goals": [25, 100], "rewards": [{"gold": 1000}, {"gold": 5000}], "then_step": 100, "then_reward": {"gold": 10000}},
	{"id": "e_friend", "text": "Use Friend's Monster x%s", "event": "friend_use", "goals": [5], "rewards": [{"gold": 1000}]},
	{"id": "e_dino", "text": "Clear Dino Gorge", "event": "clear:dino_gorge", "goals": [1], "rewards": [{"gems": 2}]},
	{"id": "e_volcano", "text": "Clear Volcano Isle Field 1", "event": "special_clear:volcano_island/0", "goals": [1], "rewards": [{"gems": 2}]},
	{"id": "e_quests", "text": "Complete %s Quests", "event": "quest", "step": 50, "reward": {"gems": 15}},
	{"id": "e_index", "text": "[Index] Discover %s Monsters", "event": "state:owned", "goals": [25, 50, 100, 200, 300, 500], "rewards": [{"gems": 4}, {"gems": 8}, {"gems": 12}, {"gems": 20}, {"gems": 30}, {"gems": 50}]},
	{"id": "e_lv30", "text": "Raise %s different Monsters to Lv.30", "event": "state:maxed", "goals": [5, 15, 30, 60, 100], "rewards": [{"gems": 6}, {"gems": 10}, {"gems": 16}, {"gems": 24}, {"gems": 40}]},
	{"id": "e_tower", "text": "Reach Sky Tower Floor %s", "event": "state:tower_floor", "goals": [5, 10, 15, 20, 25, 30, 40, 50], "rewards": [{"gems": 10}, {"gems": 20}, {"gems": 40}, {"gems": 80}, {"gems": 160}, {"gems": 320}, {"gems": 640}, {"gems": 1280}]},
	{"id": "e_hell", "text": "[Hell] Clear %s Island(s)", "event": "state:hell_islands", "goals": [1, 3, 5, 8], "rewards": [{"gems": 6}, {"gems": 12}, {"gems": 20}, {"gems": 40}]},
	{"id": "e_raid", "text": "Clear %s Raid Stages", "event": "raid_room", "goals": [5, 20, 50, 100, 250], "rewards": [{"gems": 4}, {"gems": 8}, {"gems": 12}, {"gems": 20}, {"gems": 30}]},
	{"id": "e_arena", "text": "Battle at the Arena %s times", "event": "arena", "goals": [10, 50, 150, 300, 600], "rewards": [{"gems": 4}, {"gems": 8}, {"gems": 12}, {"gems": 20}, {"gems": 30}]},
	{"id": "e_special", "text": "Explore Special Islands %s times", "event": "special", "goals": [25, 100, 250, 500, 1000], "rewards": [{"gems": 4}, {"gems": 8}, {"gems": 12}, {"gems": 20}, {"gems": 30}]},
	{"id": "e_boost", "text": "Boost Monsters %s times", "event": "boost", "goals": [25, 100, 300, 750, 1500], "rewards": [{"gems": 4}, {"gems": 6}, {"gems": 10}, {"gems": 16}, {"gems": 24}]},
	{"id": "e_evolve", "text": "Evolve Monsters %s times", "event": "evolve", "goals": [3, 10, 25, 50, 100], "rewards": [{"gems": 4}, {"gems": 8}, {"gems": 12}, {"gems": 20}, {"gems": 30}]},
	{"id": "e_fuse", "text": "Fuse Monsters %s times", "event": "fuse", "goals": [3, 10, 25, 50, 100], "rewards": [{"gems": 4}, {"gems": 8}, {"gems": 12}, {"gems": 20}, {"gems": 30}]},
	{"id": "e_catch", "text": "Catch %s Monsters in Quests", "event": "quest_cube", "goals": [25, 100, 300, 750, 1500], "rewards": [{"gems": 4}, {"gems": 8}, {"gems": 12}, {"gems": 20}, {"gems": 30}]},
	{"id": "e_cubes", "text": "Open %s Cubes at the Store", "event": "store_cube", "goals": [10, 50, 100, 250, 500], "rewards": [{"gems": 4}, {"gems": 8}, {"gems": 12}, {"gems": 20}, {"gems": 30}]},
	{"id": "e_dailies", "text": "Clear %s Daily Missions", "event": "daily_done", "goals": [25, 100, 300, 750, 1500], "rewards": [{"gems": 4}, {"gems": 8}, {"gems": 12}, {"gems": 20}, {"gems": 30}]},
	{"id": "e_fp", "text": "Send Friend Points %s times", "event": "send_fp", "goals": [10, 50, 150, 365], "rewards": [{"gems": 2}, {"gems": 6}, {"gems": 10}, {"gems": 20}]},
]
const ATTENDANCE := [
	{"cube": "yellow"}, {"energy": 20}, {"gold": 2000}, {"cube": "blue"}, {"energy": 20}, {"gold": 2000}, {"gems": 5},
	{"cube": "yellow"}, {"energy": 20}, {"gold": 2000}, {"cube": "blue"}, {"energy": 25}, {"gold": 2500}, {"gems": 10},
	{"cube": "red"}, {"energy": 20}, {"gold": 2000}, {"cube": "blue"}, {"energy": 30}, {"gold": 5000}, {"gems": 15},
	{"cube": "red"}, {"energy": 20}, {"gold": 2000}, {"cube": "blue"}, {"energy": 40}, {"gold": 9999}, {"gems": 30},
]
const CUBE_NAMES := {"blue": "Blue Cube", "yellow": "Yellow Cube", "red": "Red Cube"}


static func reward_text(r: Dictionary) -> String:
	var parts := []
	if r.has("gold") and int(r.gold) > 0:
		parts.append("%s gold" % Screen._thousands(int(r.gold)))
	if r.has("energy"):
		parts.append("%d energy" % int(r.energy))
	if r.has("gems") and int(r.gems) > 0:
		parts.append("%d gems" % int(r.gems))
	if r.has("cube"):
		parts.append(CUBE_NAMES.get(r.cube, r.cube))
	if r.has("monster"):
		parts.append(String(DB.monster(String(r.monster)).get("name", r.monster)))
	return " + ".join(parts)


static func reward_icon(r: Dictionary) -> String:
	if r.has("cube"):
		return {"blue": "betaHud00/H_cube_00.png", "yellow": "betaHud00/H_cube_01.png", "red": "betaHud00/H_cube_02.png"}.get(r.cube, "betaHud00/H_cube_00.png")
	if r.has("energy"):
		return "betaHud00/H_energy_01.png"
	if r.has("gems"):
		return "betaHud00/H_crystal_01.png"
	return "betaHud00/H_money_02.png"


static func endless_tier(m: Dictionary, tier: int) -> Dictionary:
	if m.has("step"):
		var goal := int(m.step) * (tier + 1)
		return {"text": String(m.text) % Screen._thousands(goal), "goal": goal, "reward": m.reward, "done_all": false}
	if m.has("then_step") and tier >= m.goals.size():
		var next: int = int(m.goals[-1]) + int(m.then_step) * (tier - m.goals.size() + 1)
		return {"text": String(m.text) % Screen._thousands(next), "goal": next, "reward": m.then_reward, "done_all": false}
	var i := mini(tier, m.goals.size() - 1)
	var text := String(m.text)
	if text.contains("%s"):
		text = text % Screen._thousands(int(m.goals[i]))
	return {"text": text, "goal": int(m.goals[i]), "reward": m.rewards[i], "done_all": tier >= m.goals.size()}


static func progress(bucket: String, event: String) -> int:
	if event.begins_with("collect:"):
		var stars := int(event.get_slice(":", 1))
		var n := 0
		for m in Save.data.monsters:
			var def := DB.monster(String(m.id))
			if not def.is_empty() and not def.get("material", false) and (stars == 0 or int(def.stars) == stars):
				n += 1
		return maxi(n, Save.counter("total", "get:%d" % stars))
	if event.begins_with("clear:"):
		var island := DB.island(event.get_slice(":", 1))
		var stages: int = island.difficulties.normal.stages.size()
		return 1 if Save.cleared_stages(String(island.id), "normal") >= stages else 0
	if event.begins_with("state:"):
		match event.get_slice(":", 1):
			"owned":
				return Save.data.owned.size()
			"maxed":
				return Save.data.maxed.size()
			"tower_floor":
				return int(Save.data.get("tower_floor", 0))
			"hell_islands":
				var n := 0
				for island in DB.islands:
					if Save.cleared_stages(String(island.id), "hell") >= island.difficulties.hell.stages.size():
						n += 1
				return n
		return 0
	if event.begins_with("special_clear:"):
		return 1 if Save.data.special_clears.has(event.get_slice(":", 1)) else 0
	return Save.counter("total" if bucket in ["endless", "event"] else bucket, event)
