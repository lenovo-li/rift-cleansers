class_name Enemy extends CharacterBody3D
## 敌人：按 EnemyDef 的行为类型追击 / 冲刺自爆 / 远程吐酸 / 治疗友军 / 死亡留减速区，可带精英词缀。
## 死亡结算（经验、掉落、计数）由监听 died 信号的 EnemySpawner 负责。

signal died(enemy: Enemy)

const DEFAULT_DEF: EnemyDef = preload("res://content/enemies/zombie.tres")
const ProjectileScript: GDScript = preload("res://gameplay/actors/enemy_projectile.gd")
const HazardScript: GDScript = preload("res://gameplay/actors/hazard_zone.gd")
const BlastScript: GDScript = preload("res://gameplay/actors/delayed_blast.gd")
const ELITE_HEALTH_MULT: float = 4.0
const ELITE_EXP_MULT: float = 5.0
const ELITE_SCALE: float = 1.35
const ELITE_COLORS: Dictionary = {
	"teleporter": Color(0.2, 0.9, 1.0), "vampire": Color(0.85, 0.05, 0.25), "haste": Color(1.0, 0.9, 0.1),
	"armored": Color(0.5, 0.55, 0.6), "explosive": Color(1.0, 0.4, 0.05), "regenerating": Color(0.2, 1.0, 0.5),
	"frost": Color(0.6, 0.85, 1.0), "burning": Color(1.0, 0.55, 0.1), "giant": Color(0.8, 0.7, 0.95),
}
const ELITE_NAMES: Dictionary = {
	"teleporter": "传送", "vampire": "吸血", "haste": "迅捷", "armored": "装甲", "explosive": "爆裂",
	"regenerating": "再生", "frost": "冰霜", "burning": "燃烧", "giant": "巨型",
}
const FLASH_TIME: float = 0.08
const KNOCKBACK_DECAY: float = 0.9
const MAGNET_SPEED: float = 14.0
const IMP_EXPLOSION_RADIUS: float = 2.5
## 碰撞层：2 障碍物，3 玩家，4 敌人。敌人之间不做物理碰撞（500 只时物理耗时 19ms → 6ms），
## 改由 EnemySpawner 每帧用网格算分离力写入 separation。
const LAYER_ENEMY: int = 1 << 3
const MASK_ENEMY: int = (1 << 1) | (1 << 2)
const SEPARATION_STRENGTH: float = 4.0

static var _materials: Dictionary = {}  # Color -> StandardMaterial3D（同色敌人共享材质）
static var _meshes: Dictionary = {}     # float scale -> CapsuleMesh
static var _shapes: Dictionary = {}     # float scale -> CapsuleShape3D

var def: EnemyDef = null
var elite_mod: String = ""
var entity_id: int = -1
var max_health: float = 60.0
var current_health: float = 60.0
var exp_reward: float = 2.0
var is_alive: bool = true
var status: StatusEffects = StatusEffects.new()
var target_player: Node3D = null
## 嘲讽：强制把目标锁定为某个玩家若干秒（多人时由嘲讽者承担火力）。
var _taunt_time: float = 0.0
var _retarget_timer: float = 0.0
## 投射物、危险区的父节点（一般是游戏场景根）。
var effects_parent: Node = null
var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_resist: float = 0.0
## 多人时 Boss 血量倍率（加入场景树前设置）。
var health_scale: float = 1.0
## 与邻近敌人的分离向量（由 EnemySpawner 每帧写入）。
var separation: Vector3 = Vector3.ZERO
var attack_timer: float = 0.0
var special_timer: float = 0.0

var _mesh: MeshInstance3D = null
var _base_material: Material = null
## 顶点动画驱动（有带动作分区的模型时才有；灰盒胶囊为 null）
var anim: EnemyAnimator = null
var _flash_timer: float = 0.0
## 下一次 take_damage 的飘字类型（-1 = 按伤害大小自动）
var _number_kind: int = -1
var _magnet_point: Vector3 = Vector3.ZERO
var _magnet_time: float = 0.0
var _teleported: bool = false
var _dash_state: int = 0  # 0 接近 1 蓄力 2 冲刺 3 硬直
var _dash_timer: float = 0.0
var _dash_dir: Vector3 = Vector3.ZERO
var _dash_hit: bool = false
var _burning_timer: float = 0.0


