extends RefCounted
## 本地存档：排行榜排序与截断、碎片、读写往返、损坏文件回退。

const TMP: String = "user://test_save_tmp.json"


func _fresh() -> void:
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	SaveData.reset(TMP)


func _cleanup() -> void:
	_fresh()
	SaveData.reset()


func test_record_and_rank() -> String:
	_fresh()
	var lose: Dictionary = SaveData.record_run("iron_guard", "ashen_city", false, 300.0, 15, 900)
	var win: Dictionary = SaveData.record_run("elementalist", "ashen_city", true, 560.0, 30, 3000)
	var board: Array = SaveData.leaderboard()
	var err: String = ""
	if lose.rank != 1 or win.rank != 1:
		err = "新纪录应排第 1：%d %d" % [lose.rank, win.rank]
	elif board.size() != 2 or board[0].char != "elementalist":
		err = "胜利局应排在前面"
	elif win.shards != 3000 / 100 + 30 / 5 + 10:
		err = "胜利碎片计算错误：%d" % win.shards
	elif SaveData.shards() != lose.shards + win.shards or int(SaveData.data().runs) != 2:
		err = "累计碎片/局数错误"
	_cleanup()
	return err


func test_leaderboard_truncates() -> String:
	_fresh()
	for i in 12:
		SaveData.record_run("iron_guard", "ashen_city", false, 100.0 + i, 5, 100 * i)
	var last: Dictionary = SaveData.record_run("iron_guard", "ashen_city", false, 10.0, 1, 0)
	var err: String = ""
	if SaveData.leaderboard().size() != SaveData.LEADERBOARD_SIZE:
		err = "排行榜应截断到 %d" % SaveData.LEADERBOARD_SIZE
	elif last.rank != 0:
		err = "最低分不应上榜"
	_cleanup()
	return err


func test_roundtrip_and_corrupt_file() -> String:
	_fresh()
	SaveData.record_run("iron_guard", "ashen_city", true, 500.0, 25, 2500)
	SaveData.data().talents["iron_guard"] = {"vitality": 2}
	SaveData.save_file()
	SaveData.reset(TMP)
	var err: String = ""
	if SaveData.leaderboard().size() != 1 or int(SaveData.data().talents.iron_guard.vitality) != 2:
		err = "重新读取后数据丢失"
	var f: FileAccess = FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	SaveData.reset(TMP)
	if err.is_empty() and (SaveData.leaderboard().size() != 0 or SaveData.shards() != 0):
		err = "损坏的存档应退回默认值"
	if err.is_empty() and not FileAccess.file_exists(TMP + ".corrupt"):
		err = "损坏的存档应备份为 .corrupt"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP + ".corrupt"))
	_cleanup()
	return err


## 计数字段写入再读回仍是原值（JSON 数字读回为 float，不能因类型不同被丢掉）。
func test_counters_survive_reload() -> String:
	_fresh()
	SaveData.record_run("iron_guard", "ashen_city", true, 500.0, 25, 2500)
	var shards: int = SaveData.shards()
	SaveData.reset(TMP)
	var err: String = ""
	if int(SaveData.data().runs) != 1 or int(SaveData.data().wins) != 1 or SaveData.shards() != shards:
		err = "读回后局数/胜场/碎片丢失：%s" % str([SaveData.data().runs, SaveData.data().wins, SaveData.shards()])
	elif typeof(SaveData.data().runs) != TYPE_INT:
		err = "计数字段读回后应为 int"
	_cleanup()
	return err


func test_migrate_v1_and_keep_unknown_fields() -> String:
	var v1: Dictionary = {"version": 1, "runs": 3.0, "shards": 12.0, "leaderboard": [], "talents": {},
		"future_field": {"x": 1}}
	var d: Dictionary = SaveData.migrate(v1)
	if int(d.version) != SaveData.VERSION:
		return "迁移后版本应为 %d" % SaveData.VERSION
	if not (d.achievements is Dictionary) or not (d.stats is Dictionary):
		return "v1 迁移后应有 achievements / stats"
	if int(d.runs) != 3 or int(d.shards) != 12:
		return "迁移丢失了计数"
	if not d.has("future_field"):
		return "不认识的字段应保留"
	var newer: Dictionary = SaveData.migrate({"version": 99, "runs": 1})
	if int(newer.version) != 99:
		return "新版本存档的版本号不应被降低"
	return ""
