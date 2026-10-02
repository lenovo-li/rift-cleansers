class_name ShadowClone extends Skill
## 影分身：在身旁留下暗影分身，持续对周围敌人挥砍（跟随施法者的暗影区域，附带暗影元素→虚弱）。
## Lv1: 持续 8 秒，半径 3.5 米，35 DPS
## Lv3: 持续 12 秒
## Lv5: 55 DPS，半径 4.5 米
## Lv8: 持续 15 秒，90 DPS，分身挥砍算重击（引爆燃烧）

func _init() -> void:
	skill_id = "shadow_clone"
	display_name = "影分身"
	max_level = 8


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 20.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var duration: float = 15.0 if tier >= 8 else (12.0 if tier >= 3 else 8.0)
	var dps: float = (90.0 if tier >= 8 else (55.0 if tier >= 5 else 35.0)) * ctx.damage_mult
	var radius: float = (4.5 if tier >= 5 else 3.5) * ctx.area_mult
	var zone: GroundZone = GroundZone.new(ctx.origin, ctx.origin, radius, dps, duration)
	zone.anchor = ctx.caster
	zone.kind = "shadow"
	zone.heavy = tier >= 8
	ctx.new_zones.append(zone)
	return {"hits": 0, "damage": 0.0, "tier": tier, "duration": duration, "radius": radius}
