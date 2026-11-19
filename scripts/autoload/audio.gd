extends Node

const DIR := "res://assets/apk/audio/"
const SOUNDS := {
	"heal": "skill_heal_base1.ogg",
	"heal_fire": "skill_heal_fire.ogg",
	"heal_water": "skill_heal_water.ogg",
	"heal_nature": "skill_heal_nature.ogg",
	"buff": "skill_buff_normal.ogg",
	"buff_big": "skill_buff_heavy.ogg",
	"debuff": "skill_debuff_03.ogg",
	"shield": "skill_shield_01.ogg",
	"cleanse": "skill_purify_02.ogg",
	"cast_fire": "f_flametiger_21382_cast.ogg",
	"cast_water": "w_otter_21447_cast.ogg",
	"cast_nature": "n_greene_32_cast.ogg",
	"cast_normal": "b_ogre_21296_cast.ogg",
	"hit_fire": "f_pongpong_100_damage.ogg",
	"hit_water": "w_pongpong_21476_damage.ogg",
	"hit_nature": "n_pongpong_21477_damage.ogg",
	"hit_normal": "b_pongpong_21478_damage.ogg",
	"click": "res://assets/sfx/button.ogg",
	"cube_open": "res://assets/sfx/cube_open.ogg",
	"popup_open": "res://assets/sfx/popup_open.ogg",
	"popup_ok": "res://assets/sfx/popup_ok.ogg",
	"back": "res://assets/sfx/back.ogg",
	"tab": "res://assets/sfx/tab.ogg",
	"begin_quest": "res://assets/sfx/begin_quest.ogg",
	"stage_select": "res://assets/sfx/stage_select.ogg",
	"battle_start": "res://assets/sfx/battle_start.ogg",
	"boost_success": "res://assets/sfx/boost_success.ogg",
	"boost_fail": "res://assets/sfx/boost_fail.ogg",
	"evolve": "res://assets/sfx/evolve.ogg",
	"fusion": "res://assets/sfx/fusion.ogg",
	"quest_complete": "res://assets/sfx/quest_complete.ogg",
	"exp_count": "res://assets/sfx/exp_count.ogg",
	"stage_clear": "res://assets/sfx/stage_clear.ogg",
	"cube_get": "res://assets/sfx/cube_get.ogg",
	"cube_pickup": "res://assets/sfx/cube_pickup.ogg",
	"coin": "res://assets/sfx/coin.ogg",}
