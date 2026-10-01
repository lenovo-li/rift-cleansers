extends SceneTree
## 发布相关界面截图（需要真实渲染）：godot --path . --script res://tests/release_showcase.gd -- --out=C:/tmp/rel
## 主菜单、设置面板、关于与许可证、成就面板，以及游戏内画质低 / 高对比。

var _out: String = "user://release_shots"
var _step: int = 0
var _t: float = 0.0
var _node: Node = null


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(_out)
	SaveData.reset("user://release_showcase_save.json")  # 不动玩家存档
	Talents.enabled = false
	_load("res://scenes/menu.tscn")


func _load(path: String) -> void:
	if _node != null:
		_node.queue_free()
	_node = (load(path) as PackedScene).instantiate()
	if "record_runs" in _node:
		_node.auto_pick_upgrades = true
		_node.record_runs = false
	root.add_child(_node)
	current_scene = _node


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("[shot] %s" % name)


func _overlay(panel: Control, name: String) -> void:
	_node.add_child(panel)
	await create_timer(0.6).timeout
	_shot(name)
	panel.queue_free()


func _process(delta: float) -> bool:
	_t += delta
	if _t < 1.0 or _step < 0:
		return false
	_t = 0.0
	match _step:
		0: _shot("menu")
		1: _overlay(SettingsPanel.new(), "settings")
		2: _overlay(LicensesPanel.new(), "licenses")
		3:
			if ClassDB.class_exists("AchievementsPanel") or ResourceLoader.exists("res://ui/achievements_panel.gd"):
				_overlay((load("res://ui/achievements_panel.gd") as GDScript).new(), "achievements")
		4:
			Settings.data().quality = Settings.QUALITY_LOW
			_load("res://scenes/game_scene.tscn")
		6:
			print("[q] low shadow=", _node.get_node("Sun").shadow_enabled, " q=", Settings.quality())
			_shot("game_low")
		7: Settings.set_value("quality", Settings.QUALITY_HIGH)
		8:
			print("[q] high shadow=", _node.get_node("Sun").shadow_enabled, " q=", Settings.quality())
			_shot("game_high")
		9:
			SaveData.reset()
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://release_showcase_save.json"))
			quit()
	_step += 1
	return false