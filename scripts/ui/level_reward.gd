class_name LevelReward
extends RefCounted

const GEMS := {1: 3, 2: 3, 3: 3, 4: 5, 5: 10, 6: 15}
const SKIP_SCREENS := ["title", "battle", "starter", "layout"]


static func gems_for(id: String) -> int:
	return int(GEMS.get(int(DB.monster(id).get("stars", 1)), 1))


static func reached(m: Dictionary) -> void:
	var gems := roundi(gems_for(String(m.id)) * Events.effect("lv30_gems"))
	Mail.send(Mail.TEAM, {"gems": gems}, "%s reached Lv. 30! Here is your Level Up Reward." % DB.monster(m.id).get("name", m.id), true)
	var pending: Array = Save.data.get("lv30_pending", [])
	pending.append(String(m.id))
	Save.data["lv30_pending"] = pending


static func show_pending(screen: Screen, name: String) -> void:
	if name in SKIP_SCREENS or not is_instance_valid(screen) or screen.tutorial_active():
		return
	var pending: Array = Save.data.get("lv30_pending", [])
	if pending.is_empty():
		return
	var id := String(pending.pop_front())
	Save.save_game()
	var d := Layout.load_into(screen, "R_d_maxLevel")
	d.root.z_index = 90
	d.node("ID_9PATCH_2").mouse_filter = Control.MOUSE_FILTER_STOP
	var def := DB.monster(id)
	d.text("ID_monName", String(def.get("name", id)))
	var att: Control = d.node("ID_mon1att")
	if att is TextureRect:
		(att as TextureRect).texture = UI.element_icon(String(def.get("element", "")))
	var card_box: Control = d.node("ID_ev1")
	for c in card_box.get_children():
		c.visible = false
	var card := UI.monster_card(id, 0, 0, card_box.size)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_box.add_child(card)
	d.text("ID_baseText", "Congratulations on reaching Lv. %d!\nCheck Level Up Reward in Mailbox." % DB.MAX_LEVEL)
	Sfx.play("buff_big")
	d.on("ID_btnOk", func():
		d.root.queue_free()
		show_pending(screen, name))
	d.sound(["ID_btnOk"], "ok")
