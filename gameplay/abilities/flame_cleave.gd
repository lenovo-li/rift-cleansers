class_name FlameCleave extends Skill
## 烈焰斩：向前挥砍，留下火焰地带（伤害+控场）
## Lv1: 前方锥形6米，伤害70，留下3秒火焰（20DPS）
## Lv3: 范围1.3x
## Lv5: 伤害120，火焰5秒，30DPS
## Lv8: 伤害200，火焰持续8秒，50DPS，重击引爆燃烧

const BASE_RANGE: float = 6.0
const BASE_DAMAGE: float = 70.0
const CONE_ANGLE: float = 60.0


func _init() -> void:
	skill_id = "flame_cleave"
	display_name = "烈焰斩"
	max_level = 8


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 7.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var range_val: float = BASE_RANGE * (1.3 if tier >= 3 else 1.0) * ctx.area_mult
	var damage: float = BASE_DAMAGE * ctx.damage_mult
	if tier >= 5:
		damage = 120.0 * ctx.damage_mult
	if tier >= 8:
		damage = 200.0 * ctx.damage_mult

	var duration: float = 8.0 if tier >= 8 else (5.0 if tier >= 5 else 3.0)
	var dps: float = (50.0 if tier >= 8 else (30.0 if tier >= 5 else 20.0)) * ctx.damage_mult

	var hits: int = 0
	var total: float = 0.0
	for t: Variant in ctx.targets_in_cone(ctx.origin, ctx.facing, range_val, CONE_ANGLE):
		var dealt: float = ctx.hit(t, damage)
		total += dealt
		hits += 1

	# 留下火焰地带
	var end: Vector3 = ctx.origin + ctx.facing * range_val
	var zone: GroundZone = GroundZone.new(ctx.origin, end, 2.5, dps, duration)
	zone.kind = "flame"
	zone.heavy = tier >= 8
	ctx.new_zones.append(zone)

	return {"hits": hits, "damage": total, "tier": tier}
