extends Control
## 主菜单：单人 / 创建房间 / 加入房间（局域网 IP）。命令行带 --host / --join= 时直接进入游戏。

const GAME_SCENE: String = "res://scenes/game_scene.tscn"

var _name_edit: LineEdit
var _char_buttons: Array[Button] = []
var _map_buttons: Array[Button] = []
var _desc: Label
var _addr_edit: LineEdit
var _port_edit: LineEdit
var _status: Label
var _single_btn: Button


func _ready() -> void:
	CrashReporter.install(get_tree())
	UiTheme.install(get_tree())
	Settings.apply()
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
	box.offset_left = -320
	box.offset_right = 320
	box.offset_top = -420
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title: Label = Label.new()
	title.text = "裂界清扫者"
	title.add_theme_font_size_override("font_size", 48)  # 像素字体取 12 的倍数最清晰
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
		btn.custom_minimum_size = Vector2(110, 40)
		btn.pressed.connect(_on_char_select.bind(id))
		char_row.add_child(btn)
		_char_buttons.append(btn)
	var map_row: HBoxContainer = HBoxContainer.new()
	map_row.add_theme_constant_override("separation", 8)
	box.add_child(map_row)
	var map_label: Label = Label.new()
	map_label.text = "地图"
	map_label.custom_minimum_size.x = 80
	map_row.add_child(map_label)
	for id: String in MapCatalog.ids():
		var btn: Button = Button.new()
		btn.text = MapCatalog.get_def(id).name
		btn.custom_minimum_size = Vector2(110, 40)
		btn.tooltip_text = MapCatalog.get_def(id).desc
		btn.pressed.connect(_on_map_select.bind(id))
		map_row.add_child(btn)
		_map_buttons.append(btn)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_font_size_override("font_size", 16)
	box.add_child(_desc)
	_update_char_buttons()
	_single_btn = _button(box, "单人游戏", _on_single)
	var p2p_row: HBoxContainer = HBoxContainer.new()
	p2p_row.add_theme_constant_override("separation", 12)
	box.add_child(p2p_row)
	_button(p2p_row, "P2P 创建房间", _on_p2p_host).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(p2p_row, "P2P 加入房间", _on_p2p_join).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_port_edit = _field(box, "端口", str(NetConfig.DEFAULT_PORT))
	_button(box, "局域网创建房间", _on_host)
	_addr_edit = _field(box, "主机 IP", NetConfig.address)
	_button(box, "局域网加入房间", _on_join)
	var extra_row: HBoxContainer = HBoxContainer.new()
	extra_row.add_theme_constant_override("separation", 8)
	box.add_child(extra_row)
	for pair: Array in [["天赋树", func() -> void: add_child(TalentPanel.build(NetConfig.character_id))],
			["排行榜", _show_leaderboard],
			["成就", func() -> void: add_child(AchievementsPanel.new())],
			["设置", func() -> void: add_child(SettingsPanel.new())],
			["关于", func() -> void: add_child(LicensesPanel.new())]]:
		var b: Button = _button(extra_row, pair[0], pair[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 18)
	_button(box, "退出", func() -> void: get_tree().quit())
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.text = "P2P：不在同一个网络也能联机，双方互发一次连接码即可（加密直连，不经过服务器）\n" + \
			"局域网：主机需要放行 UDP 端口；无加密与鉴权，只在可信网络使用"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	_single_btn.grab_focus.call_deferred()  # 手柄：十字键 / 摇杆移动焦点，A 确认
	if not CrashReporter.pending_report.is_empty():
		_show_crash_notice(CrashReporter.pending_report)
		CrashReporter.pending_report = ""


## 上次异常退出：提示日志位置，可直接打开文件夹（日志只在本机，不上传）。
func _show_crash_notice(report: String) -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "上次游戏异常退出"
	dialog.dialog_text = "已把上次的日志保存到：\n%s\n\n反馈问题时可以附上这个文件。日志只保存在本机，不会上传。" % \
			ProjectSettings.globalize_path(report)
	dialog.ok_button_text = "打开文件夹"
	dialog.cancel_button_text = "知道了"
	dialog.confirmed.connect(func() -> void: OS.shell_open(CrashReporter.report_dir_global()))
	add_child(dialog)
	dialog.popup_centered()


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


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _read_common() -> void:
	_update_char_buttons()
	NetConfig.player_name = _name_edit.text.strip_edges().left(16) if not _name_edit.text.strip_edges().is_empty() else "玩家"
	NetConfig.port = clampi(int(_port_edit.text), 1024, 65535) if _port_edit.text.is_valid_int() else NetConfig.DEFAULT_PORT
	if NetConfig.reconnect_token.is_empty():
		NetConfig.reconnect_token = NetConfig.generate_token()


func _on_char_select(id: String) -> void:
	NetConfig.character_id = id
	_update_char_buttons()


func _on_map_select(id: String) -> void:
	NetConfig.map_id = id
	_update_char_buttons()


## 已选的角色/地图按钮置灰，下方显示两者说明。
func _update_char_buttons() -> void:
	for i in _char_buttons.size():
		_char_buttons[i].disabled = (CharacterCatalog.ids()[i] == NetConfig.character_id)
	for i in _map_buttons.size():
		_map_buttons[i].disabled = (MapCatalog.ids()[i] == NetConfig.map_id)
	if _desc != null:
		_desc.text = "%s\n%s：%s" % [CharacterCatalog.get_def(NetConfig.character_id).desc,
				MapCatalog.get_def(NetConfig.map_id).name, MapCatalog.get_def(NetConfig.map_id).desc]


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


## P2P 房主：直接进游戏，游戏里弹出邀请面板（暂停中）。
func _on_p2p_host() -> void:
	_read_common()
	NetConfig.mode = NetConfig.Mode.HOST
	NetConfig.p2p = true
	_start()


## P2P 好友：先在菜单里交换连接码，连上房主后再进游戏。
func _on_p2p_join() -> void:
	_read_common()
	var panel: P2PPanel = P2PPanel.build(false)
	panel.joined.connect(func() -> void:
		NetConfig.mode = NetConfig.Mode.CLIENT
		NetConfig.p2p = true
		_start())
	add_child(panel)


## 排行榜浮层：前 10 局 + 累计统计，点击任意处关闭。
func _show_leaderboard() -> void:
	var overlay: Button = Button.new()
	overlay.flat = true
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	var label: Label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.text = leaderboard_text()
	overlay.add_child(label)
	overlay.pressed.connect(overlay.queue_free)
	add_child(overlay)


static func leaderboard_text() -> String:
	var d: Dictionary = SaveData.data()
	var lines: PackedStringArray = ["本地排行榜", ""]
	var board: Array = SaveData.leaderboard()
	if board.is_empty():
		lines.append("还没有记录，去打一局吧")
	for i in board.size():
		var e: Dictionary = board[i]
		lines.append("%2d. %6d 分  %s  %s  %s  %d:%02d  Lv%d  击杀 %d  %s" % [i + 1, e.score,
			CharacterCatalog.get_def(e.char).name, MapCatalog.get_def(e.map).name, "胜" if e.victory else "负",
			int(e.time) / 60, int(e.time) % 60, e.level, e.kills, e.date])
	lines.append("")
	lines.append("总局数 %d   胜利 %d   累计击杀 %d   天赋碎片 %d" % [d.runs, d.wins, d.total_kills, d.shards])
	lines.append("")
	lines.append("点击任意处返回")
	return "\n".join(lines)


func _start() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
