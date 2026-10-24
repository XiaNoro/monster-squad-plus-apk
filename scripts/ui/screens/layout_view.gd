extends Screen


func build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("2a3a2a")
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	for xml in String(args.get("xml", "R_main")).split("+"):
		Layout.load_into(self, xml)
