class_name Purify extends Skill
## 净化（文档 11 神圣净化）：清除范围内队友的减速/燃烧/中毒/虚弱并治疗，同时灼烧周围敌人（圣光元素）。
## Lv1: 半径 8 米，治疗 80，每清除一种状态额外 +50；对敌 40 伤害
## Lv3: 治疗 120
## Lv5: 半径 12 米，治疗 180，队友 3 秒减伤 30%
## Lv8: 治疗 280，对敌伤害 ×3（附加净化灼烧）

const BASE_RADIUS: float = 8.0


func _init() -> void:
	skill_id = "purify"
	display_name = "净化"
	max_level = 999


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 12.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var radius: float = BASE_RADIUS * (1.5 if tier >= 5 else 1.0) * ctx.area_mult
	var heal: float = (280.0 if tier >= 8 else (180.0 if tier >= 5 else (120.0 if tier >= 3 else 80.0))) * ctx.heal_mult
	var healed: Array[Vector3] = []
	var cleansed: int = 0
	for a: Variant in ctx.allies_in_radius(ctx.origin, radius):
		var r: Dictionary = Reactions.purify(a, ctx.heal_mult)
		cleansed += (r.get("cleansed", []) as Array).size()
		a.heal(heal)
		if tier >= 5 and (a.stats as CharacterStats).aura_remaining <= 0.0:
			(a.stats as CharacterStats).set_aura(3.0, 0.0, 0.3)
		healed.append(a.global_position)
	var damage: float = 40.0 * (3.0 if tier >= 8 else 1.0) + 20.0 * cleansed
	var hits: int = 0
	var total: float = 0.0
	for t: Variant in ctx.targets_in_radius(ctx.origin, radius):
		total += ctx.hit(t, damage)
		hits += 1
	return {"hits": hits, "damage": total, "tier": tier, "radius": radius, "healed": healed, "heal": heal,
			"cleansed": cleansed}
