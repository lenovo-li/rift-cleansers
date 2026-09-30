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
## 延迟打击（陨石术），见 queue_strike。
var new_strikes: Array[Dictionary] = []

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


## 返回距离施法者 max_range 内最近的 count 个敌人（用于火球/闪电链选目标）。
func nearest_targets(max_range: float, count: int) -> Array:
	var candidates: Array = []
	var r2: float = max_range * max_range
	for t: Variant in alive_targets():
		var d2: float = (t.global_position - origin).length_squared()
		if d2 < r2:
			candidates.append([d2, t])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var result: Array = []
	for i in mini(count, candidates.size()):
		result.append(candidates[i][1])
	return result


## 朝最近的敌人瞄准，返回单位方向向量（用于冰枪/火球的自动瞄准）。没有敌人时用面朝方向。
func aim_direction(max_range: float) -> Vector3:
	var list: Array = nearest_targets(max_range, 1)
	if list.is_empty():
		return flat_facing()
	var dir: Vector3 = (list[0].global_position - origin) * Vector3(1, 0, 1)
	return dir.normalized() if dir.length() > 0.01 else flat_facing()


## 排队延迟打击（陨石术）：AbilitySystem.cast 收走 new_strikes，tick 倒计时到 0 时结算。
## damage 为基础伤害，这里乘上施法时的 damage_mult 锁定。
func queue_strike(delay: float, center: Vector3, radius: float, damage: float, knockback: float, burn_dps: float, second_wave: bool) -> void:
	new_strikes.append({
		"delay": delay, "center": center, "radius": radius, "damage": damage * damage_mult,
		"knockback": knockback, "burn": burn_dps, "second_wave": second_wave, "magnet": magnet,
	})


## 目标中心 radius 内的存活敌人。
func targets_in_radius(center: Vector3, radius: float) -> Array:
	var result: Array = []
	var r2: float = radius * radius
	for t: Variant in alive_targets():
		var d: Vector3 = (t.global_position - center) * Vector3(1, 0, 1)
		if d.length_squared() <= r2:
			result.append(t)
	return result
