class_name ShadowStep extends Skill
## 影步：瞬移到 10 米内优先级最高的敌人（Boss/精英/被标记 > 最近）身后，对它和周围造成伤害。
## 施法者的位移由调用方根据返回的 end_position 执行。
## Lv1: 目标 70 伤害，周围 2 米 30 伤害，冷却 6 秒
## Lv3: 被标记或落点击杀时冷却刷新到 1 秒（标记资源的核心循环）
## Lv5: 伤害 1.5x，落点周围半径 3 米
## Lv8: 连跳：对第二个目标再影步一次（终点为第二个目标）

const RANGE: float = 10.0
const BASE_DAMAGE: float = 70.0
const SPLASH_DAMAGE: float = 30.0
const RESET_COOLDOWN: float = 1.0


func _init() -> void:
	skill_id = "shadow_step"
	display_name = "影步"
	max_level = 999


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 6.0


## 优先级：被标记 > Boss/精英 > 最近。
static func pick_target(ctx: SkillContext, exclude: Variant = null) -> Variant:
	var best: Variant = null
	var best_score: float = -INF
	for t: Variant in ctx.nearest_targets(RANGE, 12):
		if t == exclude:
			continue
		var d: float = ((t.global_position - ctx.origin) * Vector3(1, 0, 1)).length()
		var score: float = -d
		var st: StatusEffects = Reactions.status_of(t)
		if st != null and st.is_marked():
			score += 40.0
		if t is Object and t.has_method("is_elite") and t.is_elite():
			score += 20.0
		if score > best_score:
			best_score = score
			best = t
	return best


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var damage: float = BASE_DAMAGE * (1.5 if tier >= 5 else 1.0)
	var splash_r: float = (3.0 if tier >= 5 else 2.0) * ctx.area_mult
	var first: Variant = pick_target(ctx)
	if first == null:
		return {"hits": 0, "damage": 0.0, "tier": tier, "end_position": ctx.origin, "path": [], "cooldown": 0.5}
	var chain: Array = [first]
	if tier >= 8:
		var second: Variant = pick_target(ctx, first)
		if second != null:
			chain.append(second)
	var hits: int = 0
	var total: float = 0.0
	var reset: bool = false
	var path: Array[Vector3] = [ctx.origin]
	var from: Vector3 = ctx.origin
	for t: Variant in chain:
		var tp: Vector3 = t.global_position
		var dir: Vector3 = ((tp - from) * Vector3(1, 0, 1)).normalized()
		var land: Vector3 = tp + (dir if dir != Vector3.ZERO else Vector3.FORWARD) * 1.2  # 落在目标身后
		path.append(land)
		var st: StatusEffects = Reactions.status_of(t)
		if st != null and st.is_marked():
			reset = true
		total += ctx.hit(t, damage, true)
		hits += 1
		if not t.is_alive:
			reset = true
		for s: Variant in ctx.targets_in_radius(land, splash_r):
			if s != t:
				total += ctx.hit(s, SPLASH_DAMAGE)
				hits += 1
		from = land
	var result: Dictionary = {"hits": hits, "damage": total, "tier": tier, "end_position": from, "path": path,
		"radius": splash_r}
	if tier >= 3 and reset:
		result.cooldown = RESET_COOLDOWN
	return result
