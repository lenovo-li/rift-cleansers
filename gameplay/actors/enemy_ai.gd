extends CharacterBody3D
## 简单敌人AI - 追踪并攻击玩家

@export var move_speed: float = 3.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.0
@export var max_health: float = 50.0

var entity_id: int = -1
var current_health: float = 50.0
var target_player: Node3D = null
var attack_timer: float = 0.0
var is_alive: bool = true


func _ready() -> void:
	current_health = max_health
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
		game_session.add_experience(5.0)
	
	queue_free()
