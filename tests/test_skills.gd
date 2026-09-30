extends RefCounted
## 其余 5 个主技能的四段进化 + 技能工厂。只用假目标，不依赖场景树。


class FakeTarget extends RefCounted:
	var global_position: Vector3
	var is_alive: bool = true
	var damage_taken: float = 0.0
	var knockback: Vector3 = Vector3.ZERO
	var slowed: float = 0.0
	var status: StatusEffects = StatusEffects.new()

	func _init(pos: Vector3) -> void:
		global_position = pos

	func take_damage(amount: float) -> void:
		damage_taken += amount

	func apply_knockback(impulse: Vector3) -> void:
		knockback += impulse

	func apply_slow(factor: float, duration: float) -> void:
		slowed = factor
		status.apply_slow(factor, duration)


func _ctx(targets: Array) -> SkillContext:
	var ctx: SkillContext = SkillContext.new()
	ctx.facing = Vector3.FORWARD
	ctx.targets = targets
	return ctx


func _at(skill: Skill, level: int) -> Skill:
	skill.set_level(level)
	return skill


func test_factory_creates_all_six_with_four_tiers() -> String:
	for id: String in SkillFactory.SKILL_IDS + ["fireball", "ice_lance", "frost_nova", "chain_lightning", "meteor", "storm_field"]:
		var s: Skill = SkillFactory.create(id)
		if s == null or s.skill_id != id:
			return "工厂无法创建 %s" % id
		if s.get_tier_thresholds() != [1, 3, 5, 8]:
			return "%s 应有 1/3/5/8 四段进化" % id
	return ""


func test_level_bonus_between_tiers() -> String:
	var s: Skill = _at(Taunt.new(), 4)
	if not is_equal_approx(s.level_bonus(), 1.1):
		return "Lv4（3 档）应有 +10%% 加成，实际 %.2f" % s.level_bonus()
	if not is_equal_approx(_at(Taunt.new(), 5).level_bonus(), 1.0):
		return "刚进化的等级不应有额外加成"
	return ""


func test_whirlwind_tiers() -> String:
	var r1: Dictionary = _at(Whirlwind.new(), 1).cast(_ctx([]))
	var r8: Dictionary = _at(Whirlwind.new(), 8).cast(_ctx([]))
	if not is_equal_approx(r1.radius, 4.0) or not is_equal_approx(r8.radius, 5.2):
		return "旋风斩半径应为 4 / 5.2，实际 %.1f / %.1f" % [r1.radius, r8.radius]
	var ctx: SkillContext = _ctx([])
	_at(Whirlwind.new(), 8).cast(ctx)
	var zone: GroundZone = ctx.new_zones[0]
	if not is_equal_approx(zone.damage_per_tick, 30.0):  # 60 DPS × 0.5 秒
		return "8 档每跳应为 30（2x DPS），实际 %.1f" % zone.damage_per_tick
	if not is_equal_approx(zone.remaining, 4.5):
		return "8 档持续应为 4.5 秒"
	if zone.slow_factor <= 0.0:
		return "3 档以上应附带减速"
	return ""


func test_taunt_pulls_toward_caster_and_shields() -> String:
	var near: FakeTarget = FakeTarget.new(Vector3(5, 0, 0))
	var far: FakeTarget = FakeTarget.new(Vector3(20, 0, 0))
	var r1: Dictionary = _at(Taunt.new(), 1).cast(_ctx([near, far]))
	if near.knockback.x >= 0.0:
		return "被嘲讽的敌人应被拉向施法者（-X），实际 %s" % near.knockback
	if far.knockback != Vector3.ZERO or r1.hits != 1:
		return "范围外的敌人不应被拉"
	if r1.shield > 0.0:
		return "1 档不应给护盾"
	var targets: Array = []
	for i in 5:
		targets.append(FakeTarget.new(Vector3(3, 0, i)))
	var r5: Dictionary = _at(Taunt.new(), 5).cast(_ctx(targets))
	if not is_equal_approx(r5.shield, 20.0):
		return "5 档拉 5 个敌人应得 20 护盾，实际 %.1f" % r5.shield
	if (targets[0] as FakeTarget).slowed <= 0.0:
		return "3 档以上被拉的敌人应被减速"
	return ""


