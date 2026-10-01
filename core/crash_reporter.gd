class_name CrashReporter extends Logger
## 崩溃与错误日志（只在本机保存，不上传）。
## - 启动时写 user://session.lock，正常退出时删除；下次启动发现它还在 = 上次异常退出，
##   把上次的 Godot 日志（引擎启动时已轮换到 user://logs/）复制到 user://crash_reports/，菜单里提示玩家。
## - 运行中记录脚本/引擎错误（最多 MAX_ERRORS 条）；正常退出时若有错误，写一份 errors_*.log。
## 无界面模式（测试、模拟、联机冒烟）不启用，避免被强制结束的测试进程误报崩溃。

const LOCK_PATH: String = "user://session.lock"
const REPORT_DIR: String = "user://crash_reports"
const LOG_DIR: String = "user://logs"
const MAX_ERRORS: int = 50
const MAX_REPORTS: int = 10

## 上次异常退出时复制出来的日志路径（没有则为空）。菜单读取后清空。
static var pending_report: String = ""
static var _instance: CrashReporter = null

var _mutex: Mutex = Mutex.new()
var _errors: PackedStringArray = []


## 幂等：菜单和直接开局的游戏场景都会调用。
static func install(tree: SceneTree) -> void:
	if _instance != null or DisplayServer.get_name() == "headless":
		return
	_instance = CrashReporter.new()
	_check_previous_session()
	var f: FileAccess = FileAccess.open(LOCK_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("%s %s" % [ProjectSettings.get_setting("application/config/version", "0"), Time.get_datetime_string_from_system()])
		f.close()
	OS.add_logger(_instance)
	# 跟随场景树退出：只有正常退出才会走到这里
	var watcher: Node = Node.new()
	watcher.name = "CrashReporterWatcher"
	watcher.tree_exiting.connect(_instance._on_clean_exit)
	tree.root.add_child.call_deferred(watcher)


static func report_dir_global() -> String:
	return ProjectSettings.globalize_path(REPORT_DIR)


static func _check_previous_session() -> void:
	if not FileAccess.file_exists(LOCK_PATH):
		return
	var stamp: String = FileAccess.get_file_as_string(LOCK_PATH).strip_edges()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOCK_PATH))
	DirAccess.make_dir_recursive_absolute(report_dir_global())
	var dest: String = "%s/crash_%s.log" % [REPORT_DIR, _file_stamp()]
	var src: String = _previous_log()
	var body: String = "上次会话（版本 / 开始时间）：%s\n上次的引擎日志：%s\n\n" % [stamp, src]
	if not src.is_empty():
		body += FileAccess.get_file_as_string(src)
	var f: FileAccess = FileAccess.open(dest, FileAccess.WRITE)
	if f != null:
		f.store_string(body)
		f.close()
		pending_report = dest
	_prune_reports()


## user://logs/ 里除当前 godot.log 外最新的一份（引擎每次启动把上一份改名加时间戳）。
static func _previous_log() -> String:
	var best: String = ""
	var best_time: int = -1
	for name: String in DirAccess.get_files_at(LOG_DIR):
		if name == "godot.log" or not name.ends_with(".log"):
			continue
		var p: String = "%s/%s" % [LOG_DIR, name]
		var t: int = FileAccess.get_modified_time(p)
		if t > best_time:
			best_time = t
			best = p
	return best


static func _prune_reports() -> void:
	var files: PackedStringArray = DirAccess.get_files_at(REPORT_DIR)
	files.sort()  # 文件名带时间戳，按名字排序 = 按时间排序
	for i in maxi(0, files.size() - MAX_REPORTS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [REPORT_DIR, files[i]]))


static func _file_stamp() -> String:
	return Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	_mutex.lock()
	if _errors.size() < MAX_ERRORS:
		_errors.append("[%s] %s:%d %s() %s %s" % [Time.get_time_string_from_system(), file, line, function, code, rationale])
	_mutex.unlock()


func _on_clean_exit() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOCK_PATH))
	_mutex.lock()
	var lines: PackedStringArray = _errors.duplicate()
	_mutex.unlock()
	if lines.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(report_dir_global())
	var f: FileAccess = FileAccess.open("%s/errors_%s.log" % [REPORT_DIR, _file_stamp()], FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines))
		f.close()
	_prune_reports()