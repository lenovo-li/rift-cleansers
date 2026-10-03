class_name DeathMark extends Skill
## 死亡标记：标记 12 米内生命最高的敌人，被标记者受到的所有伤害提高（队友的伤害也算）。
## 标记目标是影步的优先目标，刀扇 5 档对其伤害翻倍。
## Lv1: 1 个目标，+50% 受伤，8 秒
## Lv3: 3 个目标
## Lv5: +80% 受伤，被标记者减速 30%
## Lv8: 5 个目标，冷却 0.6x

const RANGE: float = 12.0
const DURATION: float = 8.0


func _init() -> void:
	skill_id = "death_mark"
	display_name = "死亡标记"
	max_level = 999


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 10.0 * (0.6 if get_tier() >= 8 else 1.0)


static func health_of(t: Variant) -> float:
	return float(t.current_health) if t is Object and "current_health" in t else 0.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var count: int = 5 if tier >= 8 else (3 if tier >= 3 else 1)
	var bonus: float = 0.8 if tier >= 5 else 0.5
	var candidates: Array = ctx.nearest_targets(RANGE, 40)
	candidates.sort_custom(func(a: Variant, b: Variant) -> bool: return health_of(a) > health_of(b))
	var marked: Array[Vector3] = []
	for i in mini(count, candidates.size()):
		var t: Variant = candidates[i]
		var st: StatusEffects = Reactions.status_of(t)
		if st == null:
			continue
		st.apply_mark(bonus, DURATION)
		if tier >= 5 and t.has_method("apply_slow"):
			t.apply_slow(0.3, DURATION)
		marked.append(t.global_position)
	return {"hits": marked.size(), "damage": 0.0, "tier": tier, "marked": marked}
