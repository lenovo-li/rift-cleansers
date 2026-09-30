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
	_cleanup()
	return err
