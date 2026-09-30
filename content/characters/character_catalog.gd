class_name CharacterCatalog extends RefCounted
## 可选角色（文档 M3：2 个角色，玩法差异明显）。
## 铁卫：近战、高血量、聚怪和击退；元素术士：远程、低血量、火冰雷组合反应（燃烧→爆燃，减速→碎裂）。

const DEFAULT_ID: String = "iron_guard"

const CHARACTERS: Dictionary = {
	"iron_guard": {
		"name": "铁卫",
		"desc": "近战坦克：盾击击退、嘲讽聚怪、旋风斩收割。生命 1000。",
		"model": "iron_guard",
		"skills": ["shield_bash", "whirlwind", "taunt", "charge", "ground_slam", "reflect_aura"],
		"starting": ["shield_bash", "taunt"],
		"max_health": 1000.0,
		"move_speed": 8.0,
		"attack": "pulse",  # 自身周围范围脉冲
		"attack_damage": 25.0,
		"attack_range": 3.5,
		"attack_interval": 1.0,
	},
	"elementalist": {
		"name": "元素术士",
		"desc": "远程法师：火球点燃、寒冰减速、闪电连锁、陨石引爆。生命 700，要保持距离。",
		"model": "elementalist",
		"skills": ["fireball", "ice_lance", "frost_nova", "chain_lightning", "meteor", "storm_field"],
		"starting": ["fireball", "frost_nova"],
		"max_health": 750.0,
		"move_speed": 8.5,
		"attack": "bolt",  # 自动射击最近的敌人
		"attack_damage": 22.0,
		"attack_range": 13.0,
		"attack_interval": 0.7,
	},
}


static func get_def(id: String) -> Dictionary:
	return CHARACTERS.get(id, CHARACTERS[DEFAULT_ID])


static func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in CHARACTERS:
		out.append(id)
	return out


static func is_valid(id: String) -> bool:
	return CHARACTERS.has(id)
