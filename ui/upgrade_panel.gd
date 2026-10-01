extends Control
## 升级三选一面板：鼠标点击或按 1/2/3 选择。连续升级会排队依次弹出。
## 单人时暂停游戏；联机时不暂停（pause_game = false），客户端的选项由主机发来（show_remote）。

signal chosen(choice: Dictionary, index: int)

var _queue: int = 0
var _choices: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _title: Label
var _dim: ColorRect
## 由游戏场景注入：返回三个选项的回调。
var roll_choices: Callable = Callable()
var pause_game: bool = true
var _remote: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	var box: VBoxContainer = VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -300
	box.offset_right = 300
	box.offset_top = -220
	box.custom_minimum_size = Vector2(600, 0)
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 34)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	for i in UpgradeSystem.CHOICE_COUNT:
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(600, 96)
		b.add_theme_font_size_override("font_size", 22)
		b.focus_mode = Control.FOCUS_NONE  # 联机不暂停时，空格（盾击）不能误触按钮
		b.pressed.connect(_pick.bind(i))
		box.add_child(b)
		_buttons.append(b)
	visible = false


## 升级一次：排队，未打开时立刻打开。
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


## 联机客户端：显示主机发来的选项（remaining 为包括本次在内的待选次数）。
func show_remote(choices: Array, remaining: int) -> void:
	_remote = true
	_queue = remaining
	_display(choices)


func _display(choices: Array) -> void:
	_choices.clear()
	for c: Variant in choices:
		_choices.append(c)
	_update_title()
	for i in _buttons.size():
		var c: Dictionary = _choices[i]
		_buttons[i].text = "%d. %s\n%s" % [i + 1, c.title, c.desc]
	visible = true
	_dim.color.a = 0.55 if pause_game else 0.15  # 联机不暂停，不要挡住战场
	if pause_game:
		get_tree().paused = true


func close() -> void:
	visible = false
	_queue = 0
	if pause_game:
		get_tree().paused = false


func _update_title() -> void:
	var keys: String = "十字键 ←/↑/→" if Settings.pad_connected() else "1/2/3"
	_title.text = "升级！选择一项（%s）" % keys + ("   还有 %d 次" % (_queue - 1) if _queue > 1 else "")


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
		_open()  # 远程模式下一组选项由主机再发


## 手柄：十字键左 / 上 / 右 选第 1 / 2 / 3 项（十字键在升级时不会误触技能；联机不暂停时角色会顺带走一步）。
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
