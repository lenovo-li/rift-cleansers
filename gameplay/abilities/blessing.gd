class_name Blessing extends Skill
## 祝福：15 米内队友（含自己）伤害和攻速提高。
## Lv1: +20%，8 秒
## Lv3: +30%
## Lv5: 持续 12 秒
## Lv8: +50%，同时恢复 10% 最大生命

const RANGE: float = 15.0


func _init() -> void:
	skill_id = "blessing"
	display_name = "祝福"
	max_level = 8


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 16.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var bonus: float = 0.5 if tier >= 8 else (0.3 if tier >= 3 else 0.2)
	var duration: float = 12.0 if tier >= 5 else 8.0
	var blessed: Array[Vector3] = []
	for a: Variant in ctx.allies_in_radius(ctx.origin, RANGE * ctx.area_mult):
		var st: CharacterStats = a.stats
		st.set_blessing(duration, bonus)
		if tier >= 8:
			a.heal(st.max_health * 0.1 * ctx.heal_mult)
		blessed.append(a.global_position)
	return {"hits": 0, "damage": 0.0, "tier": tier, "bonus": bonus, "duration": duration, "blessed": blessed}
