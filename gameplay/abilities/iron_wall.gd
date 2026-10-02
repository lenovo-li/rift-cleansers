class_name IronWall extends Skill
## 铁壁：大幅提升护甲，反弹近战伤害（防御型强化）
## Lv1: 持续8秒，受到伤害-40%，反弹30%近战伤害
## Lv3: 受伤-50%
## Lv5: 持续12秒，反弹50%
## Lv8: 受伤-60%，反弹80%，每次反弹回复2%最大生命

func _init() -> void:
	skill_id = "iron_wall"
	display_name = "铁壁"
	max_level = 8


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 15.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var duration: float = 12.0 if tier >= 5 else 8.0
	var reduction: float = 0.6 if tier >= 8 else (0.5 if tier >= 3 else 0.4)
	var reflect: float = 0.8 if tier >= 8 else (0.5 if tier >= 5 else 0.3)
	var heal_per_reflect: float = 0.02 if tier >= 8 else 0.0

	if ctx.caster != null and ctx.caster.has_method("get_node"):
		var stats: CharacterStats = ctx.caster.stats
		stats.set_aura(duration, reflect, reduction)
		if tier >= 8:
			stats.aura_heal_ratio = heal_per_reflect

	return {"tier": tier, "aura_duration": duration, "reflect": reflect, "reduction": reduction}
