class_name Fireball extends Skill
## 火球术：射向最近的敌人，命中处爆炸并点燃（燃烧可被重击引爆 = 爆燃）。
## Lv1: 单发，半径 2.5 米，伤害 45，燃烧 12 DPS 3 秒
## Lv3: 分裂为 3 发，各打一个不同目标
## Lv5: 爆炸半径 1.4x，燃烧 2x
## Lv8: 伤害 2x，每个落点留下 3 秒火焰地带

const RANGE: float = 15.0
const BASE_RADIUS: float = 2.5
const BASE_DAMAGE: float = 45.0
const BURN_DPS: float = 12.0


func _init() -> void:
	skill_id = "fireball"
	display_name = "火球术"
	max_level = 8


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 2.5


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var radius: float = BASE_RADIUS * (1.4 if tier >= 5 else 1.0) * ctx.area_mult
	var damage: float = BASE_DAMAGE * (2.0 if tier >= 8 else 1.0)
	var burn: float = BURN_DPS * (2.0 if tier >= 5 else 1.0) * ctx.damage_mult
	var aims: Array[Vector3] = []
	for t: Variant in ctx.nearest_targets(RANGE, 3 if tier >= 3 else 1):
		aims.append(t.global_position)
	if aims.is_empty():
		aims.append(ctx.origin + ctx.flat_facing() * 8.0)  # 没有目标时朝面前打
	var hits: int = 0
	var total: float = 0.0
	for p: Vector3 in aims:
		for t: Variant in ctx.targets_in_radius(p, radius):
			total += ctx.hit(t, damage)
			hits += 1
			if t.is_alive:
				var s: StatusEffects = Reactions.status_of(t)
				if s != null:
					s.apply_burn(burn, 3.0)
		if tier >= 8:
			var zone: GroundZone = GroundZone.new(p, p, radius * 0.8, 15.0 * ctx.damage_mult, 3.0)
			zone.burn_dps = burn
			zone.kind = "flame"
			ctx.new_zones.append(zone)
	return {"hits": hits, "damage": total, "tier": tier, "impacts": aims, "radius": radius}
