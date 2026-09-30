class_name CharacterCatalog extends RefCounted
## 可选角色（4 个，玩法差异明显）。
## 铁卫：近战、高血量、聚怪和击退；元素术士：远程、低血量、火冰雷组合反应（燃烧→爆燃，减速→碎裂）；
## 影行者：高机动、暴击、死亡标记 + 影步刷新；牧师：中距离、治疗/护盾/祝福/复活队友。
## crit_chance：自动攻击和技能的暴击率（暴击 2 倍伤害）。

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
		"attack_damage": 28.0,
		"attack_range": 3.5,
		"attack_interval": 1.0,
	},
	"elementalist": {
		"name": "元素术士",
		"desc": "远程法师：火球点燃、寒冰减速、闪电连锁、陨石引爆。生命 900，要保持距离。",
		"model": "elementalist",
		"skills": ["fireball", "ice_lance", "frost_nova", "chain_lightning", "meteor", "storm_field"],
		"starting": ["fireball", "frost_nova"],
		"max_health": 900.0,
		"move_speed": 8.5,
		"attack": "bolt",  # 自动射击最近的敌人
		"attack_damage": 20.0,
		"attack_range": 13.0,
		"attack_interval": 0.7,
	},
	"shadow_walker": {
		"name": "影行者",
		"desc": "刺客：影步闪到目标身后，死亡标记精英，处决残血。击杀标记目标刷新影步。生命 760，暴击 15%。",
		"model": "shadow_walker",
		"skills": ["shadow_step", "fan_of_knives", "death_mark", "blade_flurry", "smoke_bomb", "execute"],
		"starting": ["shadow_step", "fan_of_knives"],
		"max_health": 760.0,
		"move_speed": 9.5,
		"attack": "slash",  # 前方近身斩击（最近的敌人 + 身边顺劈）
		"attack_damage": 30.0,
		"attack_range": 3.0,
		"attack_interval": 0.6,
		"crit_chance": 0.15,
	},
	"cleric": {
		"name": "牧师",
		"desc": "辅助：圣光新星治疗全队，惩击光柱，圣域回血，护盾与祝福，大招可复活倒地队友。生命 1000。",
		"model": "cleric",
		"skills": ["holy_nova", "smite", "sanctuary", "divine_shield", "blessing", "divine_intervention"],
		"starting": ["holy_nova", "smite"],
		"max_health": 1000.0,
		"move_speed": 8.0,
		"attack": "bolt",
		"attack_damage": 24.0,
		"attack_range": 10.0,
		"attack_interval": 0.8,
		"bolt_color": Color(1.0, 0.9, 0.45, 0.85),
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
