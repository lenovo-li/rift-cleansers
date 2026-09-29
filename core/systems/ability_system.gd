class_name AbilitySystem extends RefCounted
## 管理技能实例、冷却，以及技能产生的地面效果。不依赖场景树。

signal skill_cast(skill_id: String, result: Dictionary)

var zones: Array[GroundZone] = []
var _skills: Dictionary = {}  # skill_id -> Skill
var _cooldowns: Dictionary = {}  # skill_id -> 剩余秒数


func add_skill(skill: Skill) -> void:
	_skills[skill.skill_id] = skill
	_cooldowns[skill.skill_id] = 0.0


func get_skill(skill_id: String) -> Skill:
	return _skills.get(skill_id) as Skill


func get_level(skill_id: String) -> int:
	var skill: Skill = get_skill(skill_id)
	return skill.level if skill != null else 0


func set_level(skill_id: String, value: int) -> void:
	var skill: Skill = get_skill(skill_id)
	if skill != null:
		skill.set_level(value)


func get_cooldown_remaining(skill_id: String) -> float:
	return float(_cooldowns.get(skill_id, 0.0))


## 客户端用主机快照覆盖冷却显示。
func set_cooldown_remaining(skill_id: String, value: float) -> void:
	if _cooldowns.has(skill_id):
		_cooldowns[skill_id] = maxf(0.0, value)


func can_cast(skill_id: String) -> bool:
	return _skills.has(skill_id) and get_cooldown_remaining(skill_id) <= 0.0


## 施放技能；冷却中或未拥有时返回空字典。
func cast(skill_id: String, ctx: SkillContext) -> Dictionary:
	if not can_cast(skill_id):
		return {}
	var skill: Skill = _skills[skill_id]
	var result: Dictionary = skill.cast(ctx)
	_cooldowns[skill_id] = skill.get_cooldown()
	zones.append_array(ctx.new_zones)
	skill_cast.emit(skill_id, result)
	return result


func has_zones() -> bool:
	return not zones.is_empty()


## 推进冷却和地面效果。targets 只在有地面效果时才会被使用。
func tick(delta: float, targets: Array) -> void:
	for skill_id: String in _cooldowns.keys():
		_cooldowns[skill_id] = maxf(0.0, float(_cooldowns[skill_id]) - delta)
	for zone: GroundZone in zones:
		zone.tick(delta, targets)
	for i in range(zones.size() - 1, -1, -1):
		if zones[i].is_expired():
			zones.remove_at(i)
