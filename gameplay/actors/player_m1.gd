extends CharacterBody3D
## 玩家：移动、闪避、自动攻击、6 个主技能、被动/装备、受击结算。角色（铁卫/元素术士）由 character_id 决定。
## 数值规则在 CharacterStats / 各 Skill 里，这里只负责输入、场景交互和表现。
## 联机（M2）按 control 分四种：
## - LOCAL     单人或主机本地玩家：读键盘，完整结算
## - REMOTE    主机上的远程玩家：读网络输入（net_*），完整结算；掉线时 ai_controlled 由机器人代打
## - PREDICTED 客户端自己的角色：读键盘本地预测移动，不结算战斗，位置由主机校正
## - PUPPET    客户端上的其他玩家：只插值显示主机快照

signal died(reason: String)
signal revived
## 客户端预测闪避时发出，NetSession 转发给主机。
signal dodge_requested
signal equipment_added(item_id: String)
## 实际扣血后发出（HUD 受伤闪红、飘字）。
signal hurt(amount: float)

enum ControlMode { LOCAL, REMOTE, PREDICTED, PUPPET }

const SPEED: float = 8.0
const DODGE_SPEED: float = 26.0
const DODGE_TIME: float = 0.18
const CHARGE_TIME: float = 0.2
const ARENA_HALF: float = 97.0
const FLAME_CORE_BURN_DPS: float = 12.0
## 技能栏：输入动作 -> 技能 id（顺序与角色的 skills 列表一致）
const SKILL_ACTIONS: Array[String] = ["skill_0", "skill_1", "skill_2", "skill_3", "skill_4", "skill_5"]
const SLOT_COLORS: Array[Color] = [Color(0.2, 0.6, 1.0), Color(1.0, 0.6, 0.15), Color(0.7, 0.35, 1.0), Color(0.3, 0.9, 0.5)]
const REVIVE_HEALTH_RATIO: float = 0.3

@export var max_health: float = 1000.0
@export var attack_damage: float = 25.0
@export var attack_range: float = 3.5
@export var attack_interval: float = 1.0
## 自动施放：技能冷却好且附近有敌人时自动释放（T 键切换）。
@export var auto_cast: bool = false

## 角色 id（CharacterCatalog）。远程/傀儡玩家在加入场景树前设置；
## 留空时（场景里的本地玩家）在 _ready 读 NetConfig.character_id——子节点 _ready 早于游戏场景，场景来不及设置。
var character_id: String = ""
var move_speed: float = SPEED
## "pulse" 自身周围范围脉冲（铁卫），"bolt" 射击最近的敌人（元素术士/牧师），"slash" 近身斩击（影行者）
var attack_kind: String = "pulse"
## 暴击率（影行者），自动攻击和技能共用，暴击 2 倍伤害。
var crit_chance: float = 0.0
var _bolt_color: Color = Color(0.6, 0.75, 1.0, 0.8)
## 远程普攻的飞行物外观（SkillVfx.missile 的 kind）：元素术士 crystal，牧师 holy
var _bolt_fx: String = "crystal"
## 治疗与护盾倍率（天赋）
var heal_mult: float = 1.0
## 天赋等级 {天赋 id: 等级}。本地玩家在 _ready 读存档；主机上的远程玩家由 NetSession 在加入场景树前写入。
var talent_ranks: Dictionary = {}
var _talents_set: bool = false
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
## 联机：槽位（0 = 主机）、控制方式、显示名
var net_slot: int = 0
var control: ControlMode = ControlMode.LOCAL
var display_name: String = "铁卫"
## REMOTE：最近一次网络输入（移动方向、朝向、已处理序号）
var net_move: Vector3 = Vector3.ZERO
var net_facing: Vector3 = Vector3.FORWARD
var net_input_seq: int = 0
## 掉线托管 / --bot：由 PlayerBot 驱动 move_override 并自动施放
var ai_controlled: bool = false
var bot: PlayerBot = null
## 倒地后被队友救起的进度（0-1），由游戏场景的救援逻辑写入
var revive_progress: float = 0.0
## PUPPET / PREDICTED：主机快照给出的目标位置和朝向
var net_target_position: Vector3 = Vector3.ZERO
var net_target_rotation: float = 0.0
var _correction: Vector3 = Vector3.ZERO
## PREDICTED：[序号, 本地预测位置]，收到主机确认后对比误差
var _history: Array = []
var last_prediction_error: float = 0.0
var _dash_velocity: Vector3 = Vector3.ZERO
var _dash_time: float = 0.0
var _invulnerable_time: float = 0.0
var _hurt_flash: float = 0.0
var _mesh: MeshInstance3D = null
var _base_color: Color = Color(0.2, 0.6, 1.0)
## 每个玩家自己的两份材质：身体（顶点色 × 染色）和队伍色部件（槽位颜色 × 染色）。灰盒时只有 _team_mat。
var _body_mat: StandardMaterial3D = null
var _team_mat: StandardMaterial3D = null
var _has_model: bool = false
## 程序化身体动作（纯表现，各端按自己看到的位移计算，不走网络）
var _mesh_base: Vector3 = Vector3.ZERO
var _anim_prev_pos: Vector3 = Vector3.ZERO
var _anim_vel: Vector3 = Vector3.ZERO
var _anim_phase: float = 0.0
var _anim_lean: float = 0.0
var _anim_roll: float = 0.0
var _anim_punch: float = 0.0
var _anim_down: float = 0.0
var _ghost_timer: float = 0.0
var _last_hurt_flash: float = 0.0
## 拆件模型的四肢动画；没有 <model>_rig.glb 时为 null（整块模型只做整体动作）
var _rig: PlayerRig = null
## 整块模型网格：残影、剪影用（拆件后 "Mesh" 节点本身没有网格）
var ghost_mesh: Mesh = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _fx_parent: Node = null


