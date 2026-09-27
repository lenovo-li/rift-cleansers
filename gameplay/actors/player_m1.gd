extends CharacterBody3D
## M1 玩家控制器 - 完整战斗系统版本
## 用于game_scene.tscn，不影响M0的test_arena

const SPEED: float = 8.0

@export var max_health: float = 1000.0
@export var attack_damage: float = 25.0
@export var attack_range: float = 3.5
@export var attack_interval: float = 1.0

var current_health: float = 1000.0
var entity_id: int = 0
var attack_timer: float = 0.0


func _ready() -> void:
	current_health = max_health


func _physics_process(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction: Vector3 = Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	move_and_slide()
	
	# 自动攻击
	if attack_timer > 0.0:
		attack_timer -= delta
	else:
		auto_attack()
		attack_timer = attack_interval


## 范围脉冲：对 attack_range 内所有存活敌人造成伤害（铁卫近战范围定位的灰盒版）。
## 返回命中数量，便于测试。
func auto_attack() -> int:
	var hits: int = 0
	var range_sq: float = attack_range * attack_range
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node3D) or not enemy.is_alive:
			continue
		var offset: Vector3 = (enemy as Node3D).global_position - global_position
		offset.y = 0.0
		if offset.length_squared() <= range_sq:
			enemy.take_damage(attack_damage)
			hits += 1
	return hits


func take_damage(amount: float, source_id: int) -> void:
	current_health -= amount
	
	if current_health <= 0.0:
		die()


func die() -> void:
	print("[PlayerM1] died")
	var game_session: Node = get_tree().root.find_child("GameSession", true, false)
	if game_session and game_session.has_method("end_game"):
		game_session.end_game("player_died")


func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)


func get_health() -> float:
	return current_health


func get_max_health() -> float:
	return max_health
