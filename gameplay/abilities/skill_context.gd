class_name SkillContext extends RefCounted
## 技能施放上下文：施法者位置与朝向、候选目标、施法者加成，以及技能新产生的地面效果。
## 目标对象需提供：global_position、is_alive、take_damage(float)、apply_knockback(Vector3)。
## 可选：status(StatusEffects)、apply_slow(factor, duration)、apply_magnet(Vector3)。

## 施法者（需有 global_position）。持续跟随类效果用它作为锚点，可为 null。
var caster: Object = null
var origin: Vector3 = Vector3.ZERO
var facing: Vector3 = Vector3.FORWARD
var targets: Array = []
var new_zones: Array[GroundZone] = []

## 施法者加成（来自被动、装备、怒气）。
var damage_mult: float = 1.0
var area_mult: float = 1.0
## 磁力战靴：被击退的敌人随后被拉回施法者身边。
var magnet: bool = false


## XZ 平面上的单位朝向；朝向为零时退回 Vector3.FORWARD。
func flat_facing() -> Vector3:
	var f: Vector3 = Vector3(facing.x, 0.0, facing.z)
	return Vector3.FORWARD if f.length_squared() < 0.0001 else f.normalized()


func alive_targets() -> Array:
	var result: Array = []
	for t: Variant in targets:
		if is_instance_valid(t) and t.is_alive:
			result.append(t)
	return result


## 造成技能伤害（已乘 damage_mult），返回实际伤害。
## heavy = 重击：命中燃烧目标时触发爆燃。
func hit(target: Variant, base_damage: float, heavy: bool = false) -> float:
	var damage: float = base_damage * damage_mult
	var was_burning: bool = heavy and Reactions.is_burning(target)
	target.take_damage(damage)
	if was_burning:
		Reactions.ignite(target, alive_targets())
	return damage


## 击退。被减速目标触发碎裂，返回碎裂额外伤害。
func push(target: Variant, impulse: Vector3, source_damage: float, allow_magnet: bool = true) -> float:
	var bonus: float = Reactions.shatter_bonus(target, source_damage)
	if bonus > 0.0 and target.is_alive:
		target.take_damage(bonus)
		Reactions._emit("shatter", target.global_position)
	if target.is_alive and target.has_method("apply_knockback"):
		target.apply_knockback(impulse)
		if magnet and allow_magnet and target.has_method("apply_magnet"):
			target.apply_magnet(origin)
	return bonus