func _ready() -> void:
	_rng.randomize()
	add_to_group("players")
	collision_layer = 1 << 2
	collision_mask = (1 << 0) | (1 << 1)
	if character_id.is_empty():
		character_id = NetConfig.character_id
	var cdef: Dictionary = CharacterCatalog.get_def(character_id)
	max_health = cdef.max_health
	move_speed = cdef.move_speed
	attack_kind = cdef.attack
	attack_damage = cdef.attack_damage
	attack_range = cdef.attack_range
	attack_interval = cdef.attack_interval
	crit_chance = cdef.get("crit_chance", 0.0)
	_bolt_color = cdef.get("bolt_color", Color(0.6, 0.75, 1.0, 0.8))
	_bolt_fx = cdef.get("bolt_fx", "crystal")
	stats = CharacterStats.new(max_health)
	ability_system = AbilitySystem.new()
	for id: String in cdef.skills:
		ability_system.skill_pool.append(id)
	for id: String in cdef.starting:
		ability_system.add_skill(SkillFactory.create(id))
	ability_system.strike_landed.connect(_on_strike_landed)
	if control == ControlMode.LOCAL or control == ControlMode.PREDICTED:
		if not _talents_set:
			talent_ranks = Talents.ranks(character_id)
	Talents.apply(self, character_id, talent_ranks)
	shield_bash = ability_system.get_skill("shield_bash") as ShieldBash
	_mesh = get_node_or_null("Mesh") as MeshInstance3D
	if _mesh:
		_apply_model()
	_fx_parent = get_parent()
	if _mesh:
		_mesh_base = _mesh.position
	_anim_prev_pos = global_position
	if control == ControlMode.PUPPET:
		collision_layer = 0  # 客户端上的他人只是显示
	net_target_position = global_position


func _process(delta: float) -> void:
	_animate_body(delta)


