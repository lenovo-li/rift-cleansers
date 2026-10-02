class_name StatusEffects extends RefCounted
## 单个实体身上的状态效果（燃烧、减速、感电、中毒等）。纯逻辑，不依赖场景树。
## 宿主每帧调用 tick(delta)，返回本帧应结算的燃烧伤害。

const BURN_TICK: float = 0.5

# ===== 基础状态（已有）=====
var burn_dps: float = 0.0
var burn_remaining: float = 0.0
var slow_factor: float = 0.0  # 0 = 不减速，0.5 = 移速减半
var slow_remaining: float = 0.0
## 死亡标记（影行者）：受到的所有伤害 ×(1 + mark_bonus)。
var mark_bonus: float = 0.0
var mark_remaining: float = 0.0
var _burn_timer: float = 0.0

# ===== 新增状态 =====
## 感电：每层+5%受到伤害，最多10层
var shocked_stacks: int = 0
var shocked_remaining: float = 0.0

## 中毒：持续伤害+治疗降低
var poisoned_dps: float = 0.0
var poisoned_remaining: float = 0.0
var poison_healing_reduction: float = 0.0  # 0.5 = 治疗效果-50%

## 冰冻：完全定身（覆盖减速）
var frozen_remaining: float = 0.0

## 虚弱：伤害输出降低
var weakened_reduction: float = 0.0  # 0.3 = 伤害-30%
var weakened_remaining: float = 0.0

## 腐蚀：受到伤害增加（腐蚀反应）
var corroded: float = 0.0  # 剩余时间

## 反应冷却：防止持续区域每跳都触发反应
var reaction_cooldown: float = 0.0

# ===== 元素强度（用于反应判定）=====
var fire_intensity: float = 0.0      # 火元素强度（0-100）
var ice_intensity: float = 0.0       # 冰元素强度
var lightning_intensity: float = 0.0 # 雷元素强度
var poison_intensity: float = 0.0    # 毒元素强度


func apply_burn(dps: float, duration: float, intensity: float = 0.0) -> void:
	# 燃烧不叠层：取更高的 DPS，刷新持续时间
	burn_dps = maxf(burn_dps, dps)
	burn_remaining = maxf(burn_remaining, duration)
	fire_intensity = minf(100.0, fire_intensity + intensity)


func apply_slow(factor: float, duration: float, intensity: float = 0.0) -> void:
	slow_factor = maxf(slow_factor, clampf(factor, 0.0, 0.9))
	slow_remaining = maxf(slow_remaining, duration)
	ice_intensity = minf(100.0, ice_intensity + intensity)


func apply_mark(bonus: float, duration: float) -> void:
	mark_bonus = maxf(mark_bonus, bonus)
	mark_remaining = maxf(mark_remaining, duration)


func apply_shocked(stacks: int, duration: float, intensity: float = 0.0, cap: int = 10) -> void:
	shocked_stacks = mini(cap, shocked_stacks + stacks)
	shocked_remaining = maxf(shocked_remaining, duration)
	lightning_intensity = minf(100.0, lightning_intensity + intensity)


func apply_frozen(duration: float, intensity: float = 0.0) -> void:
	frozen_remaining = duration
	ice_intensity = minf(100.0, ice_intensity + intensity)
	# 冰冻覆盖减速
	slow_factor = 0.0
	slow_remaining = 0.0


func apply_poisoned(dps: float, duration: float, healing_reduction: float = 0.5, intensity: float = 0.0) -> void:
	poisoned_dps = maxf(poisoned_dps, dps)
	poisoned_remaining = maxf(poisoned_remaining, duration)
	poison_healing_reduction = maxf(poison_healing_reduction, healing_reduction)
	poison_intensity = minf(100.0, poison_intensity + intensity)


func apply_weakened(reduction: float, duration: float) -> void:
	weakened_reduction = maxf(weakened_reduction, clampf(reduction, 0.0, 0.5))
	weakened_remaining = maxf(weakened_remaining, duration)


func is_marked() -> bool:
	return mark_remaining > 0.0


func is_shocked() -> bool:
	return shocked_remaining > 0.0


func is_frozen() -> bool:
	return frozen_remaining > 0.0


func is_poisoned() -> bool:
	return poisoned_remaining > 0.0


func is_weakened() -> bool:
	return weakened_remaining > 0.0


## 受到伤害倍率（标记 × 感电 × 腐蚀）。
func damage_taken_multiplier() -> float:
	var mult: float = 1.0
	if is_marked():
		mult *= 1.0 + mark_bonus
	if is_shocked():
		mult *= 1.0 + 0.05 * float(shocked_stacks)
	if corroded > 0.0:
		mult *= 1.2
	return mult


## 造成伤害倍率（虚弱）。
func damage_dealt_multiplier() -> float:
	return 1.0 - weakened_reduction if is_weakened() else 1.0


## 受到治疗倍率（中毒降低治疗）。
func healing_multiplier() -> float:
	return 1.0 - poison_healing_reduction if is_poisoned() else 1.0


## 当前带有的元素种类数（强度 > 10 视为附着）。
func element_count() -> int:
	var n: int = 0
	for v: float in [fire_intensity, ice_intensity, lightning_intensity, poison_intensity]:
		if v > 10.0:
			n += 1
	return n


func is_burning() -> bool:
	return burn_remaining > 0.0


func is_slowed() -> bool:
	return slow_remaining > 0.0


func speed_multiplier() -> float:
	if is_frozen():
		return 0.0
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
	if mark_remaining > 0.0:
		mark_remaining -= delta
		if mark_remaining <= 0.0:
			mark_bonus = 0.0
	if poisoned_remaining > 0.0:
		var pstep: float = minf(delta, poisoned_remaining)
		damage += poisoned_dps * pstep
		poisoned_remaining -= delta
		if poisoned_remaining <= 0.0:
			poisoned_dps = 0.0
			poison_healing_reduction = 0.0
	if shocked_remaining > 0.0:
		shocked_remaining -= delta
		if shocked_remaining <= 0.0:
			shocked_stacks = 0
	if frozen_remaining > 0.0:
		frozen_remaining -= delta
	if weakened_remaining > 0.0:
		weakened_remaining -= delta
		if weakened_remaining <= 0.0:
			weakened_reduction = 0.0
	if corroded > 0.0:
		corroded -= delta
	if reaction_cooldown > 0.0:
		reaction_cooldown -= delta
	# 元素强度自然衰减（每秒 -10）
	var decay: float = 10.0 * delta
	fire_intensity = maxf(0.0, fire_intensity - decay)
	ice_intensity = maxf(0.0, ice_intensity - decay)
	lightning_intensity = maxf(0.0, lightning_intensity - decay)
	poison_intensity = maxf(0.0, poison_intensity - decay)
	return damage
