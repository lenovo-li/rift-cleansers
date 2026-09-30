class_name FanOfKnives extends Skill
## 刀扇：朝最近的敌人甩出扇形飞刀，扇形内 8 米的敌人各中一刀。
## Lv1: 90° 扇形，8 米，伤害 35
## Lv3: 360° 环形
## Lv5: 对被标记的敌人伤害 2x，命中附带 30% 减速 1.5 秒
## Lv8: 0.4 秒后第二轮（伤害相同）

const RANGE: float = 8.0
const BASE_DAMAGE: float = 35.0


func _init() -> void:
	skill_id = "fan_of_knives"
	display_name = "刀扇"
	max_level = 8


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 2.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var aim: Vector3 = ctx.aim_direction(RANGE)
	var half_angle: float = PI if tier >= 3 else PI / 4.0
	var r: float = RANGE * ctx.area_mult
	var hits: int = 0
	var total: float = 0.0
	var points: Array[Vector3] = []
	for t: Variant in ctx.targets_in_radius(ctx.origin, r):
		var off: Vector3 = (t.global_position - ctx.origin) * Vector3(1, 0, 1)
		if tier < 3 and off.length() > 0.05 and absf(aim.signed_angle_to(off, Vector3.UP)) > half_angle:
			continue
		var dmg: float = BASE_DAMAGE
		if tier >= 5:
			var st: StatusEffects = Reactions.status_of(t)
			if st != null and st.is_marked():
				dmg *= 2.0
		total += ctx.hit(t, dmg)
		hits += 1
		points.append(t.global_position)
		if tier >= 5 and t.is_alive and t.has_method("apply_slow"):
			t.apply_slow(0.3, 1.5)
	if tier >= 8:
		# 第二轮：以施法点为中心的延迟打击，范围取扇形半径（环形时等价）
		ctx.queue_strike(0.4, ctx.origin, r, BASE_DAMAGE, 0.0, 0.0, false)
		ctx.new_strikes[-1].kind = "knives"
	return {"hits": hits, "damage": total, "tier": tier, "aim": aim, "half_angle": half_angle, "radius": r,
		"points": points}
