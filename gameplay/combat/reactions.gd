class_name Reactions extends RefCounted
## 元素反应（文档 11）。技能命中时由 Elements.apply 附着元素并调用 resolve 自动挑选反应。
## 目标只需提供 global_position / is_alive / take_damage，状态放在可选的 status 属性里。
## 15 种反应：爆燃 碎裂 蒸发 融化 超载 超导 扩散 结晶 感电链 剧毒爆发 腐蚀 净化 审判 冰封 湮灭。
## mods（全部可选）：reaction_mult 反应伤害倍率、overload_mult/overload_radius_mult、melt_bonus、
## chain_bonus/chain_range_mult、swirl_mult、shatter_mult、freeze_bonus、freeze_threshold、annihilate_min、
## ignite_mult、shatter_aoe（冰大共鸣）、reaction_cd_mult（雷大共鸣）。

const IGNITE_BASE_DAMAGE: float = 40.0
const IGNITE_RADIUS: float = 3.0
const SHATTER_RATIO: float = 0.5  # 碎裂额外伤害 = 击退来源伤害 × 0.5
const SHATTER_MIN: float = 15.0
const AURA_MIN: float = 20.0  # 元素强度达到该值才算「附着」，可参与反应
const VAPORIZE_MULT: float = 1.5
const MELT_MIN_INTENSITY: float = 40.0
const OVERLOAD_BASE: float = 80.0
const OVERLOAD_RADIUS: float = 4.0
const SUPERCONDUCT_RADIUS: float = 5.0
const SWIRL_RADIUS: float = 4.5
const CHAIN_RADIUS: float = 6.0
const TOXIC_RADIUS: float = 4.0
const FREEZE_MIN_INTENSITY: float = 60.0
const FREEZE_DURATION: float = 1.5
const ANNIHILATE_BASE: float = 200.0
const REACTION_COOLDOWN: float = 0.35  # 同一目标两次反应的最短间隔，防止持续区域每跳都反应

## 表现层可以挂监听（反应名, 位置）。逻辑层不关心是否有人监听。
static var on_reaction: Callable = Callable()
## 统计（测试与 sim 报告用）：反应名 -> 次数
static var counts: Dictionary = {}


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


static func _emit(reaction: String, pos: Vector3) -> void:
	counts[reaction] = int(counts.get(reaction, 0)) + 1
	if on_reaction.is_valid():
		on_reaction.call(reaction, pos)


static func _alive(c: Variant) -> bool:
	return is_instance_valid(c) and c.is_alive


static func _in_radius(candidates: Array, center: Vector3, radius: float, exclude: Variant = null) -> Array:
	var out: Array = []
	var r2: float = radius * radius
	for c: Variant in candidates:
		if c == exclude or not _alive(c):
			continue
		var d: Vector3 = (c.global_position - center) * Vector3(1, 0, 1)
		if d.length_squared() <= r2:
			out.append(c)
	return out


# ---------------- 基础反应（重击 / 击退触发） ----------------

## 爆燃：燃烧目标受重击 → 剩余燃烧伤害 + 基础伤害作用于周围。返回命中数；目标不在燃烧时返回 0。
static func ignite(target: Variant, candidates: Array, mult: float = 1.0) -> int:
	var s: StatusEffects = status_of(target)
	if s == null or not s.is_burning():
		return 0
	var damage: float = (IGNITE_BASE_DAMAGE + s.consume_burn()) * mult
	var center: Vector3 = target.global_position
	var hits: int = 0
	for c: Variant in _in_radius(candidates, center, IGNITE_RADIUS * sqrt(mult)):
		c.take_damage(damage)
		hits += 1
	_emit("ignite", center)
	return hits


