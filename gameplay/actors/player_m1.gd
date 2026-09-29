extends CharacterBody3D
## M1 玩家（铁卫）：移动、闪避、自动攻击、6 个主技能、被动/装备、受击结算。
## 数值规则在 CharacterStats / 各 Skill 里，这里只负责输入、场景交互和表现。

signal died(reason: String)
signal equipment_added(item_id: String)

const SPEED: float = 8.0
const DODGE_SPEED: float = 26.0
const DODGE_TIME: float = 0.18
const CHARGE_TIME: float = 0.2
const ARENA_HALF: float = 97.0
const FLAME_CORE_BURN_DPS: float = 12.0
## 技能栏：输入动作 -> 技能 id（顺序与 SkillFactory.SKILL_IDS 一致）
const SKILL_ACTIONS: Array[String] = ["skill_0", "skill_1", "skill_2", "skill_3", "skill_4", "skill_5"]
const STARTING_SKILLS: Array[String] = ["shield_bash", "taunt"]

@export var max_health: float = 1000.0
@export var attack_damage: float = 25.0
@export var attack_range: float = 3.5
@export var attack_interval: float = 1.0
## 自动施放：技能冷却好且附近有敌人时自动释放（T 键切换）。
@export var auto_cast: bool = false

var entity_id: int = 0
var attack_timer: float = 0.0
var stats: CharacterStats = null
var ability_system: AbilitySystem = null
var shield_bash: ShieldBash = null
var status: StatusEffects = StatusEffects.new()
var facing: Vector3 = Vector3.FORWARD
## 模拟/AI 用：非零时代替键盘输入作为移动方向。
var move_override: Vector3 = Vector3.ZERO
var dodge_cooldown_remaining: float = 0.0
var last_damage_source: String = ""
## 来源 -> 累计承受伤害（结算界面和模拟用）
var damage_taken_by_source: Dictionary = {}
var is_dead: bool = false
var _dash_velocity: Vector3 = Vector3.ZERO
var _dash_time: float = 0.0
var _invulnerable_time: float = 0.0
var _hurt_flash: float = 0.0
var _mesh: MeshInstance3D = null
var _base_color: Color = Color(0.2, 0.6, 1.0)
var _body_mat: StandardMaterial3D = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _fx_parent: Node = null


func _ready() -> void:
	_rng.randomize()
	add_to_group("players")
	collision_layer = 1 << 2
	collision_mask = (1 << 0) | (1 << 1)
	stats = CharacterStats.new(max_health)
	ability_system = AbilitySystem.new()
	for id: String in STARTING_SKILLS:
		ability_system.add_skill(SkillFactory.create(id))
	shield_bash = ability_system.get_skill("shield_bash") as ShieldBash
	_mesh = get_node_or_null("Mesh") as MeshInstance3D
	if _mesh:
		_body_mat = (_mesh.get_surface_override_material(0) as StandardMaterial3D).duplicate()
		_mesh.set_surface_override_material(0, _body_mat)
		_base_color = _body_mat.albedo_color
	_fx_parent = get_parent()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	stats.tick(delta)
	status.tick(delta)
	dodge_cooldown_remaining = maxf(0.0, dodge_cooldown_remaining - delta)
	_invulnerable_time = maxf(0.0, _invulnerable_time - delta)
	_update_hurt_flash(delta)
	_move(delta)

	attack_timer -= delta
	if attack_timer <= 0.0:
		auto_attack()
		attack_timer = attack_interval * stats.attack_interval_multiplier()

	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	ability_system.tick(delta, enemies)
	for i in SKILL_ACTIONS.size():
		if InputMap.has_action(SKILL_ACTIONS[i]) and Input.is_action_just_pressed(SKILL_ACTIONS[i]):
			cast_skill(SkillFactory.SKILL_IDS[i])
	if auto_cast:
		_auto_cast(enemies)
	if InputMap.has_action("dash") and Input.is_action_just_pressed("dash"):
		dodge()




func _move(delta: float) -> void:
	if _dash_time > 0.0:
		_dash_time -= delta
		velocity = _dash_velocity
	else:
		var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var direction: Vector3 = Vector3(input_dir.x, 0, input_dir.y).normalized()
		if move_override != Vector3.ZERO:
			direction = move_override.normalized()
		var speed: float = SPEED * status.speed_multiplier()
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			facing = direction
			rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 0.25)
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
	velocity.y = 0.0
	move_and_slide()
	global_position = Vector3(clampf(global_position.x, -ARENA_HALF, ARENA_HALF), 0.0,
			clampf(global_position.z, -ARENA_HALF, ARENA_HALF))