## 程序化身体动作：按实际位移速度计算——跑动时上下颠、前倾、左右轻摆，落步扬尘；
## 冲刺（闪避/冲锋）时拉长并留残影；受击缩一下；倒地侧躺。静止时轻微呼吸。
func _animate_body(delta: float) -> void:
	if _mesh == null or delta <= 0.0:
		return
	var moved: Vector3 = (global_position - _anim_prev_pos) * Vector3(1, 0, 1)
	_anim_prev_pos = global_position
	if moved.length() > 6.0:
		moved = Vector3.ZERO  # 瞬移 / 快照跳变
	_anim_vel = _anim_vel.lerp(moved / delta, clampf(delta * 15.0, 0.0, 1.0))
	var speed: float = _anim_vel.length()
	var run: float = clampf(speed / maxf(move_speed, 1.0), 0.0, 1.0)
	var dashing: bool = speed > move_speed * 1.8
	# 步频随速度变化；每半个周期落一次脚
	var prev_phase: float = _anim_phase
	_anim_phase += delta * (4.0 + 7.0 * run) if run > 0.05 else delta * 1.5
	var local_vel: Vector3 = global_transform.basis.inverse() * _anim_vel
	# 前方是 -Z：向前跑时 local_vel.z < 0，绕 X 轴负向旋转 = 头向前倾
	var lean_target: float = 0.0 if dashing else clampf(local_vel.z / maxf(move_speed, 1.0), -1.0, 1.0) * 0.16
	var roll_target: float = clampf(local_vel.x / maxf(move_speed, 1.0), -1.0, 1.0) * -0.1
	_anim_lean = lerpf(_anim_lean, lean_target, clampf(delta * 10.0, 0.0, 1.0))
	_anim_roll = lerpf(_anim_roll, roll_target, clampf(delta * 10.0, 0.0, 1.0))
	# 受击：hurt_flash 刚被点亮时缩一下
	if _hurt_flash > _last_hurt_flash + 0.01:
		_anim_punch = 1.0
	_last_hurt_flash = _hurt_flash
	_anim_punch = move_toward(_anim_punch, 0.0, delta * 6.0)
	_anim_down = move_toward(_anim_down, 1.0 if is_dead else 0.0, delta * 4.0)
	var bob: float = absf(sin(_anim_phase)) * 0.12 * run
	var breathe: float = sin(_anim_phase * 1.3) * 0.015 * (1.0 - run)
	var stretch: float = 0.25 if dashing else 0.0
	var squash: float = _anim_punch * 0.18
	var sy: float = 1.0 + breathe + stretch * 0.4 - squash - bob * 0.3
	var sxz: float = 1.0 - breathe * 0.5 - stretch * 0.25 + squash * 0.6
	_mesh.position = _mesh_base + Vector3(0, bob + _anim_down * 0.2, 0)
	_mesh.rotation = Vector3(_anim_lean - (0.35 if dashing else 0.0),
			0.0, _anim_roll + sin(_anim_phase) * 0.05 * run + _anim_down * 1.45)
	_mesh.scale = Vector3(sxz, sy, sxz * (1.0 + stretch))
	if _rig != null:
		_rig.update(delta, _anim_phase, 0.0 if dashing else run, _anim_punch, _anim_down)
	if not VfxKit.enabled():
		return
	# 落步扬尘（每落一脚一次，速度够快才有）
	if run > 0.6 and not dashing and int(prev_phase / PI) != int(_anim_phase / PI):
		ParticleFx.burst(_fx_parent, "dust", global_position + Vector3(0, 0.05, 0), 0.25, Color(0.7, 0.62, 0.5, 0.45))
	# 高速位移残影
	_ghost_timer -= delta
	if dashing and _ghost_timer <= 0.0 and ghost_mesh != null:
		_ghost_timer = 0.035
		SkillVfx.ghost_at(_fx_parent, ghost_mesh, global_position, -global_transform.basis.z, _base_color.lightened(0.3), 0.25)


func _physics_process(delta: float) -> void:
	match control:
		ControlMode.PUPPET:
			_puppet_step(delta)
			return
		ControlMode.PREDICTED:
			_predicted_step(delta)
			return
	_update_hurt_flash(delta)
	if is_dead:
		return
	stats.tick(delta)
	status.tick(delta)
	dodge_cooldown_remaining = maxf(0.0, dodge_cooldown_remaining - delta)
	_invulnerable_time = maxf(0.0, _invulnerable_time - delta)

	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	if ai_controlled and bot != null:
		bot.think(self, enemies)
	_move(delta, _desired_direction())

	attack_timer -= delta
	if attack_timer <= 0.0:
		auto_attack()
		attack_timer = attack_interval * stats.attack_interval_multiplier()

	ability_system.tick(delta, enemies, PlayerQuery.alive(get_tree()) if ability_system.has_zones() else [])
	if control == ControlMode.LOCAL and not ai_controlled:
		for i in SKILL_ACTIONS.size():
			if InputMap.has_action(SKILL_ACTIONS[i]) and Input.is_action_just_pressed(SKILL_ACTIONS[i]):
				cast_skill(ability_system.pool()[i])
		if InputMap.has_action("dash") and Input.is_action_just_pressed("dash"):
			dodge()
	if auto_cast or ai_controlled:
		_auto_cast(enemies)


