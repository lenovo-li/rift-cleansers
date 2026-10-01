extends RefCounted
## 属性（被动/装备）、升级三选一、状态效果、刷怪时间线、掉落、Boss 阶段。


func test_block_recovery_and_spiked_shield() -> String:
	var s: CharacterStats = CharacterStats.new(1000.0)
	s.add_passive("block_recovery")
	s.add_equipment("spiked_shield")
	var r: Dictionary = s.receive_damage(100.0, 0.0)  # roll 0 = 必定格挡
	if not r.blocked or s.health != 1000.0:
		return "格挡应免伤"
	if not is_equal_approx(s.shield, 10.0) or not is_equal_approx(r.reflect, 60.0):
		return "格挡回复 +10 护盾、尖刺盾牌反伤 60"
	s.receive_damage(30.0, 0.99)
	if not is_equal_approx(s.shield, 0.0) or not is_equal_approx(s.health, 980.0):
		return "护盾应先吸收 10，剩 20 扣血，实际 hp=%.0f shield=%.0f" % [s.health, s.shield]
	return ""


func test_damage_multipliers() -> String:
	var s: CharacterStats = CharacterStats.new(1000.0)
	if s.damage_multiplier() != 1.0:
		return "默认倍率应为 1"
	s.add_passive("rage_damage")
	s.rage = 90.0
	s.add_equipment("berserker_helm")
	s.health = 400.0
	if not is_equal_approx(s.damage_multiplier(), 1.3 * 1.4):
		return "狂怒 1.3 × 狂战 1.4，实际 %.2f" % s.damage_multiplier()
	return ""


func test_revenge_leech_adrenaline_rally() -> String:
	var s: CharacterStats = CharacterStats.new(1000.0)
	for id: String in ["revenge", "rally"]:
		s.add_passive(id)
	for id: String in ["leech_gauntlet", "adrenaline_injector"]:
		s.add_equipment(id)
	s.receive_damage(100.0, 0.99)
	if not is_equal_approx(s.attack_interval_multiplier(), 1.0 / 1.2):
		return "复仇：受击后攻速 +20%"
	s.tick(5.1)
	if s.attack_interval_multiplier() != 1.0:
		return "复仇 5 秒后应结束"
	var healed: float = s.on_damage_dealt(2, 100.0, true)
	if not is_equal_approx(healed, 15.0):
		return "汲取手套应吸血 15%%，实际 %.1f" % healed
	if not is_equal_approx(s.dodge_cooldown(), 2.1) or not is_equal_approx(s.taunt_radius_multiplier(), 1.3):
		return "肾上腺闪避冷却 2.1、集结范围 1.3"
	return ""


func test_reflect_aura_reduces_and_reflects() -> String:
	var s: CharacterStats = CharacterStats.new(1000.0)
	s.set_aura(5.0, 0.5, 0.2)
	var r: Dictionary = s.receive_damage(100.0, 0.99)
	if not is_equal_approx(r.taken, 80.0) or not is_equal_approx(r.reflect, 50.0):
		return "光环：减伤 20%%、反射 50%%，实际 taken=%.0f reflect=%.0f" % [r.taken, r.reflect]
	return ""


func test_status_burn_and_slow() -> String:
	var st: StatusEffects = StatusEffects.new()
	st.apply_burn(10.0, 2.0)
	st.apply_slow(0.5, 1.0)
	var total: float = 0.0
	for i in 30:
		total += st.tick(0.1)
	if not is_equal_approx(total, 20.0):
		return "10 DPS 燃烧 2 秒应造成 20，实际 %.1f" % total
	if st.is_burning() or st.is_slowed() or st.speed_multiplier() != 1.0:
		return "状态到期后应清除"
	return ""


func test_upgrade_choices_are_unique_and_apply() -> String:
	var abilities: AbilitySystem = AbilitySystem.new()
	abilities.add_skill(ShieldBash.new())
	var stats: CharacterStats = CharacterStats.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	for round in 40:
		var choices: Array[Dictionary] = UpgradeSystem.roll_choices(abilities, stats, rng)
		if choices.size() != 3:
			return "应有 3 个选项"
		var keys: Dictionary = {}
		for c: Dictionary in choices:
			keys["%s:%s" % [c.type, c.id]] = true
		if keys.size() != 3 and choices[0].type != "heal":
			return "选项不应重复: %s" % str(keys.keys())
		if not UpgradeSystem.apply(choices[0], abilities, stats):
			return "选项应能应用: %s" % choices[0].title
	for id: String in abilities.pool():
		if abilities.get_skill(id) == null:
			return "40 次升级后应已学会全部技能，缺 %s" % id
	return ""


func test_upgrade_falls_back_to_heal_when_maxed() -> String:
	var abilities: AbilitySystem = AbilitySystem.new()
	for id: String in CharacterCatalog.get_def("iron_guard").skills:
		abilities.skill_pool.append(id)
		var s: Skill = SkillFactory.create(id)
		s.set_level(s.max_level)
		abilities.add_skill(s)
	var stats: CharacterStats = CharacterStats.new()
	for id: String in ItemCatalog.PASSIVES:
		stats.add_passive(id)
	var choices: Array[Dictionary] = UpgradeSystem.roll_choices(abilities, stats, RandomNumberGenerator.new())
	for c: Dictionary in choices:
		if c.type != "heal":
			return "全部满级后应只剩治疗选项"
	return ""


