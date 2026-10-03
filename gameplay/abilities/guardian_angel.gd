class_name GuardianAngel extends Skill
## 守护天使：为 12 米内的队友（含自己）施加守护，期间受到致命伤时免死并回复生命（每人一次）。
## Lv1: 守护 10 秒，触发回复 30%
## Lv3: 回复 50%
## Lv5: 回复 70%，触发后 3 秒无敌
## Lv8: 守护 15 秒，回复 100%，5 秒无敌

const RANGE: float = 12.0


func _init() -> void:
	skill_id = "guardian_angel"
	display_name = "守护天使"
	max_level = 999


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 40.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var duration: float = 15.0 if tier >= 8 else 10.0
	var ratio: float = 1.0 if tier >= 8 else (0.7 if tier >= 5 else (0.5 if tier >= 3 else 0.3))
	var invuln: float = 5.0 if tier >= 8 else (3.0 if tier >= 5 else 0.0)
	var guarded: Array[Vector3] = []
	for a: Variant in ctx.allies_in_radius(ctx.origin, RANGE * ctx.area_mult):
		(a.stats as CharacterStats).set_guardian(duration, minf(1.0, ratio * ctx.heal_mult), invuln)
		guarded.append(a.global_position)
	return {"hits": 0, "damage": 0.0, "tier": tier, "guarded": guarded, "duration": duration}
