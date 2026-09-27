extends SceneTree
## 无依赖的最小测试运行器。
## 用法: godot --headless --path . --script res://tests/run_all_tests.gd
## 自动发现 tests/ 下所有 test_*.gd，执行其中 test_ 开头的方法。
## 每个测试方法返回 String：空字符串表示通过，否则为失败原因。

const TEST_DIR: String = "res://tests"


func _init() -> void:
	var passed: int = 0
	var failed: int = 0
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		if not (file_name.begins_with("test_") and file_name.ends_with(".gd")):
			continue
		var script: GDScript = load("%s/%s" % [TEST_DIR, file_name]) as GDScript
		if script == null:
			printerr("[FAIL] %s: 脚本加载失败" % file_name)
			failed += 1
			continue
		var suite: Object = script.new()
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var result: Variant = suite.call(method_name)
			if result is String and (result as String).is_empty():
				print("[PASS] %s::%s" % [file_name, method_name])
				passed += 1
			else:
				printerr("[FAIL] %s::%s: %s" % [file_name, method_name, str(result)])
				failed += 1
		if suite is Node:
			(suite as Node).free()
	print("结果: %d 通过, %d 失败" % [passed, failed])
	quit(1 if failed > 0 or passed == 0 else 0)
