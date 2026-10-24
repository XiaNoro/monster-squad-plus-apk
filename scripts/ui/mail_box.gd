class_name MailBox
extends RefCounted


static func open(parent: Control, on_close: Callable = Callable()) -> void:
	Mail.refresh()
	var lay := Layout.load_into(parent, "R_d_message")
	lay.root.z_index = 60
	lay.node("ID_9PATCH_2").mouse_filter = Control.MOUSE_FILTER_STOP
	lay.on("ID_btnEsc", func():
		lay.root.queue_free()
		if on_close.is_valid():
			on_close.call())
	lay.on("ID_btnOk", func(): _receive_all(parent, lay))
	_fill(parent, lay)


static func _fill(parent: Control, lay: Layout) -> void:
	var box := Mail.inbox()
	lay.text("ID_numText", str(box.size()))
	lay.text("ID_maxText", "/%d" % Mail.MAX)
	var rows := []
	for m in box:
		rows.append(_slot(parent, lay, m))
	if rows.is_empty():
		var empty := UI.label("No messages", 22, UI.BROWN)
		empty.add_theme_constant_override("outline_size", 0)
		empty.custom_minimum_size = Vector2(450, 260)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rows.append(empty)
	lay.list_into("ID_arrayPosition", rows, 2)


static func _slot(parent: Control, lay: Layout, m: Dictionary) -> Control:
	var s := Layout.instance("R_messageSlotTM" if bool(m.team) else "R_messageSlotFr")
	var msg := s.text("ID_friendstat", String(m.text))
	msg.clip_text = true
	msg.size.x = 316
	var from := s.text("ID_friendName", "%s  ·  %s" % [String(m.from), Mail.age(m)])
	from.clip_text = true
	from.size.x = 316
	from.add_theme_font_size_override("font_size", 19)
	s.show("ID_icon", false)
	var icon := Mail.icon(m.reward, Vector2(80, 80))
	s.put("ID_gift", icon)
	var row: Control = s.root
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.tooltip_text = "Receive " + Mail.text(m.reward)
	var id := int(m.id)
	row.gui_input.connect(func(e: InputEvent):
		if UI.tapped(e):
			_receive(parent, lay, id))
	return s.root


static func _receive(parent: Control, lay: Layout, id: int) -> void:
	var m := {}
	for x in Mail.inbox():
		if int(x.id) == id:
			m = x
	if m.is_empty():
		return
	if not Mail.can_claim(m):
		UI.toast(parent, "Your monster box is full", Color("ff8080"))
		return
	var r := Mail.claim(id)
	Sfx.play("buff")
	_fill(parent, lay)
	_received_popup(parent, String(m.from), r)


static func _received_popup(parent: Control, from: String, r: Dictionary) -> void:
	var p := Layout.load_into(parent, "R_d_message2")
	p.root.z_index = 61
	p.node("ID_9PATCH_2").mouse_filter = Control.MOUSE_FILTER_STOP
	var head := p.text("ID_headText", "[%s]\nsent you an item\nReceived %s" % [from, Mail.text(r)])
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var monster := r.has("monster")
	p.show("ID_monster", monster)
	p.show("ID_item", not monster)
	if monster:
		p.put("ID_imgMon", Mail.icon(r, Vector2(92, 92)))
	else:
		var img := p.node("ID_imgItem") as TextureRect
		var tex := Mail.item_texture(r)
		if tex != null:
			var box: Control = p.node("ID_item")
			var k := minf(1.0, 44.0 / tex.get_height())
			img.reparent(box, false)
			img.texture = tex
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.size = tex.get_size() * k
			img.position = Vector2((box.size.x - img.size.x) / 2.0, 5.0)
		p.text("ID_txtItem", "x%s" % Screen._thousands(Mail.count(r)))
	p.on("ID_btnOk", p.root.queue_free)


static func _receive_all(parent: Control, lay: Layout) -> void:
	if Mail.inbox().is_empty():
		UI.toast(parent, "No messages to receive")
		return
	var got := Mail.claim_all()
	_fill(parent, lay)
	if got.is_empty():
		UI.toast(parent, "Your monster box is full", Color("ff8080"))
		return
	var totals := {}
	var extras := []
	for r in got:
		for k in ["gold", "gems", "energy", "fp", "honor"]:
			if r.has(k):
				totals[k] = int(totals.get(k, 0)) + int(r[k])
		if r.has("cube") or r.has("monster"):
			extras.append(Mail.text(r))
	var parts := []
	for k in totals:
		parts.append(Mail.text({k: totals[k]}))
	Sfx.play("buff_big")
	UI.toast(parent, "Received " + ", ".join(parts + extras), UI.GOLD)
	if Mail.inbox().size() > 0:
		UI.toast(parent, "Some monsters stayed in the mail — your box is full", Color("ff8080"))
