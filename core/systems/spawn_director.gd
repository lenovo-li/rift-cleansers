class_name SpawnDirector extends Node
## 生成导演：按文档 05 §2.1 时间线控制敌人数量、种类、精英、Boss 与装备掉落时机。
## 只决定「刷什么、何时刷」，实际生成由 EnemySpawner 完成。

signal spawn_requested(enemy_id: String, elite_mod: String)
signal boss_requested(boss_index: int)  # boss_index: 0-5 对应第几个 Boss
signal equipment_drop_due(drop_index: int)

## Boss 时间表：每 3 分钟一个，共 6 个
const BOSS_TIMES: Array[float] = [180.0, 360.0, 540.0, 720.0, 900.0, 1080.0]  # 3/6/9/12/15/18 分钟
const FIRST_ELITE_TIME: float = 300.0  # 5:00
const EQUIPMENT_DROP_TIMES: Array[float] = [60.0, 180.0, 300.0, 480.0, 660.0, 840.0, 1020.0]  # 扩展到7个装备掉落
const ELITE_MODS: Array[String] = ["teleporter", "vampire", "haste", "armored", "explosive", "regenerating", "frost", "burning", "giant"]
## 精英词缀组合（后期15分钟后30%几率）
const ELITE_MOD_COMBOS: Dictionary = {
	"berserker": ["haste", "giant"],
	"ice_armor": ["frost", "armored"],
	"regenerating_vampire": ["regenerating", "vampire"],
	"explosive_teleporter": ["explosive", "teleporter"],
	"burning_haste": ["burning", "haste"],
	"frost_vampire": ["frost", "vampire"],
	"armored_regen": ["armored", "regenerating"],
	"giant_explosive": ["giant", "explosive"],
}
## 存活上限关键帧：[时间秒, 上限]，中间线性插值。20分钟游戏，峰值1000怪。
const ALIVE_CAP_CURVE: Array = [
	[0.0, 20],      # 开局20只
	[60.0, 40],     # 1分钟40只
	[180.0, 120],   # 3分钟120只
	[300.0, 220],   # 5分钟220只
	[600.0, 450],   # 10分钟450只
	[900.0, 700],   # 15分钟700只
	[1080.0, 1000], # 18分钟（Boss前）1000只
	[1200.0, 500],  # Boss战降低普通怪，专注Boss
]
const BOSS_PHASE_CAP: int = 500  # Boss战期间的普通怪上限

@export var spawn_interval: float = 1.0
## 压力测试用：>0 时忽略时间线，直接把存活数维持在该值。
@export var stress_cap: int = 0
## 地图 ID（从 NetConfig 自动读取）；SpawnDirector.pick_enemy_type 按地图读敌人池。
var map_id: String = ""

var alive_count: int = 0
## 多人：返回玩家人数，存活上限 ×(1 + 0.5 × (人数-1))。
var player_count_provider: Callable = Callable()
var boss_count: int = 0  # 已刷出的 Boss 数量（0-6）
var game_session: GameSession = null
var _spawn_timer: float = 0.0
var _first_elite_done: bool = false
var _next_drop: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func initialize(session: GameSession, rng_seed: int = -1) -> void:
	game_session = session
	map_id = NetConfig.map_id
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
	# 检查每个 Boss 时间点
	while boss_count < BOSS_TIMES.size() and t >= BOSS_TIMES[boss_count] and stress_cap <= 0:
		boss_requested.emit(boss_count)
		boss_count += 1
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = spawn_interval
		_spawn_wave(t)


func _spawn_wave(t: float) -> void:
	var cap: int = stress_cap if stress_cap > 0 else int(get_alive_cap(t, boss_count > 0) * _player_scale())
	var missing: int = cap - alive_count
	if missing <= 0:
		return
	var count: int = missing if stress_cap > 0 else mini(missing, maxi(2, cap / 8))
	for i in count:
		var mods: Array[String] = []
		if stress_cap <= 0:
			if not _first_elite_done and t >= FIRST_ELITE_TIME:
				_first_elite_done = true
				mods = [ELITE_MODS[_rng.randi() % ELITE_MODS.size()]]
			elif _rng.randf() < get_elite_chance(t):
				mods = _pick_elite_mods(t)
		# 传递词缀数组（spawner需要支持）
		spawn_requested.emit(pick_enemy_type(t, _rng.randf(), map_id), mods)


