class_name DropSystem extends RefCounted
## 掉落规则（文档 05 §2.3）：装备按时间表掉落（由 SpawnDirector 触发），精英额外 35% 掉装备，
## 普通敌人 3% 掉治疗球。纯逻辑。

const ELITE_EQUIPMENT_CHANCE: float = 0.35
## 每人最多装备数（30+ 容量，拾取重复装备升品质）
const MAX_EQUIPMENT: int = 30
const HEAL_ORB_CHANCE: float = 0.03
const HEAL_ORB_AMOUNT: float = 60.0


## 从角色能用的装备池里随机挑一件；全部拿到时返回空字符串。
## 重复装备现在允许拾取（升品质），所以只在数量达到上限时才排除已拥有的。
static func pick_equipment(owned: Dictionary, pending: Array, char_id: String, rng: RandomNumberGenerator) -> String:
	var all_items: Array[String] = ItemCatalog.equipment_pool(char_id)
	var candidates: Array[String] = []

	# 优先从未拥有的装备里选
	for id: String in all_items:
		if not owned.has(id) and not pending.has(id):
			candidates.append(id)

	# 未拥有的选完了，且未达上限：从已拥有的里选（升品质）
	if candidates.is_empty() and owned.size() < MAX_EQUIPMENT:
		for id: String in all_items:
			if owned.has(id) and not pending.has(id):
				candidates.append(id)

	if candidates.is_empty():
		return ""
	return candidates[rng.randi() % candidates.size()]


static func rolls_elite_equipment(roll: float) -> bool:
	return roll < ELITE_EQUIPMENT_CHANCE


static func rolls_heal_orb(roll: float) -> bool:
	return roll < HEAL_ORB_CHANCE
