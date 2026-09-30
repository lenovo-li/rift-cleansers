class_name Reactions extends RefCounted
## 元素反应（文档 05 §1.7）：
## - 爆燃：燃烧中的目标受到重击时爆炸，剩余燃烧伤害 + 基础伤害作用于周围敌人。
## - 碎裂：被减速的目标受到击退时，额外承受一次伤害。
## 目标只需提供 global_position / is_alive / take_damage，状态放在可选的 status 属性里。

const IGNITE_BASE_DAMAGE: float = 40.0
const IGNITE_RADIUS: float = 3.0
const SHATTER_RATIO: float = 0.5  # 碎裂额外伤害 = 击退来源伤害 × 0.5
const SHATTER_MIN: float = 15.0

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
