class_name EventDirector extends Node
## 地图随机事件导演（设计文档 06「3 至 5 种随机事件」）：按 MapCatalog 的 events 在指定时间触发。
## kind：0 奖励宝箱（团队经验 + 治疗球）；1 精英突袭（玩家周围一圈精英）；2 补给空投（装备）。
## 只在主机 / 单人运行；掉落物、敌人、光柱特效都走现有的联机同步。

signal event_triggered(kind: int, text: String)

enum Kind { REWARD_CHEST, ELITE_WAVE, SUPPLY_DROP }

const ELITE_RING_RADIUS: float = 9.0
const TEXTS: Dictionary = {
	Kind.REWARD_CHEST: "远古宝藏出现了！快去拾取",
	Kind.ELITE_WAVE: "精英敌人突袭！",
	Kind.SUPPLY_DROP: "补给空投已到达！",
}
const COLORS: Dictionary = {
	Kind.REWARD_CHEST: Color(1.0, 0.85, 0.35),
	Kind.ELITE_WAVE: Color(1.0, 0.25, 0.3),
	Kind.SUPPLY_DROP: Color(0.5, 0.85, 1.0),
}

var events: Array = []
var _next: int = 0
var _map_id: String = ""
var _session: GameSession = null
var _loot: Node3D = null
var _spawner: Node3D = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func initialize(map_id: String, session: GameSession, loot: Node3D, spawner: Node3D) -> void:
	_map_id = map_id
	_session = session
	_loot = loot
	_spawner = spawner
	_rng.randomize()
	events = (MapCatalog.get_def(map_id).get("events", []) as Array).duplicate()
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.time) < float(b.time))


func _process(_delta: float) -> void:
	if _session == null or not _session.is_running or _next >= events.size():
		return
	var t: float = _session.get_game_time()
	while _next < events.size() and t >= float(events[_next].time):
		trigger(events[_next])
		_next += 1


## 触发一个事件（测试也直接调用）。位置 = 随机一名存活玩家 + offset。
func trigger(ev: Dictionary) -> void:
	var kind: int = int(ev.kind)
	var params: Dictionary = ev.get("params", {})
	var players: Array[Node3D] = PlayerQuery.alive(get_tree())
	var anchor: Vector3 = players[_rng.randi() % players.size()].global_position if not players.is_empty() else Vector3.ZERO
	var pos: Vector3 = anchor + (ev.get("offset", Vector3.ZERO) as Vector3)
	pos = Vector3(clampf(pos.x, -90.0, 90.0), 0.0, clampf(pos.z, -90.0, 90.0))
	var parent: Node = get_parent()
	match kind:
		Kind.REWARD_CHEST:
			_session.add_experience(float(params.get("exp", 50)))
			for i in 3:
				var a: float = TAU * i / 3.0
				_loot._spawn("heal", "", float(params.get("heal", 30)) / 3.0, pos + Vector3(cos(a), 0, sin(a)) * 1.2)
			SkillVfx.burst(parent, "star", pos + Vector3(0, 1.0, 0), 1.6, COLORS[kind])
		Kind.ELITE_WAVE:
			var count: int = int(params.get("count", 3))
			var t: float = _session.get_game_time()
			for i in count:
				var id: String = SpawnDirector.pick_enemy_type(t, _rng.randf(), _map_id)
				var mod: String = SpawnDirector.ELITE_MODS[_rng.randi() % SpawnDirector.ELITE_MODS.size()]
				var a: float = TAU * i / float(count)
				_spawner.spawn_enemy(id, [mod], anchor + Vector3(cos(a), 0, sin(a)) * ELITE_RING_RADIUS, 0.0)
				SkillVfx.rune(parent, anchor + Vector3(cos(a), 0, sin(a)) * ELITE_RING_RADIUS, 1.6, Color(COLORS[kind], 0.9),
						"implode", 0.6)
			pos = anchor
		Kind.SUPPLY_DROP:
			_loot.drop_equipment(pos)
	# 从天而降的光柱 + 地面法阵，远处也能看到事件位置（经 SkillVfx 录制，联机客户端同样可见）
	SkillVfx.pillar(parent, pos, 0.9, 14.0, Color(COLORS[kind], 0.85))
	SkillVfx.rune(parent, pos, 2.5, Color(COLORS[kind], 0.9), "flash", 2.5, "glow_ring")
	SfxManager.play(parent, "evolve")
	event_triggered.emit(kind, TEXTS[kind])
	print("[Event] %s t=%.0f at %s" % [Kind.keys()[kind], _session.get_game_time(), pos])
