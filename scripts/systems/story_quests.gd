class_name StoryQuests
extends RefCounted

const CHAIN := [
	{
		"id": "talmag1", "who": "talmag", "after": "cleared:sprout_island",
		"ask": "I lost my jewel in Lake Island! Can you pick a\nrandom field and search it a few times? Maybe 5?",
		"text": "[Quest] Explore Lake Island", "event": "island:lake_island", "goal": 5, "reward": {"gold": 4000},
		"done": "I didn't find anything in this field.",
	},
	{
		"id": "talmag2", "who": "talmag", "after": "",
		"ask": "I think the monsters in Lake Island took my jewel!\nCan you capture 5 2-star monsters for me?",
		"text": "[Collect] [★2] Monsters", "event": "get:2", "goal": 5, "reward": {"gold": 8000},
		"done": "It doesn't look like the monsters have anything.",
	},
	{
		"id": "talmag3", "who": "talmag", "after": "cleared:lake_island",
		"ask": "Someone saw Stoneskin take my jewel! Can you\nfind Stoneskin in Lake-12 and get my jewel back?",
		"text": "[Quest] Explore Lake-12", "event": "stage:lake_island/11", "goal": 3, "reward": {"monster": "talmag"},
		"done": "Thank you! If you don't mind, may I join you?",
	},
	{
		"id": "camhil1", "who": "camhil", "after": "cleared:lake_island",
		"ask": "The desert has no room for weak monsters. Are\nyou brave enough to explore Desert Isle 7 times?",
		"text": "[Quest] Explore Desert Island", "event": "island:desert_isle", "goal": 7, "reward": {"gold": 10000},
		"done": "Not bad! You might survive the desert after all.",
	},
]
const DEFEAT := [
	"Oh no! Did your team get annihilated for the first\ntime? Well, adventure doesn't come easily! Cheer up!",
	"If your monsters' levels are low, you just need to level up.\nIf their rank are low, then go evolve them.\nOr, perhaps the elements were unfavorable for you.",
	"Your monster squad is much stronger than before.\nGo to Sprout Island and restore your confidence.",
	"Wait, do you already know?\nYou can use your skills automatically if you battle in a dungeon\nyou've already explored.",
	"Auto-combat's basic battle speed is 1.5x faster than manual\ncombat.\nOf course, you can increase the battle speed for manual combat\nanytime.",
	"Have you had enough time to get over your defeat?\nEven though you lost a battle, you're coming away\nstronger than before!",
	"Go back over the islands you've already explored.\nYou'll gain tons of EXP, gold, and monsters along the way!",
	"This area will be super easy if you just keep\nfortifying, evolving, and fusing!",
]


static func state() -> Dictionary:
	if not Save.data.has("story_quests"):
		Save.data["story_quests"] = {"step": 0, "started": false, "base": 0, "defeat_seen": false, "lost": false}
	return Save.data.story_quests


static func current() -> Dictionary:
	var s := state()
	return CHAIN[int(s.step)] if int(s.step) < CHAIN.size() else {}


static func progress() -> int:
	var q := current()
	if q.is_empty() or not bool(state().started):
		return 0
	return mini(int(q.goal), Save.counter("total", String(q.event)) - int(state().base))


static func tracker_text() -> String:
	var q := current()
	if q.is_empty() or not bool(state().started):
		return ""
	return "%s (%d/%d)" % [q.text, progress(), int(q.goal)]


static func record_defeat() -> void:
	var s := state()
	if not bool(s.defeat_seen):
		s.lost = true


static func _unlocked(q: Dictionary) -> bool:
	var after := String(q.after)
	if after.begins_with("cleared:"):
		var isl := DB.island(after.trim_prefix("cleared:"))
		return Save.cleared_stages(String(isl.id), "normal") >= int(isl.difficulties.normal.stages.size())
	return true


static func steps_for_hub() -> Array:
	var s := state()
	var steps := []
	if bool(s.lost) and not bool(s.defeat_seen):
		for line in DEFEAT:
			steps.append({"say": "tobiak", "text": line})
		s.defeat_seen = true
		s.lost = false
	while int(s.step) < CHAIN.size():
		var q: Dictionary = CHAIN[int(s.step)]
		if not bool(s.started):
			if not _unlocked(q):
				break
			steps.append({"say": q.who, "text": q.ask, "guide": false})
			var card: Dictionary = {"card": "quest", "title": "New Quest!", "text": q.text}
			card.merge(q.reward)
			steps.append(card)
			s.started = true
			s.base = Save.counter("total", String(q.event))
			break
		if progress() < int(q.goal):
			break
		steps.append({"say": q.who, "text": q.done, "guide": false})
		var clear: Dictionary = {"card": "clear", "text": "Wow, amazing!"}
		clear.merge(q.reward)
		steps.append(clear)
		Save.grant(q.reward)
		s.step = int(s.step) + 1
		s.started = false
	if not steps.is_empty():
		Save.save_game()
	return steps