func test_spawn_timeline_matches_design() -> String:
	# 文档 05 §2.1：0-1 分钟 10-20，7-9 分钟 250-400
	if SpawnDirector.get_alive_cap(30.0) > 25 or SpawnDirector.get_alive_cap(540.0) != 400:
		return "存活上限曲线不符: 30s=%d 540s=%d" % [SpawnDirector.get_alive_cap(30.0), SpawnDirector.get_alive_cap(540.0)]
	if SpawnDirector.get_elite_chance(299.0) > 0.0 or SpawnDirector.get_elite_chance(301.0) <= 0.0:
		return "精英应从 5:00 开始出现"
	if SpawnDirector.pick_enemy_type(10.0, 0.99) != "zombie":
		return "第 1 分钟只刷腐尸"
	var seen: Dictionary = {}
	for i in 100:
		seen[SpawnDirector.pick_enemy_type(400.0, i / 100.0)] = true
	if seen.size() != 6:
		return "5 分钟后 6 种敌人都应出现，实际 %s" % str(seen.keys())
	return ""


func test_drop_picks_unowned_equipment() -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var owned: Dictionary = {}
	var pool: Array[String] = ItemCatalog.equipment_pool("iron_guard")
	for i in pool.size():
		var id: String = DropSystem.pick_equipment(owned, [], "iron_guard", rng)
		if id.is_empty() or owned.has(id):
			return "应掉落未拥有的装备"
		owned[id] = true
	if not DropSystem.pick_equipment(owned, [], "iron_guard", rng).is_empty():
		return "全部拥有后不应再掉装备"
	for id: String in owned:
		if not ItemCatalog.can_use(id, "iron_guard"):
			return "铁卫掉落了其他角色的专属装备：%s" % id
	if ItemCatalog.can_use("arcane_tome", "iron_guard") or not ItemCatalog.can_use("arcane_tome", "elementalist"):
		return "专属装备的使用限制错误"
	if ItemCatalog.equipment_pool().size() != ItemCatalog.EQUIPMENT.size():
		return "不传角色时应返回全部装备"
	return ""


## 新装备的属性效果。
func test_new_equipment_effects() -> String:
	var s: CharacterStats = CharacterStats.new(1000.0)
	var base: float = s.damage_multiplier()
	s.add_equipment("war_drum")
	if not is_equal_approx(s.damage_multiplier(), base * 1.15):
		return "战鼓伤害 +15% 未生效"
	s.add_equipment("iron_skin")
	var r: Dictionary = s.receive_damage(100.0, 1.0)
	if not is_equal_approx(float(r.taken), 90.0):
		return "铁皮减伤 10% 未生效：%s" % r.taken
	s.add_equipment("thorn_mail")
	r = s.receive_damage(100.0, 1.0)
	if float(r.reflect) <= 0.0:
		return "荆棘甲应反伤"
	s.add_equipment("shield_core")
	s.tick(0.1)
	if s.shield < CharacterStats.SHIELD_CORE_AMOUNT:
		return "护盾核心应给护盾"
	var g: CharacterStats = CharacterStats.new(1000.0)
	g.add_equipment("fortress_plate")
	g.rage = 100.0
	if not is_equal_approx(g.damage_taken_multiplier(), 0.8):
		return "堡垒板甲满怒应减伤 20%%：%s" % g.damage_taken_multiplier()
	g.add_equipment("vital_bulwark")
	g.health = 500.0
	if not g.receive_damage(100.0, 0.0).blocked or not is_equal_approx(g.health, 530.0):
		return "生机壁垒格挡应回复 3%% 最大生命：%s" % g.health
	s.add_equipment("second_wind")
	s.shield = 0.0
	s.receive_damage(5000.0, 1.0)
	if not s.try_second_wind() or s.health <= 0.0:
		return "回光返照应免死一次"
	s.receive_damage(5000.0, 1.0)
	if s.try_second_wind():
		return "回光返照只能触发一次"
	return ""


func test_boss_phases() -> String:
	var expected: Dictionary = {1.0: 1, 0.61: 1, 0.6: 2, 0.31: 2, 0.3: 3, 0.01: 3}
	for ratio: float in expected:
		if Boss.phase_for_ratio(ratio) != expected[ratio]:
			return "血量 %.2f 应为阶段 %d" % [ratio, expected[ratio]]
	return ""


func test_exp_curve_timeline() -> String:
	# 升到 30 级所需总经验应在 10 分钟可达的量级（模拟约 4000-6000）
	var total: float = 0.0
	var session: GameSession = GameSession.new()
	for lv in range(1, 30):
		total += session.get_exp_required(lv)
	session.free()
	if total < 4000.0 or total > 12000.0:
		return "30 级总经验 %.0f 超出预期范围" % total
	return ""
