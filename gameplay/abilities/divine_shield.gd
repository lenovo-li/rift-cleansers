class_name DivineShield extends Skill
## 神圣护盾：给 12 米内所有队友（含自己）套上护盾。
## Lv1: 护盾 60
## Lv3: 护盾 100
## Lv5: 额外 4 秒减伤 25%（复用光环减伤）
## Lv8: 护盾 160，并清除减速

const RANGE: float = 12.0


func _init() -> void:
	skill_id = "divine_shield"
	display_name = "神圣护盾"
	max_level = 8


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 10.0


func shield_amount() -> float:
	var tier: int = get_tier()
	return 160.0 if tier >= 8 else (100.0 if tier >= 3 else 60.0)


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var amount: float = shield_amount()
	var shielded: Array[Vector3] = []
	for a: Variant in ctx.allies_in_radius(ctx.origin, RANGE * ctx.area_mult):
		var st: CharacterStats = a.stats
		st.add_shield(amount)
		if tier >= 5 and st.aura_remaining <= 0.0:
			st.set_aura(4.0, 0.0, 0.25)
		if tier >= 8 and "status" in a:
			(a.status as StatusEffects).slow_remaining = 0.0
			(a.status as StatusEffects).slow_factor = 0.0
		shielded.append(a.global_position)
	return {"hits": 0, "damage": 0.0, "tier": tier, "shield": amount, "shielded": shielded}
