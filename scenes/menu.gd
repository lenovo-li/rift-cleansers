extends Control
## 主菜单：单人 / 创建房间 / 加入房间（局域网 IP）。命令行带 --host / --join= 时直接进入游戏。

const GAME_SCENE: String = "res://scenes/game_scene.tscn"

var _name_edit: LineEdit
var _char_buttons: Array[Button] = []
var _addr_edit: LineEdit
var _port_edit: LineEdit
var _status: Label


func _ready() -> void:
	if NetConfig.parse_cmdline():
		_start.call_deferred()
		return
	NetConfig.reset()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box: VBoxContainer = VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -260
	box.offset_right = 260
	box.offset_top = -280
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var title: Label = Label.new()
	title.text = "裂界清扫者"
	title.add_theme_font_size_override("font_size", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_name_edit = _field(box, "名字", NetConfig.player_name)
	var char_row: HBoxContainer = HBoxContainer.new()
	char_row.add_theme_constant_override("separation", 8)
	box.add_child(char_row)
	var char_label: Label = Label.new()
	char_label.text = "角色"
	char_label.custom_minimum_size.x = 80
	char_row.add_child(char_label)
	for id: String in CharacterCatalog.ids():
		var btn: Button = Button.new()
		btn.text = CharacterCatalog.get_def(id).name
		btn.custom_minimum_size = Vector2(140, 40)
		btn.pressed.connect(_on_char_select.bind(id))
		char_row.add_child(btn)
		_char_buttons.append(btn)
	_button(box, "单人游戏", _on_single)
	_port_edit = _field(box, "端口", str(NetConfig.DEFAULT_PORT))
	_button(box, "创建房间（主机）", _on_host)
	_addr_edit = _field(box, "主机 IP", NetConfig.address)
	_button(box, "加入房间", _on_join)
	_button(box, "退出", func() -> void: get_tree().quit())
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.text = "局域网联机原型：主机需要放行 UDP 端口；无加密与鉴权，只在可信网络使用"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)


func _field(parent: Node, label: String, value: String) -> LineEdit:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var l: Label = Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(90, 0)
	row.add_child(l)
	var e: LineEdit = LineEdit.new()
	e.text = value
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(e)
	return e


func _button(parent: Node, text: String, cb: Callable) -> void:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	parent.add_child(b)


func _read_common() -> void:
	_update_char_buttons()
	NetConfig.player_name = _name_edit.text.strip_edges().left(16) if not _name_edit.text.strip_edges().is_empty() else "玩家"
	NetConfig.port = clampi(int(_port_edit.text), 1024, 65535) if _port_edit.text.is_valid_int() else NetConfig.DEFAULT_PORT
	if NetConfig.reconnect_token.is_empty():
		NetConfig.reconnect_token = NetConfig.generate_token()


func _on_char_select(id: String) -> void:
	NetConfig.character_id = id
	_update_char_buttons()


func _update_char_buttons() -> void:
	for i in _char_buttons.size():
		var btn: Button = _char_buttons[i]
		var id: String = CharacterCatalog.ids()[i]
		btn.disabled = (id == NetConfig.character_id)


func _on_single() -> void:
	NetConfig.reset()
	_start()


func _on_host() -> void:
	_read_common()
	NetConfig.mode = NetConfig.Mode.HOST
	_start()


func _on_join() -> void:
	_read_common()
	NetConfig.mode = NetConfig.Mode.CLIENT
	NetConfig.address = _addr_edit.text.strip_edges()
	_start()


func _start() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
