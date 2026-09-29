extends Control
## 升级三选一面板：打开时暂停游戏，鼠标点击或按 1/2/3 选择。连续升级会排队依次弹出。

signal chosen(choice: Dictionary)

var _queue: int = 0
var _choices: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _title: Label
## 由游戏场景注入：返回三个选项的回调。
var roll_choices: Callable = Callable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
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
	_choices = roll_choices.call()
	_update_title()
	for i in _buttons.size():
		var c: Dictionary = _choices[i]
		_buttons[i].text = "%d. %s\n%s" % [i + 1, c.title, c.desc]
	visible = true
	get_tree().paused = true
	_buttons[0].grab_focus()


func _update_title() -> void:
	_title.text = "升级！选择一项（1/2/3）" + ("   还有 %d 次" % (_queue - 1) if _queue > 1 else "")


func _pick(index: int) -> void:
	if not visible or index >= _choices.size():
		return
	var c: Dictionary = _choices[index]
	_queue -= 1
	visible = false
	get_tree().paused = false
	chosen.emit(c)
	if _queue > 0:
		_open()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: Key = (event as InputEventKey).keycode
	if k >= KEY_1 and k <= KEY_3:
		_pick(int(k - KEY_1))
		get_viewport().set_input_as_handled()
