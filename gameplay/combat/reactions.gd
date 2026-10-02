class_name Reactions extends RefCounted
## 元素反应系统：
## - 基础反应：爆燃（火+重击）、碎裂（冰+击退）
## - 双元素反应：蒸发、超载、超导、扩散、融化、冰封等
## 目标只需提供 global_position / is_alive / take_damage，状态放在可选的 status 属性里。

const IGNITE_BASE_DAMAGE: float = 40.0
const IGNITE_RADIUS: float = 3.0
const SHATTER_RATIO: float = 0.5  # 碎裂额外伤害 = 击退来源伤害 × 0.5
const SHATTER_MIN: float = 15.0

# 新反应常量
const VAPORIZE_MULT: float = 1.5
const OVERLOAD_BASE: float = 80.0
const OVERLOAD_RADIUS: float = 4.0
const SUPERCONDUCT_RADIUS: float = 5.0
const SWIRL_RADIUS: float = 4.5
const MELT_MIN_INTENSITY: float = 40.0
const FREEZE_MIN_INTENSITY: float = 60.0
const ANNIHILATE_BASE: float = 200.0

## 表现层可以挂监听（反应名, 位置）。逻辑层不关心是否有人监听。
static var on_reaction: Callable = Callable()


static func status_of(target: Variant) -> StatusEffects:
	if target is Object and "status" in target:
		return target.status as StatusEffects
	return null


static func is_burning(target: Variant) -> bool:
	var s: StatusEffects = status_of(target)
	return s != null and s.is_burning()


static func is_slowed(target: Variant) -> bool:
	var s: StatusEffects = status_of(target)
	return s != null and s.is_slowed()


## 爆燃。返回造成伤害的目标数；目标不在燃烧时返回 0。
static func ignite(target: Variant, candidates: Array) -> int:
	var s: StatusEffects = status_of(target)
	if s == null or not s.is_burning():
		return 0
	var damage: float = IGNITE_BASE_DAMAGE + s.consume_burn()
	var center: Vector3 = target.global_position
	var hits: int = 0
	for c: Variant in candidates:
		if not is_instance_valid(c) or not c.is_alive:
			continue
		var d: Vector3 = c.global_position - center
		d.y = 0.0
		if d.length() <= IGNITE_RADIUS:
			c.take_damage(damage)
			hits += 1
	_emit("ignite", center)
	return hits


## 碎裂额外伤害；目标未被减速时返回 0。
static func shatter_bonus(target: Variant, source_damage: float) -> float:
	if not is_slowed(target):
		return 0.0
	return maxf(SHATTER_MIN, source_damage * SHATTER_RATIO)


static func _emit(reaction: String, pos: Vector3) -> void:
	if on_reaction.is_valid():
		on_reaction.call(reaction, pos)


## ===== 新增双元素反应 =====

## 蒸发（火+冰）：移除双方元素，造成爆发伤害
static func vaporize(target: Variant, fire_damage: float, ice_damage: float) -> Dictionary:
	var s: StatusEffects = status_of(target)
	if s == null or s.fire_intensity < 20.0 or s.ice_intensity < 20.0:
		return {}

	var base: float = fire_damage + ice_damage
	var bonus: float = (s.fire_intensity + s.ice_intensity) * 0.5
	var total: float = base * VAPORIZE_MULT + bonus

	# 消耗双方元素
	s.fire_intensity = 0.0
	s.ice_intensity = 0.0
	s.burn_remaining = 0.0
	s.frozen_remaining = 0.0
	s.slow_remaining = 0.0

	_emit("vaporize", target.global_position)
	return {"damage": total, "reaction": "vaporize"}


## 超载（火+雷）：范围爆炸+击退
static func overload(target: Variant, candidates: Array) -> Dictionary:
	var s: StatusEffects = status_of(target)
	if s == null or s.fire_intensity < 20.0 or s.lightning_intensity < 20.0:
		return {}

	var explosion_damage: float = OVERLOAD_BASE + (s.fire_intensity + s.lightning_intensity) * 0.8
	var center: Vector3 = target.global_position
	var hits: int = 0

	for c: Variant in candidates:
		if not is_instance_valid(c) or not c.is_alive:
			continue
		var dist: float = (c.global_position - center).length()
		if dist <= OVERLOAD_RADIUS:
			c.take_damage(explosion_damage)
			# 击退
			if c.has_method("apply_impulse"):
				var dir: Vector3 = (c.global_position - center).normalized()
				c.apply_impulse(dir * 8.0)
			hits += 1

	# 消耗双方元素
	s.fire_intensity = 0.0
	s.lightning_intensity = 0.0

	_emit("overload", center)
	return {"hits": hits, "damage": explosion_damage, "reaction": "overload"}


