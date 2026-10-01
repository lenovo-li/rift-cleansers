class_name GameOverPanel extends Control
## 结算面板：胜负、死亡原因、存活时间、等级、击杀。游戏暂停时仍可按 Enter 重开、Esc 回菜单。
## 联机客户端不能重开，等待主机。

signal restart_requested
signal quit_requested

var can_restart: bool = true


## record：SaveData.record_run 的返回值（空 = 本局未记录，例如测试）。
static func build(victory: bool, reason: String, session: GameSession, kills: int, p_can_restart: bool = true,
		record: Dictionary = {}) -> GameOverPanel:
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
	var pad: bool = Settings.pad_connected()
	var hint: String = ("按 %s 重新开始    " % ("A" if pad else "Enter") if p_can_restart else "等待主机重新开始    ") + \
			"%s 返回菜单" % ("B" if pad else "Esc")
	var saved: String = ""
	if not record.is_empty():
		saved = "得分 %d%s    天赋碎片 +%d（共 %d）\n\n" % [record.score,
				"    本地排行第 %d 名" % record.rank if int(record.rank) > 0 else "", record.shards, SaveData.shards()]
		var names: PackedStringArray = []
		for id: String in record.get("achievements", []):
			names.append(Achievements.name_of(id))
		if not names.is_empty():
			saved += "新成就：%s\n\n" % "、".join(names)
	label.text = "%s

%s

存活 %d:%02d    等级 %d    击杀 %d

%s%s" % [
		"胜利" if victory else "失败", reason, int(t / 60.0), int(t) % 60, session.get_player_level(), kills, saved, hint]
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if victory else Color(1.0, 0.5, 0.5))
	panel.add_child(label)
	return panel


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_A:  # 手柄 A = Enter，B / Start = Esc
				if can_restart:
					get_viewport().set_input_as_handled()
					restart_requested.emit()
			JOY_BUTTON_B, JOY_BUTTON_START:
				get_viewport().set_input_as_handled()
				quit_requested.emit()
		return
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
