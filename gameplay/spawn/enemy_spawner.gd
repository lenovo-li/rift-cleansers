extends Node3D
## M1 敌人生成器：响应 SpawnDirector 的刷怪请求，在玩家视野外生成敌人，并结算死亡（经验、计数、掉落）。

signal enemy_killed(enemy: Enemy)
signal boss_spawned(boss: Boss)
signal boss_defeated

const EnemyScene: PackedScene = preload("res://gameplay/actors/enemy.tscn")
const BossScript: GDScript = preload("res://gameplay/actors/boss.gd")
const BOSS_DEF: EnemyDef = preload("res://content/bosses/corrupted_knight.tres")
const DEFS: Dictionary = {
	"zombie": preload("res://content/enemies/zombie.tres"),
	"skeleton": preload("res://content/enemies/skeleton.tres"),
	"imp": preload("res://content/enemies/imp.tres"),
	"ghoul": preload("res://content/enemies/ghoul.tres"),
	"necromancer": preload("res://content/enemies/necromancer.tres"),
	"bloater": preload("res://content/enemies/bloater.tres"),
}
const ARENA_HALF: float = 95.0
const SEPARATION_CELL: float = 1.5

@export var initial_count: int = 10
@export var spawn_radius: float = 20.0

var kills: int = 0
var boss: Boss = null
## 客户端：由 NetSession 写入的敌人数量和 Boss 信息
var net_enemy_count: int = 0
var net_boss_info: Dictionary = {}
var _next_id: int = 1000
var _director: SpawnDirector = null
var _session: GameSession = null


func _ready() -> void:
	if NetConfig.is_client():
		set_physics_process(false)
		return  # 客户端不生成敌人，敌人来自主机快照
	await get_tree().process_frame
	_director = get_tree().root.find_child("SpawnDirector", true, false) as SpawnDirector
	_session = get_tree().root.find_child("GameSession", true, false) as GameSession
	if _director:
		_director.spawn_requested.connect(func(id: String, mod: String) -> void: spawn_enemy(id, mod))
		_director.boss_requested.connect(spawn_boss)
	spawn_enemies(initial_count)


## 兼容旧接口：生成 count 只腐尸。
func spawn_enemies(count: int) -> void:
	for i in count:
		spawn_enemy("zombie", "")


func spawn_enemy(enemy_id: String, elite_mod: String, center: Variant = null, radius: float = -1.0) -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	enemy.setup(DEFS.get(enemy_id, DEFS["zombie"]), elite_mod, null, get_parent())
	_add(enemy, center, radius)
	return enemy


func spawn_boss() -> Boss:
	var enemy: Node = EnemyScene.instantiate()
	enemy.set_script(BossScript)
	boss = enemy as Boss
	boss.setup(BOSS_DEF, "", null, get_parent())
	boss.health_scale = 1.0 + 0.6 * float(PlayerQuery.all(get_tree()).size() - 1)
	boss.summon_requested.connect(_on_boss_summon)
	_add(boss, null, 18.0)
	boss_spawned.emit(boss)
	return boss


func _add(enemy: Enemy, center: Variant, radius: float) -> void:
	enemy.entity_id = _next_id
	_next_id += 1
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)
	var origin: Vector3 = center if center is Vector3 else _random_player_position()
	var r: float = radius if radius >= 0.0 else spawn_radius + randf() * 10.0
	var angle: float = randf() * TAU
	var pos: Vector3 = origin + Vector3(cos(angle) * r, 0.0, sin(angle) * r)
	pos.x = clampf(pos.x, -ARENA_HALF, ARENA_HALF)
	pos.z = clampf(pos.z, -ARENA_HALF, ARENA_HALF)
	if MapBase.current:
		pos = MapBase.current.find_free(pos, 1.2)
	enemy.global_position = pos
	if _director and not (enemy is Boss):
		_director.on_enemy_spawned()


## 普通刷怪围绕随机一名存活玩家（多人时每个人身边都有怪）。
func _random_player_position() -> Vector3:
	var players: Array[Node3D] = PlayerQuery.alive(get_tree())
	if players.is_empty():
		return Vector3.ZERO
	return players[randi() % players.size()].global_position


func _on_boss_summon(enemy_id: String, count: int, elite_mod: String, center: Vector3) -> void:
	for i in count:
		spawn_enemy(enemy_id, elite_mod, center, 4.0 + randf() * 3.0)
	SkillVfx.pulse_ring(get_parent(), center, 7.0, Color(0.6, 0.1, 0.2, 0.4), 0.5)


func _on_enemy_died(enemy: Enemy) -> void:
	kills += 1
	if _session:
		_session.add_experience(enemy.exp_reward)
	if enemy is Boss:
		boss = null
		boss_defeated.emit()
	elif _director:
		_director.on_enemy_died()
	enemy_killed.emit(enemy)


## 敌人分离：均匀网格分桶，只比较相邻 3×3 格内的敌人，把推开方向写入 enemy.separation。
## 父节点先于子节点处理，所以敌人本帧移动时用的是这里刚算好的值。
func _physics_process(_delta: float) -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var n: int = enemies.size()
	var xs: PackedFloat32Array = PackedFloat32Array()
	var zs: PackedFloat32Array = PackedFloat32Array()
	var rs: PackedFloat32Array = PackedFloat32Array()
	xs.resize(n)
	zs.resize(n)
	rs.resize(n)
	var cells: Dictionary = {}
	for i in n:
		var e: Enemy = enemies[i] as Enemy
		var p: Vector3 = e.global_position
		xs[i] = p.x
		zs[i] = p.z
		rs[i] = 0.4 * e.def.body_scale if e.def else 0.4
		var key: Vector2i = Vector2i(floori(p.x / SEPARATION_CELL), floori(p.z / SEPARATION_CELL))
		if cells.has(key):
			cells[key].append(i)
		else:
			cells[key] = [i]
	for i in n:
		var e: Enemy = enemies[i] as Enemy
		if e is Boss:
			continue
		var cx: int = floori(xs[i] / SEPARATION_CELL)
		var cz: int = floori(zs[i] / SEPARATION_CELL)
		var push_x: float = 0.0
		var push_z: float = 0.0
		for gx in range(cx - 1, cx + 2):
			for gz in range(cz - 1, cz + 2):
				var bucket: Variant = cells.get(Vector2i(gx, gz))
				if bucket == null:
					continue
				for j: int in bucket:
					if j == i:
						continue
					var dx: float = xs[i] - xs[j]
					var dz: float = zs[i] - zs[j]
					var min_d: float = rs[i] + rs[j]
					var d2: float = dx * dx + dz * dz
					if d2 >= min_d * min_d:
						continue
					if d2 < 0.0001:
						dx = randf() - 0.5
						dz = randf() - 0.5
						d2 = dx * dx + dz * dz
					var d: float = sqrt(d2)
					var k: float = (min_d - d) / (min_d * d)
					push_x += dx * k
					push_z += dz * k
		e.separation = Vector3(push_x, 0.0, push_z)


func get_enemy_count() -> int:
	if NetConfig.is_client():
		return net_enemy_count
	return get_tree().get_nodes_in_group("enemies").size()


## Boss 信息 {name, phase, hp, max_hp}；没有 Boss 时为空字典。
func get_boss_info() -> Dictionary:
	if NetConfig.is_client():
		return net_boss_info
	if boss == null or not is_instance_valid(boss) or not boss.is_alive:
		return {}
	return {"name": boss.get_display_name(), "phase": boss.phase, "hp": boss.current_health, "max_hp": boss.max_health}