## 本帧期望移动方向：机器人/测试 move_override > 网络输入（REMOTE）> 键盘。
func _desired_direction() -> Vector3:
	if move_override != Vector3.ZERO:
		return move_override.normalized()
	if control == ControlMode.REMOTE and not ai_controlled:
		if net_facing != Vector3.ZERO:
			facing = net_facing
		return net_move.normalized() if net_move.length_squared() > 0.01 else Vector3.ZERO
	return keyboard_direction()


static func keyboard_direction() -> Vector3:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return Vector3(input_dir.x, 0, input_dir.y).normalized()


## 客户端自己的角色：键盘本地预测移动，逐渐消除与主机位置的误差；战斗全部由主机结算。
func _predicted_step(delta: float) -> void:
	_update_hurt_flash(delta)
	dodge_cooldown_remaining = maxf(0.0, dodge_cooldown_remaining - delta)
	if is_dead:
		global_position = global_position.lerp(net_target_position, 0.2)
		return
	var dir: Vector3 = move_override.normalized() if move_override != Vector3.ZERO else keyboard_direction()
	_move(delta, dir)
	# 误差修正：每帧吸收 15%，误差过大（冲锋、被传送）直接对齐
	var step: Vector3 = _correction if _correction.length() > 4.0 else _correction * 0.15
	global_position += step
	_correction -= step
	for h: Array in _history:
		h[1] += step  # 已修正的部分同步到历史，避免下次确认时重复计算


## 记录本帧（输入序号 seq 处理后）的预测位置。
func record_prediction(seq: int) -> void:
	_history.append([seq, global_position])
	if _history.size() > 120:
		_history.pop_front()


## 主机确认已处理到 acked_seq，此时主机位置为 server_pos。
func server_ack(acked_seq: int, server_pos: Vector3) -> void:
	while not _history.is_empty() and _history[0][0] < acked_seq:
		_history.pop_front()
	if _history.is_empty() or _history[0][0] != acked_seq:
		return
	var error: Vector3 = (server_pos - _history[0][1]) * Vector3(1, 0, 1)
	last_prediction_error = error.length()
	# 尚未吸收的修正量已经算在 error 里
	_correction = error


## 客户端上的其他玩家：平滑插值到快照位置。
func _puppet_step(delta: float) -> void:
	_update_hurt_flash(delta)
	var k: float = clampf(delta * 12.0, 0.0, 1.0)
	if global_position.distance_to(net_target_position) > 8.0:
		global_position = net_target_position
	else:
		global_position = global_position.lerp(net_target_position, k)
	rotation.y = lerp_angle(rotation.y, net_target_rotation, k)


func _move(delta: float, direction: Vector3) -> void:
	if _dash_time > 0.0:
		_dash_time -= delta
		velocity = _dash_velocity
	else:
		var speed: float = move_speed * status.speed_multiplier()
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			facing = direction
			rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 0.25)
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
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
	_invulnerable_time = DODGE_TIME + 0.12 + (0.3 if stats.has_equipment("night_cloak") else 0.0)
	if control == ControlMode.PREDICTED:
		dodge_requested.emit()
	else:  # 客户端预测时特效由主机回放
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
	ctx.crit_chance = crit_chance
	ctx.crit_mult = 2.0
	if stats.has_equipment("backstab_dagger"):
		ctx.crit_mult = 2.6
	ctx.area_mult = 1.0
	if stats.has_equipment("range_lens"):
		ctx.area_mult *= 1.2
	if stats.has_equipment("grace_staff"):
		ctx.area_mult *= 1.25
	ctx.allies = PlayerQuery.all(get_tree())
	ctx.crit_chance = crit_chance
	ctx.rng = _rng
	ctx.heal_mult = heal_mult
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


