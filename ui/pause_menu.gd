class_name PauseMenu extends Control
## 游戏内暂停菜单（Esc / 设置里的「暂停」键）：继续、设置、返回主菜单。
## 单人时暂停整个游戏；联机时不暂停（其他人还在玩），只盖一层菜单。

signal resume_requested
signal quit_requested
signal invite_requested

var pauses_game: bool = true
## P2P 房主：显示「邀请好友」。
var show_invite: bool = false
var _settings: SettingsPanel = null


static func build(p_pauses_game: bool) -> PauseMenu:
	var menu: PauseMenu = PauseMenu.new()
	menu.pauses_game = p_pauses_game
	return menu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box: VBoxContainer = VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -160
	box.offset_right = 160
	box.offset_top = -150
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	var title: Label = Label.new()
	title.text = "暂停" if pauses_game else "菜单（联机中，游戏继续）"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36 if pauses_game else 24)
	box.add_child(title)
	_button(box, "继续", func() -> void: resume_requested.emit())
	if show_invite:
		_button(box, "邀请好友（P2P）", func() -> void: invite_requested.emit())
	_button(box, "设置", _open_settings)
	_button(box, "返回主菜单", func() -> void: quit_requested.emit())


func _button(parent: Node, text: String, cb: Callable) -> void:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 48)
	b.pressed.connect(cb)
	parent.add_child(b)


func _open_settings() -> void:
	visible = false
	_settings = SettingsPanel.new()
	_settings.closed.connect(func() -> void:
		_settings = null
		visible = true)
	add_child(_settings)


func _unhandled_input(event: InputEvent) -> void:
	if _settings != null:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()
