extends RefCounted
## 项目初始化冒烟测试：验证工程配置、主场景和输入映射。


func test_main_scene_loads() -> String:
	var path: String = str(ProjectSettings.get_setting("application/run/main_scene"))
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return "主场景无法加载: %s" % path
	var root: Node = packed.instantiate()
	var ok: bool = root.has_node("UI/InfoLabel") and root.has_node("Camera3D")
	root.free()
	return "" if ok else "主场景缺少 UI/InfoLabel 或 Camera3D"


func test_input_actions_defined() -> String:
	for action: String in ["move_left", "move_right", "move_up", "move_down", "dash", "skill_1"]:
		if not InputMap.has_action(action):
			return "缺少输入动作: %s" % action
	return ""


func test_engine_version_is_4_7() -> String:
	var info: Dictionary = Engine.get_version_info()
	if info["major"] != 4 or info["minor"] != 7:
		return "引擎版本应为 4.7.x，实际 %s" % info["string"]
	return ""