## 技能结算后的位移、状态和手感（音效 / 震屏 / 顿帧）；视觉特效交给 SkillFx 按段位编排。
func _apply_skill_result(skill_id: String, result: Dictionary, ctx: SkillContext) -> void:
	var tier: int = int(result.get("tier", 1))
	var hits: int = int(result.get("hits", 0))
	match skill_id:
		"shield_bash":
			if hits > 0:
				_shake(0.2 + 0.05 * tier)
				HitStop.trigger(get_tree(), 0.03 + 0.005 * tier)
				SfxManager.play(_fx_parent, "heavy")
		"taunt":
			if float(result.get("shield", 0.0)) > 0.0:
				stats.add_shield(float(result.shield))
		"charge":
			var end: Vector3 = result.end_position
			end = Vector3(clampf(end.x, -ARENA_HALF, ARENA_HALF), 0.0, clampf(end.z, -ARENA_HALF, ARENA_HALF))
			result.end_position = end
			_start_dash((end - global_position) / CHARGE_TIME, CHARGE_TIME)
			_invulnerable_time = CHARGE_TIME
			if hits > 0:
				SfxManager.play(_fx_parent, "heavy")
				HitStop.trigger(get_tree(), 0.04)
			_shake(0.2 + (0.1 if tier >= 5 else 0.0))
		"ground_slam":
			SfxManager.play(_fx_parent, "slam")
			HitStop.trigger(get_tree(), 0.06)
			_shake(0.35 + (0.15 if tier >= 8 else 0.0))
		"reflect_aura":
			stats.set_aura(float(result.aura_duration), float(result.reflect), float(result.reduction))
		"fireball":
			if hits > 0:
				SfxManager.play(_fx_parent, "explode")
		"ice_lance":
			if hits > 0:
				SfxManager.play(_fx_parent, "shatter")
		"frost_nova":
			SfxManager.play(_fx_parent, "shatter")
			_shake(0.2)
		"chain_lightning":
			if hits > 0:
				SfxManager.play(_fx_parent, "heavy")
		"shadow_step":
			var path: Array = result.get("path", [])
			if path.size() >= 2:
				var end: Vector3 = result.end_position
				end = Vector3(clampf(end.x, -ARENA_HALF, ARENA_HALF), 0.0, clampf(end.z, -ARENA_HALF, ARENA_HALF))
				if MapBase.current:
					end = MapBase.current.find_free(end, 0.6)
				global_position = end
				_invulnerable_time = maxf(_invulnerable_time, 0.25)
				if hits > 0:
					SfxManager.play(_fx_parent, "heavy")
					HitStop.trigger(get_tree(), 0.03)
		"smoke_bomb":
			_invulnerable_time = maxf(_invulnerable_time, float(result.invulnerable))
		"execute":
			if result.has("center"):
				if result.executed:
					HitStop.trigger(get_tree(), 0.06)
					_shake(0.25 + (0.15 if tier >= 8 else 0.0))
				SfxManager.play(_fx_parent, "heavy")
		"smite":
			if hits > 0:
				SfxManager.play(_fx_parent, "slam")
		"divine_intervention":
			SfxManager.play(_fx_parent, "evolve")
	SkillFx.play(_fx_parent, self, skill_id, result, ctx.origin, ctx.flat_facing(), tier)
	for zone: GroundZone in ctx.new_zones:
		if zone.anchor == null:
			var color: Color = Color(0.6, 0.45, 0.2, 0.3)
			match zone.kind:
				"flame": color = SkillVfx.FLAME_COLOR
				"frost": color = Color(0.5, 0.85, 1.0, 0.3)
				"smoke": color = Color(0.35, 0.3, 0.45, 0.45)
				"holy": color = Color(1.0, 0.9, 0.45, 0.3)
			SkillVfx.ground_zone(_fx_parent, zone.a, zone.b, zone.half_width, zone.remaining, color, zone.kind)
	SfxManager.play_whoosh(_fx_parent)
	print("[PlayerM1] %s Lv%d (Tier%d) hits=%d damage=%.0f" % [skill_id, ability_system.get_level(skill_id),
			tier, hits, float(result.get("damage", 0.0))])


