class_name Resurrection extends Skill
## 复活术：立即复活全场倒地的队友（不限距离），无人倒地时为全队提供护盾。
## Lv1: 复活回复 50%，否则护盾 80
## Lv3: 回复 70%
## Lv5: 复活后 3 秒无敌，护盾 140
## Lv8: 回复 100%，5 秒无敌，护盾 200

func _init() -> void:
	skill_id = "resurrection"
	display_name = "复活术"
	max_level = 8


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 45.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var ratio: float = 1.0 if tier >= 8 else (0.7 if tier >= 3 else 0.5)
	var invuln: float = 5.0 if tier >= 8 else (3.0 if tier >= 5 else 0.0)
	var shield: float = (200.0 if tier >= 8 else (140.0 if tier >= 5 else 80.0)) * ctx.heal_mult
	var revived: int = 0
	var healed: Array[Vector3] = []
	for a: Variant in ctx.allies:
		if not is_instance_valid(a) or not a.is_dead:
			continue
		a.revive()
		a.stats.health = a.stats.max_health * minf(1.0, ratio * ctx.heal_mult)
		if invuln > 0.0 and a.has_method("grant_invulnerability"):
			a.grant_invulnerability(invuln)
		revived += 1
		healed.append(a.global_position)
	if revived == 0:
		for a: Variant in ctx.alive_allies():
			(a.stats as CharacterStats).add_shield(shield)
			healed.append(a.global_position)
	return {"hits": 0, "damage": 0.0, "tier": tier, "revived": revived, "healed": healed, "shield": shield}
