class_name GameOverPanel extends Control
## 结算面板：胜负、死亡原因、存活时间、等级、击杀。游戏暂停时仍可按 Enter 重开、Esc 回菜单。
## 联机客户端不能重开，等待主机。

signal restart_requested
signal quit_requested

var can_restart: bool = true


static func build(victory: bool, reason: String, session: GameSession, kills: int, p_can_restart: bool = true) -> GameOverPanel:
	var panel: GameOverPanel = GameOverPanel.new()
	panel.can_restart = p_can_restart
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(dim)
	var label: Label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	var t: float = session.get_game_time()
	var hint: String = "按 Enter 重新开始    Esc 返回菜单" if p_can_restart else "等待主机重新开始    Esc 返回菜单"
	label.text = "%s

%s

存活 %d:%02d    等级 %d    击杀 %d

%s" % [
		"胜利" if victory else "失败", reason, int(t / 60.0), int(t) % 60, session.get_player_level(), kills, hint]
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if victory else Color(1.0, 0.5, 0.5))
	panel.add_child(label)
	return panel


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if can_restart:
				get_viewport().set_input_as_handled()
				restart_requested.emit()
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			quit_requested.emit()
