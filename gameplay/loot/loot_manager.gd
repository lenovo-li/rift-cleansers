extends Node3D
## 掉落管理：按时间表 / 精英击杀生成装备，普通击杀概率掉治疗球；拾取后交给玩家。

signal equipment_collected(item_id: String)

const PickupScript: GDScript = preload("res://gameplay/loot/pickup.gd")

var _pending: Array[String] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _session: GameSession = null


func _ready() -> void:
	_rng.randomize()
	await get_tree().process_frame
	_session = get_tree().root.find_child("GameSession", true, false) as GameSession
	var director: SpawnDirector = get_tree().root.find_child("SpawnDirector", true, false) as SpawnDirector
	if director:
		director.equipment_drop_due.connect(func(_i: int) -> void: drop_equipment_near_player())
	var spawner: Node = get_tree().root.find_child("EnemySpawner", true, false)
	if spawner:
		spawner.enemy_killed.connect(_on_enemy_killed)


func _on_enemy_killed(enemy: Enemy) -> void:
	if enemy is Boss:
		# Boss 必掉史诗以上装备
		drop_equipment(enemy.global_position, EquipmentQuality.Source.BOSS)
	elif enemy.is_elite() and DropSystem.rolls_elite_equipment(_rng.randf()):
		drop_equipment(enemy.global_position, EquipmentQuality.Source.ELITE)
	elif DropSystem.rolls_heal_orb(_rng.randf()):
		_spawn("heal", "", DropSystem.HEAL_ORB_AMOUNT, enemy.global_position)


## 时间表掉落：在随机一名存活玩家附近 6-9 米处出现，需要走过去拿。
func drop_equipment_near_player() -> void:
	var players: Array[Node3D] = PlayerQuery.alive(get_tree())
	if players.is_empty():
		return
	var target: Node3D = players[_rng.randi() % players.size()]
	var angle: float = _rng.randf() * TAU
	var r: float = _rng.randf_range(6.0, 9.0)
	drop_equipment(target.global_position + Vector3(cos(angle) * r, 0.0, sin(angle) * r))


## source：EquipmentQuality.Source（时间表 / 精英 / Boss），决定品质保底。
func drop_equipment(pos: Vector3, source: int = EquipmentQuality.Source.SCHEDULE) -> void:
	# 按离掉落点最近的玩家抽（通用 + 他的角色专属）：优先未拥有的，都有了就掉重复的用来升品质
	var target: Node3D = PlayerQuery.nearest_alive(get_tree(), pos)
	var char_id: String = str(target.character_id) if target != null else "-"
	var owned: Dictionary = target.stats.equipment if target != null else {}
	var id: String = DropSystem.pick_equipment(owned, _pending, char_id, _rng)
	if id.is_empty():
		_spawn("heal", "", DropSystem.HEAL_ORB_AMOUNT * 3.0, pos)
		return
	_pending.append(id)
	var t: float = _session.get_game_time() if _session != null else 0.0
	_spawn("equipment", id, 0.0, pos, EquipmentQuality.roll(t, source, _rng))


func _spawn(kind: String, item_id: String, amount: float, pos: Vector3, quality: int = 0) -> void:
	var p: Node3D = PickupScript.new()
	p.setup(kind, item_id, amount, quality)
	p.collected.connect(_on_collected)
	add_child(p)
	var clamped: Vector3 = Vector3(clampf(pos.x, -95.0, 95.0), 0.0, clampf(pos.z, -95.0, 95.0))
	# 灰烬王城：落在墙体里就螺旋外扩找空地
	p.global_position = MapBase.current.find_free(clamped, 0.5) if MapBase.current else clamped


func _owned_by_everyone() -> Dictionary:
	var result: Dictionary = {}
	var players: Array[Node3D] = PlayerQuery.all(get_tree())
	for id: String in ItemCatalog.EQUIPMENT:
		var all_have: bool = not players.is_empty()
		for p: Node3D in players:
			if not p.stats.has_equipment(id):
				all_have = false
				break
		if all_have:
			result[id] = true
	return result


func _on_collected(p: Node3D, player: Node3D) -> void:
	if p.kind == "equipment":
		_pending.erase(p.item_id)
		player.add_equipment(p.item_id, p.item_quality)
		equipment_collected.emit(p.item_id)
	else:
		player.heal(p.amount)
