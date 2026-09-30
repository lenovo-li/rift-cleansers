extends RefCounted
## 影行者与牧师的 12 个技能 + 标记/暴击/治疗区域。只用假目标和假队友，不依赖场景树。


class FakeTarget extends RefCounted:
	var global_position: Vector3
	var is_alive: bool = true
	var damage_taken: float = 0.0
	var knockback: Vector3 = Vector3.ZERO
	var slowed: float = 0.0
	var status: StatusEffects = StatusEffects.new()
	var max_health: float = 100.0
	var current_health: float = 100.0

	func _init(pos: Vector3, hp: float = 100.0) -> void:
		global_position = pos
		max_health = hp
		current_health = hp

	func take_damage(amount: float) -> void:
		amount *= status.damage_taken_multiplier()  # 与 Enemy.take_damage 一致
		damage_taken += amount
		current_health -= amount
		if current_health <= 0.0:
			is_alive = false

	func apply_knockback(impulse: Vector3) -> void:
		knockback += impulse

	func apply_slow(factor: float, duration: float) -> void:
		slowed = factor
		status.apply_slow(factor, duration)


class FakeAlly extends RefCounted:
	var global_position: Vector3
	var is_dead: bool = false
	var stats: CharacterStats = CharacterStats.new(1000.0)
	var status: StatusEffects = StatusEffects.new()
	var revived: bool = false

	func _init(pos: Vector3, hp: float = 1000.0) -> void:
		global_position = pos
		stats.health = hp

	func heal(amount: float) -> void:
		stats.heal(amount)

	func revive() -> void:
		is_dead = false
		revived = true


func _ctx(targets: Array, allies: Array = []) -> SkillContext:
	var ctx: SkillContext = SkillContext.new()
	ctx.facing = Vector3.FORWARD
	ctx.targets = targets
	ctx.allies = allies
	return ctx


func _at(skill: Skill, level: int) -> Skill:
	skill.set_level(level)
	return skill


func test_factory_and_catalog() -> String:
	for cid: String in ["shadow_walker", "cleric"]:
		var def: Dictionary = CharacterCatalog.get_def(cid)
		if def.skills.size() != 6 or not CharacterCatalog.is_valid(cid):
			return "%s 应有 6 个技能" % cid
		for id: String in def.skills:
			var s: Skill = SkillFactory.create(id)
			if s == null or s.skill_id != id or s.get_tier_thresholds() != [1, 3, 5, 8]:
				return "工厂无法创建 %s 或进化段不对" % id
		for id: String in def.starting:
			if not id in def.skills:
				return "%s 的起始技能 %s 不在技能池里" % [cid, id]
	return ""


func test_mark_amplifies_all_damage() -> String:
	var t: FakeTarget = FakeTarget.new(Vector3(0, 0, -3), 1000.0)
	var weak: FakeTarget = FakeTarget.new(Vector3(0, 0, -4), 50.0)
	var r: Dictionary = _at(DeathMark.new(), 1).cast(_ctx([t, weak]))
	if r.hits != 1 or not t.status.is_marked() or weak.status.is_marked():
		return "1 档只标记生命最高的目标"
	t.take_damage(100.0)
	if not is_equal_approx(t.damage_taken, 150.0):
		return "被标记目标受伤应 +50%%，实际 %.1f" % t.damage_taken
	t.status.tick(8.1)
	if t.status.is_marked():
		return "标记 8 秒后应消失"
	return ""


func test_shadow_step_prefers_marked_and_resets() -> String:
	var near: FakeTarget = FakeTarget.new(Vector3(0, 0, -2), 1000.0)
	var marked: FakeTarget = FakeTarget.new(Vector3(6, 0, 0), 1000.0)
	marked.status.apply_mark(0.5, 5.0)
	var r: Dictionary = _at(ShadowStep.new(), 3).cast(_ctx([near, marked]))
	if marked.damage_taken <= 0.0 or near.damage_taken > 0.0:
		return "影步应优先闪到被标记的目标"
	if (r.end_position as Vector3).x <= 6.0:
		return "落点应在目标身后（x > 6），实际 %s" % r.end_position
	if not is_equal_approx(float(r.get("cooldown", -1.0)), ShadowStep.RESET_COOLDOWN):
		return "3 档命中标记目标应刷新冷却"
	var r1: Dictionary = _at(ShadowStep.new(), 1).cast(_ctx([marked]))
	if r1.has("cooldown"):
		return "1 档不刷新冷却"
	var r8: Dictionary = _at(ShadowStep.new(), 8).cast(_ctx([FakeTarget.new(Vector3(0, 0, -3), 999.0),
			FakeTarget.new(Vector3(3, 0, -3), 999.0)]))
	if (r8.path as Array).size() != 3:
		return "8 档应连跳两个目标"
	return ""


