extends Control
## 升级面板 v2：卡牌式三选一，带动画效果
## 保持与原版相同的接口，可无缝替换

signal chosen(choice: Dictionary, index: int)

var _queue: int = 0
var _choices: Array[Dictionary] = []
var _cards: Array = []
var _title: Label
var _dim: ColorRect
var roll_choices: Callable = Callable()
var pause_game: bool = true
var _remote: bool = false


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
	vbox.offset_left = -500
	vbox.offset_right = 500
	vbox.offset_top = -320
	vbox.add_theme_constant_override("separation", 24)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	# 标题
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 42)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_title.add_theme_constant_override("outline_size", 7)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_title)

	# 卡牌横排容器
	var cards_container: HBoxContainer = HBoxContainer.new()
	cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_container.add_theme_constant_override("separation", 32)
	cards_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(cards_container)

	# 创建三张卡牌
	for i in 3:
		var card: Control = load("res://ui/upgrade_card.gd").new()
		card.clicked.connect(_pick.bind(i))
		# 设置缩放中心点
		card.pivot_offset = Vector2(140, 180)  # CARD_WIDTH/2, CARD_HEIGHT/2
		cards_container.add_child(card)
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
	_display(roll_choices.call())


func show_remote(choices: Array, remaining: int) -> void:
	_remote = true
	_queue = remaining
	_display(choices)


func _display(choices: Array) -> void:
	_choices.clear()
	for c: Variant in choices:
		_choices.append(c)

	_update_title()

	# 设置卡牌内容
	for i in mini(_choices.size(), _cards.size()):
		_cards[i].set_choice(_choices[i], i)

	visible = true
	_dim.color.a = 0.65 if pause_game else 0.25

	# 卡牌入场动画
	for i in _cards.size():
		var card: Control = _cards[i] as Control
		card.modulate.a = 0.0
		card.scale = Vector2(0.7, 0.7)
		var tw: Tween = card.create_tween()
		tw.set_ease(Tween.EASE_OUT)
		tw.set_trans(Tween.TRANS_BACK)
		tw.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(i * 0.08)
		tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.35).set_delay(i * 0.08)

	if pause_game:
		get_tree().paused = true


func close() -> void:
	visible = false
	_queue = 0
	if pause_game:
		get_tree().paused = false


func _update_title() -> void:
	var keys: String = "十字键 ←/↑/→" if Settings.pad_connected() else "1/2/3"
	var queue_text: String = ("   还有 %d 次" % (_queue - 1)) if _queue > 1 else ""
	_title.text = "✦ 升级！选择一项 (%s) ✦%s" % [keys, queue_text]


func _pick(index: int) -> void:
	if not visible or index >= _choices.size():
		return

	var c: Dictionary = _choices[index]
	_queue -= 1
	visible = false
	if pause_game:
		get_tree().paused = false

	chosen.emit(c, index)

	if _queue > 0 and not _remote:
		_open()


# 键盘/手柄快捷键
const PAD_PICKS: Dictionary = {JOY_BUTTON_DPAD_LEFT: 0, JOY_BUTTON_DPAD_UP: 1, JOY_BUTTON_DPAD_RIGHT: 2}


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return

	if event is InputEventJoypadButton and PAD_PICKS.has((event as InputEventJoypadButton).button_index):
		_pick(PAD_PICKS[(event as InputEventJoypadButton).button_index])
		get_viewport().set_input_as_handled()
		return

	if not (event is InputEventKey):
		return

	var k: Key = (event as InputEventKey).keycode
	if k >= KEY_1 and k <= KEY_3:
		_pick(int(k - KEY_1))
		get_viewport().set_input_as_handled()
