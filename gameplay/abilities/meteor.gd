class_name Meteor extends Skill
## 陨石术：天降火球，1.2 秒后砸向鼠标落点（无鼠标时砸向敌人最密集处），大范围伤害并向外击退（被减速 = 碎裂，燃烧 = 爆燃）。
## Lv1: 半径 5 米，伤害 120，燃烧 18 DPS 4 秒
## Lv3: 半径 1.3x
## Lv5: 伤害 1.5x，击退距离 +30%
## Lv8: 伤害 2x（= 360），冲击波第二圈 50% 伤害

const DELAY: float = 1.2
const BASE_RADIUS: float = 5.0
const BASE_DAMAGE: float = 120.0
const KNOCKBACK: float = 6.0
const BURN_DPS: float = 18.0
## 鼠标瞄准时的最大施法距离（米）
const MAX_RANGE: float = 22.0


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

	var center: Vector3 = target_point(ctx)
	ctx.queue_strike(DELAY, center, radius, damage, push, burn, tier >= 8)
	return {"tier": tier, "center": center, "radius": radius, "delay": DELAY}


## 落点：有瞄准点（鼠标）时落在瞄准点，超出 MAX_RANGE 则收到边缘；
## 没有瞄准点（手柄、机器人、自动施放）时砸向敌人最密集处（5 米内邻居最多的敌人）。
static func target_point(ctx: SkillContext) -> Vector3:
	if ctx.has_aim:
		var off: Vector3 = (ctx.aim_point - ctx.origin) * Vector3(1, 0, 1)
		return ctx.origin + off.limit_length(MAX_RANGE)
	var best: Variant = null
	var best_count: int = 0
	var alive: Array = ctx.alive_targets()
	for t: Variant in alive:
		var count: int = 0
		for other: Variant in alive:
			if t != other and (t.global_position - other.global_position).length_squared() < 25.0:
				count += 1
		if count > best_count:
			best_count = count
			best = t
	return best.global_position if best != null else ctx.origin + ctx.flat_facing() * 10.0
