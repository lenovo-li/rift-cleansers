class_name Smite extends Skill
## 惩击：天降光柱砸向最近的敌人，范围伤害（重击，可引爆燃烧）。
## Lv1: 1 道光柱，半径 2.5 米，伤害 80
## Lv3: 3 道光柱，各打一个不同目标
## Lv5: 命中减速 50% 2 秒（配合铁卫/冰枪可碎裂）
## Lv8: 伤害 2x，半径 1.4x

const RANGE: float = 14.0
const BASE_RADIUS: float = 2.5
const BASE_DAMAGE: float = 80.0


func _init() -> void:
	skill_id = "smite"
	display_name = "惩击"
	max_level = 8


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 3.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var radius: float = BASE_RADIUS * (1.4 if tier >= 8 else 1.0) * ctx.area_mult
	var damage: float = BASE_DAMAGE * (2.0 if tier >= 8 else 1.0)
	var impacts: Array[Vector3] = []
	for t: Variant in ctx.nearest_targets(RANGE, 3 if tier >= 3 else 1):
		impacts.append(t.global_position)
	var hits: int = 0
	var total: float = 0.0
	for p: Vector3 in impacts:
		for t: Variant in ctx.targets_in_radius(p, radius):
			total += ctx.hit(t, damage, true)
			hits += 1
			if tier >= 5 and t.is_alive and t.has_method("apply_slow"):
				t.apply_slow(0.5, 2.0)
	return {"hits": hits, "damage": total, "tier": tier, "impacts": impacts, "radius": radius}
