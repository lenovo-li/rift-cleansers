class_name Sanctuary extends Skill
## 圣域：在脚下展开圣地，圈内敌人持续受伤并减速，圈内队友持续回血。
## Lv1: 半径 5 米，6 秒，敌人 15 DPS、减速 25%，队友每秒回复 15
## Lv3: 半径 1.3x
## Lv5: 回复 2x，持续 8 秒
## Lv8: DPS 3x，每一跳都算重击（引爆燃烧 = 爆燃）

const BASE_RADIUS: float = 5.0
const BASE_DPS: float = 15.0
const BASE_HEAL: float = 15.0


func _init() -> void:
	skill_id = "sanctuary"
	display_name = "圣域"
	max_level = 999


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 12.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var radius: float = BASE_RADIUS * (1.3 if tier >= 3 else 1.0) * ctx.area_mult
	var duration: float = 8.0 if tier >= 5 else 6.0
	var zone: GroundZone = GroundZone.new(ctx.origin, ctx.origin, radius,
			BASE_DPS * (3.0 if tier >= 8 else 1.0) * ctx.damage_mult, duration)
	zone.slow_factor = 0.25
	zone.slow_duration = 0.6
	zone.heal_per_second = BASE_HEAL * (2.0 if tier >= 5 else 1.0) * ctx.heal_mult
	zone.heavy = tier >= 8
	zone.kind = "holy"
	ctx.new_zones.append(zone)
	return {"tier": tier, "radius": radius, "duration": duration, "heal_per_second": zone.heal_per_second}
