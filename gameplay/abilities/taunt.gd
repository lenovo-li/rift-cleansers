class_name Taunt extends Skill
## 嘲讽：把周围敌人拉到施法者身边（聚怪），配合旋风斩/震地收割。
## Lv1: 半径7米，拉向施法者
## Lv3: 半径1.3x，被拉敌人减速40%（2秒）——可与击退组成碎裂
## Lv5: 每拉到一个敌人获得4点护盾（上限80）
## Lv8: 冷却0.7x，拉拢后在身边造成一次冲击

const BASE_RADIUS: float = 7.0
const PULL_STOP_DISTANCE: float = 1.5
## 敌人击退速度按每帧 ×0.9 衰减，总位移约为初速度的 1/6。
const PULL_VELOCITY_PER_METER: float = 6.0
const MAX_PULL_SPEED: float = 45.0
const SHIELD_PER_TARGET: float = 4.0
const MAX_SHIELD: float = 80.0
const IMPACT_DAMAGE: float = 40.0


func _init() -> void:
	skill_id = "taunt"
	display_name = "嘲讽"
	max_level = 8


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 6.0 * (0.7 if get_tier() >= 8 else 1.0)


func get_radius() -> float:
	return BASE_RADIUS * (1.3 if get_tier() >= 3 else 1.0)


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var radius: float = get_radius() * ctx.area_mult
	var pulled: int = 0
	var total_damage: float = 0.0
	for target: Variant in ctx.alive_targets():
		var offset: Vector3 = ctx.origin - target.global_position
		offset.y = 0.0
		var dist: float = offset.length()
		if dist > radius:
			continue
		pulled += 1
		if tier >= 3 and target.has_method("apply_slow"):
			target.apply_slow(0.4, 2.0)
		if dist > PULL_STOP_DISTANCE:
			var speed: float = minf(MAX_PULL_SPEED, (dist - PULL_STOP_DISTANCE) * PULL_VELOCITY_PER_METER)
			if target.has_method("apply_knockback"):
				target.apply_knockback(offset / dist * speed)
		if tier >= 8:
			total_damage += ctx.hit(target, IMPACT_DAMAGE, true)

	var shield: float = 0.0
	if tier >= 5:
		shield = minf(MAX_SHIELD, pulled * SHIELD_PER_TARGET)
	return {"hits": pulled, "damage": total_damage, "tier": tier, "shield": shield, "radius": radius}
