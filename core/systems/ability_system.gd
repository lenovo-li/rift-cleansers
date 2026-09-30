class_name AbilitySystem extends RefCounted
## 管理技能实例、冷却、技能产生的地面效果和延迟打击（陨石）。不依赖场景树。

signal skill_cast(skill_id: String, result: Dictionary)
## 延迟打击落地（表现层播放爆炸）：strike 为 SkillContext.queue_strike 的字典，hits 为命中数。
signal strike_landed(strike: Dictionary, hits: int)

var zones: Array[GroundZone] = []
var strikes: Array[Dictionary] = []
## 该角色可学的 6 个技能（HUD 技能栏顺序、升级三选一的候选池）。空时退回 SkillFactory.SKILL_IDS。
var skill_pool: Array[String] = []
## 所有技能冷却倍率（天赋）。
var cooldown_mult: float = 1.0
var _skills: Dictionary = {}  # skill_id -> Skill
var _cooldowns: Dictionary = {}  # skill_id -> 剩余秒数


func pool() -> Array[String]:
	return skill_pool if not skill_pool.is_empty() else SkillFactory.SKILL_IDS


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
	# 技能可以用 result.cooldown 覆盖本次冷却（影步击杀刷新、处决斩杀返还）
	_cooldowns[skill_id] = float(result.get("cooldown", skill.get_cooldown())) * cooldown_mult
	zones.append_array(ctx.new_zones)
	strikes.append_array(ctx.new_strikes)
	skill_cast.emit(skill_id, result)
	return result


func has_zones() -> bool:
	return not zones.is_empty()


## 推进冷却、地面效果和延迟打击。allies：治疗类地面效果（圣域）作用的玩家。
func tick(delta: float, targets: Array, allies: Array = []) -> void:
	for skill_id: String in _cooldowns.keys():
		_cooldowns[skill_id] = maxf(0.0, float(_cooldowns[skill_id]) - delta)
	for zone: GroundZone in zones:
		zone.tick_heal(delta, allies)
		zone.tick(delta, targets)
	for i in range(zones.size() - 1, -1, -1):
		if zones[i].is_expired():
			zones.remove_at(i)
	for i in range(strikes.size() - 1, -1, -1):
		strikes[i].delay -= delta
		if strikes[i].delay <= 0.0:
			var s: Dictionary = strikes[i]
			strikes.remove_at(i)
			strike_landed.emit(s, resolve_strike(s, targets))


## 结算一次延迟打击：重击（爆燃）+ 向外击退（碎裂）+ 燃烧；second_wave 时外圈再补 50% 伤害。
static func resolve_strike(s: Dictionary, targets: Array) -> int:
	var ctx: SkillContext = SkillContext.new()
	ctx.origin = s.center
	ctx.targets = targets
	ctx.magnet = s.get("magnet", false)
	var hits: int = 0
	for t: Variant in ctx.targets_in_radius(s.center, s.radius):
		hits += 1
		var dealt: float = ctx.hit(t, s.damage, true)
		if not t.is_alive:
			continue
		var off: Vector3 = (t.global_position - s.center) * Vector3(1, 0, 1)
		var dir: Vector3 = off.normalized() if off.length() > 0.01 else Vector3.FORWARD
		ctx.push(t, dir * float(s.knockback), dealt)
		var st: StatusEffects = Reactions.status_of(t)
		if st != null and float(s.burn) > 0.0:
			st.apply_burn(s.burn, 4.0)
	if s.get("second_wave", false):
		for t: Variant in ctx.targets_in_radius(s.center, s.radius * 1.6):
			var d: float = ((t.global_position - s.center) * Vector3(1, 0, 1)).length()
			if d > s.radius:
				ctx.hit(t, s.damage * 0.5)
				hits += 1
	return hits