## 自动攻击。烈焰核心附加燃烧，汲取手套吸血。返回命中数量，便于测试。
## pulse（铁卫）：对 attack_range 内所有存活敌人造成伤害；bolt（元素术士）：射击 attack_range 内最近的敌人。
func auto_attack() -> int:
	var damage: float = attack_damage * stats.damage_multiplier()
	var burn: bool = stats.has_equipment("flame_core")
	var victims: Array = []
	match attack_kind:
		"pulse": victims = _pulse_victims()
		"slash": victims = _slash_victims()
		_: victims = _bolt_victims()
	var dealt_total: float = 0.0
	for enemy: Variant in victims:
		var crit: float = 2.6 if stats.has_equipment("backstab_dagger") else 2.0
		var dealt: float = damage * (crit if crit_chance > 0.0 and _rng.randf() < crit_chance else 1.0)
		enemy.take_damage(dealt)
		dealt_total += dealt
		if burn and enemy.is_alive and "status" in enemy:
			enemy.status.apply_burn(FLAME_CORE_BURN_DPS * stats.damage_multiplier(), 3.0)
	var hits: int = victims.size()
	if hits > 0:
		stats.on_damage_dealt(hits, dealt_total, true)
		SkillFx.auto_attack(_fx_parent, self, attack_kind, _bolt_fx, victims, attack_range, burn, _bolt_color)
	return hits


func _pulse_victims() -> Array:
	var result: Array = []
	var range_sq: float = attack_range * attack_range
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node3D) or not enemy.is_alive:
			continue
		var offset: Vector3 = (enemy as Node3D).global_position - global_position
		offset.y = 0.0
		if offset.length_squared() <= range_sq:
			result.append(enemy)
	return result


## 斩击：attack_range 内最近的敌人 + 它 1.5 米内的敌人（顺劈），最多 3 个。
func _slash_victims() -> Array:
	var first: Array = _bolt_victims()
	if first.is_empty():
		return first
	var center: Vector3 = (first[0] as Node3D).global_position
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if first.size() >= 3:
			break
		if enemy != first[0] and enemy is Node3D and enemy.is_alive \
				and (enemy as Node3D).global_position.distance_squared_to(center) < 1.5 * 1.5:
			first.append(enemy)
	return first


func _bolt_victims() -> Array:
	var best: Node3D = null
	var best_d: float = attack_range * attack_range
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node3D) or not enemy.is_alive:
			continue
		var d: float = ((enemy as Node3D).global_position - global_position).length_squared()
		if d < best_d:
			best_d = d
			best = enemy
	return [best] if best != null else []


## 自动施放：技能好了且附近有敌人就放（近战 6 米、远程 12 米）。
## 反射光环/烟雾弹被围时再放，神圣干预在有人低血或倒地时再放。
func _auto_cast(enemies: Array) -> void:
	var r: float = 12.0 if attack_kind == "bolt" else 6.0
	var near: int = 0
	for e: Node in enemies:
		if e is Node3D and (e as Node3D).global_position.distance_squared_to(global_position) < r * r:
			near += 1
	if near == 0:
		return
	for id: String in ability_system.pool():
		if (id == "reflect_aura" or id == "smoke_bomb") and near < 5:
			continue
		if id == "divine_intervention" and not _someone_needs_rescue():
			continue
		if ability_system.can_cast(id):
			cast_skill(id)
			return


func _someone_needs_rescue() -> bool:
	for p: Node in get_tree().get_nodes_in_group("players"):
		if p.is_dead or p.stats.health_ratio() < 0.45:
			return true
	return false