func _player_scale() -> float:
	var n: int = int(player_count_provider.call()) if player_count_provider.is_valid() else 1
	return 1.0 + 0.5 * float(maxi(0, n - 1))


## 敌人强度倍率：按游戏时间、玩家等级、玩家数量递增血量和伤害。
## 返回 {health: float, damage: float}
func enemy_scaling_full(t: float) -> Dictionary:
	var level: int = game_session.get_player_level() if game_session != null else 1
	var player_count: int = int(player_count_provider.call()) if player_count_provider.is_valid() else 1

	# 时间缩放：每分钟 +8%，18 分钟时约 2.5 倍
	var time_mult: float = 1.0 + t / 60.0 * 0.08

	# 等级缩放：等级 10 以后，每级血量 +2.5%，伤害 +1.5%
	var level_health_mult: float = 1.0 + maxf(0.0, float(level - 10)) * 0.025
	var level_damage_mult: float = 1.0 + maxf(0.0, float(level - 10)) * 0.015

	# 多人缩放：每多一个玩家，血量 +40%，伤害 +20%
	var coop_health_mult: float = 1.0 + maxf(0.0, float(player_count - 1)) * 0.4
	var coop_damage_mult: float = 1.0 + maxf(0.0, float(player_count - 1)) * 0.2

	return {
		"health": time_mult * level_health_mult * coop_health_mult,
		"damage": time_mult * level_damage_mult * coop_damage_mult
	}


## 敌人强度倍率（向后兼容）：返回血量倍率。
func enemy_scaling(t: float) -> float:
	return enemy_scaling_full(t).health


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
	if t < 900.0:  # 15分钟前
		return 0.02
	return 0.03  # 15分钟后提高到3%


## 选择精英词缀（15分钟后30%几率双词缀）
func _pick_elite_mods(t: float) -> Array[String]:
	if t > 900.0 and _rng.randf() < 0.3:
		# 双词缀
		var combo_keys: Array = ELITE_MOD_COMBOS.keys()
		var combo_key: String = combo_keys[_rng.randi() % combo_keys.size()]
		return ELITE_MOD_COMBOS[combo_key]
	else:
		# 单词缀
		return [ELITE_MODS[_rng.randi() % ELITE_MODS.size()]]


## 按时间段的种类权重抽取敌人（roll ∈ [0,1)）。读当前地图的敌人池；无池时用默认权重。
static func pick_enemy_type(t: float, roll: float, map_id: String = "") -> String:
	var weights: Dictionary = get_type_weights(t, map_id)
	var total: float = 0.0
	for w: float in weights.values():
		total += w
	var r: float = roll * total
	for id: String in weights:
		r -= float(weights[id])
		if r < 0.0:
			return id
	return weights.keys()[-1]


static func get_type_weights(t: float, map_id: String = "") -> Dictionary:
	if not map_id.is_empty():
		var map: Dictionary = MapCatalog.get_def(map_id)
		if map.has("enemies"):
			var pools: Dictionary = map.enemies
			if t < 180.0 and pools.has("early"):
				return pools.early
			elif t < 420.0 and pools.has("mid"):
				return pools.mid
			elif pools.has("late"):
				return pools.late
	# 默认池（兼容旧地图和测试）
	if t < 60.0:
		return {"zombie": 1.0}
	if t < 180.0:
		return {"zombie": 0.6, "skeleton": 0.3, "imp": 0.1}
	if t < 300.0:
		return {"zombie": 0.35, "skeleton": 0.3, "imp": 0.15, "ghoul": 0.1, "necromancer": 0.05, "bloater": 0.05}
	return {"zombie": 0.25, "skeleton": 0.3, "imp": 0.15, "ghoul": 0.12, "necromancer": 0.08, "bloater": 0.1}