func test_fan_of_knives_cone_and_ring() -> String:
	var front: FakeTarget = FakeTarget.new(Vector3(0, 0, -5))
	var back: FakeTarget = FakeTarget.new(Vector3(0, 0, 5))
	_at(FanOfKnives.new(), 1).cast(_ctx([front, back]))
	if front.damage_taken <= 0.0 or back.damage_taken > 0.0:
		return "1 档只打前方扇形"
	var back2: FakeTarget = FakeTarget.new(Vector3(0, 0, 5))
	_at(FanOfKnives.new(), 3).cast(_ctx([FakeTarget.new(Vector3(0, 0, -5)), back2]))
	if back2.damage_taken <= 0.0:
		return "3 档应为 360° 环形"
	var m: FakeTarget = FakeTarget.new(Vector3(0, 0, -3), 1000.0)
	m.status.apply_mark(0.5, 5.0)
	var ctx: SkillContext = _ctx([m])
	_at(FanOfKnives.new(), 8).cast(ctx)
	if not is_equal_approx(m.damage_taken, FanOfKnives.BASE_DAMAGE * 2.0 * 1.5):
		return "5 档以上对标记目标 2 倍（再 ×1.5 标记），实际 %.1f" % m.damage_taken
	if ctx.new_strikes.size() != 1 or ctx.new_strikes[0].kind != "knives":
		return "8 档应排一轮延迟飞刀"
	return ""


func test_execute_threshold_and_refund() -> String:
	var low: FakeTarget = FakeTarget.new(Vector3(0, 0, -2), 1000.0)
	low.current_health = 250.0  # 25%
	var full: FakeTarget = FakeTarget.new(Vector3(1, 0, -2), 1000.0)
	_at(Execute.new(), 1).cast(_ctx([low, full]))
	if not is_equal_approx(low.damage_taken, 270.0) or full.damage_taken > 0.0:
		return "处决应选血量比例最低的目标并造成 3 倍伤害，实际 %.1f / %.1f" % [low.damage_taken, full.damage_taken]
	var victim: FakeTarget = FakeTarget.new(Vector3(0, 0, -2), 100.0)
	victim.current_health = 20.0
	var r8: Dictionary = _at(Execute.new(), 8).cast(_ctx([victim]))
	if victim.is_alive or not is_equal_approx(float(r8.get("cooldown", -1.0)), 1.0):
		return "8 档处决击杀应返还冷却到 1 秒"
	return ""


func test_smoke_bomb_and_flurry_zones() -> String:
	var t: FakeTarget = FakeTarget.new(Vector3(2, 0, 0))
	var ctx: SkillContext = _ctx([t])
	var r: Dictionary = _at(SmokeBomb.new(), 5).cast(ctx)
	if ctx.new_zones.size() != 1 or ctx.new_zones[0].slow_factor < 0.5:
		return "烟雾弹应留下减速区域"
	if not t.status.is_marked() or not is_equal_approx(r.invulnerable, 1.5):
		return "5 档烟里的敌人被标记，3 档起无敌 1.5 秒"
	var ctx2: SkillContext = SkillContext.new()
	ctx2.caster = t
	_at(BladeFlurry.new(), 8).cast(ctx2)
	if ctx2.new_zones[0].anchor != t or not ctx2.new_zones[0].heavy:
		return "刃舞应跟随施法者，8 档为重击"
	return ""