## 碎裂额外伤害；目标未被减速/冰冻时返回 0。
static func shatter_bonus(target: Variant, source_damage: float, mult: float = 1.0) -> float:
	var s: StatusEffects = status_of(target)
	if s == null or not (s.is_slowed() or s.is_frozen()):
		return 0.0
	var bonus: float = maxf(SHATTER_MIN, source_damage * SHATTER_RATIO) * mult
	if s.is_frozen():
		bonus *= 2.0  # 打碎冰冻目标：双倍并解除冰冻
		s.frozen_remaining = 0.0
	return bonus


# ---------------- 自动反应选择 ----------------

## 命中带元素 element 的技能时，按目标身上已附着的元素挑一个反应结算（附着新元素之前调用）。
## 返回 {reaction, damage, consumed}；consumed = true 时新元素被反应消耗，不再附着。没有反应返回 {}。
static func resolve(target: Variant, element: String, damage: float, candidates: Array, mods: Dictionary = {}) -> Dictionary:
	var s: StatusEffects = status_of(target)
	if s == null or element.is_empty() or not _alive(target) or s.reaction_cooldown > 0.0:
		return {}
	var r: Dictionary = {}
	match element:
		"fire":
			if s.ice_intensity >= AURA_MIN:
				r = melt(target, damage, mods) if s.ice_intensity >= MELT_MIN_INTENSITY else vaporize(target, damage, mods)
			elif s.lightning_intensity >= AURA_MIN:
				r = overload(target, candidates, mods)
			elif s.poison_intensity >= AURA_MIN and s.is_poisoned():
				r = toxic_blast(target, candidates, mods)
		"ice":
			if s.fire_intensity >= AURA_MIN:
				r = melt(target, damage, mods) if s.fire_intensity >= MELT_MIN_INTENSITY else vaporize(target, damage, mods)
			elif s.lightning_intensity >= AURA_MIN:
				r = superconduct(target, candidates, mods)
		"lightning":
			if s.fire_intensity >= AURA_MIN:
				r = overload(target, candidates, mods)
			elif s.ice_intensity >= AURA_MIN:
				r = superconduct(target, candidates, mods)
			elif s.shocked_stacks >= 3:
				r = electro_chain(target, candidates, damage, mods)
		"wind":
			r = swirl(target, candidates, mods)
		"poison":
			if s.fire_intensity >= AURA_MIN:
				r = toxic_blast(target, candidates, mods)
			elif s.is_marked() or s.is_weakened():
				r = corrode(target, mods)
		"shadow":
			if s.poison_intensity >= AURA_MIN:
				r = corrode(target, mods)
		"holy":
			if s.is_burning() or s.is_marked():
				r = judgment(target, damage, mods)
	if r.is_empty():
		var need: int = int(mods.get("annihilate_min", 3))
		if s.element_count() + (1 if _adds_new_element(s, element) else 0) >= need:
			r = annihilate(target, mods)
	if not r.is_empty():
		s.reaction_cooldown = REACTION_COOLDOWN * float(mods.get("reaction_cd_mult", 1.0))
	return r


## 该元素是否会让目标多出一种附着元素（湮灭计数用）。
static func _adds_new_element(s: StatusEffects, element: String) -> bool:
	match element:
		"fire": return s.fire_intensity <= 10.0
		"ice": return s.ice_intensity <= 10.0
		"lightning": return s.lightning_intensity <= 10.0
		"poison": return s.poison_intensity <= 10.0
	return false


static func _rmult(mods: Dictionary) -> float:
	return float(mods.get("reaction_mult", 1.0))


static func _deal(target: Variant, amount: float) -> float:
	if _alive(target) and amount > 0.0:
		target.take_damage(amount)
	return amount


# ---------------- 双元素反应 ----------------

