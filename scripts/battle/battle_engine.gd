class_name BattleEngine
extends RefCounted

signal battle_event(e: Dictionary)

const MP_REGEN := 8.0
const DOT_TICK := 1.0
const SHIELD_PER_STAGE := 0.08
const DEF_FACTOR := 0.5
const ENEMY_SKILL_INTERVAL := Vector2(7.0, 11.0)
const BOSS_SKILL_INTERVAL := Vector2(5.0, 8.0)
const TIME_LIMIT := 900.0
const BOSS_HP_MULT := 2.0
const BOSS_ATK_MULT := 1.15
const FEVER_MAX := 100.0
const FEVER_PER_HIT := 0.25
const FEVER_PER_SKILL_HIT := 6.0
const FEVER_SECONDS := 10.0
const WAVE_HEAL := 0.1

var allies: Array[BattleUnit] = []
var enemies: Array[BattleUnit] = []
var waves: Array = []
var wave_index := -1
var time := 0.0
var result := ""
var auto_skills := false
var manual_supports := false
var focus: BattleUnit

var mp := 0.0
var max_mp := 100.0
var mp_regen_mult := 1.0
var kills: Array[String] = []
var time_limit := TIME_LIMIT
var wave_heal := WAVE_HEAL
var fever_enabled := false
var fever := 0.0
var fever_active := false
var fever_left := 0.0
var room_limit := 0.0
var final_room_limit := 0.0
var room_time := 0.0
var pvp := false
var enemy_mp := 0.0
var enemy_max_mp := 100.0
var enemy_mp_regen := 1.0
var league := false
var ally_bench: Array = []
var enemy_bench: Array = []
var ally_total := 0
var enemy_total := 0
var endless := false
var immortal_enemies := false
var infinite_mp := false

var _rng := RandomNumberGenerator.new()
var _dot_clock := 0.0
var _wave_delay := 0.0
var hold := 0.0


func setup(team: Array, wave_specs: Array, seed_value: int = 0) -> void:
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	for i in team.size():
		var t: Dictionary = team[i]
		var u := BattleUnit.create(BattleUnit.PLAYER, i, t.id, int(t.level), int(t.get("boost", 0)))
		u.is_leader = i == 0
		_apply_stones(u, t.get("stones", {}))
		_apply_pet_stats(u, t.get("pet", {}))
		u.support_timer = float(u.support.get("cooldown", 12.0)) * _rng.randf_range(0.4, 0.8)
		u.attack_timer = _rng.randf_range(0.2, 0.8)
		allies.append(u)
	_apply_passives(allies)
	_apply_pet_passives(allies, team)
	for i in team.size():
		if team[i].has("hp_ratio"):
			allies[i].hp = allies[i].max_hp * clampf(float(team[i].hp_ratio), 0.01, 1.0)
	var leader := allies[0]
	max_mp = float(DB.monster(leader.monster_id).stats.mp) + leader.extra_max_mp
	mp = max_mp * 0.3
	waves = wave_specs
	_next_wave()


func leader() -> BattleUnit:
	return allies[0] if not allies.is_empty() else null


func living(side: int) -> Array[BattleUnit]:
	var src := allies if side == BattleUnit.PLAYER else enemies
	var out: Array[BattleUnit] = []
	for u in src:
		if u.alive():
			out.append(u)
	return out