## 生成后、加入场景树之前调用。
func setup(p_def: EnemyDef, p_elite_mod: String, player: Node3D, p_effects_parent: Node) -> void:
	def = p_def
	elite_mod = p_elite_mod
	target_player = player
	effects_parent = p_effects_parent


func _ready() -> void:
	if def == null:
		def = DEFAULT_DEF
	var elite: bool = not elite_mod.is_empty()
	var health_mult: float = ELITE_HEALTH_MULT if elite else 1.0
	if elite_mod == "giant":
		health_mult *= 1.6
	max_health = def.max_health * health_mult * health_scale
	current_health = max_health
	exp_reward = def.exp_reward * (ELITE_EXP_MULT if elite else 1.0)
	special_timer = def.special_cooldown * randf()
	collision_layer = LAYER_ENEMY
	collision_mask = MASK_ENEMY
	add_to_group("enemies")
	var scale_mult: float = ELITE_SCALE if elite else 1.0
	if elite_mod == "giant":
		scale_mult = 1.8
	var s: float = def.body_scale * scale_mult
	_mesh = get_node("Mesh") as MeshInstance3D
	apply_look(_mesh, def, elite_mod)
	_base_material = _mesh.material_override
	if _base_material is ShaderMaterial:
		anim = EnemyAnimator.new(_mesh, move_speed())
	var col: CollisionShape3D = get_node("Collision") as CollisionShape3D
	col.shape = _cached_shape(s)
	col.position = Vector3(0, 0.8 * s, 0)
	_retarget_timer = randf() * 0.5
	if effects_parent == null:
		effects_parent = get_parent()


func get_display_name() -> String:
	var n: String = def.display_name if def != null else "敌人"
	return "%s·%s" % [ELITE_NAMES[elite_mod], n] if not elite_mod.is_empty() else n


func is_elite() -> bool:
	return not elite_mod.is_empty()


func move_speed() -> float:
	var mult: float = 1.0
	if elite_mod == "haste":
		mult = 1.5
	elif elite_mod == "giant":
		mult = 0.85
	return def.move_speed * status.speed_multiplier() * mult


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	var burn: float = status.tick(delta)
	if burn > 0.0:
		_number_kind = DamageNumbers.Kind.BURN
		take_damage(burn)
		_number_kind = -1
		if not is_alive:
			return
	_update_flash(delta)
	_update_elite(delta)
	_update_target(delta)
	if target_player == null:
		return
	# 冰冻：跳过所有行动
	if status.is_frozen():
		velocity = Vector3.ZERO
		return
	if attack_timer > 0.0:
		attack_timer -= delta
	var to_player: Vector3 = target_player.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	var dir: Vector3 = to_player / dist if dist > 0.001 else Vector3.ZERO

	var desired: Vector3 = _behavior_velocity(delta, dir, dist) + separation * SEPARATION_STRENGTH
	if knockback_velocity.length_squared() > 0.04:
		velocity = knockback_velocity
		knockback_velocity *= KNOCKBACK_DECAY
	elif _magnet_time > 0.0:
		_magnet_time -= delta
		var to_magnet: Vector3 = _magnet_point - global_position
		to_magnet.y = 0.0
		velocity = to_magnet.normalized() * MAGNET_SPEED if to_magnet.length() > 1.5 else desired
	else:
		knockback_velocity = Vector3.ZERO
		velocity = desired
	move_and_slide()
	global_position.y = 0.0
	if anim != null:
		anim.update(delta, velocity)
	if desired.length_squared() > 0.01:
		rotation.y = atan2(-desired.x, -desired.z)

	# 近战接触攻击（小鬼由冲刺逻辑结算，食尸鬼只远程）
	if _has_contact_attack() and dist < def.attack_range * def.body_scale and attack_timer <= 0.0:
		_melee(def.attack_damage)


func _has_contact_attack() -> bool:
	return def.behavior != EnemyDef.Behavior.DASHER and def.behavior != EnemyDef.Behavior.RANGED


