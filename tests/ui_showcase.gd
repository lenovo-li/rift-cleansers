extends SceneTree
## 界面截图（需要真实渲染）：godot --path . --script res://tests/ui_showcase.gd -- --out=C:/tmp/ui
## 截设置面板（改键等待状态）和游戏内暂停菜单；同时检查改键写入 InputMap、互换冲突键。

var _out: String = "user://ui_shots"
var _step: int = 0
var _t: float = 0.0
var _scene: Node = null
var _panel: SettingsPanel = null


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(_out)
	SaveData.reset("user://ui_showcase_save.json")  # 不动玩家存档
	Talents.enabled = false
	_scene = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	_scene.auto_pick_upgrades = true
	_scene.record_runs = false
	root.add_child(_scene)


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])


func _process(delta: float) -> bool:
	_t += delta
	match _step:
		0:
			if _t > 1.0:
				# 改键：闪避改成 Q（Q 原本是技能 2），应当互换
				var swapped: String = Settings.bind("dash", KEY_Q)
				var ok: bool = swapped == "skill_1" and Settings.key_of("skill_1") == KEY_SHIFT \
						and _has_key("dash", KEY_Q) and not _has_key("dash", KEY_SHIFT)
				print("[ui] rebind dash->Q swapped=%s ok=%s" % [swapped, ok])
				_scene._open_pause_menu()
				_step = 1
				_t = 0.0
		1:
			if _t > 0.3:
				print("[ui] paused=%s" % paused)
				_shot("pause_menu")
				_panel = SettingsPanel.new()
				_scene.get_node("UI").add_child(_panel)
				_step = 2
				_t = 0.0
		2:
			if _t > 0.3:
				_panel._start_rebind("skill_0")
				_step = 3
				_t = 0.0
		3:
			if _t > 0.2:
				_shot("settings")
				Settings.reset_to_defaults()
				print("[ui] reset dash=%s" % Settings.key_name(Settings.key_of("dash")))
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ui_showcase_save.json"))
				return true
	return false


func _has_key(action: String, code: int) -> bool:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == code:
			return true
	return false
