class_name Achievements extends RefCounted
## 本地成就（不依赖 Steam）：解锁记录在 SaveData 的 achievements（id -> 日期），累计计数在 stats。
## 每局结算时由 SaveData.record_run 调用 evaluate()。只用本机能确定的数据：
## 联机客户端也能拿到胜负、时间、等级、击杀、Boss 词缀；技能段位 / 装备数由主机结算，客户端传 -1 跳过相关成就。

## [id, 名称, 说明]（顺序即成就面板顺序）
const LIST: Array = [
	["first_win", "初次清扫", "第一次击败 Boss"],
	["win_iron_guard", "不动之盾", "用铁卫获胜"],
	["win_elementalist", "元素掌控", "用元素术士获胜"],
	["win_shadow_walker", "无影无踪", "用影行者获胜"],
	["win_cleric", "圣光指引", "用牧师获胜"],
	["all_heroes", "全员清扫者", "四个角色都获胜过"],
	["win_ashen_city", "王城余烬", "在灰烬王城获胜"],
	["win_frost_wastes", "破冰", "在霜冻冰原获胜"],
	["win_sand_ruins", "沙海归来", "在沙海遗迹获胜"],
	["win_dark_forest", "走出森林", "在幽暗森林获胜"],
	["all_maps", "裂界巡礼", "四张地图都获胜过"],
	["kills_1500", "割草机", "一局击杀 1500 个敌人"],
	["level_30", "移动天灾", "一局达到 30 级"],
	["boss_rush", "速战速决", "Boss 登场后 60 秒内击败它"],
	["full_tier", "终极进化", "把一个技能升到第 4 段"],
	["four_tiers", "大成", "一局内四个技能都到第 4 段"],
	["gear_4", "全副武装", "一局拿到 4 件装备"],
	["untouchable", "毫发无伤", "单人获胜且从未倒下"],
	["coop_win", "并肩作战", "联机获胜"],
	["affix_all", "词缀猎人", "击败带狂暴、坚韧、召唤、爆裂词缀的 Boss 各一次"],
	["total_kills_20000", "清扫万象", "累计击杀 20000 个敌人"],
	["runs_25", "老手", "累计游玩 25 局"],
]
const BOSS_AFFIXES: Array[String] = ["berserk", "fortified", "summoner", "volatile"]

## 解锁时回调（id, 名称）。游戏场景用它弹提示。
static var on_unlocked: Callable = Callable()


static func name_of(id: String) -> String:
	for a: Array in LIST:
		if a[0] == id:
			return a[1]
	return id


static func unlocked() -> Dictionary:
	return SaveData.data().achievements


static func is_unlocked(id: String) -> bool:
	return unlocked().has(id)


## run 字段：char, map, victory, time, level, kills, boss_affix, boss_fight_time（Boss 登场到结束秒数，没打到为 -1），
## max_tier_skills（到第 4 段的技能数，未知 -1）, equipment（装备数，未知 -1）, players, downed（本局是否倒下过）。
## 先更新 stats 累计，再判断；返回本次新解锁的 id 列表（调用方负责存档）。
static func evaluate(run: Dictionary) -> Array[String]:
	var d: Dictionary = SaveData.data()
	var st: Dictionary = d.stats
	var won: bool = bool(run.get("victory", false))
	if won:
		_add_to_set(st, "won_chars", str(run.get("char", "")))
		_add_to_set(st, "won_maps", str(run.get("map", "")))
		if not str(run.get("boss_affix", "")).is_empty():
			_add_to_set(st, "beaten_affixes", str(run.boss_affix))
	var tiers: int = int(run.get("max_tier_skills", -1))
	var checks: Dictionary = {
		"first_win": won,
		"win_%s" % run.get("char", ""): won,
		"all_heroes": _set_has_all(st, "won_chars", CharacterCatalog.ids()),
		"win_%s" % run.get("map", ""): won,
		"all_maps": _set_has_all(st, "won_maps", MapCatalog.ids()),
		"kills_1500": int(run.get("kills", 0)) >= 1500,
		"level_30": int(run.get("level", 0)) >= 30,
		"boss_rush": won and float(run.get("boss_fight_time", -1.0)) >= 0.0 and float(run.boss_fight_time) <= 60.0,
		"full_tier": tiers >= 1,
		"four_tiers": tiers >= 4,
		"gear_4": int(run.get("equipment", -1)) >= 4,
		"untouchable": won and int(run.get("players", 1)) == 1 and not bool(run.get("downed", true)),
		"coop_win": won and int(run.get("players", 1)) > 1,
		"affix_all": _set_has_all(st, "beaten_affixes", BOSS_AFFIXES),
		"total_kills_20000": int(d.total_kills) >= 20000,
		"runs_25": int(d.runs) >= 25,
	}
	var fresh: Array[String] = []
	for a: Array in LIST:
		var id: String = a[0]
		if bool(checks.get(id, false)) and not d.achievements.has(id):
			d.achievements[id] = Time.get_date_string_from_system()
			fresh.append(id)
			if on_unlocked.is_valid():
				on_unlocked.call(id, a[1])
	return fresh


static func _add_to_set(st: Dictionary, key: String, value: String) -> void:
	if value.is_empty():
		return
	var arr: Array = st.get(key, [])
	if not arr.has(value):
		arr.append(value)
	st[key] = arr


static func _set_has_all(st: Dictionary, key: String, wanted: Array) -> bool:
	var arr: Array = st.get(key, [])
	for w: Variant in wanted:
		if not arr.has(w):
			return false
	return true