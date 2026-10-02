extends RefCounted
## 验证所有角色的技能池都能正常施放（冒烟测试）

class FakeTarget extends RefCounted:
	var global_position: Vector3
	var is_alive: bool = true
	var damage_taken: float = 0.0
	var status: StatusEffects = StatusEffects.new()

	func _init(pos: Vector3) -> void:
		global_position = pos

	func take_damage(amount: float) -> void:
		damage_taken += amount

	func apply_knockback(_impulse: Vector3) -> void:
		pass

	func apply_slow(_factor: float, _duration: float) -> void:
		pass


func _ctx(targets: Array) -> SkillContext:
	var ctx: SkillContext = SkillContext.new()
	ctx.origin = Vector3.ZERO
	ctx.facing = Vector3.FORWARD
	ctx.targets = targets
	ctx.damage_mult = 1.0
	ctx.area_mult = 1.0
	ctx.heal_mult = 1.0
	ctx.allies = []
	return ctx


func test_all_character_skills_castable() -> String:
	var chars: Dictionary = CharacterCatalog.CHARACTERS
	for char_id: String in chars:
		var skills: Array = chars[char_id].get("skills", [])
		for skill_id: String in skills:
			var skill: Skill = SkillFactory.create(skill_id)
			if skill == null:
				return "%s/%s: 工厂无法创建" % [char_id, skill_id]
			skill.set_level(1)
			var targets: Array = [FakeTarget.new(Vector3(5, 0, 0))]
			var result: Dictionary = skill.cast(_ctx(targets))
			if result == null:
				return "%s/%s: cast返回null" % [char_id, skill_id]
	return ""


func test_iron_guard_has_ten_skills() -> String:
	var skills: Array = CharacterCatalog.CHARACTERS.iron_guard.skills
	if skills.size() != 10:
		return "铁卫应有10个技能，实际%d" % skills.size()
	var expected: Array[String] = ["shield_bash", "whirlwind", "taunt", "charge",
			"ground_slam", "reflect_aura", "earthquake", "iron_wall", "war_cry", "flame_cleave"]
	for id: String in expected:
		if not id in skills:
			return "铁卫缺少技能: %s" % id
	return ""
