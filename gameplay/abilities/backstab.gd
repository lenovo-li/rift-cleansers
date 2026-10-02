class_name Backstab extends Skill
## 背刺：对 12 米内最近的敌人造成高额伤害（必定暴击从 3 段起）。
## Lv1: 伤害 80（正常暴击判定）
## Lv3: 伤害 120，必定暴击
## Lv5: 伤害 180，必定暴击 ×3
## Lv8: 伤害 280，必定暴击 ×4，击杀时冷却清零

const RANGE: float = 12.0


func _init() -> void:
	skill_id = "backstab"
	display_name = "背刺"
	max_level = 8


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 8.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var damage: float = 280.0 if tier >= 8 else (180.0 if tier >= 5 else (120.0 if tier >= 3 else 80.0))
	var target: Variant = ctx.nearest_alive(RANGE)
	if target == null:
		return {"hits": 0, "damage": 0.0, "tier": tier}
	var pos: Vector3 = target.global_position
	if tier >= 3:
		# 必定暴击：直接乘暴击倍率，并临时关闭 hit() 内的随机暴击，避免二次暴击
		damage *= 4.0 if tier >= 8 else (3.0 if tier >= 5 else ctx.crit_mult)
		var saved: float = ctx.crit_chance
		ctx.crit_chance = 0.0
		ctx.crits += 1
		var dealt: float = ctx.hit(target, damage, true)
		ctx.crit_chance = saved
		return _result(tier, dealt, target, pos)
	return _result(tier, ctx.hit(target, damage, true), target, pos)


func _result(tier: int, dealt: float, target: Variant, pos: Vector3) -> Dictionary:
	var r: Dictionary = {"hits": 1, "damage": dealt, "tier": tier, "center": pos, "killed": not target.is_alive}
	if tier >= 8 and not target.is_alive:
		r.cooldown = 0.0
	return r
