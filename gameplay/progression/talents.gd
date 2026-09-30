class_name Talents extends RefCounted
## 天赋树（局外成长）：每局结算获得的天赋碎片在菜单里给每个角色单独加点，开局时生效。
## 6 个通用天赋 + 每个角色 1 个专属天赋，每级花费 = base_cost × 当前等级+1。点数存在 SaveData.talents[角色][天赋]。
## 联机：客户端把自己的天赋等级随 hello 发给主机，主机按上限校验后应用到该玩家。

## 模拟/压测脚本关掉，保证结果不受玩家存档影响（--bot 联机测试同样不读天赋）。
static var enabled: bool = true

const GENERAL: Dictionary = {
	"vitality": {"name": "体魄", "desc": "最大生命 +6%", "max": 5, "cost": 3, "per": 0.06},
	"might": {"name": "力量", "desc": "所有伤害 +5%", "max": 5, "cost": 3, "per": 0.05},
	"swiftness": {"name": "迅捷", "desc": "移动速度 +4%", "max": 3, "cost": 4, "per": 0.04},
	"focus": {"name": "专注", "desc": "技能冷却 -4%", "max": 5, "cost": 4, "per": 0.04},
	"regeneration": {"name": "再生", "desc": "每秒生命回复 +1.5", "max": 4, "cost": 3, "per": 1.5},
	"wisdom": {"name": "智慧", "desc": "经验获取 +5%（联机时取主机）", "max": 4, "cost": 5, "per": 0.05},
}
## 角色专属天赋
const SIGNATURE: Dictionary = {
	"iron_guard": {"id": "fortress", "name": "堡垒", "desc": "格挡率 +4%", "max": 3, "cost": 6, "per": 0.04},
	"elementalist": {"id": "attunement", "name": "元素共鸣", "desc": "技能伤害再 +6%", "max": 3, "cost": 6, "per": 0.06},
	"shadow_walker": {"id": "lethality", "name": "致命", "desc": "暴击率 +4%", "max": 3, "cost": 6, "per": 0.04},
	"cleric": {"id": "devotion", "name": "虔诚", "desc": "治疗与护盾效果 +12%", "max": 3, "cost": 6, "per": 0.12},
}


## 某角色可点的全部天赋 {id: 定义}（通用在前，专属在后）。
static func tree(char_id: String) -> Dictionary:
	var out: Dictionary = GENERAL.duplicate()
	if SIGNATURE.has(char_id):
		var sig: Dictionary = SIGNATURE[char_id]
		out[sig.id] = sig
	return out


static func ranks(char_id: String) -> Dictionary:
	if not enabled or NetConfig.bot:
		return {}
	var all: Dictionary = SaveData.data().talents
	return (all.get(char_id, {}) as Dictionary).duplicate()


static func rank_of(ranks_dict: Dictionary, talent_id: String) -> int:
	return int(ranks_dict.get(talent_id, 0))


## 下一级的花费；已满级返回 -1。
static func next_cost(char_id: String, talent_id: String) -> int:
	var t: Dictionary = tree(char_id).get(talent_id, {})
	if t.is_empty():
		return -1
	var r: int = rank_of(ranks(char_id), talent_id)
	return -1 if r >= int(t.max) else int(t.cost) * (r + 1)


## 花碎片升一级。返回是否成功（碎片不够或已满级时失败）。
static func buy(char_id: String, talent_id: String) -> bool:
	var cost: int = next_cost(char_id, talent_id)
	var d: Dictionary = SaveData.data()
	if cost < 0 or int(d.shards) < cost:
		return false
	d.shards = int(d.shards) - cost
	var all: Dictionary = d.talents
	var mine: Dictionary = all.get(char_id, {})
	mine[talent_id] = rank_of(mine, talent_id) + 1
	all[char_id] = mine
	SaveData.save_file()
	return true


## 返还该角色的全部碎片（重置加点）。返回返还数量。
static func refund(char_id: String) -> int:
	var t: Dictionary = tree(char_id)
	var mine: Dictionary = ranks(char_id)
	var total: int = 0
	for id: String in mine:
		if t.has(id):
			for r in rank_of(mine, id):
				total += int(t[id].cost) * (r + 1)
	var d: Dictionary = SaveData.data()
	d.shards = int(d.shards) + total
	(d.talents as Dictionary).erase(char_id)
	SaveData.save_file()
	return total


## 按上限裁剪（联机时主机校验客户端发来的等级）。
static func sanitize(char_id: String, ranks_dict: Dictionary) -> Dictionary:
	var t: Dictionary = tree(char_id)
	var out: Dictionary = {}
	for id: Variant in ranks_dict:
		if t.has(String(id)):
			out[String(id)] = clampi(int(ranks_dict[id]), 0, int(t[String(id)].max))
	return out


static func bonus(ranks_dict: Dictionary, char_id: String, talent_id: String) -> float:
	var t: Dictionary = tree(char_id).get(talent_id, {})
	return 0.0 if t.is_empty() else float(t.per) * rank_of(ranks_dict, talent_id)


## 开局把天赋写入玩家属性。player 需有 stats、ability_system、move_speed、crit_chance、heal_mult。
static func apply(player: Object, char_id: String, ranks_dict: Dictionary) -> void:
	var stats: CharacterStats = player.stats
	stats.max_health *= 1.0 + bonus(ranks_dict, char_id, "vitality")
	stats.health = stats.max_health
	stats.talent_damage_mult = (1.0 + bonus(ranks_dict, char_id, "might")) \
			* (1.0 + bonus(ranks_dict, char_id, "attunement"))
	stats.regen_bonus = bonus(ranks_dict, char_id, "regeneration")
	stats.block_chance += bonus(ranks_dict, char_id, "fortress")
	player.move_speed *= 1.0 + bonus(ranks_dict, char_id, "swiftness")
	player.ability_system.cooldown_mult = 1.0 - bonus(ranks_dict, char_id, "focus")
	player.crit_chance += bonus(ranks_dict, char_id, "lethality")
	player.heal_mult = 1.0 + bonus(ranks_dict, char_id, "devotion")
