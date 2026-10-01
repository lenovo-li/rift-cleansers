class_name DropSystem extends RefCounted
## 掉落规则（文档 05 §2.3）：装备按时间表掉落（由 SpawnDirector 触发），精英额外 35% 掉装备，
## 普通敌人 3% 掉治疗球。纯逻辑。

const ELITE_EQUIPMENT_CHANCE: float = 0.35
## 每人最多装备数。装备池扩到 29 件后不设上限会在后期叠满（模拟里 9 分钟拿到 19 件），满了掉治疗球。
const MAX_EQUIPMENT: int = 8
const HEAL_ORB_CHANCE: float = 0.03
const HEAL_ORB_AMOUNT: float = 60.0


## 从未拥有、也未在地上的装备里随机挑一件；全部拿到时返回空字符串。
## char_id：筛选该角色能用的装备（通用 + 该角色专属）。
static func pick_equipment(owned: Dictionary, pending: Array, char_id: String, rng: RandomNumberGenerator) -> String:
	var candidates: Array[String] = []
	for id: String in ItemCatalog.equipment_pool(char_id):
		if not owned.has(id) and not pending.has(id):
			candidates.append(id)
	if candidates.is_empty():
		return ""
	return candidates[rng.randi() % candidates.size()]


static func rolls_elite_equipment(roll: float) -> bool:
	return roll < ELITE_EQUIPMENT_CHANCE


static func rolls_heal_orb(roll: float) -> bool:
	return roll < HEAL_ORB_CHANCE