func test_taunt_area_mult_from_rally() -> String:
	var t: FakeTarget = FakeTarget.new(Vector3(8, 0, 0))  # 7 米外
	var ctx: SkillContext = _ctx([t])
	ctx.area_mult = 1.3
	if _at(Taunt.new(), 1).cast(ctx).hits != 1:
		return "集结 +30% 后 8 米处的敌人应被拉到"
	return ""


func test_charge_hits_path_and_returns_end() -> String:
	var on_path: FakeTarget = FakeTarget.new(Vector3(0.5, 0, -4))
	var off_path: FakeTarget = FakeTarget.new(Vector3(4, 0, -4))
	var r: Dictionary = _at(Charge.new(), 1).cast(_ctx([on_path, off_path]))
	if not (r.end_position as Vector3).is_equal_approx(Vector3(0, 0, -8)):
		return "1 档冲锋终点应为 (0,0,-8)，实际 %s" % r.end_position
	if not is_equal_approx(on_path.damage_taken, 40.0) or off_path.damage_taken > 0.0:
		return "只有路径上的敌人受伤（40），实际 %.1f / %.1f" % [on_path.damage_taken, off_path.damage_taken]
	if on_path.knockback.x <= 0.0:
		return "路径右侧的敌人应被推向右侧"
	var victim: FakeTarget = FakeTarget.new(Vector3(0, 0, -3))
	_at(Charge.new(), 8).cast(_ctx([victim]))
	if not victim.status.is_burning():
		return "8 档冲锋应点燃路径上的敌人"
	return ""


func test_ground_slam_tiers() -> String:
	var t: FakeTarget = FakeTarget.new(Vector3(4, 0, 0))
	var r: Dictionary = _at(GroundSlam.new(), 1).cast(_ctx([t]))
	if r.hits != 1 or not is_equal_approx(t.damage_taken, 60.0) or t.slowed <= 0.0:
		return "1 档震地应造成 60 伤害并减速"
	if t.knockback != Vector3.ZERO:
		return "8 档前不应击退"
	var ctx: SkillContext = _ctx([])
	_at(GroundSlam.new(), 5).cast(ctx)
	if ctx.new_zones.size() != 1:
		return "5 档应留下余震地带"
	return ""


func test_reflect_aura_parameters() -> String:
	var r1: Dictionary = _at(ReflectAura.new(), 1).cast(_ctx([]))
	var r8: Dictionary = _at(ReflectAura.new(), 8).cast(_ctx([]))
	if not is_equal_approx(r1.reflect, 0.5) or not is_equal_approx(r8.reflect, 0.8):
		return "反射比例应为 0.5 / 0.8"
	if not is_equal_approx(r8.aura_duration, 8.0) or not is_equal_approx(r8.reduction, 0.4):
		return "8 档持续 8 秒、减伤 40%"
	return ""


func test_shatter_on_slowed_knockback() -> String:
	var slowed: FakeTarget = FakeTarget.new(Vector3(4, 0, 0))
	slowed.apply_slow(0.5, 2.0)
	slowed.damage_taken = 0.0
	var fresh: FakeTarget = FakeTarget.new(Vector3(-4, 0, 0))
	# 8 档震地：120 伤害 + 击退，被减速的目标额外碎裂 60
	_at(GroundSlam.new(), 8).cast(_ctx([slowed, fresh]))
	if not is_equal_approx(slowed.damage_taken, 180.0):
		return "碎裂：被减速的目标应受 120 + 60，实际 %.1f" % slowed.damage_taken
	if not is_equal_approx(fresh.damage_taken, 120.0):
		return "未减速的目标不应碎裂，实际 %.1f" % fresh.damage_taken
	return ""


func test_ignite_on_heavy_hit_of_burning_target() -> String:
	var burning: FakeTarget = FakeTarget.new(Vector3(0, 0, -1))
	burning.status.apply_burn(10.0, 3.0)  # 剩余 30 燃烧伤害
	var bystander: FakeTarget = FakeTarget.new(Vector3(1.5, 0, -1))
	_at(ShieldBash.new(), 1).cast(_ctx([burning, bystander]))
	# 盾击 50 + 爆燃（40 + 30）波及自身和 3 米内的旁观者
	if not is_equal_approx(burning.damage_taken, 120.0):
		return "燃烧目标应受 50 + 70，实际 %.1f" % burning.damage_taken
	if not is_equal_approx(bystander.damage_taken, 70.0):
		return "爆燃应波及 3 米内的敌人（70），实际 %.1f" % bystander.damage_taken
	if burning.status.is_burning():
		return "爆燃后燃烧应被消耗"
	return ""