## 蒸发（火+冰）：消耗双方元素，额外造成 本次伤害×0.5 + 强度加成。
static func vaporize(target: Variant, damage: float, mods: Dictionary = {}) -> Dictionary:
	var s: StatusEffects = status_of(target)
	var bonus: float = (damage * (VAPORIZE_MULT - 1.0 + float(mods.get("melt_bonus", 0.0)))
			+ (s.fire_intensity + s.ice_intensity) * 0.5) * _rmult(mods)
	var pos: Vector3 = target.global_position
	s.fire_intensity = 0.0
	s.ice_intensity = 0.0
	s.burn_remaining = 0.0
	s.slow_remaining = 0.0
	_deal(target, bonus)
	_emit("vaporize", pos)
	return {"reaction": "vaporize", "damage": bonus, "consumed": true}


## 融化（火+冰 高强度）：本次伤害 ×(1.5~2.5)，保留 30% 强度。
static func melt(target: Variant, damage: float, mods: Dictionary = {}) -> Dictionary:
	var s: StatusEffects = status_of(target)
	var mult: float = 1.5 + (s.fire_intensity + s.ice_intensity) * 0.005 + float(mods.get("melt_bonus", 0.0))
	var bonus: float = damage * (mult - 1.0) * _rmult(mods) + 30.0
	var pos: Vector3 = target.global_position
	s.fire_intensity *= 0.3
	s.ice_intensity *= 0.3
	_deal(target, bonus)
	_emit("melt", pos)
	return {"reaction": "melt", "damage": bonus, "mult": mult, "consumed": true}


## 超载（火+雷）：范围爆炸 + 击退。
static func overload(target: Variant, candidates: Array, mods: Dictionary = {}) -> Dictionary:
	var s: StatusEffects = status_of(target)
	var dmg: float = (OVERLOAD_BASE + (s.fire_intensity + s.lightning_intensity) * 0.8) \
			* _rmult(mods) * float(mods.get("overload_mult", 1.0))
	var center: Vector3 = target.global_position
	s.fire_intensity = 0.0
	s.lightning_intensity = 0.0
	var hits: int = 0
	for c: Variant in _in_radius(candidates + [target], center, OVERLOAD_RADIUS * float(mods.get("overload_radius_mult", 1.0))):
		var off: Vector3 = (c.global_position - center) * Vector3(1, 0, 1)
		c.take_damage(dmg)
		if _alive(c) and c.has_method("apply_knockback"):
			c.apply_knockback((off.normalized() if off.length() > 0.1 else Vector3.FORWARD) * 8.0)
		hits += 1
	_emit("overload", center)
	return {"reaction": "overload", "damage": dmg * hits, "hits": hits, "consumed": true}


## 超导（冰+雷）：范围感电 2 层 + 小额伤害。
static func superconduct(target: Variant, candidates: Array, mods: Dictionary = {}) -> Dictionary:
	var s: StatusEffects = status_of(target)
	var center: Vector3 = target.global_position
	var dmg: float = (30.0 + s.lightning_intensity * 0.5) * _rmult(mods)
	s.ice_intensity *= 0.5
	s.lightning_intensity = 0.0
	var affected: int = 0
	for c: Variant in _in_radius(candidates + [target], center, SUPERCONDUCT_RADIUS):
		var cs: StatusEffects = status_of(c)
		if cs != null:
			cs.apply_shocked(2, 8.0, 0.0, int(mods.get("shock_cap", 10)))
		c.take_damage(dmg)
		affected += 1
	_emit("superconduct", center)
	return {"reaction": "superconduct", "damage": dmg * affected, "hits": affected, "consumed": true}


