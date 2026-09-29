class_name SpawnDirector extends Node
## 生成导演：按文档 05 §2.1 时间线控制敌人数量、种类、精英、Boss 与装备掉落时机。
## 只决定「刷什么、何时刷」，实际生成由 EnemySpawner 完成。

signal spawn_requested(enemy_id: String, elite_mod: String)
signal boss_requested
signal equipment_drop_due(drop_index: int)

const BOSS_TIME: float = 540.0  # 9:00
const FIRST_ELITE_TIME: float = 300.0  # 5:00
const EQUIPMENT_DROP_TIMES: Array[float] = [60.0, 180.0, 300.0, 420.0, 520.0]
const ELITE_MODS: Array[String] = ["teleporter", "vampire", "haste"]
## 存活上限关键帧：[时间秒, 上限]，中间线性插值。
const ALIVE_CAP_CURVE: Array = [[0.0, 15], [60.0, 25], [180.0, 55], [300.0, 110], [420.0, 220], [540.0, 400]]
const BOSS_PHASE_CAP: int = 120

@export var spawn_interval: float = 1.0
## 压力测试用：>0 时忽略时间线，直接把存活数维持在该值。
@export var stress_cap: int = 0

var alive_count: int = 0
var boss_spawned: bool = false
var game_session: GameSession = null
var _spawn_timer: float = 0.0
var _first_elite_done: bool = false
var _next_drop: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func initialize(session: GameSession, rng_seed: int = -1) -> void:
	game_session = session
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()


func _process(delta: float) -> void:
	if game_session == null or not game_session.is_running:
		return
	var t: float = game_session.get_game_time()
	while _next_drop < EQUIPMENT_DROP_TIMES.size() and t >= EQUIPMENT_DROP_TIMES[_next_drop]:
		equipment_drop_due.emit(_next_drop)
		_next_drop += 1
	if not boss_spawned and t >= BOSS_TIME and stress_cap <= 0:
		boss_spawned = true
		boss_requested.emit()
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = spawn_interval
		_spawn_wave(t)


func _spawn_wave(t: float) -> void:
	var cap: int = stress_cap if stress_cap > 0 else get_alive_cap(t, boss_spawned)
	var missing: int = cap - alive_count
	if missing <= 0:
		return
	var count: int = missing if stress_cap > 0 else mini(missing, maxi(2, cap / 8))
	for i in count:
		var mod: String = ""
		if stress_cap <= 0:
			if not _first_elite_done and t >= FIRST_ELITE_TIME:
				_first_elite_done = true
				mod = ELITE_MODS[_rng.randi() % ELITE_MODS.size()]
			elif _rng.randf() < get_elite_chance(t):
				mod = ELITE_MODS[_rng.randi() % ELITE_MODS.size()]
		spawn_requested.emit(pick_enemy_type(t, _rng.randf()), mod)


func on_enemy_spawned() -> void:
	alive_count += 1


func on_enemy_died() -> void:
	alive_count = maxi(0, alive_count - 1)


## 当前时间的存活上限（Boss 阶段固定为 BOSS_PHASE_CAP）。
static func get_alive_cap(t: float, boss_phase: bool = false) -> int:
	if boss_phase:
		return BOSS_PHASE_CAP
	for i in range(1, ALIVE_CAP_CURVE.size()):
		var t1: float = ALIVE_CAP_CURVE[i][0]
		if t <= t1:
			var t0: float = ALIVE_CAP_CURVE[i - 1][0]
			var c0: float = ALIVE_CAP_CURVE[i - 1][1]
			var c1: float = ALIVE_CAP_CURVE[i][1]
			return int(lerpf(c0, c1, (t - t0) / (t1 - t0)))
	return int(ALIVE_CAP_CURVE[-1][1])


## 精英概率：5 分钟前没有精英，之后逐步增加。
static func get_elite_chance(t: float) -> float:
	if t < FIRST_ELITE_TIME:
		return 0.0
	if t < 420.0:
		return 0.01
	return 0.02


## 按时间段的种类权重抽取敌人（roll ∈ [0,1)）。
static func pick_enemy_type(t: float, roll: float) -> String:
	var weights: Dictionary = get_type_weights(t)
	var total: float = 0.0
	for w: float in weights.values():
		total += w
	var r: float = roll * total
	for id: String in weights:
		r -= float(weights[id])
		if r < 0.0:
			return id
	return weights.keys()[-1]


static func get_type_weights(t: float) -> Dictionary:
	if t < 60.0:
		return {"zombie": 1.0}
	if t < 180.0:
		return {"zombie": 0.6, "skeleton": 0.3, "imp": 0.1}
	if t < 300.0:
		return {"zombie": 0.35, "skeleton": 0.3, "imp": 0.15, "ghoul": 0.1, "necromancer": 0.05, "bloater": 0.05}
	return {"zombie": 0.25, "skeleton": 0.3, "imp": 0.15, "ghoul": 0.12, "necromancer": 0.08, "bloater": 0.1}
