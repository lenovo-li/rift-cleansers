class_name FrostNova extends Skill
## 寒冰新星：以自身为中心爆发寒气，伤害并大幅减速（给碎裂反应打底，也是术士的保命技）。
## Lv1: 半径 5 米，伤害 30，减速 60% 2.5 秒
## Lv3: 半径 1.3x
## Lv5: 减速 85%（近乎冻结），并把敌人向外推开
## Lv8: 伤害 2x，留下 4 秒冰霜地带持续减速

const BASE_RADIUS: float = 5.0
const BASE_DAMAGE: float = 30.0
const PUSH: float = 5.0


func _init() -> void:
	skill_id = "frost_nova"
	display_name = "寒冰新星"
	max_level = 8


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 8.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var radius: float = BASE_RADIUS * (1.3 if tier >= 3 else 1.0) * ctx.area_mult
	var damage: float = BASE_DAMAGE * (2.0 if tier >= 8 else 1.0)
	var slow: float = 0.85 if tier >= 5 else 0.6
	var hits: int = 0
	var total: float = 0.0
	for t: Variant in ctx.targets_in_radius(ctx.origin, radius):
		hits += 1
		var dealt: float = ctx.hit(t, damage)
		total += dealt
		if tier >= 5 and t.is_alive:
			var off: Vector3 = (t.global_position - ctx.origin) * Vector3(1, 0, 1)
			var dir: Vector3 = off.normalized() if off.length() > 0.01 else ctx.flat_facing()
			# 先推后减速：新星自己不触发碎裂，碎裂留给后续的冰枪/陨石
			total += ctx.push(t, dir * PUSH, dealt, false)
		if t.is_alive and t.has_method("apply_slow"):
			t.apply_slow(slow, 2.5)
	if tier >= 8:
		var zone: GroundZone = GroundZone.new(ctx.origin, ctx.origin, radius, 10.0 * ctx.damage_mult, 4.0)
		zone.slow_factor = 0.6
		zone.slow_duration = 1.0
		zone.kind = "frost"
		ctx.new_zones.append(zone)
	return {"hits": hits, "damage": total, "tier": tier, "radius": radius}
