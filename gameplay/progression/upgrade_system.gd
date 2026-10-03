class_name UpgradeSystem extends RefCounted
## 升级选项：新技能 / 技能升级 / 技能替换 / 被动 / 属性加成 / 装备强化，无可选项时退回治疗。
## 选项格式：{type, id, title, desc, weight}
## type ∈ skill_new / skill_up / skill_swap / passive / stat_boost / equip_buff / heal

const CHOICE_COUNT: int = 5
## 五张卡里技能类（升级 / 新学 / 替换）最多几张
const MAX_SKILL_CARDS: int = 2
const SKILL_TYPES: Array[String] = ["skill_up", "skill_new", "skill_swap", "skill_reset"]
const MAX_SKILLS: int = 6
const HEAL_AMOUNT: float = 200.0
const WEIGHT_SKILL_UP: float = 3.0
const WEIGHT_SKILL_NEW: float = 2.0
const WEIGHT_SKILL_SWAP: float = 1.5
const WEIGHT_PASSIVE: float = 1.5
const WEIGHT_STAT_BOOST: float = 1.2
const WEIGHT_EQUIP_BUFF: float = 1.0

const STAT_BOOSTS: Array[Dictionary] = [
	{"id": "move_speed", "title": "迅捷步伐", "desc": "移速 +15%", "value": 0.15},
	{"id": "attack_speed", "title": "急速打击", "desc": "攻速 +20%", "value": 0.20},
	{"id": "crit", "title": "致命精准", "desc": "暴击率 +8%", "value": 0.08},
]