func step(dt: float) -> void:
	if result != "":
		return
	if hold > 0.0:
		hold -= dt
		return
	time += dt
	if time >= time_limit and not endless:
		_finish(_league_timeout_result() if league else "lose")
		return
	if _wave_delay > 0.0:
		_wave_delay -= dt
		if _wave_delay <= 0.0:
			_next_wave()
		return
	room_time += dt
	if room_limit_now() > 0.0 and room_time >= room_limit_now() and not endless:
		_finish("lose")
		return

	var lead := leader()
	if lead.alive():
		mp = max_mp if infinite_mp else minf(max_mp, mp + MP_REGEN * mp_regen_mult * dt)

	for u in allies + enemies:
		_tick_statuses(u, dt)

	_dot_clock += dt
	if _dot_clock >= DOT_TICK:
		_dot_clock -= DOT_TICK
		for u in allies + enemies:
			_tick_dots(u)

	for u in allies:
		if not u.can_act():
			continue
		u.attack_timer -= dt
		if u.attack_timer <= 0.0:
			u.attack_timer += u.attack_interval()
			_basic_attack(u)
		if (league or not u.is_leader) and u.can_cast():
			var was_ready := u.support_timer <= 0.0
			u.support_timer -= dt
			if u.support_timer <= 0.0:
				if manual_supports and not auto_skills and not league:
					u.support_timer = 0.0
					if not was_ready:
						_emit({"kind": "support_ready", "unit": u})
				else:
					u.support_timer = float(u.support.get("cooldown", 12.0)) * u.cooldown_mult
					_cast(u, u.support, "support")

	for u in enemies:
		if u.is_boss and u.alive() and not u.traits.is_empty():
			_tick_traits(u, dt)
		if not u.can_act():
			continue
		u.attack_timer -= dt
		if u.attack_timer <= 0.0:
			u.attack_timer += u.attack_interval()
			_basic_attack(u)
		if pvp:
			if (league or not u.is_leader) and u.can_cast():
				u.support_timer -= dt
				if u.support_timer <= 0.0:
					u.support_timer = float(u.support.get("cooldown", 12.0)) * u.cooldown_mult
					_cast(u, u.support, "support")
			continue
		if u.can_cast() and not u.skills.is_empty():
			u.skill_timer -= dt
			if u.skill_timer <= 0.0:
				var r := BOSS_SKILL_INTERVAL if u.is_boss else ENEMY_SKILL_INTERVAL
				u.skill_timer = _rng.randf_range(r.x, r.y)
				_cast(u, u.skills[_rng.randi() % u.skills.size()], "enemy_skill")

	if auto_skills and not league:
		_auto_cast()
	if pvp and not league:
		_enemy_leader_ai(dt)
	if league:
		_league_reinforce()

	_check_end()


func cast_leader_skill(index: int) -> bool:
	var lead := leader()
	if result != "" or _wave_delay > 0.0 or hold > 0.0 or lead == null or not lead.can_cast():
		return false
	if index < 0 or index >= lead.skills.size():
		return false
	var skill: Dictionary = lead.skills[index]
	var cost := 0.0 if fever_active else float(skill.mp)
	if mp < cost:
		return false
	mp -= cost
	_cast(lead, skill, "leader")
	_check_end()
	return true


func support_ready(u: BattleUnit) -> bool:
	return manual_supports and u.side == BattleUnit.PLAYER and not u.is_leader and u.alive() and u.can_cast() \
		and not u.support.is_empty() and u.support_timer <= 0.0 and result == "" and _wave_delay <= 0.0 and hold <= 0.0


func cast_support(u: BattleUnit) -> bool:
	if not support_ready(u):
		return false
	u.support_timer = float(u.support.get("cooldown", 12.0)) * u.cooldown_mult
	_cast(u, u.support, "support")
	_check_end()
	return true


func activate_fever() -> bool:
	if not fever_enabled or fever_active or fever < FEVER_MAX or result != "":
		return false
	fever = 0.0
	fever_active = true
	fever_left = FEVER_SECONDS
	_emit({"kind": "fever"})
	return true


func tick_fever(real_dt: float) -> void:
	if not fever_active:
		return
	fever_left -= real_dt
	if fever_left <= 0.0:
		fever_left = 0.0
		fever_active = false
		_emit({"kind": "fever_end"})


func room_limit_now() -> float:
	if final_room_limit > 0.0 and wave_index == waves.size() - 1:
		return final_room_limit
	return room_limit


func revive_team() -> void:
	for u in allies:
		u.hp = u.max_hp
		u.statuses.clear()
		u.shield = 0.0
	mp = max_mp
	result = ""
	time = minf(time, time_limit - 60.0)
	if room_limit_now() > 0.0:
		room_time = minf(room_time, room_limit_now() - 30.0)


func set_focus(u: BattleUnit) -> void:
	if u != null and u.alive() and u.side == BattleUnit.ENEMY:
		focus = u


