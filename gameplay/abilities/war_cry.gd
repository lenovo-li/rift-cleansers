class_name WarCry extends Skill
## 战吼：范围提升友军攻击速度与移速（团队增益）
## Lv1: 半径8米，持续6秒，攻速+30%，移速+20%
## Lv3: 半径1.3x，持续8秒
## Lv5: 攻速+50%，移速+30%，附加10%伤害加成
## Lv8: 持续10秒，攻速+70%，移速+40%，伤害+20%

const BASE_RADIUS: float = 8.0


func _init() -> void:
	skill_id = "war_cry"
	display_name = "战吼"
	max_level = 8


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 12.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var radius: float = BASE_RADIUS * (1.3 if tier >= 3 else 1.0) * ctx.area_mult
	var duration: float = 10.0 if tier >= 8 else (8.0 if tier >= 3 else 6.0)
	var attack_speed: float = 0.7 if tier >= 8 else (0.5 if tier >= 5 else 0.3)
	var move_speed: float = 0.4 if tier >= 8 else (0.3 if tier >= 5 else 0.2)
	var damage_bonus: float = 0.2 if tier >= 8 else (0.1 if tier >= 5 else 0.0)

	var buffed: int = 0
	for ally: Variant in ctx.allies_in_radius(ctx.origin, radius):
		if ally != null and ally == ctx.caster and ally.has_method("get_node"):
			var stats: CharacterStats = ally.stats
			stats.set_war_cry(duration, attack_speed, move_speed, damage_bonus)
		buffed += 1

	return {"tier": tier, "radius": radius, "buffed": buffed}
