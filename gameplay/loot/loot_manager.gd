extends Node3D
## 掉落管理：按时间表 / 精英击杀生成装备，普通击杀概率掉治疗球；拾取后交给玩家。

signal equipment_collected(item_id: String)

const PickupScript: GDScript = preload("res://gameplay/loot/pickup.gd")

var _player: Node3D = null
var _pending: Array[String] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	await get_tree().process_frame
	_player = get_tree().root.find_child("PlayerM1", true, false) as Node3D
	var director: SpawnDirector = get_tree().root.find_child("SpawnDirector", true, false) as SpawnDirector
	if director:
		director.equipment_drop_due.connect(func(_i: int) -> void: drop_equipment_near_player())
	var spawner: Node = get_tree().root.find_child("EnemySpawner", true, false)
	if spawner:
		spawner.enemy_killed.connect(_on_enemy_killed)


func _on_enemy_killed(enemy: Enemy) -> void:
	if enemy.is_elite() and DropSystem.rolls_elite_equipment(_rng.randf()):
		drop_equipment(enemy.global_position)
	elif DropSystem.rolls_heal_orb(_rng.randf()):
		_spawn("heal", "", DropSystem.HEAL_ORB_AMOUNT, enemy.global_position)


## 时间表掉落：在玩家附近 6-9 米处出现，需要走过去拿。
func drop_equipment_near_player() -> void:
	if _player == null:
		return
	var angle: float = _rng.randf() * TAU
	var r: float = _rng.randf_range(6.0, 9.0)
	drop_equipment(_player.global_position + Vector3(cos(angle) * r, 0.0, sin(angle) * r))


func drop_equipment(pos: Vector3) -> void:
	var owned: Dictionary = _player.stats.equipment if _player else {}
	var id: String = DropSystem.pick_equipment(owned, _pending, _rng)
	if id.is_empty():
		_spawn("heal", "", DropSystem.HEAL_ORB_AMOUNT * 3.0, pos)
		return
	_pending.append(id)
	_spawn("equipment", id, 0.0, pos)


func _spawn(kind: String, item_id: String, amount: float, pos: Vector3) -> void:
	var p: Node3D = PickupScript.new()
	p.setup(kind, item_id, amount, _player)
	p.collected.connect(_on_collected)
	add_child(p)
	p.global_position = Vector3(clampf(pos.x, -95.0, 95.0), 0.0, clampf(pos.z, -95.0, 95.0))


func _on_collected(p: Node3D) -> void:
	if _player == null:
		return
	if p.kind == "equipment":
		_pending.erase(p.item_id)
		_player.add_equipment(p.item_id)
		equipment_collected.emit(p.item_id)
	else:
		_player.heal(p.amount)