func _next_wave() -> void:
	wave_index += 1
	enemies.clear()
	focus = null
	room_time = 0.0
	if wave_index > 0 and wave_heal > 0.0:
		for a in living(BattleUnit.PLAYER):
			a.hp = minf(a.max_hp, a.hp + a.max_hp * wave_heal)
	var specs: Array = waves[wave_index]
	for i in specs.size():
		var s: Dictionary = specs[i]
		var u := BattleUnit.create(BattleUnit.ENEMY, i, s.id, int(s.level), int(s.get("boost", 0)))
		u.is_boss = bool(s.get("boss", false))
		if pvp:
			u.is_leader = i == 0
			_apply_stones(u, s.get("stones", {}))
			u.support_timer = float(u.support.get("cooldown", 12.0)) * _rng.randf_range(0.4, 0.8)
		if u.is_boss:
			u.max_hp *= BOSS_HP_MULT
			u.hp = u.max_hp
			u.base.atk *= BOSS_ATK_MULT
			u.traits = s.get("traits", [])
			if u.traits.has("armored"):
				u.base.def *= 4.0
			if u.traits.has("swift"):
				u.base.speed *= 1.6
		u.max_hp *= float(s.get("hp_mult", 1.0))
		u.hp = u.max_hp
		u.base.atk *= float(s.get("atk_mult", 1.0))
		u.attack_timer = _rng.randf_range(0.6, 1.4)
		var r := BOSS_SKILL_INTERVAL if u.is_boss else ENEMY_SKILL_INTERVAL
		u.skill_timer = _rng.randf_range(r.x, r.y)
		enemies.append(u)
	if pvp and not enemies.is_empty():
		_apply_passives(enemies)
		enemy_max_mp = float(DB.monster(enemies[0].monster_id).stats.mp) + enemies[0].extra_max_mp
		enemy_mp = enemy_max_mp * 0.3
	_emit({"kind": "wave", "index": wave_index, "count": waves.size()})


func _check_end() -> void:
	if result != "":
		return
	if league:
		if living(BattleUnit.PLAYER).is_empty() and ally_bench.is_empty():
			_finish("lose")
		elif living(BattleUnit.ENEMY).is_empty() and enemy_bench.is_empty():
			_finish("win")
		return
	if living(BattleUnit.PLAYER).is_empty():
		_finish("lose")
	elif living(BattleUnit.ENEMY).is_empty() and _wave_delay <= 0.0:
		if wave_index + 1 >= waves.size() and endless:
			waves.append_array(waves.slice(0, waves.size()))
		if wave_index + 1 >= waves.size():
			_finish("win")
		else:
			_wave_delay = 1.5
			_emit({"kind": "wave_clear", "index": wave_index})


func _finish(r: String) -> void:
	result = r
	_emit({"kind": "end", "result": r})


func _basic_attack(u: BattleUnit) -> void:
	var target := _pick_enemy_of(u)
	if target == null:
		return
	var dmg := _deal_damage(u, target, 1.0, "attack")
	var steal := u.status_value("lifesteal", "pct")
	if steal > 0.0 and dmg > 0.0:
		_heal(u, u, dmg * steal / maxf(1.0, u.stat("rec")), "lifesteal")


func _cast(caster: BattleUnit, skill: Dictionary, source: String) -> void:
	_emit({"kind": "skill", "unit": caster, "skill": skill, "source": source})
	var last_damage_targets: Array[BattleUnit] = []
	for e in skill.get("effects", []):
		var targets := _targets(caster, e)
		match String(e.type):
			"damage":
				last_damage_targets = targets
				for t in targets:
					_deal_damage(caster, t, float(e.mult), "skill")
			"heal":
				for t in targets:
					_heal(caster, t, float(e.mult), "skill")
			"lifesteal":
				_add_status(caster, {"type": "lifesteal", "pct": float(e.pct), "time": float(e.duration)})
			"shield":
				for t in targets:
					t.shield = maxf(t.shield, caster.max_hp * SHIELD_PER_STAGE * float(e.stage) + caster.stat("rec") * float(e.stage))
					t.shield_time = float(e.duration)
					_emit({"kind": "status", "unit": t, "status": "shield"})
			"buff":
				for t in targets:
					_add_status(t, {"type": "buff", "stat": e.stat, "pct": float(e.pct), "time": float(e.duration)})
			"debuff", "stun", "silence", "dot", "time_bomb":
				var pool := last_damage_targets if (not last_damage_targets.is_empty() and e.get("target", "") == "enemy") else targets
				for t in pool:
					_apply_negative(caster, t, e)
			"dispel":
				for t in targets:
					t.statuses = t.statuses.filter(func(s): return s.type != "buff" and s.type != "reflect" and s.type != "immune")
					t.shield = 0.0
			"cleanse":
				for t in targets:
					t.statuses = t.statuses.filter(func(s): return not (s.type in ["debuff", "dot", "stun", "silence", "time_bomb"]))
			"provoke":
				_add_status(caster, {"type": "provoke", "time": float(e.duration)})
			"reflect":
				_add_status(caster, {"type": "reflect", "pct": float(e.pct), "time": float(e.duration)})
			"immune":
				for t in targets:
					_add_status(t, {"type": "immune", "time": float(e.duration)})
			"shield_break":
				for t in targets:
					t.shield = 0.0
			"revive":
				var fallen := _fallen(caster.side)
				if not fallen.is_empty():
					var r: BattleUnit = fallen[0]
					r.statuses = []
					r.hp = r.max_hp * float(e.pct)
					_emit({"kind": "revive", "unit": r})