func _behavior_velocity(delta: float, dir: Vector3, dist: float) -> Vector3:
	var speed: float = move_speed()
	match def.behavior:
		EnemyDef.Behavior.DASHER:
			return _dasher(delta, dir, dist, speed)
		EnemyDef.Behavior.RANGED:
			special_timer -= delta
			if dist < def.attack_range and special_timer <= 0.0:
				special_timer = def.attack_cooldown
				_shoot(dir)
			if dist > def.attack_range * 0.8:
				return dir * speed
			if dist < def.special_range * 0.6:
				return -dir * speed * 0.7  # 太近就后撤
			return Vector3.ZERO
		EnemyDef.Behavior.HEALER:
			special_timer -= delta
			if special_timer <= 0.0:
				special_timer = def.special_cooldown
				_heal_allies()
			return dir * speed if dist > def.special_range else -dir * speed * 0.5
	return dir * speed


## 小鬼：接近 → 0.6 秒蓄力（变白闪烁，可读的前摇）→ 直线冲刺 → 硬直。
func _dasher(delta: float, dir: Vector3, dist: float, speed: float) -> Vector3:
	_dash_timer -= delta
	match _dash_state:
		0:
			if dist < def.special_range and special_timer <= 0.0:
				_dash_state = 1
				_dash_timer = 0.6
				_dash_dir = dir
				_set_windup_flash(true)
				if anim != null:
					anim.attack(EnemyAnimator.Kind.WINDUP, 0.6)
				return Vector3.ZERO
			special_timer -= delta
			return dir * speed
		1:
			if _dash_timer <= 0.0:
				_dash_state = 2
				_dash_timer = 0.45
				_dash_hit = false
				_set_windup_flash(false)
			return Vector3.ZERO
		2:
			if not _dash_hit and global_position.distance_to(target_player.global_position) < 1.4:
				_dash_hit = true
				_melee(def.attack_damage * 1.5)
			if _dash_timer <= 0.0:
				_dash_state = 3
				_dash_timer = 0.8
			return _dash_dir * speed * 4.0
		_:
			if _dash_timer <= 0.0:
				_dash_state = 0
				special_timer = def.special_cooldown
			return dir * speed * 0.3


## 精英词缀的持续效果：再生回血、燃烧留地火（移动时每 0.4 秒一块）。
func _update_elite(delta: float) -> void:
	if elite_mod == "regenerating":
		receive_heal(max_health * 0.02 * delta)
	elif elite_mod == "burning" and velocity.length() > 0.5:
		_burning_timer -= delta
		if _burning_timer <= 0.0:
			_burning_timer = 0.4
			_spawn_burning_zone()


## 每 0.5 秒重新选择最近的存活玩家；被嘲讽期间锁定嘲讽者。
func _update_target(delta: float) -> void:
	_taunt_time -= delta
	_retarget_timer -= delta
	var invalid: bool = target_player == null or not is_instance_valid(target_player) or target_player.get("is_dead")
	if _taunt_time > 0.0 and not invalid:
		return
	if invalid or _retarget_timer <= 0.0:
		_retarget_timer = 0.5
		target_player = PlayerQuery.nearest_alive(get_tree(), global_position)


func apply_taunt(taunter: Node3D, duration: float) -> void:
	if taunter != null and not taunter.get("is_dead"):
		target_player = taunter
		_taunt_time = duration


func _melee(amount: float) -> void:
	attack_timer = def.attack_cooldown
	play_attack(EnemyAnimator.Kind.SWING)
	amount *= status.damage_dealt_multiplier()  # 虚弱 / 腐蚀
	if target_player.has_method("take_damage"):
		target_player.take_damage(amount, self)
		if elite_mod == "vampire":
			# 吸血词缀：回复造成伤害的 100%（相对精英的高血量不算多，但会拖长击杀时间）
			receive_heal(amount)
		elif elite_mod == "frost" and target_player.has_method("apply_slow"):
			target_player.apply_slow(0.5, 1.5)  # 冰霜词缀：命中减速 50%，1.5 秒


