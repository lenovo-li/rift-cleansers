extends RefCounted
## 发布相关：许可证页面内容、设置字段（画质 / 帧率）读回类型、崩溃日志的旧日志查找。


func test_license_text_lists_everything() -> String:
	var text: String = LicensesPanel.build_text()
	for needle: String in ["Godot Engine", "Permission is hereby granted", "Fusion Pixel", "Kenney",
			"webrtc-native", "Mozilla Public License"]:
		if not text.contains(needle):
			return "许可证页面缺少：%s" % needle
	return ""


func test_yaml_field_parser() -> String:
	var f: Dictionary = LicensesPanel.parse_yaml_fields("asset_name: A\nlicense: CC0\nused_in:\n  - x: y\nnotes: |\n  long")
	if f.get("asset_name") != "A" or f.get("license") != "CC0":
		return "顶层字段解析错误：%s" % str(f)
	if f.has("used_in") or f.has("notes") or f.has("  - x"):
		return "不应解析列表 / 多行字段：%s" % str(f)
	return ""


func test_gamepad_bindings_added() -> String:
	Settings.apply()
	Settings.apply()  # 重复应用不应重复添加
	for action: String in Settings.ACTIONS:
		var pads: int = 0
		for ev: InputEvent in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				pads += 1
		var want: int = int(Settings.PAD_BUTTONS.has(action)) + int(Settings.PAD_AXES.has(action))
		if pads != want:
			return "%s 手柄绑定数量 %d，应为 %d" % [action, pads, want]
	var press: InputEventJoypadButton = InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	if not press.is_action_pressed("dash"):
		return "手柄 A 应触发闪避"
	var stick: InputEventJoypadMotion = InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = -0.9
	if not stick.is_action_pressed("move_left"):
		return "左摇杆向左应触发 move_left"
	return ""


func test_settings_int_fields_survive_json() -> String:
	var tmp: String = "user://test_settings_tmp.json"
	SaveData.reset(tmp)
	Settings.data().quality = Settings.QUALITY_LOW
	Settings.data().max_fps = 144
	SaveData.save_file()
	SaveData.reset(tmp)
	var err: String = ""
	if Settings.quality() != Settings.QUALITY_LOW or int(Settings.get_value("max_fps")) != 144:
		err = "画质 / 帧率上限读回后丢失：%s" % str([Settings.get_value("quality"), Settings.get_value("max_fps")])
	elif typeof(Settings.get_value("quality")) != TYPE_INT:
		err = "画质读回后应为 int"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	SaveData.reset()
	return err