extends RefCounted
## 本地成就：单局条件、跨局累计（角色 / 地图 / 词缀集合）、不重复解锁、客户端未知字段跳过。

const TMP: String = "user://test_ach_tmp.json"


func _fresh() -> void:
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	SaveData.reset(TMP)


func _cleanup() -> String:
	_fresh()
	SaveData.reset()
	return ""


func _win(char_id: String, map_id: String, extra: Dictionary = {}) -> Array:
	var base: Dictionary = {"players": 1, "downed": true, "max_tier_skills": 0, "equipment": 0}
	base.merge(extra, true)
	return SaveData.record_run(char_id, map_id, true, 560.0, 20, 800, base).achievements


func test_first_win_once() -> String:
	_fresh()
	var a: Array = _win("iron_guard", "ashen_city")
	var b: Array = _win("iron_guard", "ashen_city")
	var err: String = ""
	if not a.has("first_win") or not a.has("win_iron_guard") or not a.has("win_ashen_city"):
		err = "首胜应解锁 first_win / 角色 / 地图：%s" % str(a)
	elif not b.is_empty():
		err = "重复条件不应再次解锁：%s" % str(b)
	_cleanup()
	return err


func test_cross_run_sets() -> String:
	_fresh()
	var ids: Array[String] = CharacterCatalog.ids()
	var maps: Array[String] = MapCatalog.ids()
	var last: Array = []
	for i in ids.size():
		last = _win(ids[i], maps[i % maps.size()], {"boss_affix": Achievements.BOSS_AFFIXES[i]})
	var err: String = ""
	if not last.has("all_heroes") or not last.has("all_maps") or not last.has("affix_all"):
		err = "四角色 / 四地图 / 四词缀都赢过后应解锁：%s" % str(last)
	_cleanup()
	return err


func test_run_conditions_and_unknowns() -> String:
	_fresh()
	var lose: Array = SaveData.record_run("cleric", "dark_forest", false, 300.0, 31, 1600,
		{"players": 1, "max_tier_skills": -1, "equipment": -1, "downed": true}).achievements
	var err: String = ""
	if not lose.has("level_30") or not lose.has("kills_1500"):
		err = "失败局也应判断等级 / 击杀成就：%s" % str(lose)
	elif lose.has("full_tier") or lose.has("gear_4") or lose.has("first_win"):
		err = "未知字段（-1）或失败局不应解锁：%s" % str(lose)
	if err.is_empty():
		var w: Array = _win("cleric", "dark_forest", {"downed": false, "boss_fight_time": 45.0, "max_tier_skills": 4,
			"equipment": 4})
		for id: String in ["untouchable", "boss_rush", "full_tier", "four_tiers", "gear_4"]:
			if not w.has(id):
				err = "应解锁 %s：%s" % [id, str(w)]
				break
		if err.is_empty() and w.has("coop_win"):
			err = "单人不应解锁联机成就"
	_cleanup()
	return err


func test_list_ids_unique_and_named() -> String:
	var seen: Dictionary = {}
	for a: Array in Achievements.LIST:
		if seen.has(a[0]):
			return "成就 id 重复：%s" % a[0]
		seen[a[0]] = true
	for id: String in CharacterCatalog.ids():
		if not seen.has("win_%s" % id):
			return "缺少角色成就：win_%s" % id
	for id: String in MapCatalog.ids():
		if not seen.has("win_%s" % id):
			return "缺少地图成就：win_%s" % id
	return ""