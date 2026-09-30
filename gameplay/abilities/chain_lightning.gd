class_name ChainLightning extends Skill
## 闪电链：击中最近的敌人后在 6 米内连续弹跳，每跳伤害衰减 10%。
## Lv1: 弹跳 4 次，伤害 40
## Lv3: 弹跳 6 次
## Lv5: 弹跳 8 次，不再衰减
## Lv8: 每一跳都算重击（引爆燃烧 = 爆燃），伤害 1.5x

const RANGE: float = 13.0
const JUMP_RANGE: float = 6.0
const BASE_DAMAGE: float = 40.0


func _init() -> void:
	skill_id = "chain_lightning"
	display_name = "闪电链"
	max_level = 8


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 5.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var jumps: int = 8 if tier >= 5 else (6 if tier >= 3 else 4)
	var damage: float = BASE_DAMAGE * (1.5 if tier >= 8 else 1.0)
	var decay: float = 1.0 if tier >= 5 else 0.9
	var first: Array = ctx.nearest_targets(RANGE, 1)
	if first.is_empty():
		return {"hits": 0, "damage": 0.0, "tier": tier, "links": []}
	var links: Array = []
	var visited: Dictionary = {}
	var current: Variant = first[0]
	var from: Vector3 = ctx.origin
	var total: float = 0.0
	var hits: int = 0
	for i in jumps + 1:
		visited[current] = true
		links.append([from, current.global_position])
		total += ctx.hit(current, damage, tier >= 8)
		hits += 1
		damage *= decay
		from = current.global_position
		var next: Variant = null
		var best: float = JUMP_RANGE * JUMP_RANGE
		for t: Variant in ctx.alive_targets():
			if visited.has(t):
				continue
			var d: float = (t.global_position - from).length_squared()
			if d < best:
				best = d
				next = t
		if next == null:
			break
		current = next
	return {"hits": hits, "damage": total, "tier": tier, "links": links}
