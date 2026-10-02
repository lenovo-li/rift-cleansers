class_name ArcaneBarrage extends Skill
## 奥术弹幕：多重投射物
## Lv1: 5发弹幕，各30伤害
## Lv3: 7发
## Lv5: 各50伤害
## Lv8: 10发，各80伤害

const BASE_COUNT: int = 5
const BASE_DAMAGE: float = 30.0

func _init() -> void:
	skill_id = "arcane_barrage"
	display_name = "奥术弹幕"
	max_level = 8

func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]

func get_cooldown() -> float:
	return 6.0

func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var count: int = BASE_COUNT
	if tier >= 3:
		count = 7
	if tier >= 8:
		count = 10
	var damage: float = BASE_DAMAGE if tier < 5 else (50.0 if tier < 8 else 80.0)

	var hits: int = 0
	var total: float = 0.0
	for i in count:
		var nearest: Variant = ctx.nearest_alive(20.0)
		if nearest != null:
			var dealt: float = ctx.hit(nearest, damage)
			total += dealt
			hits += 1

	return {"hits": hits, "damage": total, "projectiles": count, "tier": tier}
