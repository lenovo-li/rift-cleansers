class_name IceLance extends Skill
## 冰枪术：朝最近的敌人射出穿透冰枪，沿途击退（被减速的敌人受击退 = 碎裂）。
## Lv1: 长 12 米、宽 1.8 米，伤害 55，击退
## Lv3: 命中附加 40% 减速 2 秒（下一次冰枪/陨石就会碎裂）
## Lv5: 扇形 3 支（±15°）
## Lv8: 长度 1.5x，伤害 2x

const LENGTH: float = 12.0
const HALF_WIDTH: float = 0.9
const BASE_DAMAGE: float = 55.0
const KNOCKBACK: float = 4.5


func _init() -> void:
	skill_id = "ice_lance"
	display_name = "冰枪术"
	max_level = 8


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 3.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var length: float = LENGTH * (1.5 if tier >= 8 else 1.0)
	var damage: float = BASE_DAMAGE * (2.0 if tier >= 8 else 1.0)
	var aim: Vector3 = ctx.aim_direction(length)
	var dirs: Array[Vector3] = [aim]
	if tier >= 5:
		dirs.append(aim.rotated(Vector3.UP, deg_to_rad(15)))
		dirs.append(aim.rotated(Vector3.UP, deg_to_rad(-15)))
	var hit_set: Dictionary = {}
	var total: float = 0.0
	var ends: Array[Vector3] = []
	for d: Vector3 in dirs:
		var end: Vector3 = ctx.origin + d * length
		ends.append(end)
		for t: Variant in ctx.alive_targets():
			if hit_set.has(t) or GroundZone.distance_xz_to_segment(t.global_position, ctx.origin, end) > HALF_WIDTH:
				continue
			hit_set[t] = true
			var dealt: float = ctx.hit(t, damage)
			total += dealt + ctx.push(t, d * KNOCKBACK, dealt)
			if tier >= 3 and t.is_alive and t.has_method("apply_slow"):
				t.apply_slow(0.4, 2.0)
	return {"hits": hit_set.size(), "damage": total, "tier": tier, "ends": ends}
