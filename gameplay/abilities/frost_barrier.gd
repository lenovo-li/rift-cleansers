class_name FrostBarrier extends Skill
## 冰霜屏障：给自己加护盾，并冻伤 8 米内的敌人（冰元素，叠够强度会冰封）。
## Lv1: 护盾 200，敌人减速 40% 4 秒，伤害 30
## Lv3: 护盾 350
## Lv5: 护盾 550，减速 60%
## Lv8: 护盾 900，直接冰冻 2 秒（Boss 按冰冻抗性缩短）

const RADIUS: float = 8.0


func _init() -> void:
	skill_id = "frost_barrier"
	display_name = "冰霜屏障"
	max_level = 999


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 15.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var shield: float = (900.0 if tier >= 8 else (550.0 if tier >= 5 else (350.0 if tier >= 3 else 200.0))) * ctx.heal_mult
	if ctx.caster != null and "stats" in ctx.caster:
		(ctx.caster.stats as CharacterStats).add_shield(shield)
	var slow: float = 0.6 if tier >= 5 else 0.4
	var radius: float = RADIUS * ctx.area_mult
	var hits: int = 0
	var total: float = 0.0
	for t: Variant in ctx.targets_in_radius(ctx.origin, radius):
		total += ctx.hit(t, 30.0)
		hits += 1
		if not t.is_alive:
			continue
		if tier >= 8:
			var s: StatusEffects = Reactions.status_of(t)
			if s != null:
				s.apply_frozen(2.0 * float(t.get("freeze_resist") if "freeze_resist" in t else 1.0))
		else:
			ctx.slow(t, slow, 4.0)
	return {"hits": hits, "damage": total, "tier": tier, "shield": shield, "radius": radius}
