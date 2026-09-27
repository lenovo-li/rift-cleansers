extends CharacterBody3D
## 简单敌人AI - 追踪并攻击玩家

@export var move_speed: float = 3.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.0
@export var max_health: float = 60.0
@export var exp_reward: float = 2.0

var entity_id: int = -1
var current_health: float = 60.0
var target_player: Node3D = null
var attack_timer: float = 0.0
var is_alive: bool = true
var knockback_velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	find_player()


func find_player() -> void:
	target_player = get_tree().root.find_child("PlayerM1", true, false)


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	
	if target_player == null:
		find_player()
		return
	
	# 追踪玩家
	var direction: Vector3 = (target_player.global_position - global_position).normalized()
	direction.y = 0.0
	
	# 应用击退，然后正常移动
	if knockback_velocity.length_squared() > 0.01:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, 0.1)
	else:
		velocity = direction * move_speed
	
	move_and_slide()
	
	# 攻击冷却
	if attack_timer > 0.0:
		attack_timer -= delta
	
	# 检测接触攻击
	var distance: float = global_position.distance_to(target_player.global_position)
	if distance < 1.5 and attack_timer <= 0.0:
		deal_damage()
		attack_timer = attack_cooldown


func deal_damage() -> void:
	if target_player and target_player.has_method("take_damage"):
		target_player.take_damage(attack_damage, entity_id)


func take_damage(amount: float) -> void:
	if not is_alive:
		return
	
	current_health -= amount
	
	# 音效
	var scene_root: Node = get_tree().root.get_child(0)
	var sfx: Script = preload("res://core/audio/sfx_manager.gd")
	sfx.play_hit(scene_root, global_position, -8.0)
	
	# 受伤视觉反馈：变红0.1秒
	var mesh: MeshInstance3D = get_node_or_null("Mesh")
	if mesh:
		var mat: StandardMaterial3D = mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			var original_color: Color = mat.albedo_color
			mat.albedo_color = Color(1, 0.5, 0.5)
			await get_tree().create_timer(0.1).timeout
			if is_instance_valid(mesh) and is_instance_valid(mat):
				mat.albedo_color = original_color
	
	if current_health <= 0.0:
		die()


func die() -> void:
	is_alive = false
	
	# 通知SpawnDirector
	var spawn_director: Node = get_tree().root.find_child("SpawnDirector", true, false)
	if spawn_director and spawn_director.has_method("on_enemy_died"):
		spawn_director.on_enemy_died()
	
	# 掉落经验
	var game_session: Node = get_tree().root.find_child("GameSession", true, false)
	if game_session and game_session.has_method("add_experience"):
		game_session.add_experience(exp_reward)
	
	queue_free()


func apply_knockback(impulse: Vector3) -> void:
	knockback_velocity = impulse