const SKILL_SOUNDS := {
	"triple hit": "f_flametiger_21381", "pepper shot": "f_flametiger_21384", "flaming claws": "w_babytarang_21645",
	"concentrated venom": "w_otter_21447", "poison ball": "w_otter_21449", "panda stun punch": "w_babytarang_21644",
	"dark orb": "b_ocpid_21241", "meteor kick": ["w_otter_21447", ""], "hunter's trap": "b_butterfairy_21218",
	"weak urgent heal": "f_pongpong_100", "total critical up": "f_pongpong_103",
}
const RAM_SKILLS := ["strong ram", "swamp needle"]
const RAM_SOUNDS := {"fire": "f_ogre_21658", "water": "w_ogre_21659", "nature": "n_ogre_21522", "normal": "b_ogre_21296"}
const SKILL_POOLS := {
	"fire": ["f_butterfairy_21499", "f_butterfairy_550", "f_chiqueen_4", "f_flametiger_21382", "f_pongpong_100", "f_pongpong_103"],
	"water": ["w_babytarang_11005", "w_babytarang_21608", "w_butterfairy_21501", "w_butterfairy_551", "w_fisher_23", "w_fisher_26", "w_pongpong_21476", "w_snik_173", "w_winny_21342", "w_winny_21344", "w_winny_21345"],
	"nature": ["n_butterfairy_21550", "n_butterfairy_552", "n_greene_21247", "n_greene_2", "n_greene_32", "n_pongpong_21477"],
	"normal": ["b_birdfly_27", "b_birdfly_30", "b_butterfairy_21216", "b_butterfairy_21218", "b_mud_21493", "b_nectar_21280", "b_ocpid_21241", "b_ocpid_21469", "b_ogre_21298", "b_pongpong_21478"],
}
const MUSIC_DIR := "res://assets/music/"
const MUSIC := {
	"title": "Title.mp3",
	"lobby": MUSIC_DIR + "lobby.ogg",
	"sprout": MUSIC_DIR + "sprout.ogg",
	"lake": MUSIC_DIR + "lake.ogg",
	"desert": MUSIC_DIR + "desert.ogg",
	"boneyard": MUSIC_DIR + "boneyard.ogg",
	"robo": MUSIC_DIR + "robo.ogg",
	"lake_boss": MUSIC_DIR + "lake_boss.ogg",
	"moonlight_boss": MUSIC_DIR + "moonlight_boss.ogg",
	"dino_boss": MUSIC_DIR + "dino_boss.ogg",
	"robo_boss": MUSIC_DIR + "robo_boss.ogg",
	"boss": "Boss-01.mp3",
	"pvp": "Battle-pvp2.mp3",
	"duel": "Battle-pvp.mp3",
	"league": "Battle-pvp3.mp3",
}
const ISLAND_MUSIC := {"sprout_island": "sprout", "lake_island": "lake", "desert_isle": "desert", "moonlight_desert": "desert", "boneyard_island": "boneyard", "robo_island": "robo"}
const ISLAND_BOSS_MUSIC := {"lake_island": "lake_boss", "moonlight_desert": "moonlight_boss", "dino_gorge": "dino_boss", "robo_island": "robo_boss"}
const MODE_MUSIC := {"arena": "pvp", "duel": "duel", "league": "league", "tower": "boss"}
const VOICES := 8
const MUSIC_DB := -8.0

var music: AudioStreamPlayer
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _current_music := ""
var _cache: Dictionary = {}
var _fade: Tween


const SETTINGS := "user://settings.cfg"
const BUSES := ["Master", "Music", "SFX"]

var volume := {"Master": 1.0, "Music": 0.8, "SFX": 0.9}
var enabled := {"Music": true, "SFX": true}
const RESOLUTIONS := ["1280x720", "1920x1080", "fullscreen"]
var resolution := "1280x720"


func set_resolution(r: String) -> void:
	resolution = r if r in RESOLUTIONS else "1280x720"
	apply_resolution()
	_save_settings()


func apply_resolution() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("mobile"):
		return
	var w := get_window()
	if resolution == "fullscreen":
		w.mode = Window.MODE_FULLSCREEN
		return
	w.mode = Window.MODE_WINDOWED
	var parts := resolution.split("x")
	var size := Vector2i(int(parts[0]), int(parts[1]))
	var screen := DisplayServer.screen_get_usable_rect(w.current_screen)
	if size.x > screen.size.x or size.y > screen.size.y:
		w.mode = Window.MODE_FULLSCREEN
		return
	w.size = size
	w.position = screen.position + (screen.size - size) / 2


func _ready() -> void:
	for b in ["Music", "SFX"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	music = AudioStreamPlayer.new()
	music.volume_db = MUSIC_DB
	music.bus = "Music"
	add_child(music)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = -4.0
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_load_settings()


func set_volume(bus: String, v: float) -> void:
	volume[bus] = clampf(v, 0.0, 1.0)
	_apply()
	_save_settings()


func set_enabled(bus: String, on: bool) -> void:
	enabled[bus] = on
	_apply()
	_save_settings()


func _apply() -> void:
	for b in BUSES:
		var i := AudioServer.get_bus_index(b)
		if i < 0:
			continue
		var v: float = volume.get(b, 1.0)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v * v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001 or not enabled.get(b, true))


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		for b in BUSES:
			volume[b] = float(cfg.get_value("volume", b, volume[b]))
		for b in enabled:
			enabled[b] = bool(cfg.get_value("enabled", b, true))
		resolution = String(cfg.get_value("display", "resolution", resolution))
	_apply()
	apply_resolution.call_deferred()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for b in BUSES:
		cfg.set_value("volume", b, volume[b])
	for b in enabled:
		cfg.set_value("enabled", b, enabled[b])
	cfg.set_value("display", "resolution", resolution)
	cfg.save(SETTINGS)