## source：造成伤害的敌人节点，或描述伤害来源的字符串（用于死亡原因）。
func take_damage(amount: float, source: Variant = null) -> void:
	if is_dead or _invulnerable_time > 0.0:
		return
	var result: Dictionary = stats.receive_damage(amount, _rng.randf())
	if float(result.reflect) > 0.0 and source is Node and is_instance_valid(source) and source.has_method("take_damage"):
		source.take_damage(float(result.reflect))
	if result.blocked:
		SkillVfx.pulse_ring(_fx_parent, global_position, 1.5, Color(0.9, 0.9, 1.0, 0.5), 0.15)
		SkillVfx.burst(_fx_parent, "spark", global_position + Vector3(0, 1.2, 0), 0.7, Color(0.9, 0.95, 1.0))
		SfxManager.play(_fx_parent, "block")
		return
	last_damage_source = _describe_source(source)
	var key: String = last_damage_source.split("·")[-1]
	damage_taken_by_source[key] = float(damage_taken_by_source.get(key, 0.0)) + float(result.taken)
	if float(result.taken) > 0.0:
		_hurt_flash = 0.12
		hurt.emit(float(result.taken))
		if float(result.taken) >= 20.0:
			SfxManager.play(_fx_parent, "hurt")
	if not stats.is_alive() and stats.try_second_wind():
		_invulnerable_time = maxf(_invulnerable_time, 2.0)
		SkillVfx.burst(_fx_parent, "star", global_position + Vector3(0, 1, 0), 1.6, Color(1.0, 0.9, 0.5))
		SfxManager.play(_fx_parent, "evolve")
		return
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
	revive_progress = 0.0
	velocity = Vector3.ZERO
	var reason: String = "被 %s 击倒" % last_damage_source
	print("[%s] died: %s" % [display_name, reason])
	died.emit(reason)


## 槽位确定后刷新身体颜色。
func refresh_color() -> void:
	_base_color = SLOT_COLORS[net_slot % SLOT_COLORS.size()]
	if _has_model:
		_team_mat.albedo_color = _base_color


## 被队友救起（多人）：恢复 30% 生命和短暂无敌。
func revive() -> void:
	if not is_dead:
		return
	is_dead = false
	revive_progress = 0.0
	stats.health = stats.max_health * REVIVE_HEALTH_RATIO
	_invulnerable_time = 2.0
	revived.emit()
	SkillVfx.pulse_ring(_fx_parent, global_position, 3.0, Color(0.4, 1.0, 0.5, 0.5), 0.4)


func is_invulnerable() -> bool:
	return _invulnerable_time > 0.0


## 主机收到的远程输入（REMOTE）。
## 远程玩家加入场景树前调用（主机校验过的天赋等级）。
func set_talents(ranks_dict: Dictionary) -> void:
	talent_ranks = ranks_dict
	_talents_set = true


func apply_net_input(seq: int, move: Vector3, p_facing: Vector3) -> void:
	if seq <= net_input_seq:
		return
	net_input_seq = seq
	net_move = move
	if p_facing.length_squared() > 0.01:
		net_facing = p_facing.normalized()


func add_equipment(item_id: String) -> void:
	stats.add_equipment(item_id)
	# 固定属性：装备时立即应用
	match item_id:
		"hp_pendant":
			stats.max_health *= 1.25
			stats.health = minf(stats.health, stats.max_health)
		"glass_cannon":
			stats.max_health *= 0.8
			stats.health = minf(stats.health, stats.max_health)
		"crit_amulet":
			crit_chance += 0.12
		"assassin_mark":
			crit_chance += 0.15
		"bulwark_sigil":
			stats.block_chance += 0.1
		"sprint_boots":
			move_speed *= 1.18
		"cd_crystal":
			ability_system.cooldown_mult *= 0.88
		"mana_prism":
			ability_system.cooldown_mult *= 0.85
		"holy_relic":
			heal_mult *= 1.25
	SkillVfx.burst(_fx_parent, "star", global_position + Vector3(0, 1, 0), 1.2)
	SfxManager.play(_fx_parent, "pickup")
	equipment_added.emit(item_id)
	print("[PlayerM1] equipment: %s" % ItemCatalog.equipment_name(item_id))


func heal(amount: float) -> void:
	stats.heal(amount)


func get_health() -> float:
	return stats.health


func get_max_health() -> float:
	return stats.max_health


