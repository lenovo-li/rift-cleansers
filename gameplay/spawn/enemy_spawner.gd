extends Node3D
## M1 敌人生成器：响应 SpawnDirector 的刷怪请求，在玩家视野外生成敌人，并结算死亡（经验、计数、掉落）。

signal enemy_killed(enemy: Enemy)
signal boss_spawned(boss: Boss)
signal boss_defeated(boss_name: String, is_final: bool)

const EnemyScene: PackedScene = preload("res://gameplay/actors/enemy.tscn")
const BossScript: GDScript = preload("res://gameplay/actors/boss.gd")
const BOSS_DEF: EnemyDef = preload("res://content/bosses/corrupted_knight.tres")
## 每张地图的 Boss（MapCatalog.boss -> 定义）
const BOSS_DEFS: Dictionary = {
	"corrupted_knight": BOSS_DEF,
	"frost_lich": preload("res://content/bosses/frost_lich.tres"),
	"sand_colossus": preload("res://content/bosses/sand_colossus.tres"),
	"rotwood_treant": preload("res://content/bosses/rotwood_treant.tres"),
	"ember_tyrant": preload("res://content/bosses/ember_tyrant.tres"),
	"void_reaper": preload("res://content/bosses/void_reaper.tres"),
}
const DEFS: Dictionary = {
	"zombie": preload("res://content/enemies/zombie.tres"),
	"skeleton": preload("res://content/enemies/skeleton.tres"),
	"imp": preload("res://content/enemies/imp.tres"),
	"ghoul": preload("res://content/enemies/ghoul.tres"),
	"necromancer": preload("res://content/enemies/necromancer.tres"),
	"bloater": preload("res://content/enemies/bloater.tres"),
	"ember_guard": preload("res://content/enemies/ember_guard.tres"),
	"frost_wraith": preload("res://content/enemies/frost_wraith.tres"),
	"sand_scarab": preload("res://content/enemies/sand_scarab.tres"),
	"spore_shambler": preload("res://content/enemies/spore_shambler.tres"),
}
const ARENA_HALF: float = 95.0
const SEPARATION_CELL: float = 1.5

@export var initial_count: int = 10
@export var spawn_radius: float = 20.0

var kills: int = 0
## 测试用：固定 Boss 词缀（"none" = 无词缀），空 = 随机
var forced_boss_affix: String = ""
var bosses: Array[Boss] = []  # 当前存活的所有 Boss
var boss_defeats: int = 0  # 已击败的 Boss 数量
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
		_director.spawn_requested.connect(func(id: String, mods: Variant) -> void:
			if mods is Array:
				spawn_enemy(id, mods)
			else:
				spawn_enemy(id, [str(mods)] if not str(mods).is_empty() else [])
		)
		_director.boss_requested.connect(spawn_boss)
	spawn_enemies(initial_count)


## 兼容旧接口：生成 count 只腐尸。
func spawn_enemies(count: int) -> void:
	for i in count:
		spawn_enemy("zombie", [])


func spawn_enemy(enemy_id: String, elite_mods: Array, center: Variant = null, radius: float = -1.0) -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	# 双词缀：组合字符串 "mod1+mod2"
	var mod_str: String = ""
	if elite_mods.size() == 1:
		mod_str = str(elite_mods[0])
	elif elite_mods.size() >= 2:
		mod_str = "%s+%s" % [elite_mods[0], elite_mods[1]]
	enemy.setup(DEFS.get(enemy_id, DEFS["zombie"]), mod_str, null, get_parent())
	# 敌人随游戏时间变强（血量 + 伤害）
	var power: float = _director.enemy_scaling(_session.get_game_time()) if _director != null and _session != null else 1.0
	enemy.health_scale *= power
	enemy.def.attack_damage *= power
	_add(enemy, center, radius)
	return enemy


## 根据 Boss 序号选择变体：6 个不同的 Boss，难度递增
func _pick_boss_variant(boss_index: int) -> String:
	var variants: Array[String] = [
		"corrupted_knight",  # Boss 1: 3分钟
		"frost_lich",        # Boss 2: 6分钟
		"sand_colossus",     # Boss 3: 9分钟
		"rotwood_treant",    # Boss 4: 12分钟
		"ember_tyrant",      # Boss 5: 15分钟
		"void_reaper"        # Boss 6: 18分钟（终极Boss）
	]
	return variants[clampi(boss_index, 0, variants.size() - 1)]


func spawn_boss(boss_index: int) -> Boss:
	var enemy: Node = EnemyScene.instantiate()
	enemy.set_script(BossScript)
	var boss: Boss = enemy as Boss
	var boss_id: String = _pick_boss_variant(boss_index)
	boss.setup(BOSS_DEFS.get(boss_id, BOSS_DEF), "", null, get_parent())
	if forced_boss_affix.is_empty():
		boss.affix = Boss.AFFIXES.pick_random()
	else:
		boss.affix = "" if forced_boss_affix == "none" else forced_boss_affix
	# Boss 血量随序号递增：第1个 ×1.0，第6个 ×3.0
	var order_scale: float = 1.0 + float(boss_index) * 0.4
	boss.health_scale = order_scale * (1.0 + 0.6 * float(PlayerQuery.all(get_tree()).size() - 1))
	boss.boss_index = boss_index
	boss.summon_requested.connect(_on_boss_summon)
	_add(boss, null, 18.0)
	bosses.append(boss)
	boss_spawned.emit(boss)
	return boss


func _add(enemy: Enemy, center: Variant, radius: float) -> void:
	enemy.entity_id = _next_id
	_next_id += 1
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)
	if radius == 0.0 and center is Vector3:
		# 事件刷怪：直接用给定位置
		enemy.global_position = center
	else:
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


func _on_boss_summon(enemy_id: String, count: int, elite_mods: Array, center: Vector3) -> void:
	for i in count:
		spawn_enemy(enemy_id, elite_mods, center, 4.0 + randf() * 3.0)
	SkillVfx.pulse_ring(get_parent(), center, 7.0, Color(0.6, 0.1, 0.2, 0.4), 0.5)


func _on_enemy_died(enemy: Enemy) -> void:
	kills += 1
	if _session:
		_session.add_experience(enemy.exp_reward)
		for p: Node in get_tree().get_nodes_in_group("players"):
			if p.has_method("get") and p.get("stats") != null:
				p.stats.on_kill()
	if enemy is Boss:
		bosses.erase(enemy)
		boss_defeats += 1
		# 6 个 Boss 全部击败才算胜利
		boss_defeated.emit(enemy.get_display_name(), boss_defeats >= SpawnDirector.BOSS_TIMES.size())
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


## Boss 信息 {name, phase, hp, max_hp, index}；没有 Boss 时为空字典。返回最新的 Boss。
func get_boss_info() -> Dictionary:
	if NetConfig.is_client():
		return net_boss_info
	if bosses.is_empty():
		return {}
	# 返回最后刷出的 Boss（序号最大）
	var latest: Boss = bosses[-1]
	if not is_instance_valid(latest) or not latest.is_alive:
		return {}
	return {
		"name": latest.get_display_name(),
		"phase": latest.phase,
		"hp": latest.current_health,
		"max_hp": latest.max_health,
		"index": latest.boss_index,
		"alive": bosses.size(),
		"pos": latest.global_position,
	}
