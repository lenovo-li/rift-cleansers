class_name ShieldBash extends Skill
## 盾击：前方锥形冲撞，击退敌人。Lv1/3/5/8 四段进化。

const BASE_DAMAGE: float = 50.0
const BASE_RANGE: float = 3.0
const CONE_ANGLE: float = PI / 4.0  # 45度锥形
const KNOCKBACK_FORCE: float = 5.0


func _init() -> void:
	skill_id = "shield_bash"
	display_name = "盾击"
	max_level = 8


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	var cd: float = 4.0
	if level >= 3:
		cd *= 0.9
	if level >= 5:
		cd *= 0.8
	return cd


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var damage: float = BASE_DAMAGE * _damage_mult(tier)
	var range: float = BASE_RANGE * _range_mult(tier) * ctx.area_mult
	var max_targets: int = _max_targets(tier)
	
	var hits: int = 0
	var total_damage: float = 0.0
	var facing: Vector3 = ctx.flat_facing()
	var hit_enemies: Array = []
	
	# 锥形检测
	for target: Variant in ctx.alive_targets():
		var offset: Vector3 = target.global_position - ctx.origin
		offset.y = 0.0
		var dist: float = offset.length()
		if dist > range:
			continue
		var angle: float = facing.angle_to(offset.normalized())
		if angle <= CONE_ANGLE:
			hit_enemies.append(target)
			if hit_enemies.size() >= max_targets:
				break
	
	# 造成伤害和击退
	for target: Variant in hit_enemies:
		var direction: Vector3 = target.global_position - ctx.origin
		direction.y = 0.0
		direction = direction.normalized()
		var dealt: float = ctx.hit(target, damage, true)
		total_damage += dealt + ctx.push(target, direction * KNOCKBACK_FORCE, dealt)
		hits += 1

	# Lv3+：连锁伤害
	if tier >= 3 and hits > 0:
		var chain_hits: int = _apply_chain(ctx, hit_enemies, damage * 0.5)
		hits += chain_hits
		total_damage += chain_hits * damage * 0.5 * ctx.damage_mult

	# Lv5+：冲击波
	if tier >= 5:
		var shockwave_hits: int = _apply_shockwave(ctx, damage * 0.3, range * 1.5)
		hits += shockwave_hits
		total_damage += shockwave_hits * damage * 0.3 * ctx.damage_mult

	# Lv8+：火焰地带（燃烧，可与后续重击组成爆燃）
	if tier >= 8:
		var trail_end: Vector3 = ctx.origin + facing * range
		var zone: GroundZone = GroundZone.new(ctx.origin, trail_end, 1.5, damage * 0.2 * ctx.damage_mult, 3.0)
		zone.burn_dps = 10.0
		zone.kind = "flame"
		ctx.new_zones.append(zone)
	
	var hit_points: Array = []
	for t: Variant in hit_enemies:
		hit_points.append(t.global_position)
	return {"hits": hits, "damage": total_damage, "tier": tier, "hit_points": hit_points, "chain_links": ctx.get_meta("chain_links", [])}


func _damage_mult(tier: int) -> float:
	match tier:
		1: return 1.0
		3: return 1.2
		5: return 1.5
		8: return 2.0
		_: return 1.0


func _range_mult(tier: int) -> float:
	return 1.5 if tier >= 5 else 1.0


func _max_targets(tier: int) -> int:
	return 3 if tier >= 3 else 1


## 被击中的敌人撞到周围 CHAIN_RADIUS 内的其他敌人（每个敌人最多被连锁一次，主目标不重复受伤）。
func _apply_chain(ctx: SkillContext, primaries: Array, damage: float) -> int:
	const CHAIN_RADIUS: float = 3.0
	var chain_hits: int = 0
	var already_hit: Array = primaries.duplicate()
	for primary: Variant in primaries:
		if not is_instance_valid(primary):
			continue
		for candidate: Variant in ctx.alive_targets():
			if candidate in already_hit:
				continue
			var offset: Vector3 = candidate.global_position - primary.global_position
			offset.y = 0.0
			if offset.length() < CHAIN_RADIUS:
				ctx.hit(candidate, damage)
				var links: Array = ctx.get_meta("chain_links", [])
				links.append([primary.global_position, candidate.global_position])
				ctx.set_meta("chain_links", links)
				already_hit.append(candidate)
				chain_hits += 1
	return chain_hits


## 玩家等级 -> 盾击等级：每 3 级 +1，上限 8。
## 对应文档 05 §2.1 时间线：玩家 Lv7 -> 盾击 3 级，Lv13 -> 5 级，Lv22 -> 8 级。
static func level_for_player_level(player_level: int) -> int:
	return clampi(1 + (player_level - 1) / 3, 1, 8)


func _apply_shockwave(ctx: SkillContext, damage: float, radius: float) -> int:
	var shockwave_hits: int = 0
	for target: Variant in ctx.alive_targets():
		var offset: Vector3 = target.global_position - ctx.origin
		offset.y = 0.0
		if offset.length() < radius:
			ctx.hit(target, damage)
			shockwave_hits += 1
	return shockwave_hits
