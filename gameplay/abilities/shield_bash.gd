class_name ShieldBash extends Skill
## 盾击：前方锥形冲撞，击退敌人。Lv1/3/5/8 四段进化。

const BASE_DAMAGE: float = 50.0
const BASE_RANGE: float = 3.0
const CONE_ANGLE: float = PI / 4.0  # 45度锥形
const KNOCKBACK_FORCE: float = 5.0


func _init() -> void:
	skill_id = "shield_bash"
	display_name = "盾击"
	max_level = 10


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
	var range: float = BASE_RANGE * _range_mult(tier)
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
		target.take_damage(damage)
		hits += 1
		total_damage += damage
		var direction: Vector3 = (target.global_position - ctx.origin).normalized()
		direction.y = 0.0
		if target.has_method("apply_knockback"):
			target.apply_knockback(direction * KNOCKBACK_FORCE)
	
	# Lv3+：连锁伤害
	if tier >= 3 and hits > 0:
		var chain_hits: int = _apply_chain(hit_enemies, damage * 0.5)
		hits += chain_hits
		total_damage += chain_hits * damage * 0.5
	
	# Lv5+：冲击波
	if tier >= 5:
		var shockwave_hits: int = _apply_shockwave(ctx, damage * 0.3, range * 1.5)
		hits += shockwave_hits
		total_damage += shockwave_hits * damage * 0.3
	
	# Lv8+：火焰地带
	if tier >= 8:
		var trail_end: Vector3 = ctx.origin + facing * range
		var zone: GroundZone = GroundZone.new(ctx.origin, trail_end, 1.5, damage * 0.2, 3.0)
		ctx.new_zones.append(zone)
	
	return {"hits": hits, "damage": total_damage, "tier": tier}


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


func _apply_chain(primaries: Array, damage: float) -> int:
	var chain_hits: int = 0
	for primary: Variant in primaries:
		if not is_instance_valid(primary):
			continue
		# 查找附近3米内的其他敌人
		for candidate: Node in primary.get_tree().get_nodes_in_group("enemies"):
			if candidate == primary or not candidate.is_alive:
				continue
			var distance: float = (candidate as Node3D).global_position.distance_to(primary.global_position)
			if distance < 3.0 and candidate.has_method("take_damage"):
				candidate.take_damage(damage)
				chain_hits += 1
	return chain_hits


func _apply_shockwave(ctx: SkillContext, damage: float, radius: float) -> int:
	var shockwave_hits: int = 0
	for target: Variant in ctx.alive_targets():
		var distance: float = (target.global_position - ctx.origin).length()
		if distance < radius:
			target.take_damage(damage)
			shockwave_hits += 1
	return shockwave_hits
