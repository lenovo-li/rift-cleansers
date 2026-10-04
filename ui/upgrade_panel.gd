extends Control
## 升级面板 v3：卡牌式五选一，带刷新按钮
## 保持与原版相同的接口，可无缝替换

signal chosen(choice: Dictionary, index: int)
signal refresh_requested  # 联机客户端：请求主机重新抽取

var _queue: int = 0
var _choices: Array[Dictionary] = []
var _cards: Array = []
var _title: Label
var _dim: ColorRect
var _refresh_btn: Button
var roll_choices: Callable = Callable()
var pause_game: bool = true
var _remote: bool = false
var _can_refresh: int = 2  # 每次升级允许刷新的剩余次数
var _focus: int = 0  # 手柄焦点


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 半透明遮罩
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.65)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -780
	vbox.offset_right = 780
	vbox.offset_top = -400
	vbox.add_theme_constant_override("separation", 16)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	# 标题行（标题 + 刷新按钮）
	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_row)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 42)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_title.add_theme_constant_override("outline_size", 7)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(_title)

	# 刷新按钮
	_refresh_btn = Button.new()
	_refresh_btn.text = "🔄 刷新"
	_refresh_btn.custom_minimum_size = Vector2(120, 48)
	_refresh_btn.add_theme_font_size_override("font_size", 24)
	_refresh_btn.set_meta("no_auto_sound", true)  # 自己处理音效
	_refresh_btn.pressed.connect(_on_refresh)
	title_row.add_child(_refresh_btn)

	# 卡牌网格容器（两行五列）
	var cards_grid: VBoxContainer = VBoxContainer.new()
	cards_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_grid.add_theme_constant_override("separation", 15)
	cards_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(cards_grid)

	# 上排5张卡牌
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 15)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards_grid.add_child(top_row)

	for i in 5:
		var card: Control = load("res://ui/upgrade_card.gd").new()
		card.clicked.connect(_pick.bind(i))
		card.pivot_offset = Vector2(140, 180)
		top_row.add_child(card)
		_cards.append(card)

	# 下排5张卡牌
	var bottom_row: HBoxContainer = HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 15)
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards_grid.add_child(bottom_row)

	for i in 5:
		var card: Control = load("res://ui/upgrade_card.gd").new()
		card.clicked.connect(_pick.bind(i + 5))
		card.pivot_offset = Vector2(140, 180)
		bottom_row.add_child(card)
		_cards.append(card)

	visible = false


func request() -> void:
	_queue += 1
	if not visible:
		_open()
	else:
		_update_title()


func is_open() -> bool:
	return visible


func _open() -> void:
	if not roll_choices.is_valid():
		_queue = 0
		return
	_remote = false
	_can_refresh = UpgradeSystem.REFRESH_COUNT  # 每次升级重置刷新次数
	_display(roll_choices.call())


func show_remote(choices: Array, remaining: int, can_refresh_count: int = 0) -> void:
	_remote = true
	_queue = remaining
	_can_refresh = can_refresh_count
	_display(choices)


func _display(choices: Array) -> void:
	_choices.clear()
	for c: Variant in choices:
		_choices.append(c)

	_update_title()
	_refresh_btn.disabled = (_can_refresh <= 0)
	_refresh_btn.visible = true
	_set_focus(0)

	# 设置卡牌内容，隐藏多余卡牌
	for i in _cards.size():
		if i < _choices.size():
			_cards[i].set_choice(_choices[i], i)
			_cards[i].visible = true
		else:
			_cards[i].visible = false

	if not visible:  # 刷新选项也会走这里，只在真正打开面板时播
		SfxManager.play(self, "ui_open")
	visible = true
	_dim.color.a = 0.65 if pause_game else 0.25

	# 卡牌入场动画
	for i in mini(_choices.size(), _cards.size()):
		var card: Control = _cards[i] as Control
		card.modulate.a = 0.0
		card.scale = Vector2(0.7, 0.7)
		var tw: Tween = card.create_tween()
		tw.set_ease(Tween.EASE_OUT)
		tw.set_trans(Tween.TRANS_BACK)
		tw.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(i * 0.06)
		tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.35).set_delay(i * 0.06)

	if pause_game:
		get_tree().paused = true


func close() -> void:
	if visible:
		SfxManager.play(self, "ui_close")
	visible = false
	_queue = 0
	if pause_game:
		get_tree().paused = false


func _update_title() -> void:
	var pad: bool = Settings.pad_connected()
	var keys: String = "十字键移动 + A" if pad else "1-9, 0"
	var queue_text: String = ("   还有 %d 次" % (_queue - 1)) if _queue > 1 else ""
	var refresh_text: String = (" (还可刷新 %d 次)" % _can_refresh) if _can_refresh > 0 else ""
	_title.text = "✦ 升级！选择一项 (%s) ✦%s%s" % [keys, queue_text, refresh_text]
	_refresh_btn.text = "刷新 (%s)" % ("Y" if pad else "R")
	_refresh_btn.disabled = (_can_refresh <= 0)


## 刷新：换一批选项，每次升级可刷新多次。联机客户端交给主机重新抽取。
func _on_refresh() -> void:
	if not visible or _can_refresh <= 0:
		return
	_can_refresh -= 1
	SfxManager.play(self, "ui_click")
	if _remote:
		_refresh_btn.disabled = true
		refresh_requested.emit()
	elif roll_choices.is_valid():
		_display(roll_choices.call())


func _pick(index: int) -> void:
	if not visible or index >= _choices.size():
		return

	var c: Dictionary = _choices[index]
	_queue -= 1
	visible = false
	SfxManager.play(self, "ui_click")
	if pause_game:
		get_tree().paused = false

	chosen.emit(c, index)

	if _queue > 0 and not _remote:
		_open()


func _set_focus(index: int) -> void:
	var prev: int = _focus
	_focus = clampi(index, 0, maxi(0, _choices.size() - 1))
	if visible and _focus != prev:  # 十字键 / 方向键切换选中卡片
		SfxManager.play(self, "ui_hover")
	for i in _cards.size():
		_cards[i].set_highlight(i == _focus)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return

	# 手柄：十字键/摇杆移动焦点（上下左右），A 确认，Y 刷新
	var jb: InputEventJoypadButton = event as InputEventJoypadButton
	if jb != null:
		match jb.button_index:
			JOY_BUTTON_DPAD_LEFT: _set_focus(_focus - 1)
			JOY_BUTTON_DPAD_RIGHT: _set_focus(_focus + 1)
			JOY_BUTTON_DPAD_UP: _set_focus(_focus - 5)  # 上排
			JOY_BUTTON_DPAD_DOWN: _set_focus(_focus + 5)  # 下排
			JOY_BUTTON_A: _pick(_focus)
			JOY_BUTTON_Y: _on_refresh()
			_: return
		get_viewport().set_input_as_handled()
		return

	if not (event is InputEventKey):
		return

	var k: Key = (event as InputEventKey).keycode
	# 1-9 键对应前 9 张卡，0 键对应第 10 张
	if k >= KEY_1 and k <= KEY_9:
		_pick(int(k - KEY_1))
		get_viewport().set_input_as_handled()
	elif k == KEY_0:
		_pick(9)  # 第 10 张卡
		get_viewport().set_input_as_handled()
	elif k == KEY_R:
		_on_refresh()
		get_viewport().set_input_as_handled()