## 闪避翻滚：短距离位移 + 无敌帧。返回是否成功。
func dodge() -> bool:
	if dodge_cooldown_remaining > 0.0 or _dash_time > 0.0:
		return false
	dodge_cooldown_remaining = stats.dodge_cooldown()
	_start_dash(facing * DODGE_SPEED, DODGE_TIME)
	_invulnerable_time = DODGE_TIME + 0.12
	SkillVfx.pulse_ring(_fx_parent, global_position, 1.2, Color(0.6, 0.8, 1.0, 0.4), 0.2)
	return true


func _start_dash(v: Vector3, time: float) -> void:
	_dash_velocity = v
	_dash_time = time


func make_context(enemies: Array) -> SkillContext:
	var ctx: SkillContext = SkillContext.new()
	ctx.caster = self
	ctx.origin = global_position
	ctx.facing = facing
	ctx.targets = enemies
	ctx.damage_mult = stats.damage_multiplier()
	ctx.magnet = stats.has_equipment("magnetic_boots")
	return ctx


## 施放技能；未拥有或冷却中返回空字典。
func cast_skill(skill_id: String) -> Dictionary:
	if is_dead or not ability_system.can_cast(skill_id):
		return {}
	var skill: Skill = ability_system.get_skill(skill_id)
	var ctx: SkillContext = make_context(get_tree().get_nodes_in_group("enemies"))
	ctx.damage_mult *= skill.level_bonus()
	if skill_id == "taunt":
		ctx.area_mult = stats.taunt_radius_multiplier()
	var result: Dictionary = ability_system.cast(skill_id, ctx)
	if result.is_empty():
		return result
	stats.on_damage_dealt(int(result.get("hits", 0)), float(result.get("damage", 0.0)), false)
	_apply_skill_result(skill_id, result, ctx)
	return result


func _apply_skill_result(skill_id: String, result: Dictionary, ctx: SkillContext) -> void:
	var tier: int = int(result.get("tier", 1))
	match skill_id:
		"shield_bash":
			SkillVfx.shield_bash(_fx_parent, ctx.origin, ctx.flat_facing(), ShieldBash.BASE_RANGE * (1.5 if tier >= 5 else 1.0))
			if tier >= 5:
				SkillVfx.pulse_ring(_fx_parent, ctx.origin, ShieldBash.BASE_RANGE * 2.25, Color(0.4, 0.7, 1.0, 0.3))
			if int(result.hits) > 0:
				_shake(0.25)
		"whirlwind":
			SkillVfx.whirlwind(_fx_parent, self, float(result.radius), float(result.duration))
		"taunt":
			SkillVfx.pulse_ring(_fx_parent, ctx.origin, float(result.radius), Color(1.0, 0.3, 0.2, 0.35), 0.4)
			if float(result.get("shield", 0.0)) > 0.0:
				stats.add_shield(float(result.shield))
		"charge":
			var end: Vector3 = result.end_position
			end = Vector3(clampf(end.x, -ARENA_HALF, ARENA_HALF), 0.0, clampf(end.z, -ARENA_HALF, ARENA_HALF))
			_start_dash((end - global_position) / CHARGE_TIME, CHARGE_TIME)
			_invulnerable_time = CHARGE_TIME
			SkillVfx.dash_trail(_fx_parent, ctx.origin, end, Charge.HALF_WIDTH * 2.0,
					Color(1.0, 0.5, 0.1, 0.45) if tier >= 8 else Color(0.5, 0.8, 1.0, 0.4))
			if tier >= 5:
				SkillVfx.pulse_ring(_fx_parent, end, Charge.IMPACT_RADIUS, Color(1.0, 0.8, 0.3, 0.4))
			_shake(0.2)
		"ground_slam":
			SkillVfx.pulse_ring(_fx_parent, ctx.origin, float(result.radius), Color(0.8, 0.6, 0.3, 0.5), 0.35)
			_shake(0.35)
		"reflect_aura":
			stats.set_aura(float(result.aura_duration), float(result.reflect), float(result.reduction))
			SkillVfx.whirlwind(_fx_parent, self, ReflectAura.AURA_RADIUS, float(result.aura_duration), Color(1.0, 0.85, 0.3, 0.35))
	for zone: GroundZone in ctx.new_zones:
		if zone.anchor == null:
			var color: Color = SkillVfx.FLAME_COLOR if zone.kind == "flame" else Color(0.6, 0.45, 0.2, 0.3)
			SkillVfx.ground_zone(_fx_parent, zone.a, zone.b, zone.half_width, zone.remaining, color)
	SfxManager.play_whoosh(_fx_parent)
	print("[PlayerM1] %s Lv%d (Tier%d) hits=%d damage=%.0f" % [skill_id, ability_system.get_level(skill_id),
			tier, int(result.get("hits", 0)), float(result.get("damage", 0.0))])