## 感电链（雷+感电≥3 层）：在感电目标之间连锁传导，每跳衰减 20%。
static func electro_chain(target: Variant, candidates: Array, damage: float, mods: Dictionary = {}) -> Dictionary:
	var s: StatusEffects = status_of(target)
	s.shocked_stacks = maxi(0, s.shocked_stacks - 2)
	var visited: Array = [target]
	var current: Variant = target
	var dmg: float = maxf(25.0, damage * 0.6) * _rmult(mods)
	var radius: float = CHAIN_RADIUS * float(mods.get("chain_range_mult", 1.0))
	var total: float = 0.0
	for i in 3 + int(mods.get("chain_bonus", 0)):
		var best: Variant = null
		var best_d: float = radius * radius
		for c: Variant in _in_radius(candidates, current.global_position, radius):
			if c in visited:
				continue
			var d: float = (c.global_position - current.global_position).length_squared()
			var cs: StatusEffects = status_of(c)
			if cs != null and cs.is_shocked():
				d *= 0.5  # 优先传给感电目标
			if d < best_d:
				best_d = d
				best = c
		if best == null:
			break
		visited.append(best)
		best.take_damage(dmg)
		total += dmg
		dmg *= 0.8
		current = best
	_emit("electro_chain", target.global_position)
	return {"reaction": "electro_chain", "damage": total, "hits": visited.size() - 1, "path": visited.map(
			func(v: Variant) -> Vector3: return v.global_position), "consumed": false}


## 扩散（风+元素）：传播目标身上最强的元素到周围，消耗 50% 强度。
static func swirl(target: Variant, candidates: Array, mods: Dictionary = {}) -> Dictionary:
	var s: StatusEffects = status_of(target)
	var elem: String = ""
	var intensity: float = 0.0
	for e: Array in [["fire", s.fire_intensity], ["ice", s.ice_intensity],
			["lightning", s.lightning_intensity], ["poison", s.poison_intensity]]:
		if float(e[1]) > intensity:
			elem = str(e[0])
			intensity = float(e[1])
	if intensity < AURA_MIN:
		return {}
	var spread: int = 0
	var center: Vector3 = target.global_position
	var dmg: float = intensity * 0.4 * _rmult(mods) * float(mods.get("swirl_mult", 1.0))
	for c: Variant in _in_radius(candidates, center, SWIRL_RADIUS * float(mods.get("swirl_mult", 1.0)), target):
		var cs: StatusEffects = status_of(c)
		if cs == null:
			continue
		match elem:
			"fire":
				cs.apply_burn(maxf(s.burn_dps * 0.5, 6.0), 2.0, intensity * 0.3)
			"ice":
				cs.apply_slow(s.slow_factor * 0.7, 2.0, intensity * 0.3)
			"lightning":
				cs.apply_shocked(1, 3.0, intensity * 0.3, int(mods.get("shock_cap", 10)))
			"poison":
				cs.apply_poisoned(maxf(s.poisoned_dps * 0.5, 5.0), 2.0, 0.3, intensity * 0.3)
		c.take_damage(dmg)
		spread += 1
	match elem:
		"fire": s.fire_intensity *= 0.5
		"ice": s.ice_intensity *= 0.5
		"lightning": s.lightning_intensity *= 0.5
		"poison": s.poison_intensity *= 0.5
	_emit("swirl_" + elem, center)
	return {"reaction": "swirl", "element": elem, "spread": spread, "damage": dmg * spread, "consumed": false}


## 剧毒爆发（毒+火）：立即结算剩余中毒伤害 ×1.5 + 范围传播中毒。
static func toxic_blast(target: Variant, candidates: Array, mods: Dictionary = {}) -> Dictionary:
	var s: StatusEffects = status_of(target)
	var burst: float = (s.poisoned_dps * s.poisoned_remaining * 1.5 + 40.0) * _rmult(mods)
	var center: Vector3 = target.global_position
	target.take_damage(burst)
	s.poisoned_remaining = 0.0
	s.poisoned_dps = 0.0
	s.poison_intensity *= 0.5
	s.fire_intensity = 0.0
	var spread: int = 0
	for c: Variant in _in_radius(candidates, center, TOXIC_RADIUS, target):
		var cs: StatusEffects = status_of(c)
		if cs != null:
			cs.apply_poisoned(maxf(s.poisoned_dps * 0.6, 6.0), 4.0, 0.3, 15.0)
		spread += 1
	_emit("toxic_blast", center)
	return {"reaction": "toxic_blast", "burst": burst, "spread": spread, "consumed": true}


