class_name UpgradeSystem extends RefCounted
## 升级三选一：新技能 / 技能升级 / 被动模块，没有可选项时退回治疗。纯逻辑。
## 选项格式：{type, id, title, desc}，type ∈ skill_new / skill_up / passive / heal。

const CHOICE_COUNT: int = 3
const MAX_SKILLS: int = 6
const HEAL_AMOUNT: float = 200.0
const WEIGHT_SKILL_UP: float = 3.0
const WEIGHT_SKILL_NEW: float = 2.0
const WEIGHT_PASSIVE: float = 1.5


static func roll_choices(abilities: AbilitySystem, stats: CharacterStats, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var owned: int = 0
	for id: String in abilities.pool():
		var skill: Skill = abilities.get_skill(id)
		if skill != null:
			owned += 1
			if skill.level < skill.max_level:
				pool.append(_option("skill_up", id, "%s Lv%d → Lv%d" % [skill.display_name, skill.level, skill.level + 1],
						_tier_hint(skill, skill.level + 1), WEIGHT_SKILL_UP))
	if owned < MAX_SKILLS:
		for id: String in abilities.pool():
			if abilities.get_skill(id) == null:
				pool.append(_option("skill_new", id, "新技能：%s" % SkillFactory.display_name(id), "获得 Lv1", WEIGHT_SKILL_NEW))
	for id: String in ItemCatalog.PASSIVES:
		if not stats.has_passive(id):
			pool.append(_option("passive", id, "被动：%s" % ItemCatalog.passive_name(id),
					ItemCatalog.PASSIVES[id].desc, WEIGHT_PASSIVE))

	var choices: Array[Dictionary] = []
	while choices.size() < CHOICE_COUNT and not pool.is_empty():
		var idx: int = _weighted_pick(pool, rng)
		choices.append(pool[idx])
		pool.remove_at(idx)
	while choices.size() < CHOICE_COUNT:
		choices.append(_option("heal", "heal", "治疗", "恢复 %d 生命" % int(HEAL_AMOUNT), 0.0))
	return choices


## 应用选项；返回 true 表示已应用。
static func apply(choice: Dictionary, abilities: AbilitySystem, stats: CharacterStats) -> bool:
	match choice.get("type", ""):
		"skill_new":
			if abilities.get_skill(choice.id) != null:
				return false
			abilities.add_skill(SkillFactory.create(choice.id))
			return true
		"skill_up":
			var skill: Skill = abilities.get_skill(choice.id)
			if skill == null or skill.level >= skill.max_level:
				return false
			skill.set_level(skill.level + 1)
			return true
		"passive":
			stats.add_passive(choice.id)
			return true
		"heal":
			stats.heal(HEAL_AMOUNT)
			return true
	return false


static func _option(type: String, id: String, title: String, desc: String, weight: float) -> Dictionary:
	return {"type": type, "id": id, "title": title, "desc": desc, "weight": weight}


## 升到进化档位时提示「进化！」
static func _tier_hint(skill: Skill, next_level: int) -> String:
	if next_level in skill.get_tier_thresholds():
		return "★ 进化到第 %d 段" % (skill.get_tier_thresholds().find(next_level) + 1)
	return "伤害 +10%"


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
