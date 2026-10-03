class_name BladeFlurry extends Skill
## 刃舞：身边刀光环绕，跟随施法者持续切割（每 0.5 秒一次）。
## Lv1: 半径 2.8 米，40 DPS，3 秒
## Lv3: 持续 4.5 秒
## Lv5: 半径 1.4x
## Lv8: DPS 2x，每一跳都算重击（引爆燃烧 = 爆燃）

const BASE_RADIUS: float = 2.8
const BASE_DPS: float = 40.0


func _init() -> void:
	skill_id = "blade_flurry"
	display_name = "刃舞"
	max_level = 999


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 8.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var radius: float = BASE_RADIUS * (1.4 if tier >= 5 else 1.0) * ctx.area_mult
	var dps: float = BASE_DPS * (2.0 if tier >= 8 else 1.0) * ctx.damage_mult
	var duration: float = 4.5 if tier >= 3 else 3.0
	var zone: GroundZone = GroundZone.new(ctx.origin, ctx.origin, radius, dps, duration)
	zone.anchor = ctx.caster
	zone.kind = "blades"
	zone.heavy = tier >= 8
	ctx.new_zones.append(zone)
	return {"tier": tier, "radius": radius, "duration": duration}