## 腐蚀（毒+暗影或暗影+毒）：虚弱 + 受到伤害 +20%（需在 StatusEffects 添加 corroded 字段）。
static func corrode(target: Variant, mods: Dictionary = {}) -> Dictionary:
	var s: StatusEffects = status_of(target)
	s.apply_weakened(0.2, 6.0)
	if "corroded" in s:
		s.corroded = 6.0  # 腐蚀：受到伤害 +20%
	_emit("corrode", target.global_position)
	return {"reaction": "corrode", "consumed": false}


## 审判（圣光+燃烧/标记）：对该目标额外 100% 伤害，消耗燃烧。
static func judgment(target: Variant, damage: float, mods: Dictionary = {}) -> Dictionary:
	var s: StatusEffects = status_of(target)
	var bonus: float = damage * _rmult(mods) + 50.0
	if s.is_burning():
		bonus += s.consume_burn()
	target.take_damage(bonus)
	_emit("judgment", target.global_position)
	return {"reaction": "judgment", "damage": bonus, "consumed": false}


## 冰封（冰强度≥60）：冰冻 1.5 秒，消耗一半强度。Boss 抗性 0.3x。
static func freeze(target: Variant, mods: Dictionary = {}) -> Dictionary:
	var s: StatusEffects = status_of(target)
	if s.ice_intensity < float(mods.get("freeze_threshold", FREEZE_MIN_INTENSITY)):
		return {}
	var dur: float = (FREEZE_DURATION + float(mods.get("freeze_bonus", 0.0))) \
			* float(target.get("freeze_resist", 1.0))
	s.apply_frozen(dur, 0.0)
	s.ice_intensity *= 0.5
	_emit("freeze", target.global_position)
	return {"reaction": "freeze", "duration": dur, "consumed": false}


## 元素湮灭（3+ 种元素）：巨额伤害，清除所有元素。
static func annihilate(target: Variant, mods: Dictionary = {}) -> Dictionary:
	var s: StatusEffects = status_of(target)
	var total_intensity: float = s.fire_intensity + s.ice_intensity + s.lightning_intensity + s.poison_intensity
	var damage: float = (ANNIHILATE_BASE + total_intensity * 2.0) * _rmult(mods)
	target.take_damage(damage)
	var elements: int = s.element_count()
	s.fire_intensity = 0.0
	s.ice_intensity = 0.0
	s.lightning_intensity = 0.0
	s.poison_intensity = 0.0
	s.burn_remaining = 0.0
	s.poisoned_remaining = 0.0
	s.shocked_remaining = 0.0
	s.frozen_remaining = 0.0
	_emit("annihilate", target.global_position)
	return {"reaction": "annihilate", "damage": damage, "elements": elements, "consumed": true}


## 净化（圣光技能后清除友方负面状态）：移除减速/燃烧/中毒/虚弱，每个返还 50 治疗。
static func purify(target: Variant, heal_mult: float = 1.0) -> Dictionary:
	var s: StatusEffects = status_of(target)
	if s == null:
		return {}
	var cleansed: Array[String] = []
	if s.is_slowed():
		s.slow_remaining = 0.0
		s.slow_factor = 0.0
		cleansed.append("slow")
	if s.is_burning():
		s.burn_remaining = 0.0
		s.burn_dps = 0.0
		cleansed.append("burn")
	if s.is_poisoned():
		s.poisoned_remaining = 0.0
		s.poisoned_dps = 0.0
		cleansed.append("poison")
	if s.is_weakened():
		s.weakened_remaining = 0.0
		s.weakened_reduction = 0.0
		cleansed.append("weaken")
	if cleansed.size() > 0:
		var heal_amount: float = cleansed.size() * 50.0 * heal_mult
		if target.has_method("heal"):
			target.heal(heal_amount)
		_emit("purify", target.global_position)
		return {"reaction": "purify", "cleansed": cleansed, "heal": heal_amount}
	return {}