func _shoot(dir: Vector3) -> void:
	play_attack(EnemyAnimator.Kind.CAST)
	var p: Node3D = ProjectileScript.new()
	p.setup(self, dir, def.attack_damage, Color(0.4, 1.0, 0.3))
	effects_parent.add_child(p)
	p.global_position = global_position + Vector3(0, 1.0, 0) + dir * 0.8
	SkillVfx.record(["proj", p.global_position, dir])


func _heal_allies() -> void:
	var healed: int = 0
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		var other: Enemy = e as Enemy
		if other == null or other == self or not other.is_alive or other is Boss:
			continue
		if other.global_position.distance_to(global_position) <= def.special_range:
			other.receive_heal(def.special_value)
			healed += 1
	if healed > 0:
		play_attack(EnemyAnimator.Kind.CAST, 0.6)
		SkillVfx.pulse_ring(effects_parent, global_position, def.special_range, Color(0.6, 0.3, 1.0, 0.35), 0.4)


func receive_heal(amount: float) -> void:
	current_health = minf(max_health, current_health + amount * status.healing_multiplier())  # 中毒削减治疗


func take_damage(amount: float) -> void:
	if not is_alive:
		return
	if elite_mod == "armored":
		amount *= 0.6
	amount *= status.damage_taken_multiplier()  # 死亡标记、感电、腐蚀
	current_health -= amount
	SfxManager.play_hit(effects_parent)
	DamageNumbers.spawn(effects_parent, global_position, amount, _number_kind)
	if amount >= DamageNumbers.BIG_DAMAGE:
		ParticleFx.burst(effects_parent, "spark", global_position + Vector3(0, 1, 0), 0.8)
	if anim != null:
		anim.hit()
	else:
		_flash_timer = FLASH_TIME
		_mesh.material_override = flash_material()
	if elite_mod == "teleporter" and not _teleported and current_health > 0.0 and current_health < max_health * 0.3:
		_teleported = true
		_teleport_away()
	if current_health <= 0.0:
		if elite_mod == "explosive":
			_elite_death_blast()
		die()


func _teleport_away() -> void:
	SkillVfx.pulse_ring(effects_parent, global_position, 1.5, Color(0.2, 0.9, 1.0, 0.5), 0.3)
	var angle: float = randf() * TAU
	var anchor: Vector3 = target_player.global_position if target_player else global_position
	global_position = anchor + Vector3(cos(angle), 0, sin(angle)) * 10.0
	knockback_velocity = Vector3.ZERO


## 爆裂精英：死后原地 0.9 秒预警，半径 4 米爆炸（和爆裂小鬼一样可以走出去）。
func _elite_death_blast() -> void:
	var blast: Node3D = BlastScript.new()
	blast.setup(4.0, def.attack_damage * 2.0, 0.9, "%s的爆炸" % get_display_name())
	blast.color = Color(ELITE_COLORS["explosive"], 0.45)
	effects_parent.add_child(blast)
	blast.global_position = global_position
	SkillVfx.record(["blast", global_position, 4.0, 0.9])


## 燃烧精英：脚下留一块 2 秒的小火区（减速 30% + 持续伤害）。
func _spawn_burning_zone() -> void:
	var zone: Node3D = HazardScript.new()
	zone.setup(1.6, 0.7, 2.0, Color(ELITE_COLORS["burning"], 0.35))
	zone.dps = def.attack_damage * 0.4
	zone.source_name = "%s的火焰" % get_display_name()
	effects_parent.add_child(zone)
	zone.global_position = global_position
	SkillVfx.record(["hazard", global_position, 1.6, 2.0])


func die() -> void:
	if not is_alive:
		return
	is_alive = false
	current_health = 0.0
	remove_from_group("enemies")
	SkillVfx.death(effects_parent, global_position, _mesh.mesh, _mesh.position.y, look_color(def, elite_mod),
			is_elite() or self is Boss, _mesh.scale.x)
	SfxManager.play(effects_parent, "explode" if is_elite() or self is Boss else "death")
	match def.behavior:
		EnemyDef.Behavior.DASHER:
			_explode()
		EnemyDef.Behavior.BLOATER:
			var hz: Node3D = HazardScript.new()
			hz.setup(def.special_range, def.special_value, def.special_cooldown, Color(0.6, 0.65, 0.1, 0.35))
			effects_parent.add_child(hz)
			hz.global_position = global_position
			SkillVfx.record(["hazard", global_position, def.special_range, def.special_cooldown])
	died.emit(self)
	queue_free()


