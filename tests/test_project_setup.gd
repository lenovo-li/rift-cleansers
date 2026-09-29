extends RefCounted
## 项目冒烟测试：验证工程配置、场景可加载和输入映射。

const SCENES: Array[String] = [
	"res://scenes/main.tscn",
	"res://scenes/test_arena.tscn",
	"res://scenes/game_scene.tscn",
	"res://scenes/menu.tscn",
]


func test_main_scene_loads() -> String:
	return _check_scene(str(ProjectSettings.get_setting("application/run/main_scene")))


func test_all_scenes_load() -> String:
	for path: String in SCENES:
		var err: String = _check_scene(path)
		if not err.is_empty():
			return err
	return ""


func test_game_scene_has_core_nodes() -> String:
	var root: Node = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	var missing: Array[String] = []
	for node_path: String in ["PlayerM1", "GameSession", "GameSession/SpawnDirector", "EnemySpawner", "UI/HUD"]:
		if not root.has_node(node_path):
			missing.append(node_path)
	root.free()
	return "" if missing.is_empty() else "game_scene 缺少节点: %s" % ", ".join(missing)


func _check_scene(path: String) -> String:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return "场景无法加载: %s" % path
	var root: Node = packed.instantiate()
	if root == null:
		return "场景无法实例化: %s" % path
	root.free()
	return ""


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
