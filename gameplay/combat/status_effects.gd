class_name StatusEffects extends RefCounted
## 单个实体身上的状态效果（燃烧、减速）。纯逻辑，不依赖场景树。
## 宿主每帧调用 tick(delta)，返回本帧应结算的燃烧伤害。

const BURN_TICK: float = 0.5

var burn_dps: float = 0.0
var burn_remaining: float = 0.0
var slow_factor: float = 0.0  # 0 = 不减速，0.5 = 移速减半
var slow_remaining: float = 0.0
var _burn_timer: float = 0.0


func apply_burn(dps: float, duration: float) -> void:
	# 燃烧不叠层：取更高的 DPS，刷新持续时间
	burn_dps = maxf(burn_dps, dps)
	burn_remaining = maxf(burn_remaining, duration)


func apply_slow(factor: float, duration: float) -> void:
	slow_factor = maxf(slow_factor, clampf(factor, 0.0, 0.9))
	slow_remaining = maxf(slow_remaining, duration)


func is_burning() -> bool:
	return burn_remaining > 0.0


func is_slowed() -> bool:
	return slow_remaining > 0.0


func speed_multiplier() -> float:
	return 1.0 - slow_factor if is_slowed() else 1.0


## 取走剩余的燃烧伤害并清除燃烧（爆燃反应用）。
func consume_burn() -> float:
	var left: float = burn_dps * burn_remaining
	burn_dps = 0.0
	burn_remaining = 0.0
	_burn_timer = 0.0
	return left


## 推进时间，返回本帧产生的燃烧伤害（每 BURN_TICK 结算一次）。
func tick(delta: float) -> float:
	var damage: float = 0.0
	if burn_remaining > 0.0:
		var step: float = minf(delta, burn_remaining)
		burn_remaining -= delta
		_burn_timer += step
		while _burn_timer >= BURN_TICK - 0.0001:  # 容忍浮点累积误差
			_burn_timer -= BURN_TICK
			damage += burn_dps * BURN_TICK
		if burn_remaining <= 0.0:
			burn_dps = 0.0
			_burn_timer = 0.0
	if slow_remaining > 0.0:
		slow_remaining -= delta
		if slow_remaining <= 0.0:
			slow_factor = 0.0
	return damage