static func roll_choices(abilities: AbilitySystem, stats: CharacterStats, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var owned: int = abilities.equipped.size()

	# 技能升级
	for id: String in abilities.equipped:
		var skill: Skill = abilities.get_skill(id)
		if skill != null and skill.level < skill.max_level:
			pool.append(_option("skill_up", id, "%s Lv%d → Lv%d" % [skill.display_name, skill.level, skill.level + 1],
					_tier_hint(skill, skill.level + 1), WEIGHT_SKILL_UP))

	# 新技能
	if owned < MAX_SKILLS:
		for id: String in abilities.pool():
			if abilities.get_skill(id) == null:
				pool.append(_option("skill_new", id, "学习 %s" % SkillFactory.display_name(id),
						_new_skill_desc(id), WEIGHT_SKILL_NEW))

	# 技能替换（满技能时）
	if owned >= MAX_SKILLS:
		for old_id: String in abilities.equipped:
			for new_id: String in abilities.pool():
				if abilities.get_skill(new_id) == null:
					pool.append(_option("skill_swap", "%s→%s" % [old_id, new_id],
							"替换：%s → %s" % [SkillFactory.display_name(old_id), SkillFactory.display_name(new_id)],
							_swap_desc(old_id, new_id), WEIGHT_SKILL_SWAP))

	# 被动
	for id: String in ItemCatalog.PASSIVES:
		if not stats.has_passive(id):
			var p: Dictionary = ItemCatalog.PASSIVES[id]
			pool.append(_option("passive", id, p.name, p.desc, WEIGHT_PASSIVE))

	# 属性加成
	for boost: Dictionary in STAT_BOOSTS:
		pool.append(_option("stat_boost", boost.id, boost.title, boost.desc, WEIGHT_STAT_BOOST))

	# 装备强化
	if stats.equipment.size() > 0:
		var current: int = stats.equipment_power
		var dmg_now: float = 1.0 + 0.03 * current * stats.equipment.size()
		var dmg_next: float = 1.0 + 0.03 * (current + 1) * stats.equipment.size()
		var cd_now: float = 1.0 / (1.0 + 0.02 * current * stats.equipment.size())
		var cd_next: float = 1.0 / (1.0 + 0.02 * (current + 1) * stats.equipment.size())
		pool.append(_option("equip_buff", "power", "装备强化 Lv%d" % (current + 1),
				"伤害 ×%.2f → ×%.2f，冷却 ×%.2f → ×%.2f" % [dmg_now, dmg_next, cd_now, cd_next],
				WEIGHT_EQUIP_BUFF))

	if pool.is_empty():
		return [_option("heal", "", "治疗 %d" % int(HEAL_AMOUNT), "无可升级选项", 1.0)]

	# 类型多样化：技能类卡牌最多 MAX_SKILL_CARDS 张，其余位置给被动 / 属性 / 装备强化，不够再用技能补
	var skill_pool: Array[Dictionary] = []
	var other_pool: Array[Dictionary] = []
	for o: Dictionary in pool:
		(skill_pool if SKILL_TYPES.has(o.type) else other_pool).append(o)
	var result: Array[Dictionary] = []
	result.append_array(_pick_many(skill_pool, mini(MAX_SKILL_CARDS, CHOICE_COUNT), rng))
	result.append_array(_pick_many(other_pool, CHOICE_COUNT - result.size(), rng))
	result.append_array(_pick_many(skill_pool, CHOICE_COUNT - result.size(), rng))
	# 打乱顺序，避免技能卡总在最左边
	for i in range(result.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Dictionary = result[i]
		result[i] = result[j]
		result[j] = tmp

	if result.is_empty():
		result.append(_option("heal", "", "治疗 %d" % int(HEAL_AMOUNT), "", 1.0))

	return result


static func apply(choice: Dictionary, abilities: AbilitySystem, stats: CharacterStats) -> bool:
	match choice.type:
		"skill_new":
			var skill: Skill = SkillFactory.create(choice.id)
			if skill == null:
				return false
			abilities.add_skill(skill)
			return true
		"skill_up":
			var skill: Skill = abilities.get_skill(choice.id)
			if skill == null or skill.level >= skill.max_level:
				return false
			skill.set_level(skill.level + 1)
			return true
		"skill_swap":
			var parts: PackedStringArray = choice.id.split("→")
			if parts.size() != 2:
				return false
			var old_id: String = parts[0]
			var new_id: String = parts[1]
			var old_skill: Skill = abilities.get_skill(old_id)
			var old_level: int = old_skill.level if old_skill != null else 1
			var new_skill: Skill = SkillFactory.create(new_id)
			if new_skill == null:
				return false
			new_skill.set_level(old_level)  # 继承旧技能等级
			abilities.replace_skill(old_id, new_skill)
			return true
		"passive":
			stats.add_passive(choice.id)
			return true
		"stat_boost":
			for boost: Dictionary in STAT_BOOSTS:
				if boost.id == choice.id:
					match choice.id:
						"move_speed": stats.bonus_move_speed += boost.value
						"attack_speed": stats.bonus_attack_speed += boost.value
						"crit": stats.bonus_crit += boost.value
					return true
			return false
		"equip_buff":
			stats.equipment_power += 1
			return true
		"heal":
			stats.heal(HEAL_AMOUNT)
			return true
	return false


static func _option(type: String, id: String, title: String, desc: String, weight: float) -> Dictionary:
	return {"type": type, "id": id, "title": title, "desc": desc, "weight": weight}


static func _tier_hint(skill: Skill, next_level: int) -> String:
	var hints: PackedStringArray = []
	if next_level in skill.get_tier_thresholds():
		hints.append("★ 进化到第 %d 段" % (skill.get_tier_thresholds().find(next_level) + 1))
	hints.append("伤害 +10%")
	hints.append("范围 +5%")
	if next_level > 8 and next_level % 2 == 0:
		hints.append("✦ 特效增强")
	if next_level % 10 == 0:
		hints.append("✧ 里程碑爆发")
	return "  ".join(hints)


static func _new_skill_desc(skill_id: String) -> String:
	var elem: String = Elements.of(skill_id)
	return "元素：%s" % elem if not elem.is_empty() else "新技能"


static func _swap_desc(old_id: String, new_id: String) -> String:
	return "继承原技能等级"


## 按权重不放回地抽 count 个（会从 pool 中移除）。
static func _pick_many(pool: Array[Dictionary], count: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	while out.size() < count and not pool.is_empty():
		var idx: int = _weighted_pick(pool, rng)
		out.append(pool[idx])
		pool.remove_at(idx)
	return out


static func _weighted_pick(pool: Array[Dictionary], rng: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for o: Dictionary in pool:
		total += float(o.weight)
	var r: float = rng.randf() * total
	for i in pool.size():
		r -= float(pool[i].weight)
		if r <= 0.0:
			return i
	return pool.size() - 1
