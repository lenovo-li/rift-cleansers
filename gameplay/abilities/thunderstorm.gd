class_name Thunderstorm extends Skill
## 雷暴：持续闪电打击区域内随机敌人
## Lv1: 10秒，每秒3次打击，各25伤害，半径10米
## Lv3: 每秒5次
## Lv5: 各40伤害
## Lv8: 15秒，各65伤害，感电叠加到15层

const BASE_RADIUS: float = 10.0

func _init() -> void:
	skill_id = "thunderstorm"
	display_name = "雷暴"
	max_level = 999

func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]

func get_cooldown() -> float:
	return 18.0

func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var duration: float = 15.0 if tier >= 8 else 10.0
	var strikes_per_sec: int = 5 if tier >= 3 else 3
	var damage: float = 25.0 if tier < 5 else (40.0 if tier < 8 else 65.0)
	damage *= ctx.damage_mult

	# 简化：创建持续区域
	var zone: GroundZone = GroundZone.new(ctx.origin, ctx.origin, BASE_RADIUS * ctx.area_mult,
			damage * strikes_per_sec, duration)
	zone.kind = "thunderstorm"
	zone.element = "lightning"
	zone.intensity = ctx.intensity
	ctx.new_zones.append(zone)

	return {"tier": tier, "duration": duration, "radius": BASE_RADIUS}
