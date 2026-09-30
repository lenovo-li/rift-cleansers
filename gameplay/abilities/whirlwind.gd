class_name Whirlwind extends Skill
## 旋风斩：以施法者为中心的持续圆形伤害，跟随施法者移动。
## Lv1: 半径4米，30DPS，持续3秒
## Lv3: 伤害1.3x，命中减速50%（1秒）
## Lv5: 半径1.3x，冷却0.8x
## Lv8: 伤害2x，持续1.5x

const BASE_DPS: float = 30.0
const BASE_RADIUS: float = 4.0
const BASE_DURATION: float = 3.0


func _init() -> void:
	skill_id = "whirlwind"
	display_name = "旋风斩"
	max_level = 8


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 8.0 * (0.8 if get_tier() >= 5 else 1.0)


func get_radius() -> float:
	return BASE_RADIUS * (1.3 if get_tier() >= 5 else 1.0)


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var radius: float = get_radius() * ctx.area_mult
	var duration: float = BASE_DURATION * (1.5 if tier >= 8 else 1.0)
	var dps: float = BASE_DPS
	if tier >= 8:
		dps *= 2.0
	elif tier >= 3:
		dps *= 1.3

	# 创建跟随施法者的圆形持续伤害区域
	var zone: GroundZone = GroundZone.new(ctx.origin, ctx.origin, radius, dps * ctx.damage_mult, duration)
	zone.anchor = ctx.caster
	zone.kind = "whirl"
	if tier >= 3:
		zone.slow_factor = 0.5
		zone.slow_duration = 1.0
	ctx.new_zones.append(zone)

	return {"hits": 0, "damage": 0.0, "tier": tier, "duration": duration, "radius": radius}
