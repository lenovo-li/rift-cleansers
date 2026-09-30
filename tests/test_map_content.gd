extends RefCounted
## 地图主题内容：每张地图的敌人池只引用存在的敌人、各阶段都有专属敌人；随机事件定义合法；每张地图有自己的音乐。


func test_map_enemy_pools_reference_known_enemies() -> String:
	var spawner: GDScript = load("res://gameplay/spawn/enemy_spawner.gd")
	for map_id: String in MapCatalog.ids():
		var pools: Dictionary = MapCatalog.get_def(map_id).get("enemies", {})
		for phase: String in ["early", "mid", "late"]:
			if not pools.has(phase):
				return "%s 缺少 %s 敌人池" % [map_id, phase]
			for id: String in pools[phase]:
				if not spawner.DEFS.has(id):
					return "%s/%s 引用了不存在的敌人 %s" % [map_id, phase, id]
	return ""


func test_each_map_has_theme_enemy_in_every_phase() -> String:
	var theme: Dictionary = {"ashen_city": "ember_guard", "frost_wastes": "frost_wraith", "sand_ruins": "sand_scarab",
		"dark_forest": "spore_shambler"}
	for map_id: String in theme:
		for phase: String in ["early", "mid", "late"]:
			if not (MapCatalog.get_def(map_id).enemies[phase] as Dictionary).has(theme[map_id]):
				return "%s 的 %s 阶段没有主题敌人 %s" % [map_id, phase, theme[map_id]]
	return ""


func test_pick_enemy_type_uses_map_pool() -> String:
	# 沙海遗迹早期池里没有腐尸以外的默认第一分钟敌人：抽 200 次应当出现沙甲虫
	var seen: Dictionary = {}
	for i in 200:
		seen[SpawnDirector.pick_enemy_type(30.0, float(i) / 200.0, "sand_ruins")] = true
	if not seen.has("sand_scarab"):
		return "沙海遗迹早期没有抽到沙甲虫: %s" % [seen.keys()]
	# 不传地图时保持旧行为（第一分钟只有腐尸）
	if SpawnDirector.pick_enemy_type(30.0, 0.9) != "zombie":
		return "默认池第一分钟应只有腐尸"
	return ""


func test_map_events_valid() -> String:
	for map_id: String in MapCatalog.ids():
		var evs: Array = MapCatalog.get_def(map_id).get("events", [])
		if evs.size() < 3:
			return "%s 随机事件少于 3 个" % map_id
		for ev: Dictionary in evs:
			if int(ev.kind) < 0 or int(ev.kind) >= EventDirector.Kind.size():
				return "%s 事件类型非法: %s" % [map_id, ev.kind]
			if float(ev.time) <= 0.0 or float(ev.time) >= SpawnDirector.BOSS_TIME:
				return "%s 事件时间应在开局后、Boss 之前: %s" % [map_id, ev.time]
	return ""


func test_each_map_has_own_music() -> String:
	var script: GDScript = load("res://presentation/music_manager.gd")
	for map_id: String in MapCatalog.ids():
		for state: int in [0, 1, 2]:
			var path: String = script.track_path(map_id, state)
			if not path.contains(map_id):
				return "%s 缺少专属音乐: %s" % [map_id, path]
			if not ResourceLoader.exists(path):
				return "音乐文件不存在: %s" % path
	return ""