func _fallen(side: int) -> Array:
	return (allies if side == BattleUnit.PLAYER else enemies).filter(func(x): return not x.alive())


func _wasted(caster: BattleUnit, s: Dictionary) -> bool:
	return s.effects.all(func(e): return e.type == "revive") and _fallen(caster.side).is_empty()


func _apply_negative(caster: BattleUnit, t: BattleUnit, e: Dictionary) -> void:
	if not t.alive() or t.has_status("immune") or t.traits.has("immune"):
		return
	if _rng.randf() > float(e.get("chance", 1.0)):
		return
	match String(e.type):
		"debuff":
			_add_status(t, {"type": "debuff", "stat": e.stat, "pct": float(e.pct), "time": float(e.duration)})
		"stun":
			_add_status(t, {"type": "stun", "time": float(e.duration) * (0.5 if t.is_boss else 1.0)})
		"silence":
			_add_status(t, {"type": "silence", "time": float(e.duration)})
		"dot":
			_add_status(t, {"type": "dot", "kind": e.kind, "stage": int(e.stage), "power": caster.stat("atk"), "time": float(e.duration)})
		"time_bomb":
			_add_status(t, {"type": "time_bomb", "damage": float(e.damage), "time": float(e.delay)})


func _deal_damage(attacker: BattleUnit, target: BattleUnit, mult: float, source: String) -> float:
	if not target.alive():
		return 0.0
	var raw := attacker.stat("atk") * mult * DB.element_mult(attacker.element, target.element)
	var crit := _rng.randf() < attacker.stat("crit")
	if crit:
		raw *= 1.0 + attacker.stat("crit_dmg")
	raw *= _rng.randf_range(0.92, 1.08)
	var dmg := maxf(1.0, raw - target.stat("def") * DEF_FACTOR)
	var absorbed := 0.0
	if target.side == BattleUnit.PLAYER and fever_enabled and not fever_active:
		fever = minf(FEVER_MAX, fever + (FEVER_PER_HIT if source == "attack" else FEVER_PER_SKILL_HIT))
	if target.shield > 0.0 and source != "pierce":
		absorbed = minf(target.shield, dmg)
		target.shield -= absorbed
		dmg -= absorbed
	target.hp = maxf(0.0, target.hp - dmg)
	_emit({"kind": "damage", "unit": target, "from": attacker, "amount": dmg, "absorbed": absorbed, "crit": crit, "source": source})
	var reflect := target.status_value("reflect", "pct")
	if reflect > 0.0 and attacker.alive() and source != "reflect":
		var back := dmg * reflect
		attacker.hp = maxf(0.0, attacker.hp - back)
		_emit({"kind": "damage", "unit": attacker, "from": target, "amount": back, "absorbed": 0.0, "crit": false, "source": "reflect"})
		_check_death(attacker)
	_check_death(target)
	return dmg


func _heal(caster: BattleUnit, target: BattleUnit, mult: float, source: String) -> void:
	if not target.alive():
		return
	var amount := minf(target.max_hp - target.hp, caster.stat("rec") * mult)
	if amount <= 0.0:
		return
	target.hp += amount
	_emit({"kind": "heal", "unit": target, "amount": amount, "source": source})


func _check_death(u: BattleUnit) -> void:
	if u.hp > 0.0 or u.has_status("dead"):
		return
	if (endless and u.side == BattleUnit.PLAYER) or (immortal_enemies and u.side == BattleUnit.ENEMY):
		u.hp = u.max_hp
		return
	u.statuses = [{"type": "dead", "time": INF}]
	u.shield = 0.0
	if u.side == BattleUnit.ENEMY:
		kills.append(u.monster_id)
	if focus == u:
		focus = null
	_emit({"kind": "death", "unit": u})


