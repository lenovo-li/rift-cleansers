class_name Earthquake extends Skill
## 地震：大范围持续震荡，减速并造成周期伤害
## Lv1: 半径10米，持续5秒，每秒30伤害，减速40%
## Lv3: 半径1.3x，持续6秒
## Lv5: 伤害50/秒，减速60%
## Lv8: 伤害80/秒，持续8秒，每跳有30%几率眩晕0.5秒

const BASE_RADIUS: float = 10.0


func _init() -> void:
	skill_id = "earthquake"
	display_name = "地震"
	max_level = 999


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 18.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var radius: float = BASE_RADIUS * (1.3 if tier >= 3 else 1.0) * ctx.area_mult
	var duration: float = 8.0 if tier >= 8 else (6.0 if tier >= 3 else 5.0)
	var dps: float = 80.0 if tier >= 8 else (50.0 if tier >= 5 else 30.0)
	var slow: float = 0.6 if tier >= 5 else 0.4

	var zone: GroundZone = GroundZone.new(ctx.origin, ctx.origin, radius,
			dps * ctx.damage_mult, duration)
	zone.slow_factor = slow
	zone.slow_duration = 1.5
	zone.kind = "earthquake"
	ctx.new_zones.append(zone)

	return {"tier": tier, "radius": radius, "duration": duration}