## 范围脉冲：对 attack_range 内所有存活敌人造成伤害（铁卫近战范围定位的灰盒版）。
## 烈焰核心附加燃烧，汲取手套吸血。返回命中数量，便于测试。
func auto_attack() -> int:
	var hits: int = 0
	var damage: float = attack_damage * stats.damage_multiplier()
	var range_sq: float = attack_range * attack_range
	var burn: bool = stats.has_equipment("flame_core")
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node3D) or not enemy.is_alive:
			continue
		var offset: Vector3 = (enemy as Node3D).global_position - global_position
		offset.y = 0.0
		if offset.length_squared() <= range_sq:
			enemy.take_damage(damage)
			if burn and enemy.is_alive and "status" in enemy:
				enemy.status.apply_burn(FLAME_CORE_BURN_DPS * stats.damage_multiplier(), 3.0)
			hits += 1
	if hits > 0:
		stats.on_damage_dealt(hits, damage * hits, true)
		SkillVfx.pulse_ring(_fx_parent, global_position, attack_range,
				Color(1.0, 0.5, 0.2, 0.18) if burn else Color(0.7, 0.85, 1.0, 0.15), 0.18)
	return hits


## 自动施放：技能好了且 6 米内有敌人就放（反射光环等被围时再放）。
func _auto_cast(enemies: Array) -> void:
	var near: int = 0
	for e: Node in enemies:
		if e is Node3D and (e as Node3D).global_position.distance_squared_to(global_position) < 36.0:
			near += 1
	if near == 0:
		return
	for id: String in SkillFactory.SKILL_IDS:
		if id == "reflect_aura" and near < 5:
			continue
		if ability_system.can_cast(id):
			cast_skill(id)
			return


## source：造成伤害的敌人节点，或描述伤害来源的字符串（用于死亡原因）。
func take_damage(amount: float, source: Variant = null) -> void:
	if is_dead or _invulnerable_time > 0.0:
		return
	var result: Dictionary = stats.receive_damage(amount, _rng.randf())
	if float(result.reflect) > 0.0 and source is Node and is_instance_valid(source) and source.has_method("take_damage"):
		source.take_damage(float(result.reflect))
	if result.blocked:
		SkillVfx.pulse_ring(_fx_parent, global_position, 1.5, Color(0.9, 0.9, 1.0, 0.5), 0.15)
		return
	last_damage_source = _describe_source(source)
	var key: String = last_damage_source.split("·")[-1]
	damage_taken_by_source[key] = float(damage_taken_by_source.get(key, 0.0)) + float(result.taken)
	if float(result.taken) > 0.0:
		_hurt_flash = 0.12
	if not stats.is_alive():
		die()


static func _describe_source(source: Variant) -> String:
	if source is Node and is_instance_valid(source) and source.has_method("get_display_name"):
		return source.get_display_name()
	if source is String:
		return source
	return "未知"


func apply_slow(factor: float, duration: float) -> void:
	status.apply_slow(factor, duration)


func die() -> void:
	if is_dead:
		return
	is_dead = true
	var reason: String = "被 %s 击倒" % last_damage_source
	print("[PlayerM1] died: %s" % reason)
	died.emit(reason)


func add_equipment(item_id: String) -> void:
	stats.add_equipment(item_id)
	equipment_added.emit(item_id)
	print("[PlayerM1] equipment: %s" % ItemCatalog.equipment_name(item_id))


func heal(amount: float) -> void:
	stats.heal(amount)


func get_health() -> float:
	return stats.health


func get_max_health() -> float:
	return stats.max_health


func _update_hurt_flash(delta: float) -> void:
	if _body_mat == null:
		return
	if _hurt_flash > 0.0:
		_hurt_flash -= delta
		_body_mat.albedo_color = Color(1, 0.3, 0.3)
	elif _invulnerable_time > 0.0:
		_body_mat.albedo_color = Color(0.7, 0.9, 1.0)
	else:
		_body_mat.albedo_color = _base_color


func _shake(strength: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam and cam.has_method("shake"):
		cam.shake(strength)
