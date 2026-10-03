class_name StormField extends Skill
## 雷暴领域：在自身周围持续放电，每 0.5 秒伤害一次（升级后变成跟随光环）。
## Lv1: 半径 6 米，持续 6 秒，12 DPS，跟随术士
## Lv3: 半径 1.3x
## Lv5: 持续 8 秒，附加 30% 减速
## Lv8: DPS 2x，每一跳都算重击（引爆燃烧 = 爆燃）

const BASE_RADIUS: float = 6.0
const BASE_DPS: float = 12.0


func _init() -> void:
	skill_id = "storm_field"
	display_name = "雷暴领域"
	max_level = 999


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 12.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var radius: float = BASE_RADIUS * (1.3 if tier >= 3 else 1.0) * ctx.area_mult
	var dps: float = BASE_DPS * (2.0 if tier >= 8 else 1.0) * ctx.damage_mult
	var duration: float = 8.0 if tier >= 5 else 6.0
	var zone: GroundZone = GroundZone.new(ctx.origin, ctx.origin, radius, dps, duration)
	zone.anchor = ctx.caster  # 跟随术士移动
	zone.kind = "lightning"
	zone.heavy = tier >= 8
	if tier >= 5:
		zone.slow_factor = 0.3
		zone.slow_duration = 0.6
	ctx.new_zones.append(zone)
	return {"tier": tier, "radius": radius, "duration": duration}