func _update_hurt_flash(delta: float) -> void:
	if _team_mat == null:
		return
	var tint: Color = Color.WHITE
	if is_dead:
		tint = Color(0.35, 0.35, 0.35).lerp(Color(0.4, 1.0, 0.5), revive_progress)
	elif _hurt_flash > 0.0:
		_hurt_flash -= delta
		tint = Color(1, 0.3, 0.3)
	elif _invulnerable_time > 0.0:
		tint = Color(0.7, 0.9, 1.0)
	if _has_model:
		_body_mat.albedo_color = tint
		_team_mat.albedo_color = _base_color * tint
	else:
		_team_mat.albedo_color = _base_color if tint == Color.WHITE else tint


## 铁卫低模：身体读顶点色，"Team" 表面用槽位颜色。没有模型时保留灰盒胶囊。
func _apply_model() -> void:
	_base_color = SLOT_COLORS[net_slot % SLOT_COLORS.size()]
	var model: Mesh = ModelLibrary.mesh(CharacterCatalog.get_def(character_id).model)
	if model == null:
		_team_mat = (_mesh.get_surface_override_material(0) as StandardMaterial3D).duplicate()
		_mesh.set_surface_override_material(0, _team_mat)
		return
	_has_model = true
	ghost_mesh = model
	_mesh.position = Vector3.ZERO
	_body_mat = ModelLibrary.material().duplicate()
	_team_mat = ModelLibrary.material(_base_color).duplicate()
	var model_id: String = CharacterCatalog.get_def(character_id).model
	var parts: Dictionary = ModelLibrary.rig(model_id)
	if not parts.is_empty():
		# 拆件模型：根节点不显示网格，四肢各自是子节点（PlayerRig 驱动）
		_mesh.mesh = null
		_rig = PlayerRig.new()
		_rig.build(_mesh, parts, _surface_materials)
		return
	_mesh.mesh = model
	var mats: Array = _surface_materials(model)
	for i in mats.size():
		_mesh.set_surface_override_material(i, mats[i])


## 网格每个表面对应的材质："Team" 表面用队伍色，其余读顶点色。
func _surface_materials(m: Mesh) -> Array:
	var team_surface: int = ModelLibrary.surface_index(m, "Team")
	var mats: Array = []
	for i in m.get_surface_count():
		mats.append(_team_mat if i == team_surface else _body_mat)
	return mats


## 播放身体动作（PlayerRig.ACTIONS）。没有拆件模型时忽略。联机时由 SkillVfx.pose 事件在各端调用。
func play_pose(action: String, duration: float = -1.0) -> void:
	if _rig != null:
		_rig.play(action, duration)


## 受击闪红（客户端根据快照血量变化调用）。
func flash_hurt() -> void:
	_hurt_flash = 0.12


func _shake(strength: float) -> void:
	if control == ControlMode.REMOTE:
		SkillVfx.record(["shake", strength, net_slot])  # 只震该玩家自己的屏幕
		return
	SkillVfx.shake(get_tree(), strength, net_slot)


## 陨石术落地：表现层播放爆炸。
func _on_strike_landed(strike: Dictionary, hits: int) -> void:
	if strike.get("kind", "") == "knives":
		SkillVfx.pulse_ring(_fx_parent, strike.center, strike.radius, Color(0.8, 0.8, 0.95, 0.25), 0.2)
		# 刀扇 8 段第二轮：一圈飞刀从身上再次甩出
		SkillVfx.whirlwind(_fx_parent, self, float(strike.radius) * 0.6, 0.35, Color(1.0, 0.5, 0.6, 0.5), "blades", 8)
		SkillVfx.rune(_fx_parent, strike.center, float(strike.radius) * 0.5, Color(1.0, 0.3, 0.45, 0.8), "expand", 0.35)
	else:
		# 陨石落地总是爆炸（没砸到敌人也要看到落点）
		var meteor: Skill = ability_system.get_skill("meteor")
		SkillFx.meteor_landed(_fx_parent, strike.center, strike.radius, strike.get("second_wave", false),
				meteor.get_tier() if meteor != null else 1)
		if hits > 0:
			SfxManager.play(_fx_parent, "explode")
