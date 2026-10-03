class_name LavaBlast extends Skill
## 熔岩爆发：大范围AOE，燃烧+减速
## Lv1: 半径8米，伤害80，燃烧3秒(15DPS)
## Lv3: 半径1.3x
## Lv5: 伤害140，燃烧5秒(25DPS)
## Lv8: 伤害220，燃烧8秒(40DPS)，重击引爆

const BASE_RADIUS: float = 8.0
const BASE_DAMAGE: float = 80.0

func _init() -> void:
	skill_id = "lava_blast"
	display_name = "熔岩爆发"
	max_level = 999

func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]

func get_cooldown() -> float:
	return 10.0

func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var radius: float = BASE_RADIUS * (1.3 if tier >= 3 else 1.0) * ctx.area_mult
	var damage: float = BASE_DAMAGE
	if tier >= 5:
		damage = 140.0
	if tier >= 8:
		damage = 220.0

	var burn_dps: float = 15.0 if tier < 5 else (25.0 if tier < 8 else 40.0)
	var burn_dur: float = 3.0 if tier < 5 else (5.0 if tier < 8 else 8.0)
	var heavy: bool = tier >= 8

	var hits: int = 0
	var total: float = 0.0
	for t: Variant in ctx.targets_in_radius(ctx.origin, radius):
		var dealt: float = ctx.hit(t, damage)
		total += dealt
		hits += 1
		if t.is_alive and heavy:
			Reactions.ignite(t, ctx.targets)
		if t.is_alive:
			var s: StatusEffects = Reactions.status_of(t)
			if s != null:
				s.apply_burn(burn_dps, burn_dur, ctx.intensity * 0.5)

	return {"hits": hits, "damage": total, "tier": tier, "radius": radius}
