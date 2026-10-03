class_name SmokeBomb extends Skill
## 烟雾弹：在脚下炸开烟幕，施法者短暂无敌；烟里的敌人被大幅减速并持续受伤。
## Lv1: 半径 4 米，4 秒，减速 50%，10 DPS，无敌 1 秒
## Lv3: 无敌 1.5 秒
## Lv5: 半径 1.3x，烟里的敌人被标记（+30% 受伤）
## Lv8: 持续 6 秒，DPS 3x

const BASE_RADIUS: float = 4.0
const BASE_DPS: float = 10.0


func _init() -> void:
	skill_id = "smoke_bomb"
	display_name = "烟雾弹"
	max_level = 999


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 12.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var radius: float = BASE_RADIUS * (1.3 if tier >= 5 else 1.0) * ctx.area_mult
	var duration: float = 6.0 if tier >= 8 else 4.0
	var zone: GroundZone = GroundZone.new(ctx.origin, ctx.origin, radius,
			BASE_DPS * (3.0 if tier >= 8 else 1.0) * ctx.damage_mult, duration)
	zone.slow_factor = 0.5
	zone.slow_duration = 0.8
	zone.kind = "smoke"
	ctx.new_zones.append(zone)
	var marked: int = 0
	if tier >= 5:
		for t: Variant in ctx.targets_in_radius(ctx.origin, radius):
			var st: StatusEffects = Reactions.status_of(t)
			if st != null:
				st.apply_mark(0.3, duration)
				marked += 1
	return {"hits": marked, "damage": 0.0, "tier": tier, "radius": radius, "duration": duration,
		"invulnerable": 1.5 if tier >= 3 else 1.0}