func play(sound: String, db: float = 0.0) -> AudioStreamPlayer:
	var stream := _stream(SOUNDS.get(sound, ""))
	if stream == null:
		return null
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.volume_db = -4.0 + db
	p.play()
	return p


func play_skill(skill_name: String, element: String, part: String) -> void:
	var base := skill_sound(skill_name, element, part)
	var stream := _stream(base + "_" + part + ".ogg")
	if stream == null and part == "cast":
		stream = _stream(base + "_cast_voice.ogg")
	if stream == null:
		play(part.replace("damage", "hit") + "_" + element)
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.volume_db = -4.0
	p.play()


func menu_paths() -> Array:
	var out := []
	for file in SOUNDS.values() + [MUSIC.lobby]:
		var path := String(file) if String(file).begins_with("res://") else DIR + String(file)
		if ResourceLoader.exists(path):
			out.append(path)
	return out


func battle_paths(quest: Dictionary, island_id: String) -> Array:
	var out := []
	for file in SOUNDS.values() + [MUSIC.get(battle_music(quest, island_id, true), ""), MUSIC.lobby]:
		var path := String(file) if String(file).begins_with("res://") else DIR + String(file)
		if ResourceLoader.exists(path):
			out.append(path)
	return out


func skill_paths(skill_name: String, element: String) -> Array:
	var out := [DIR + String(SOUNDS.get("hit_" + element, ""))]
	for part in ["cast", "damage"]:
		var base := skill_sound(skill_name, element, part)
		for tail in ["_" + part + ".ogg", "_cast_voice.ogg"]:
			if ResourceLoader.exists(DIR + base + tail):
				out.append(DIR + base + tail)
	return out


func has_skill_sound(skill_name: String) -> bool:
	return SKILL_SOUNDS.has(skill_name.to_lower())


func skill_sound(skill_name: String, element: String, part: String = "cast") -> String:
	var key := skill_name.to_lower()
	var known = SKILL_SOUNDS.get(key, "")
	if known is Array:
		known = known[0 if part == "cast" else 1]
	if known != "":
		return known
	if key in RAM_SKILLS:
		return RAM_SOUNDS.get(element, RAM_SOUNDS.normal)
	var pool: Array = SKILL_POOLS.get(element, SKILL_POOLS.normal)
	return pool[absi(hash(skill_name)) % pool.size()]


func play_music(track: String) -> void:
	if track == _current_music:
		return
	_current_music = track
	if _fade != null and _fade.is_valid():
		_fade.kill()
	var stream := _stream(MUSIC.get(track, ""))
	if stream == null:
		music.stop()
		return
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = true
	music.stream = stream
	music.volume_db = MUSIC_DB
	music.play()


func fade_music(seconds: float) -> void:
	_current_music = ""
	_fade = music.create_tween()
	_fade.tween_property(music, "volume_db", -60.0, seconds)
	_fade.tween_callback(music.stop)
	_fade.tween_callback(func(): music.volume_db = MUSIC_DB)


func battle_music(quest: Dictionary, island_id: String, boss: bool) -> String:
	var kind := String(quest.get("kind", "story"))
	if MODE_MUSIC.has(kind):
		return MODE_MUSIC[kind]
	if boss:
		return ISLAND_BOSS_MUSIC.get(island_id, "boss") if kind == "story" else "boss"
	return ISLAND_MUSIC.get(island_id, "sprout") if kind == "story" else "sprout"


func _stream(file: String) -> AudioStream:
	if file == "":
		return null
	if not _cache.has(file):
		var path := file if file.begins_with("res://") else DIR + file
		_cache[file] = load(path) if ResourceLoader.exists(path) else null
	return _cache[file]
