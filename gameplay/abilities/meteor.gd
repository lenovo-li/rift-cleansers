class_name Meteor extends Skill
## 陨石术：天降火球，1.2 秒后砸向敌人最密集处，大范围伤害并向外击退（被减速 = 碎裂，燃烧 = 爆燃）。
## Lv1: 半径 5 米，伤害 120，燃烧 18 DPS 4 秒
## Lv3: 半径 1.3x
## Lv5: 伤害 1.5x，击退距离 +30%
## Lv8: 伤害 2x（= 360），冲击波第二圈 50% 伤害

const DELAY: float = 1.2
const BASE_RADIUS: float = 5.0
const BASE_DAMAGE: float = 120.0
const KNOCKBACK: float = 6.0
const BURN_DPS: float = 18.0


func _init() -> void:
	skill_id = "meteor"
	display_name = "陨石术"
	max_level = 8


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 9.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var radius: float = BASE_RADIUS * (1.3 if tier >= 3 else 1.0) * ctx.area_mult
	var damage: float = BASE_DAMAGE * (1.5 if tier >= 5 else 1.0) * (2.0 if tier >= 8 else 1.0)
	var push: float = KNOCKBACK * (1.3 if tier >= 5 else 1.0)
	var burn: float = BURN_DPS * ctx.damage_mult
	# 找敌人最密集的点（5 米内邻居数）
	var best: Variant = null
	var best_count: int = 0
	for t: Variant in ctx.alive_targets():
		var count: int = 0
		for other: Variant in ctx.alive_targets():
			if t != other and (t.global_position - other.global_position).length_squared() < 25.0:
				count += 1
		if count > best_count:
			best_count = count
			best = t
	var center: Vector3 = best.global_position if best != null else ctx.origin + ctx.flat_facing() * 10.0
	ctx.queue_strike(DELAY, center, radius, damage, push, burn, tier >= 8)
	return {"tier": tier, "center": center, "radius": radius, "delay": DELAY}
