extends RefCounted
## 编译闸门：加载项目里所有 .gd，任何一个解析/编译失败都算失败。
## 运行器本身对解析错误不敏感（失败的脚本只在 stderr 打印），所以单独检查。

const ROOTS: Array[String] = ["res://core", "res://gameplay", "res://content", "res://presentation",
		"res://scenes", "res://ui", "res://net"]


func test_all_scripts_compile() -> String:
	var bad: Array[String] = []
	for root: String in ROOTS:
		_scan(root, bad)
	return "" if bad.is_empty() else "编译失败: %s" % ", ".join(bad)


func _scan(dir: String, bad: Array[String]) -> void:
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			var path: String = dir.path_join(f)
			var s: GDScript = load(path) as GDScript
			if s == null or not s.can_instantiate():
				bad.append(path)
	for d: String in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(d), bad)