func _add_status(u: BattleUnit, s: Dictionary) -> void:
	if not u.alive():
		return
	for i in u.statuses.size():
		var o: Dictionary = u.statuses[i]
		if o.type == s.type and o.get("stat", "") == s.get("stat", "") and o.get("kind", "") == s.get("kind", ""):
			u.statuses[i] = s
			_emit({"kind": "status", "unit": u, "status": s.type})
			return
	u.statuses.append(s)
	_emit({"kind": "status", "unit": u, "status": s.type})


func _tick_statuses(u: BattleUnit, dt: float) -> void:
	if not u.alive():
		return
	if u.shield > 0.0:
		u.shield_time -= dt
		if u.shield_time <= 0.0:
			u.shield = 0.0
	var keep: Array = []
	for s in u.statuses:
		s.time = float(s.time) - dt
		if s.time > 0.0:
			keep.append(s)
		elif s.type == "time_bomb":
			u.hp = maxf(0.0, u.hp - float(s.damage))
			_emit({"kind": "damage", "unit": u, "from": null, "amount": float(s.damage), "absorbed": 0.0, "crit": false, "source": "time_bomb"})
	u.statuses = keep
	_check_death(u)


func _tick_dots(u: BattleUnit) -> void:
	if not u.alive():
		return
	for s in u.statuses:
		if s.type != "dot":
			continue
		var dmg := float(s.power) * 0.06 * float(s.stage)
		if s.kind == "poison":
			dmg = maxf(dmg, u.max_hp * 0.01 * float(s.stage))
		u.hp = maxf(0.0, u.hp - dmg)
		_emit({"kind": "damage", "unit": u, "from": null, "amount": dmg, "absorbed": 0.0, "crit": false, "source": s.kind})
	_check_death(u)


func _pick_enemy_of(u: BattleUnit) -> BattleUnit:
	var foes := living(BattleUnit.ENEMY if u.side == BattleUnit.PLAYER else BattleUnit.PLAYER)
	if foes.is_empty():
		return null
	for f in foes:
		if f.has_status("provoke"):
			return f
	if u.side == BattleUnit.PLAYER and focus != null and focus.alive():
		return focus
	if u.side == BattleUnit.PLAYER:
		foes.sort_custom(func(a, b): return a.hp < b.hp)
		return foes[0]
	return foes[_rng.randi() % foes.size()]


func _targets(caster: BattleUnit, e: Dictionary) -> Array[BattleUnit]:
	var mine := living(caster.side)
	var foes := living(BattleUnit.ENEMY if caster.side == BattleUnit.PLAYER else BattleUnit.PLAYER)
	var out: Array[BattleUnit] = []
	match String(e.get("target", "enemy")):
		"enemy":
			var t := _pick_enemy_of(caster)
			if t != null:
				out.append(t)
		"all_enemies":
			out = foes
		"all_allies":
			out = mine
		"leader":
			var l: BattleUnit = allies[0] if caster.side == BattleUnit.PLAYER else (enemies[0] if not enemies.is_empty() else null)
			if l != null and l.alive():
				out.append(l)
			elif not mine.is_empty():
				out.append(mine[0])
		"most_hurt":
			if not mine.is_empty():
				mine.sort_custom(func(a, b): return a.hp_ratio() < b.hp_ratio())
				out.append(mine[0])
		"random_ally":
			if not mine.is_empty():
				out.append(mine[_rng.randi() % mine.size()])
		"self":
			out.append(caster)
	return out


