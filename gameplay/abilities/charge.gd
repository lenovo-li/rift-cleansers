class_name Charge extends Skill
## 冲锋：沿朝向冲出一段距离，撞击路径上所有敌人并向两侧击退。
## 施法者的位移由调用方根据返回的 end_position 执行（技能不改场景树）。
## Lv1: 距离8米，伤害40，路径宽1.5米
## Lv3: 伤害1.5x，距离1.25x
## Lv5: 终点冲击波，半径3.5米，伤害30
## Lv8: 路径上的敌人被点燃（15DPS，3秒），冷却0.7x

const BASE_DISTANCE: float = 8.0
const BASE_DAMAGE: float = 40.0
const HALF_WIDTH: float = 1.5
const KNOCKBACK_FORCE: float = 7.0
const IMPACT_RADIUS: float = 3.5
const IMPACT_DAMAGE: float = 30.0
const BURN_DPS: float = 15.0


func _init() -> void:
	skill_id = "charge"
	display_name = "冲锋"
	max_level = 8


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 7.0 * (0.7 if get_tier() >= 8 else 1.0)


func get_distance() -> float:
	return BASE_DISTANCE * (1.25 if get_tier() >= 3 else 1.0)


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var facing: Vector3 = ctx.flat_facing()
	var start: Vector3 = ctx.origin
	var end: Vector3 = start + facing * get_distance()
	var damage: float = BASE_DAMAGE * (1.5 if tier >= 3 else 1.0)
	var side: Vector3 = facing.cross(Vector3.UP)
	var hits: int = 0
	var total_damage: float = 0.0

	for target: Variant in ctx.alive_targets():
		if GroundZone.distance_xz_to_segment(target.global_position, start, end) > HALF_WIDTH:
			continue
		var dealt: float = ctx.hit(target, damage, true)
		total_damage += dealt
		hits += 1
		if tier >= 8 and target.is_alive:
			var s: StatusEffects = Reactions.status_of(target)
			if s != null:
				s.apply_burn(BURN_DPS * ctx.damage_mult, 3.0)
		if target.is_alive:
			# 往路径两侧推开，同时带一点前冲方向
			var rel: Vector3 = target.global_position - start
			var sign: float = 1.0 if rel.dot(side) >= 0.0 else -1.0
			var dir: Vector3 = (side * sign + facing * 0.5).normalized()
			total_damage += ctx.push(target, dir * KNOCKBACK_FORCE, dealt)

	if tier >= 5:
		for target: Variant in ctx.alive_targets():
			var d: Vector3 = target.global_position - end
			d.y = 0.0
			if d.length() <= IMPACT_RADIUS:
				total_damage += ctx.hit(target, IMPACT_DAMAGE)
				hits += 1

	return {"hits": hits, "damage": total_damage, "tier": tier, "end_position": end}
