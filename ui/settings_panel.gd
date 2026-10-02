class_name SettingsPanel extends Control
## 设置浮层（主菜单和游戏内暂停菜单共用）：音量（总 / 音乐 / 音效）、伤害数字、震屏、改键。
## 改动立即生效；关闭时写存档并发出 closed。游戏暂停时也能操作（PROCESS_MODE_ALWAYS）。

signal closed

var _rows: VBoxContainer
var _waiting: String = ""  # 正在等待新按键的动作
var _key_buttons: Dictionary = {}  # 动作 -> Button
var _hint: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box: VBoxContainer = VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -330
	box.offset_right = 330
	box.offset_top = -340
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var title: Label = Label.new()
	title.text = "设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(660, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	box.add_child(_hint)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var reset: Button = Button.new()
	reset.text = "恢复默认"
	reset.custom_minimum_size = Vector2(150, 40)
	reset.pressed.connect(func() -> void:
		Settings.reset_to_defaults()
		_build_rows())
	buttons.add_child(reset)
	var close_btn: Button = Button.new()
	close_btn.text = "返回"
	close_btn.custom_minimum_size = Vector2(150, 40)
	close_btn.pressed.connect(_close)
	buttons.add_child(close_btn)
	_build_rows()
	close_btn.grab_focus.call_deferred()


func _build_rows() -> void:
	for c: Node in _rows.get_children():
		c.queue_free()
	_key_buttons.clear()
	_waiting = ""
	_hint.text = "点击按键后按下新键；Esc 取消。与其他动作冲突时会互换。\n" + \
			"按住鼠标左键或右键：角色朝向和技能方向跟随鼠标。T 键可在游戏中切换自动施放。\n" + \
		"手柄（固定）：左摇杆移动  A 闪避  X/Y/B/LB/RB/RT 技能  Back 自动施放  Start 菜单"
	_slider("总音量", "master")
	_slider("音乐", "music")
	_slider("音效", "sfx")
	_toggle("伤害数字", "damage_numbers")
	_toggle("震屏", "screen_shake")
	_toggle("自动施放技能", "auto_cast")
	_option("画质", "quality", Settings.QUALITY_NAMES, [0, 1, 2])
	_toggle("全屏", "fullscreen")
	_toggle("垂直同步", "vsync")
	var fps_names: Array[String] = []
	for cap: int in Settings.FPS_CAPS:
		fps_names.append("不限" if cap == 0 else str(cap))
	_option("帧率上限", "max_fps", fps_names, Settings.FPS_CAPS)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	_rows.add_child(grid)
	for action: String in Settings.ACTIONS:
		var label: Label = Label.new()
		label.text = Settings.ACTION_NAMES[action]
		label.custom_minimum_size.x = 130
		label.add_theme_font_size_override("font_size", 16)
		grid.add_child(label)
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(170, 32)
		btn.text = Settings.key_name(Settings.key_of(action))
		btn.pressed.connect(_start_rebind.bind(action))
		grid.add_child(btn)
		_key_buttons[action] = btn


func _row(text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_rows.add_child(row)
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size.x = 130
	label.add_theme_font_size_override("font_size", 18)
	row.add_child(label)
	return row


func _slider(text: String, key: String) -> void:
	var row: HBoxContainer = _row(text)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(Settings.get_value(key))
	slider.custom_minimum_size = Vector2(360, 28)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var pct: Label = Label.new()
	pct.custom_minimum_size.x = 60
	pct.text = "%d%%" % roundi(slider.value * 100.0)
	row.add_child(pct)
	slider.value_changed.connect(func(v: float) -> void:
		Settings.set_value(key, v)
		pct.text = "%d%%" % roundi(v * 100.0)
		if key == "sfx":
			SfxManager.play(self, "pickup"))  # 调音效时试听


func _toggle(text: String, key: String) -> void:
	var row: HBoxContainer = _row(text)
	var box: CheckButton = CheckButton.new()
	box.button_pressed = bool(Settings.get_value(key))
	box.text = "开" if box.button_pressed else "关"
	box.toggled.connect(func(on: bool) -> void:
		Settings.set_value(key, on)
		box.text = "开" if on else "关")
	row.add_child(box)


## 下拉选项：names 为显示文字，values 为存进设置的值（顺序一一对应）。
func _option(text: String, key: String, names: Array, values: Array) -> void:
	var row: HBoxContainer = _row(text)
	var opt: OptionButton = OptionButton.new()
	opt.custom_minimum_size = Vector2(170, 32)
	for n: String in names:
		opt.add_item(n)
	opt.selected = maxi(0, values.find(int(Settings.get_value(key))))
	opt.item_selected.connect(func(i: int) -> void: Settings.set_value(key, values[i]))
	row.add_child(opt)


func _start_rebind(action: String) -> void:
	_waiting = action
	(_key_buttons[action] as Button).text = "按下新键…"
	_hint.text = "为「%s」按下新键（Esc 取消）" % Settings.ACTION_NAMES[action]


func _input(event: InputEvent) -> void:
	# 用 _input 抢在游戏和其他面板之前拿到按键
	if event is InputEventJoypadButton and event.pressed and _waiting.is_empty() \
			and (event as InputEventJoypadButton).button_index in [JOY_BUTTON_B, JOY_BUTTON_START]:
		get_viewport().set_input_as_handled()
		_close()  # 手柄 B / Start 关闭（改键只针对键盘，手柄键位固定）
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: InputEventKey = event as InputEventKey
	get_viewport().set_input_as_handled()
	if _waiting.is_empty():
		if key.physical_keycode == KEY_ESCAPE or key.keycode == KEY_ESCAPE:
			_close()
		return
	var action: String = _waiting
	_waiting = ""
	if key.physical_keycode == KEY_ESCAPE and action != "pause":
		(_key_buttons[action] as Button).text = Settings.key_name(Settings.key_of(action))
		_hint.text = "已取消"
		return
	var code: int = int(key.physical_keycode) if key.physical_keycode != 0 else int(key.keycode)
	var swapped: String = Settings.bind(action, code)
	for a: String in _key_buttons:
		(_key_buttons[a] as Button).text = Settings.key_name(Settings.key_of(a))
	_hint.text = "「%s」= %s%s" % [Settings.ACTION_NAMES[action], Settings.key_name(code),
			"（与「%s」互换）" % Settings.ACTION_NAMES[swapped] if not swapped.is_empty() else ""]


func _close() -> void:
	Settings.save()
	closed.emit()
	queue_free()