func _apply_passives(units: Array) -> void:
	for i in range(1, units.size()):
		var p: Dictionary = DB.monster(units[i].monster_id).passive_effect
		if p.is_empty():
			continue
		for u in units:
			var scope: String = p.element
			if scope == "leader" and not u.is_leader:
				continue
			if scope in DB.BEATS.keys() + ["normal"] and u.element != scope:
				continue
			var stat: String = p.stat
			if stat == "mp":
				if u == units[0]:
					u.extra_max_mp += float(p.get("flat", 0.0))
				continue
			if stat == "mp_regen":
				if u.is_leader:
					if u.side == BattleUnit.PLAYER:
						mp_regen_mult += float(p.get("pct", 0.0))
					else:
						enemy_mp_regen += float(p.get("pct", 0.0))
				continue
			if p.has("flat"):
				if stat == "hp":
					u.max_hp += float(p.flat)
				elif u.base.has(stat):
					u.base[stat] += float(p.flat)
			elif stat == "hp":
				u.max_hp *= 1.0 + float(p.pct)
			elif stat == "crit" or stat == "crit_dmg":
				u.base[stat] += float(p.pct)
			elif u.base.has(stat):
				u.base[stat] *= 1.0 + float(p.pct)
			u.hp = u.max_hp


func _auto_cast() -> void:
	var lead := leader()
	if not lead.can_cast():
		return
	if fever >= FEVER_MAX and wave_index == waves.size() - 1:
		activate_fever()
	var low := false
	for u in living(BattleUnit.PLAYER):
		if u.hp_ratio() < 0.45:
			low = true
	var best := -1
	for i in lead.skills.size():
		var s: Dictionary = lead.skills[i]
		if float(s.mp) > mp or _wasted(lead, s):
			continue
		var heals := false
		for e in s.effects:
			if e.type == "heal":
				heals = true
		if low and heals:
			best = i
			break
		if not heals and (best < 0 or float(s.mp) > float(lead.skills[best].mp)):
			best = i
	var top_cost := 0.0
	for s in lead.skills:
		top_cost = maxf(top_cost, float(s.mp))
	if best >= 0 and (low or mp >= minf(max_mp, top_cost)):
		cast_leader_skill(best)


func _enemy_leader_ai(dt: float) -> void:
	if enemies.is_empty():
		return
	var lead := enemies[0]
	if not lead.alive():
		return
	enemy_mp = minf(enemy_max_mp, enemy_mp + MP_REGEN * enemy_mp_regen * dt)
	if not lead.can_cast():
		return
	var low := false
	for u in living(BattleUnit.ENEMY):
		if u.hp_ratio() < 0.45:
			low = true
	var best := -1
	var top_cost := 0.0
	for i in lead.skills.size():
		var s: Dictionary = lead.skills[i]
		top_cost = maxf(top_cost, float(s.mp))
		if float(s.mp) > enemy_mp or _wasted(lead, s):
			continue
		var heals := false
		for e in s.effects:
			if e.type == "heal":
				heals = true
		if low and heals:
			best = i
			break
		if not heals and (best < 0 or float(s.mp) > float(lead.skills[best].mp)):
			best = i
	if best >= 0 and (low or enemy_mp >= minf(enemy_max_mp, top_cost)):
		enemy_mp -= float(lead.skills[best].mp)
		_cast(lead, lead.skills[best], "enemy_skill")


func _emit(e: Dictionary) -> void:
	battle_event.emit(e)


func _apply_stones(u: BattleUnit, b: Dictionary) -> void:
	if b.is_empty():
		return
	u.max_hp += float(b.get("hp", 0.0))
	u.hp = u.max_hp
	u.base.atk += float(b.get("atk", 0.0))
	u.base.def += float(b.get("def", 0.0))
	u.base.rec += float(b.get("rec", 0.0))
	u.base.speed *= 1.0 + float(b.get("speed", 0.0))
	u.base.crit += float(b.get("crit", 0.0))
	u.base.crit_dmg += float(b.get("crit_dmg", 0.0))
	u.cooldown_mult *= maxf(0.3, 1.0 - float(b.get("cooldown", 0.0)))
	if u.is_leader:
		if u.side == BattleUnit.PLAYER:
			mp_regen_mult += float(b.get("mp_regen", 0.0))
		else:
			enemy_mp_regen += float(b.get("mp_regen", 0.0))
		u.extra_max_mp += float(b.get("max_mp", 0.0))


const TRAIT_INTERVALS := {"anti_heal": 6.0, "curse": 8.0, "weakness": 10.0, "healer": 10.0, "enrage": 20.0, "pierce": 9.0, "reflect": 12.0}


