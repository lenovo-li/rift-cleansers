class_name Execute extends Skill
## 处决：对 4 米内血量比例最低的敌人重斩；目标低血或被标记时伤害 3 倍。
## Lv1: 伤害 90，斩杀线 30%
## Lv3: 斩杀线 40%
## Lv5: 顺劈：目标 2.5 米内的敌人受 50% 伤害
## Lv8: 伤害 2x；处决击杀时冷却返还到 1 秒

const RANGE: float = 4.0
const BASE_DAMAGE: float = 90.0
const CLEAVE_RADIUS: float = 2.5


func _init() -> void:
	skill_id = "execute"
	display_name = "处决"
	max_level = 8


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 5.0


## 生命比例；目标没有生命字段（单元测试的假目标）时视为满血。
static func health_ratio(t: Variant) -> float:
	if t is Object and "current_health" in t and "max_health" in t and float(t.max_health) > 0.0:
		return float(t.current_health) / float(t.max_health)
	return 1.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var threshold: float = 0.4 if tier >= 3 else 0.3
	var damage: float = BASE_DAMAGE * (2.0 if tier >= 8 else 1.0)
	var target: Variant = null
	for t: Variant in ctx.nearest_targets(RANGE * ctx.area_mult, 20):
		if target == null or health_ratio(t) < health_ratio(target):
			target = t
	if target == null:
		return {"hits": 0, "damage": 0.0, "tier": tier, "cooldown": 0.5}
	var st: StatusEffects = Reactions.status_of(target)
	var executes: bool = health_ratio(target) <= threshold or (st != null and st.is_marked())
	var center: Vector3 = target.global_position
	var total: float = ctx.hit(target, damage * (3.0 if executes else 1.0), true)
	var hits: int = 1
	var killed: bool = not target.is_alive
	if tier >= 5:
		for t: Variant in ctx.targets_in_radius(center, CLEAVE_RADIUS):
			if t != target:
				total += ctx.hit(t, damage * 0.5)
				hits += 1
	var result: Dictionary = {"hits": hits, "damage": total, "tier": tier, "center": center, "executed": executes}
	if tier >= 8 and killed:
		result.cooldown = 1.0
	return result