func test_crit_uses_injected_rng() -> String:
	var t: FakeTarget = FakeTarget.new(Vector3.ZERO, 1000.0)
	var ctx: SkillContext = _ctx([t])
	ctx.crit_chance = 1.0
	ctx.rng = RandomNumberGenerator.new()
	ctx.hit(t, 10.0)
	if not is_equal_approx(t.damage_taken, 20.0) or ctx.crits != 1:
		return "暴击率 100%% 时伤害应 2 倍"
	var ctx2: SkillContext = _ctx([t])
	ctx2.crit_chance = 1.0  # 没有 rng：不暴击
	ctx2.hit(t, 10.0)
	if not is_equal_approx(t.damage_taken, 30.0):
		return "没有 rng 时不应暴击"
	return ""


func test_holy_nova_heals_allies_in_radius() -> String:
	var enemy: FakeTarget = FakeTarget.new(Vector3(3, 0, 0))
	var near: FakeAlly = FakeAlly.new(Vector3(2, 0, 0), 500.0)
	var far: FakeAlly = FakeAlly.new(Vector3(20, 0, 0), 500.0)
	var r: Dictionary = _at(HolyNova.new(), 5).cast(_ctx([enemy], [near, far]))
	if not is_equal_approx(near.stats.health, 600.0) or not is_equal_approx(far.stats.health, 500.0):
		return "5 档新星应给范围内队友治疗 100，实际 %.0f / %.0f" % [near.stats.health, far.stats.health]
	if enemy.damage_taken <= 0.0 or enemy.knockback == Vector3.ZERO or r.healed != 1:
		return "新星应伤害并推开敌人"
	return ""


func test_smite_heavy_ignites() -> String:
	var burning: FakeTarget = FakeTarget.new(Vector3(0, 0, -5), 1000.0)
	burning.status.apply_burn(10.0, 3.0)
	_at(Smite.new(), 1).cast(_ctx([burning]))
	if burning.status.is_burning() or burning.damage_taken < Smite.BASE_DAMAGE + Reactions.IGNITE_BASE_DAMAGE:
		return "惩击是重击，应引爆燃烧（爆燃），实际 %.1f" % burning.damage_taken
	return ""


func test_sanctuary_heals_over_time() -> String:
	var ally: FakeAlly = FakeAlly.new(Vector3(1, 0, 0), 500.0)
	var ctx: SkillContext = _ctx([])
	_at(Sanctuary.new(), 1).cast(ctx)
	var zone: GroundZone = ctx.new_zones[0]
	zone.tick_heal(1.0, [ally])
	if not is_equal_approx(ally.stats.health, 500.0 + Sanctuary.BASE_HEAL):
		return "圣域每秒回复 %.0f，实际 %.1f" % [Sanctuary.BASE_HEAL, ally.stats.health - 500.0]
	var abilities: AbilitySystem = AbilitySystem.new()
	abilities.zones.append(zone)
	abilities.tick(1.0, [], [ally])
	if not is_equal_approx(ally.stats.health, 500.0 + Sanctuary.BASE_HEAL * 2.0):
		return "AbilitySystem.tick 应把队友交给治疗区域"
	return ""


func test_divine_shield_and_blessing() -> String:
	var a: FakeAlly = FakeAlly.new(Vector3(3, 0, 0))
	_at(DivineShield.new(), 5).cast(_ctx([], [a]))
	if not is_equal_approx(a.stats.shield, 100.0) or a.stats.aura_remaining <= 0.0:
		return "5 档护盾 100 + 减伤光环"
	_at(Blessing.new(), 3).cast(_ctx([], [a]))
	if not is_equal_approx(a.stats.damage_multiplier(), 1.3):
		return "3 档祝福伤害 +30%%，实际 %.2f" % a.stats.damage_multiplier()
	if not is_equal_approx(a.stats.attack_interval_multiplier(), 1.0 / 1.3):
		return "祝福同时提高攻速"
	a.stats.tick(8.1)
	if a.stats.damage_multiplier() != 1.0:
		return "祝福 8 秒后结束"
	return ""


func test_divine_intervention_revives_at_tier5() -> String:
	var down: FakeAlly = FakeAlly.new(Vector3(5, 0, 0), 0.0)
	down.is_dead = true
	_at(DivineIntervention.new(), 3).cast(_ctx([], [down]))
	if down.revived:
		return "3 档不能复活"
	_at(DivineIntervention.new(), 5).cast(_ctx([], [down]))
	if not down.revived or not is_equal_approx(down.stats.health, 350.0):
		return "5 档应复活并恢复 35%%，实际 %.0f" % down.stats.health
	return ""
