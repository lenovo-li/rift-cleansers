class_name AchievementsPanel extends Control
## 成就浮层（主菜单）：已解锁的显示日期，未解锁的置灰。Esc / 手柄 B 关闭。


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.05, 0.98)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box: VBoxContainer = VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -420
	box.offset_right = 420
	box.offset_top = -440
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var done: Dictionary = Achievements.unlocked()
	var title: Label = Label.new()
	title.text = "成就  %d / %d" % [done.size(), Achievements.LIST.size()]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for a: Array in Achievements.LIST:
		var got: bool = done.has(a[0])
		var label: Label = Label.new()
		label.custom_minimum_size.x = 400
		label.text = "%s %s%s\n    %s" % ["★" if got else "☆", a[1], "  （%s）" % done[a[0]] if got else "", a[2]]
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35) if got else Color(0.55, 0.55, 0.6))
		grid.add_child(label)
	var back: Button = Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(180, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(queue_free)
	box.add_child(back)
	back.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()