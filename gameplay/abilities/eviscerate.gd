class_name Eviscerate extends Skill
## 剔骨：近身（5 米内）重击最近的敌人，对残血目标伤害翻倍。
## Lv1: 伤害 100，目标血量 <30% 时 ×2
## Lv3: 伤害 150
## Lv5: 阈值 40%，×3
## Lv8: 伤害 240，阈值 50%，×4，并对周围 3 米溅射 50%

const RANGE: float = 5.0


func _init() -> void:
	skill_id = "eviscerate"
	display_name = "剔骨"
	max_level = 999


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 7.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var damage: float = 240.0 if tier >= 8 else (150.0 if tier >= 3 else 100.0)
	var threshold: float = (0.5 if tier >= 8 else (0.4 if tier >= 5 else 0.3)) + ctx.execute_bonus
	var mult: float = 4.0 if tier >= 8 else (3.0 if tier >= 5 else 2.0)
	var target: Variant = ctx.nearest_alive(RANGE)
	if target == null:
		return {"hits": 0, "damage": 0.0, "tier": tier}
	var ratio: float = 1.0
	if "current_health" in target and "max_health" in target and float(target.max_health) > 0.0:
		ratio = float(target.current_health) / float(target.max_health)
	var executed: bool = ratio <= threshold
	var pos: Vector3 = target.global_position
	var total: float = ctx.hit(target, damage * (mult if executed else 1.0), true)
	var hits: int = 1
	if tier >= 8:
		for t: Variant in ctx.targets_in_radius(pos, 3.0):
			if t != target:
				total += ctx.hit(t, damage * 0.5)
				hits += 1
	return {"hits": hits, "damage": total, "tier": tier, "executed": executed, "center": pos}
