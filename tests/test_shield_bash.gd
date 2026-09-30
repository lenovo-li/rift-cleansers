extends RefCounted
## 盾击四段进化、地面效果与技能系统的单元测试。只用假目标，不依赖场景树。


class FakeTarget extends RefCounted:
	var global_position: Vector3
	var is_alive: bool = true
	var damage_taken: float = 0.0
	var knockback: Vector3 = Vector3.ZERO

	func _init(pos: Vector3) -> void:
		global_position = pos

	func take_damage(amount: float) -> void:
		damage_taken += amount

	func apply_knockback(impulse: Vector3) -> void:
		knockback += impulse


## 施法者在原点、面朝 -Z（Vector3.FORWARD）。
func _ctx(targets: Array) -> SkillContext:
	var ctx: SkillContext = SkillContext.new()
	ctx.origin = Vector3.ZERO
	ctx.facing = Vector3.FORWARD
	ctx.targets = targets
	return ctx


func _bash(level: int) -> ShieldBash:
	var s: ShieldBash = ShieldBash.new()
	s.set_level(level)
	return s


func test_tier_mapping() -> String:
	var expected: Dictionary = {1: 1, 2: 1, 3: 3, 4: 3, 5: 5, 6: 5, 7: 5, 8: 8}
	for lv: int in expected:
		var tier: int = _bash(lv).get_tier()
		if tier != expected[lv]:
			return "Lv%d 档位应为 %d，实际 %d" % [lv, expected[lv], tier]
	return ""


func test_player_level_mapping_reaches_all_tiers() -> String:
	var expected: Dictionary = {1: 1, 6: 2, 7: 3, 13: 5, 21: 7, 22: 8, 40: 8}
	for pl: int in expected:
		var got: int = ShieldBash.level_for_player_level(pl)
		if got != expected[pl]:
			return "玩家 Lv%d 盾击应为 %d，实际 %d" % [pl, expected[pl], got]
	return ""


func test_tier1_hits_single_target_in_cone() -> String:
	var front_a: FakeTarget = FakeTarget.new(Vector3(0, 0, -1))
	var front_b: FakeTarget = FakeTarget.new(Vector3(0.3, 0, -2))
	var behind: FakeTarget = FakeTarget.new(Vector3(0, 0, 1))
	var result: Dictionary = _bash(1).cast(_ctx([front_a, front_b, behind]))
	if result.hits != 1:
		return "1 档应只命中 1 个，实际 %d" % result.hits
	if behind.damage_taken > 0.0:
		return "身后的目标不应被命中"
	var hit: FakeTarget = front_a if front_a.damage_taken > 0.0 else front_b
	if not is_equal_approx(hit.damage_taken, 50.0):
		return "1 档伤害应为 50，实际 %.1f" % hit.damage_taken
	if hit.knockback.z >= 0.0:
		return "击退方向应朝 -Z，实际 %s" % hit.knockback
	return ""


func test_tier3_hits_three_and_chains() -> String:
	var primaries: Array = [
		FakeTarget.new(Vector3(0, 0, -1)),
		FakeTarget.new(Vector3(0.2, 0, -1.5)),
		FakeTarget.new(Vector3(-0.2, 0, -2)),
	]
	var bystander: FakeTarget = FakeTarget.new(Vector3(2.5, 0, -1))  # 锥形外，但在连锁半径内
	var far_away: FakeTarget = FakeTarget.new(Vector3(20, 0, 0))
	var targets: Array = primaries.duplicate()
	targets.append_array([bystander, far_away])
	var result: Dictionary = _bash(3).cast(_ctx(targets))
	for p: FakeTarget in primaries:
		if not is_equal_approx(p.damage_taken, 60.0):
			return "3 档主目标伤害应为 60（50×1.2），实际 %.1f" % p.damage_taken
	if not is_equal_approx(bystander.damage_taken, 30.0):
		return "连锁伤害应为 30 且只结算一次，实际 %.1f" % bystander.damage_taken
	if far_away.damage_taken > 0.0:
		return "远处目标不应被连锁"
	if result.hits != 4:
		return "命中数应为 4（3 主目标 + 1 连锁），实际 %d" % result.hits
	return ""


func test_tier5_longer_range_and_shockwave() -> String:
	var at_4m: FakeTarget = FakeTarget.new(Vector3(0, 0, -4))  # 超出基础 3 米，但在 4.5 米内
	var side: FakeTarget = FakeTarget.new(Vector3(5, 0, 0))    # 锥形外，冲击波半径 6.75 内
	_bash(5).cast(_ctx([at_4m, side]))
	if at_4m.damage_taken < 75.0:
		return "5 档应命中 4 米处目标（伤害≥75），实际 %.1f" % at_4m.damage_taken
	if not is_equal_approx(side.damage_taken, 22.5):
		return "冲击波伤害应为 22.5（75×0.3），实际 %.1f" % side.damage_taken
	return ""


func test_tier8_leaves_flame_zone() -> String:
	var ctx: SkillContext = _ctx([])
	_bash(8).cast(ctx)
	if ctx.new_zones.size() != 1:
		return "8 档应生成 1 个火焰地带，实际 %d" % ctx.new_zones.size()
	var zone: GroundZone = ctx.new_zones[0]
	var inside: FakeTarget = FakeTarget.new(Vector3(0, 0, -2))
	var outside: FakeTarget = FakeTarget.new(Vector3(5, 0, -2))
	# 3 秒持续，每 0.5 秒结算一次，每次 100×0.2×0.5 = 10 伤害
	for i in 40:
		zone.tick(0.1, [inside, outside])
	if not is_equal_approx(inside.damage_taken, 60.0):
		return "火焰地带 3 秒内应造成 60 伤害，实际 %.1f" % inside.damage_taken
	if outside.damage_taken > 0.0:
		return "地带外的目标不应受伤"
	if not zone.is_expired():
		return "3 秒后地带应已过期"
	return ""


func test_ability_system_cooldown_and_zones() -> String:
	var system: AbilitySystem = AbilitySystem.new()
	system.add_skill(_bash(8))
	var target: FakeTarget = FakeTarget.new(Vector3(0, 0, -2))
	if system.cast("shield_bash", _ctx([target])).is_empty():
		return "首次施放应成功"
	if not system.cast("shield_bash", _ctx([target])).is_empty():
		return "冷却中不应能再次施放"
	if not system.has_zones():
		return "8 档施放后系统应持有地面效果"
	var cd: float = system.get_cooldown_remaining("shield_bash")
	for i in int(ceil(cd / 0.1)) + 1:
		system.tick(0.1, [target])
	if not system.can_cast("shield_bash"):
		return "冷却 %.2f 秒结束后应可再次施放" % cd
	if system.has_zones():
		return "地面效果过期后应被移除"
	return ""
