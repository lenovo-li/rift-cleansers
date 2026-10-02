class_name HolyWrath extends Skill
## 圣怒：对不死生物造成巨额伤害
## Lv1: 伤害120，对精英+50%
## Lv3: 伤害180
## Lv5: 伤害260，对精英+100%
## Lv8: 伤害400，对Boss+150%

const BASE_DAMAGE: float = 120.0
const RANGE: float = 15.0

func _init() -> void:
	skill_id = "holy_wrath"
	display_name = "圣怒"
	max_level = 8

func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]

func get_cooldown() -> float:
	return 8.0

func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var damage: float = BASE_DAMAGE
	if tier >= 3: damage = 180.0
	if tier >= 5: damage = 260.0
	if tier >= 8: damage = 400.0

	var target: Variant = ctx.nearest_alive(RANGE)
	if target == null:
		return {"hits": 0}

	var elite_bonus: float = 1.5 if tier < 5 else 2.0
	var is_elite: bool = target.has_method("is_elite") and target.is_elite()
	var is_boss: bool = target.is_in_group("boss") if target.has_method("is_in_group") else false

	var mult: float = 1.0
	if is_boss and tier >= 8:
		mult = 2.5
	elif is_elite:
		mult = elite_bonus

	var dealt: float = ctx.hit(target, damage * mult)
	return {"hits": 1, "damage": dealt, "tier": tier, "center": target.global_position}
