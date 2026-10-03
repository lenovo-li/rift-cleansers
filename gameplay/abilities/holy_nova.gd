class_name HolyNova extends Skill
## 圣光新星：以自身为中心爆发圣光，伤害周围敌人并治疗范围内的队友（含自己）。
## Lv1: 半径 5 米，伤害 45，治疗 50
## Lv3: 半径 1.3x
## Lv5: 治疗 2x，敌人被向外推开
## Lv8: 伤害 2x，命中减速 40% 2 秒

const BASE_RADIUS: float = 5.0
const BASE_DAMAGE: float = 45.0
const BASE_HEAL: float = 50.0
const KNOCKBACK: float = 6.0


func _init() -> void:
	skill_id = "holy_nova"
	display_name = "圣光新星"
	max_level = 999


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 3.5


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var radius: float = BASE_RADIUS * (1.3 if tier >= 3 else 1.0) * ctx.area_mult
	var damage: float = BASE_DAMAGE * (2.0 if tier >= 8 else 1.0)
	var heal: float = BASE_HEAL * (2.0 if tier >= 5 else 1.0) * ctx.heal_mult
	var hits: int = 0
	var total: float = 0.0
	for t: Variant in ctx.targets_in_radius(ctx.origin, radius):
		var dealt: float = ctx.hit(t, damage)
		total += dealt
		hits += 1
		if not t.is_alive:
			continue
		if tier >= 5:
			var off: Vector3 = (t.global_position - ctx.origin) * Vector3(1, 0, 1)
			total += ctx.push(t, (off.normalized() if off.length() > 0.05 else Vector3.FORWARD) * KNOCKBACK, dealt)
		if tier >= 8 and t.has_method("apply_slow"):
			t.apply_slow(0.4, 2.0)
	var healed: int = 0
	for a: Variant in ctx.allies_in_radius(ctx.origin, radius):
		a.heal(heal)
		healed += 1
	return {"hits": hits, "damage": total, "tier": tier, "radius": radius, "healed": healed, "heal": heal}
