class_name SaveData extends RefCounted
## 本地存档（user://save.json）：排行榜、累计统计、天赋碎片、每个角色已点的天赋、成就。
## 只存本地玩家的数据；联机时每台机器各存各的。读写失败时退回默认值，不影响游戏。
## 版本迁移：旧版本逐级升到 VERSION（migrate）；新版本游戏写的存档保留不认识的字段，降级运行也不丢数据。
## 损坏的存档先另存为 *.corrupt 再用默认值；写入先写 *.tmp 再改名，写到一半崩溃不会毁掉旧存档。

const DEFAULT_PATH: String = "user://save.json"
## 1：初版。2：加 achievements（成就 id -> 解锁日期）和 stats（成就用的累计计数）。
const VERSION: int = 2
const LEADERBOARD_SIZE: int = 10

## 测试时改成临时文件。
static var path: String = DEFAULT_PATH
static var _data: Dictionary = {}
static var _loaded: bool = false


static func defaults() -> Dictionary:
	return {"version": VERSION, "runs": 0, "wins": 0, "total_kills": 0, "shards": 0,
		"leaderboard": [], "talents": {}, "settings": {}, "achievements": {}, "stats": {}}


static func data() -> Dictionary:
	if not _loaded:
		load_file()
	return _data


static func load_file() -> void:
	_loaded = true
	_data = defaults()
	if not FileAccess.file_exists(path):
		return
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var text: String = f.get_as_text()
	f.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		push_warning("存档损坏，已备份为 %s.corrupt，使用默认值" % path)
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".corrupt"))
		return
	_data = migrate(json.data)


## 把任意版本的存档字典升级到当前格式：逐级迁移，再按默认值补齐缺失或类型不对的字段。
static func migrate(raw: Dictionary) -> Dictionary:
	var d: Dictionary = raw.duplicate(true)
	var v: int = int(d.get("version", 1))
	if v < 2:
		d["achievements"] = {}
		d["stats"] = {}
	var out: Dictionary = defaults()
	for key: String in d:
		if not out.has(key):
			out[key] = d[key]  # 新版本游戏的字段，原样保留
		elif typeof(d[key]) == typeof(out[key]) or (out[key] is int and d[key] is float):
			out[key] = int(d[key]) if out[key] is int else d[key]  # JSON 读回来的整数是 float
	out["version"] = maxi(v, VERSION)
	return out


static func save_file() -> bool:
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("存档写入失败: %s" % path)
		return false
	f.store_string(JSON.stringify(data(), "\t"))
	f.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path)) != OK:
		push_warning("存档改名失败: %s" % path)
		return false
	return true


## 测试用：清空内存里的存档（不删文件）。
static func reset(p_path: String = DEFAULT_PATH) -> void:
	path = p_path
	_data = {}
	_loaded = false


## 本局得分：击杀 + 等级×20 + 存活秒数；胜利额外 +2000 并按剩余时间加分（越快越高）。
static func score_of(victory: bool, time_s: float, level: int, kills: int) -> int:
	var s: float = kills + level * 20 + time_s
	if victory:
		s += 2000.0 + maxf(0.0, 600.0 - time_s) * 5.0
	return int(s)


## 本局获得的天赋碎片：每 100 击杀 1 个 + 每 5 级 1 个，胜利 +10。
static func shards_for(victory: bool, level: int, kills: int) -> int:
	return kills / 100 + level / 5 + (10 if victory else 0)


## 记录一局。返回 {rank（1 起，未上榜为 0）, shards, score}。
static func record_run(char_id: String, map_id: String, victory: bool, time_s: float, level: int, kills: int) -> Dictionary:
	var d: Dictionary = data()
	var score: int = score_of(victory, time_s, level, kills)
	var shards: int = shards_for(victory, level, kills)
	d.runs = int(d.runs) + 1
	d.wins = int(d.wins) + (1 if victory else 0)
	d.total_kills = int(d.total_kills) + kills
	d.shards = int(d.shards) + shards
	var entry: Dictionary = {"char": char_id, "map": map_id, "victory": victory, "time": int(time_s),
		"level": level, "kills": kills, "score": score, "date": Time.get_date_string_from_system()}
	var board: Array = d.leaderboard
	board.append(entry)
	board.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.score) > int(b.score))
	var rank: int = board.find(entry) + 1
	if board.size() > LEADERBOARD_SIZE:
		board.resize(LEADERBOARD_SIZE)
	if rank > LEADERBOARD_SIZE:
		rank = 0
	save_file()
	return {"rank": rank, "shards": shards, "score": score}


static func leaderboard() -> Array:
	return data().leaderboard


static func shards() -> int:
	return int(data().shards)
