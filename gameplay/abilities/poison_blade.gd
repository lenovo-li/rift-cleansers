class_name PoisonBlade extends Skill
## 毒刃：向最近的敌人掷出毒刃，命中后中毒（毒元素，可触发剧毒爆发/腐蚀）。
## Lv1: 伤害 40，中毒 3 秒 20 DPS
## Lv3: 中毒 5 秒 30 DPS，额外弹射 1 个目标
## Lv5: 伤害 70，中毒 7 秒 50 DPS
## Lv8: 伤害 120，中毒 10 秒 80 DPS，治疗削减 80%，弹射 3 个目标

const RANGE: float = 15.0
const BOUNCE_RANGE: float = 6.0


func _init() -> void:
	skill_id = "poison_blade"
	display_name = "毒刃"
	max_level = 999


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 5.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var damage: float = 120.0 if tier >= 8 else (70.0 if tier >= 5 else 40.0)
	var dps: float = (80.0 if tier >= 8 else (50.0 if tier >= 5 else (30.0 if tier >= 3 else 20.0))) * ctx.damage_mult
	var dur: float = 10.0 if tier >= 8 else (7.0 if tier >= 5 else (5.0 if tier >= 3 else 3.0))
	var bounces: int = 3 if tier >= 8 else (1 if tier >= 3 else 0)
	var current: Variant = ctx.nearest_alive(RANGE)
	if current == null:
		return {"hits": 0, "damage": 0.0, "tier": tier, "links": []}
	var visited: Array = []
	var links: Array = []
	var from: Vector3 = ctx.origin
	var total: float = 0.0
	for i in bounces + 1:
		visited.append(current)
		links.append([from, current.global_position])
		total += ctx.hit(current, damage)
		var s: StatusEffects = Reactions.status_of(current)
		if s != null and current.is_alive:
			s.apply_poisoned(dps, dur * ctx.cc_mult, 0.8 if tier >= 8 else 0.5, ctx.intensity * 0.5)
		from = current.global_position
		current = null
		for t: Variant in ctx.targets_in_radius(from, BOUNCE_RANGE):
			if not t in visited:
				current = t
				break
		if current == null:
			break
	return {"hits": visited.size(), "damage": total, "tier": tier, "links": links}