## 小鬼死亡爆炸：0.7 秒预警圈，之后伤害圈内玩家（近战击杀后可以走出去）。
func _explode() -> void:
	var blast: Node3D = BlastScript.new()
	blast.setup(IMP_EXPLOSION_RADIUS, def.special_value, 0.7, "%s的自爆" % get_display_name())
	effects_parent.add_child(blast)
	blast.global_position = global_position
	SkillVfx.record(["blast", global_position, IMP_EXPLOSION_RADIUS, 0.7])


func apply_knockback(impulse: Vector3) -> void:
	var resist: float = maxf(knockback_resist, 0.7 if elite_mod == "giant" else 0.0)
	knockback_velocity = impulse * (1.0 - resist)
	_dash_state = 0 if _dash_state == 2 else _dash_state


func apply_magnet(point: Vector3) -> void:
	_magnet_point = point
	_magnet_time = 0.8


func apply_slow(factor: float, duration: float) -> void:
	status.apply_slow(factor * (1.0 - knockback_resist), duration)


func _update_flash(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and _dash_state != 1:
			_mesh.material_override = _base_material


## 攻击动作（没有动画模型时忽略）。
func play_attack(kind: int, duration: float = -1.0) -> void:
	if anim != null:
		anim.attack(kind, duration)


## 小鬼蓄力的持续闪白：动画模型走 shader 参数，灰盒换白色材质。
func _set_windup_flash(on: bool) -> void:
	if anim != null:
		anim.hold_flash(on)
	else:
		_mesh.material_override = shared_material(Color(1, 1, 1)) if on else _base_material


## 外观：有低模就用低模（原点在脚底，按体型缩放，精英染色并微微发光）；没有就退回灰盒胶囊。
## 客户端的敌人视图（EnemyViewPool）也用这个函数，保证两边看起来一样。
static func apply_look(mi: MeshInstance3D, d: EnemyDef, mod: String) -> void:
	var elite: bool = not mod.is_empty()
	var s: float = d.body_scale * (ELITE_SCALE if elite else 1.0)
	var model: Mesh = ModelLibrary.mesh(d.enemy_id)
	if model != null:
		mi.mesh = model
		mi.position = Vector3.ZERO
		mi.scale = Vector3.ONE * s
		mi.material_override = ModelLibrary.anim_material(ELITE_COLORS[mod] if elite else Color.WHITE, 0.35 if elite else 0.0)
	else:
		mi.mesh = _cached_mesh(s)
		mi.position = Vector3(0, 0.8 * s, 0)
		mi.scale = Vector3.ONE
		mi.material_override = shared_material(look_color(d, mod))


## 死亡碎屑、溶解残影用的代表色。
static func look_color(d: EnemyDef, mod: String) -> Color:
	return ELITE_COLORS[mod] if not mod.is_empty() else d.color


## 受击闪白（无光照纯白，比变红更醒目）。
static func flash_material() -> StandardMaterial3D:
	if not _materials.has("flash"):
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(1, 1, 1)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials["flash"] = mat
	return _materials["flash"]


## 场景退出时释放共享的材质/网格缓存。
static func clear_caches() -> void:
	_materials.clear()
	_meshes.clear()
	_shapes.clear()
	ModelLibrary.clear()


static func shared_material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = color
		_materials[color] = mat
	return _materials[color]


static func _cached_mesh(s: float) -> CapsuleMesh:
	if not _meshes.has(s):
		var m: CapsuleMesh = CapsuleMesh.new()
		m.radius = 0.4 * s
		m.height = 1.6 * s
		m.radial_segments = 12
		m.rings = 4
		_meshes[s] = m
	return _meshes[s]


static func _cached_shape(s: float) -> CapsuleShape3D:
	if not _shapes.has(s):
		var c: CapsuleShape3D = CapsuleShape3D.new()
		c.radius = 0.4 * s
		c.height = 1.6 * s
		_shapes[s] = c
	return _shapes[s]
