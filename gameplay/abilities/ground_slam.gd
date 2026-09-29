class_name GroundSlam extends Skill
## 震地：以施法者为中心的范围重击 + 减速（范围控制）。
## Lv1: 半径5米，伤害60，减速50%（2秒）
## Lv3: 半径1.3x
## Lv5: 留下4秒余震地带（15DPS，持续减速）
## Lv8: 伤害2x，并把敌人向外震开——被减速的敌人触发碎裂

const BASE_RADIUS: float = 5.0
const BASE_DAMAGE: float = 60.0
const KNOCKBACK_FORCE: float = 6.0


func _init() -> void:
	skill_id = "ground_slam"
	display_name = "震地"
	max_level = 8


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 9.0


func get_radius() -> float:
	return BASE_RADIUS * (1.3 if get_tier() >= 3 else 1.0)


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var radius: float = get_radius() * ctx.area_mult
	var damage: float = BASE_DAMAGE * (2.0 if tier >= 8 else 1.0)
	var hits: int = 0
	var total_damage: float = 0.0

	for target: Variant in ctx.alive_targets():
		var offset: Vector3 = target.global_position - ctx.origin
		offset.y = 0.0
		var dist: float = offset.length()
		if dist > radius:
			continue
		hits += 1
		# 先重击（爆燃）、再击退（碎裂只吃之前的减速）、最后附加本次减速
		var dealt: float = ctx.hit(target, damage, true)
		total_damage += dealt
		if tier >= 8 and target.is_alive:
			var dir: Vector3 = offset / dist if dist > 0.01 else ctx.flat_facing()
			total_damage += ctx.push(target, dir * KNOCKBACK_FORCE, dealt)
		if target.is_alive and target.has_method("apply_slow"):
			target.apply_slow(0.5, 2.0)

	if tier >= 5:
		var zone: GroundZone = GroundZone.new(ctx.origin, ctx.origin, radius, 15.0 * ctx.damage_mult, 4.0)
		zone.slow_factor = 0.5
		zone.slow_duration = 1.0
		zone.kind = "slam"
		ctx.new_zones.append(zone)

	return {"hits": hits, "damage": total_damage, "tier": tier, "radius": radius}