func _tick_traits(u: BattleUnit, dt: float) -> void:
	for id in u.traits:
		if not TRAIT_INTERVALS.has(id):
			continue
		var clock: float = u.trait_clock.get(id, 0.0) + dt
		if clock < TRAIT_INTERVALS[id]:
			u.trait_clock[id] = clock
			continue
		u.trait_clock[id] = 0.0
		var team := living(BattleUnit.PLAYER)
		match String(id):
			"anti_heal":
				for a in team:
					_apply_negative(u, a, {"type": "debuff", "stat": "rec", "pct": 0.5, "duration": 6.0})
			"curse":
				for a in team:
					_apply_negative(u, a, {"type": "debuff", "stat": "atk", "pct": 0.25, "duration": 8.0})
					_apply_negative(u, a, {"type": "debuff", "stat": "def", "pct": 0.25, "duration": 8.0})
			"weakness":
				_add_status(u, {"type": "debuff", "stat": "def", "pct": 0.6, "time": 4.0})
				_emit({"kind": "trait", "unit": u, "text": "Weakened!"})
			"healer":
				_heal(u, u, u.max_hp * 0.08 / maxf(1.0, u.stat("rec")), "trait")
				_emit({"kind": "trait", "unit": u, "text": "Heal!"})
			"enrage":
				u.base.atk *= 1.5
				_emit({"kind": "trait", "unit": u, "text": "Enraged!"})
			"pierce":
				_emit({"kind": "trait", "unit": u, "text": "Lash out!"})
				for a in team:
					_deal_damage(u, a, 2.2, "pierce")
			"reflect":
				_add_status(u, {"type": "reflect", "pct": 0.3, "time": 5.0})


func _apply_pet_stats(u: BattleUnit, pet: Dictionary) -> void:
	if pet.is_empty():
		return
	var st: Dictionary = pet.stats
	u.max_hp += float(st.get("hp", 0)) * BattleUnit.HP_SCALE
	u.hp = u.max_hp
	u.base.atk += float(st.get("atk", 0))
	u.base.def += float(st.get("def", 0))
	u.base.rec += float(st.get("rec", 0))


func _apply_pet_passives(units: Array, team: Array) -> void:
	for i in team.size():
		var pet: Dictionary = team[i].get("pet", {})
		var p: Dictionary = pet.get("passive", {})
		if p.is_empty():
			continue
		for u in units:
			if p.element != "all" and u.element != p.element:
				continue
			match String(p.stat):
				"hp":
					u.max_hp *= 1.0 + float(p.pct)
					u.hp = u.max_hp
				"crit":
					u.base.crit += float(p.pct)
				_:
					u.base[p.stat] *= 1.0 + float(p.pct)


func setup_league(team: Array, enemy_team: Array, seed_value: int = 0) -> void:
	league = true
	pvp = true
	time_limit = 120.0
	ally_total = team.size()
	enemy_total = enemy_team.size()
	ally_bench = team.slice(4)
	enemy_bench = enemy_team.slice(4)
	setup(team.slice(0, 4), [enemy_team.slice(0, 4)], seed_value)


func remaining(side: int) -> int:
	return living(side).size() + (ally_bench.size() if side == BattleUnit.PLAYER else enemy_bench.size())


func _league_reinforce() -> void:
	for side in [BattleUnit.PLAYER, BattleUnit.ENEMY]:
		var field: Array[BattleUnit] = allies if side == BattleUnit.PLAYER else enemies
		var bench: Array = ally_bench if side == BattleUnit.PLAYER else enemy_bench
		for i in field.size():
			if field[i].alive() or bench.is_empty():
				continue
			var s: Dictionary = bench.pop_front()
			var u := BattleUnit.create(side, i, s.id, int(s.level), int(s.get("boost", 0)))
			_apply_stones(u, s.get("stones", {}))
			_apply_pet_stats(u, s.get("pet", {}))
			u.support_timer = float(u.support.get("cooldown", 12.0)) * _rng.randf_range(0.3, 0.6)
			u.attack_timer = _rng.randf_range(0.3, 0.8)
			field[i] = u
			_emit({"kind": "reinforce", "unit": u, "slot": i})


func _league_timeout_result() -> String:
	var a := remaining(BattleUnit.PLAYER)
	var e := remaining(BattleUnit.ENEMY)
	if a != e:
		return "win" if a > e else "lose"
	var ha := 0.0
	var he := 0.0
	for u in living(BattleUnit.PLAYER):
		ha += u.hp_ratio()
	for u in living(BattleUnit.ENEMY):
		he += u.hp_ratio()
	return "win" if ha >= he else "lose"
