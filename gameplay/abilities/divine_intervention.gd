class_name DivineIntervention extends Skill
## 神圣干预：大治疗。15 米内队友恢复最大生命的一定比例；高段可以直接拉起倒地的队友。
## Lv1: 恢复 25%
## Lv3: 恢复 35%
## Lv5: 复活范围内倒地的队友
## Lv8: 恢复 50%，冷却 0.7x

const RANGE: float = 15.0


func _init() -> void:
	skill_id = "divine_intervention"
	display_name = "神圣干预"
	max_level = 8


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 30.0 * (0.7 if get_tier() >= 8 else 1.0)


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var ratio: float = 0.5 if tier >= 8 else (0.35 if tier >= 3 else 0.25)
	var healed: Array[Vector3] = []
	var revived: int = 0
	for a: Variant in ctx.allies_in_radius(ctx.origin, RANGE * ctx.area_mult, tier >= 5):
		if a.is_dead:
			a.revive()
			revived += 1
		a.heal(a.stats.max_health * ratio)
		healed.append(a.global_position)
	return {"hits": 0, "damage": 0.0, "tier": tier, "ratio": ratio, "healed": healed, "revived": revived}
