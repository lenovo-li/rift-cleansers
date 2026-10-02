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
## 鼠标/摇杆瞄准点（地面投射技能用）。has_aim 为 false 时回退到自动目标。
var aim_point: Vector3 = Vector3.ZERO
var has_aim: bool = false

## 施法者加成（来自被动、装备、怒气）。
var damage_mult: float = 1.0
var area_mult: float = 1.0
## 磁力战靴：被击退的敌人随后被拉回施法者身边。
var magnet: bool = false
## 队友（含施法者自己和倒地的玩家），牧师的治疗/护盾/复活用。需有 global_position、is_dead、heal(float)、stats。
var allies: Array = []
## 暴击（影行者）：hit() 按 crit_chance 掷骰，暴击伤害 × crit_mult。rng 为空时不暴击（单元测试可注入）。
var crit_chance: float = 0.0
var crit_mult: float = 2.0
var rng: RandomNumberGenerator = null
var crits: int = 0
## 治疗与护盾倍率（牧师天赋「虔诚」）
var heal_mult: float = 1.0

## 元素（文档 11）：命中时附着 element（强度 intensity）并自动反应；空 = 物理技能。
## extra_elements：装备附加的额外元素 [[element, intensity], ...]（双元素核心、三元素水晶）。
var element: String = ""
var intensity: float = Elements.DEFAULT_INTENSITY
var extra_elements: Array = []
## 传给 Elements.apply / Reactions 的加成参数（装备、共鸣）
var element_mods: Dictionary = {}
## 本次施放触发的反应名（表现层 / 统计）与命中过的目标（回响、扩散、连锁反应等装备用）
var reactions: Array[String] = []
var hit_log: Array = []
## 本次施放中击杀了带死亡标记的敌人的数量（冷却返还）
var marked_kills: int = 0
## 击退距离倍率（冲击波戒指）、碎裂伤害倍率
var knockback_mult: float = 1.0
var shatter_mult: float = 1.0
## 协同 / 共鸣附加：连锁 +N、处决阈值加成、对标记目标额外暴击率
var chain_bonus: int = 0
var execute_bonus: float = 0.0
var marked_crit_bonus: float = 0.0
## 控制时长倍率（协同「控制」）
var cc_mult: float = 1.0


## 存活的队友。
func alive_allies() -> Array:
	var result: Array = []
	for a: Variant in allies:
		if is_instance_valid(a) and not a.is_dead:
			result.append(a)
	return result


## 距离 center 不超过 radius 的队友（include_dead：倒地的也算，复活用）。
func allies_in_radius(center: Vector3, radius: float, include_dead: bool = false) -> Array:
	var result: Array = []
	for a: Variant in allies:
		if not is_instance_valid(a) or (a.is_dead and not include_dead):
			continue
		if ((a.global_position - center) * Vector3(1, 0, 1)).length() <= radius:
			result.append(a)
	return result


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
	var crit: float = crit_chance
	var st: StatusEffects = Reactions.status_of(target)
	var was_marked: bool = st != null and st.is_marked()
	if was_marked:
		crit += marked_crit_bonus
	if crit > 0.0 and rng != null and rng.randf() < crit:
		damage *= crit_mult
		crits += 1
	var was_burning: bool = heavy and Reactions.is_burning(target)
	target.take_damage(damage)
	if not target in hit_log:
		hit_log.append(target)
	if target.is_alive:
		_apply_elements(target, damage)
	if was_burning:
		Reactions.ignite(target, alive_targets(), float(element_mods.get("ignite_mult", 1.0)))
	if was_marked and not target.is_alive:
		marked_kills += 1
	return damage


## 附着技能元素与装备附加元素，记录触发的反应。
func _apply_elements(target: Variant, damage: float) -> void:
	if not element.is_empty():
		_note(Elements.apply(target, element, intensity, damage, alive_targets(), element_mods))
	for e: Array in extra_elements:
		if target.is_alive and str(e[0]) != element:
			_note(Elements.apply(target, str(e[0]), float(e[1]), damage * 0.3, alive_targets(), element_mods))


func _note(r: Dictionary) -> void:
	if not r.is_empty():
		reactions.append(str(r.get("reaction", "")))


## 对目标附加减速（乘控制时长倍率）。技能用它代替直接调用 apply_slow，让协同「控制」生效。
func slow(target: Variant, factor: float, duration: float) -> void:
	if target.has_method("apply_slow"):
		target.apply_slow(factor, duration * cc_mult)


## 击退。被减速目标触发碎裂，返回碎裂额外伤害。
func push(target: Variant, impulse: Vector3, source_damage: float, allow_magnet: bool = true) -> float:
	var bonus: float = Reactions.shatter_bonus(target, source_damage, shatter_mult)
	if bonus > 0.0 and target.is_alive:
		var pos: Vector3 = target.global_position
		target.take_damage(bonus)
		Reactions._emit("shatter", pos)
		reactions.append("shatter")
		if element_mods.get("shatter_aoe", false):  # 冰大共鸣：碎裂波及周围 2.5 米
			for c: Variant in targets_in_radius(pos, 2.5):
				if c != target:
					c.take_damage(bonus * 0.5)
	if target.is_alive and target.has_method("apply_knockback"):
		impulse *= knockback_mult
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
		"element": element, "intensity": intensity, "element_mods": element_mods,
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