## 超导（冰+雷）：范围感电
static func superconduct(target: Variant, candidates: Array, duration: float = 8.0) -> Dictionary:
	var s: StatusEffects = status_of(target)
	if s == null or s.ice_intensity < 20.0 or s.lightning_intensity < 20.0:
		return {}

	var center: Vector3 = target.global_position
	var affected: int = 0

	for c: Variant in candidates:
		if not is_instance_valid(c) or not c.is_alive:
			continue
		var dist: float = (c.global_position - center).length()
		if dist <= SUPERCONDUCT_RADIUS:
			var cs: StatusEffects = status_of(c)
			if cs != null:
				cs.apply_shocked(2, duration, 20.0)
			affected += 1

	_emit("superconduct", center)
	return {"affected": affected, "reaction": "superconduct"}


## 扩散（风+元素）：将元素效果传播到周围
static func swirl(target: Variant, candidates: Array, element: String) -> Dictionary:
	var s: StatusEffects = status_of(target)
	if s == null:
		return {}

	var spread: int = 0
	var center: Vector3 = target.global_position

	for c: Variant in candidates:
		if c == target or not is_instance_valid(c) or not c.is_alive:
			continue
		var dist: float = (c.global_position - center).length()
		if dist <= SWIRL_RADIUS:
			var cs: StatusEffects = status_of(c)
			if cs != null:
				match element:
					"fire":
						if s.is_burning():
							cs.apply_burn(s.burn_dps * 0.5, 2.0, s.fire_intensity * 0.3)
					"ice":
						if s.is_slowed():
							cs.apply_slow(s.slow_factor * 0.7, 2.0)
					"lightning":
						if s.is_shocked():
							cs.apply_shocked(1, 3.0, s.lightning_intensity * 0.3)
					"poison":
						if s.is_poisoned():
							cs.apply_poisoned(s.poisoned_dps * 0.5, 2.0, 0.3, s.poison_intensity * 0.3)
				spread += 1

	_emit("swirl_" + element, center)
	return {"spread": spread, "reaction": "swirl", "element": element}


## 融化（火+冰高强度）：巨额单体伤害
static func melt(target: Variant, base_damage: float) -> Dictionary:
	var s: StatusEffects = status_of(target)
	if s == null:
		return {}

	var fire: float = s.fire_intensity
	var ice: float = s.ice_intensity

	# 需要双方都高强度
	if fire < MELT_MIN_INTENSITY or ice < MELT_MIN_INTENSITY:
		return {}

	var mult: float = 1.5 + (fire + ice) * 0.01  # 1.5x ~ 2.5x
	var damage: float = base_damage * mult

	# 消耗元素
	s.fire_intensity *= 0.3
	s.ice_intensity *= 0.3

	_emit("melt", target.global_position)
	return {"damage": damage, "mult": mult, "reaction": "melt"}


## 冰封（冰高强度）：完全冰冻
static func freeze(target: Variant, duration: float = 2.0) -> Dictionary:
	var s: StatusEffects = status_of(target)
	if s == null or s.ice_intensity < FREEZE_MIN_INTENSITY:
		return {}

	s.apply_frozen(duration, 0.0)
	s.ice_intensity *= 0.5  # 消耗一半强度

	_emit("freeze", target.global_position)
	return {"duration": duration, "reaction": "freeze"}


## 元素湮灭（3+种元素）：巨额伤害+清除所有元素
static func annihilate(target: Variant) -> Dictionary:
	var s: StatusEffects = status_of(target)
	if s == null:
		return {}

	var element_count: int = s.element_count()
	if element_count < 3:
		return {}

	var total_intensity: float = s.fire_intensity + s.ice_intensity + s.lightning_intensity + s.poison_intensity
	var damage: float = ANNIHILATE_BASE + total_intensity * 2.0
	target.take_damage(damage)

	# 清除所有元素
	s.fire_intensity = 0.0
	s.ice_intensity = 0.0
	s.lightning_intensity = 0.0
	s.poison_intensity = 0.0
	s.burn_remaining = 0.0
	s.poisoned_remaining = 0.0
	s.shocked_remaining = 0.0
	s.frozen_remaining = 0.0

	_emit("annihilate", target.global_position)
	return {"damage": damage, "elements": element_count, "reaction": "annihilate"}
