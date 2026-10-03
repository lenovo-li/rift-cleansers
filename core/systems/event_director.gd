class_name EventDirector extends Node
## 地图随机事件导演（设计文档 06「3 至 5 种随机事件」）：按 MapCatalog 的 events 在指定时间触发。
## kind：0 奖励宝箱（团队经验 + 治疗球）；1 精英突袭（玩家周围一圈精英）；2 补给空投（装备）。
## 只在主机 / 单人运行；掉落物、敌人、光柱特效都走现有的联机同步。

signal event_triggered(kind: int, text: String)

enum Kind { REWARD_CHEST, ELITE_WAVE, SUPPLY_DROP, METEOR_RAIN, HEALING_FOUNTAIN, CURSED_ALTAR }

const ELITE_RING_RADIUS: float = 9.0
const TEXTS: Dictionary = {
	Kind.REWARD_CHEST: "远古宝藏出现了！快去拾取",
	Kind.ELITE_WAVE: "精英敌人突袭！",
	Kind.SUPPLY_DROP: "补给空投已到达！",
	Kind.METEOR_RAIN: "流星雨降临！寻找安全区",
	Kind.HEALING_FOUNTAIN: "治愈之泉出现！回复生命",
	Kind.CURSED_ALTAR: "诅咒祭坛激活！击败守卫获得奖励",
}
const COLORS: Dictionary = {
	Kind.REWARD_CHEST: Color(1.0, 0.85, 0.35),
	Kind.ELITE_WAVE: Color(1.0, 0.25, 0.3),
	Kind.SUPPLY_DROP: Color(0.5, 0.85, 1.0),
	Kind.METEOR_RAIN: Color(1.0, 0.4, 0.1),
	Kind.HEALING_FOUNTAIN: Color(0.4, 1.0, 0.6),
	Kind.CURSED_ALTAR: Color(0.6, 0.2, 0.8),
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
		Kind.METEOR_RAIN:
			# 流星雨：多个预警圈随机落下
			for i in 8:
				var offset: Vector3 = Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
				var meteor_pos: Vector3 = pos + offset
				_spawn_blast(meteor_pos, 2.5, 1.2 + i * 0.15, 40.0, COLORS[kind])
		Kind.HEALING_FOUNTAIN:
			# 治愈之泉：持续治疗区域
			_spawn_healing_zone(pos, 4.0, 8.0, 10.0)
		Kind.CURSED_ALTAR:
			# 诅咒祭坛：生成精英守卫 + 宝箱
			var count: int = 2
			var t: float = _session.get_game_time()
			for i in count:
				var id: String = SpawnDirector.pick_enemy_type(t, _rng.randf(), _map_id)
				var mod: String = SpawnDirector.ELITE_MODS[_rng.randi() % SpawnDirector.ELITE_MODS.size()]
				var a: float = TAU * i / float(count)
				_spawner.spawn_enemy(id, [mod], pos + Vector3(cos(a), 0, sin(a)) * 3.0, 0.0)
			# 击败后掉落装备
			await get_tree().create_timer(2.0).timeout
			_loot.drop_equipment(pos)
	# 从天而降的光柱 + 地面法阵，远处也能看到事件位置（经 SkillVfx 录制，联机客户端同样可见）
	SkillVfx.pillar(parent, pos, 0.9, 14.0, Color(COLORS[kind], 0.85))
	SkillVfx.rune(parent, pos, 2.5, Color(COLORS[kind], 0.9), "flash", 2.5, "glow_ring")
	SfxManager.play(parent, "evolve")
	event_triggered.emit(kind, TEXTS[kind])
	print("[Event] %s t=%.0f at %s" % [Kind.keys()[kind], _session.get_game_time(), pos])


## 生成预警爆炸圈（流星雨事件用）
func _spawn_blast(pos: Vector3, radius: float, fuse: float, damage: float, color: Color) -> void:
	var BlastScript: Script = preload("res://gameplay/actors/delayed_blast.gd")
	var b: Node3D = BlastScript.new()
	b.setup(radius, damage, fuse, "流星")
	b.color = color
	get_tree().current_scene.add_child(b)
	b.global_position = Vector3(pos.x, 0.0, pos.z)
	SkillVfx.record(["blast", b.global_position, radius, fuse, color])


## 生成治疗区域（治愈之泉事件用）
func _spawn_healing_zone(pos: Vector3, radius: float, heal_per_sec: float, duration: float) -> void:
	var zone: Node3D = Node3D.new()
	zone.global_position = pos
	get_tree().current_scene.add_child(zone)

	# 视觉特效
	SkillVfx.pulse_ring(get_tree().current_scene, pos, radius, Color(0.4, 1.0, 0.6, 0.5), duration)

	# 治疗逻辑
	var timer: float = 0.0
	var heal_interval: float = 0.5
	while timer < duration:
		await get_tree().create_timer(heal_interval).timeout
		timer += heal_interval
		for player: Node3D in PlayerQuery.alive(get_tree()):
			if player.global_position.distance_to(pos) <= radius:
				var stats: CharacterStats = player.stats
				if stats:
					stats.heal(heal_per_sec * heal_interval)
					SkillVfx.burst(get_tree().current_scene, "magic", player.global_position + Vector3(0, 1.0, 0), 0.8, Color(0.4, 1.0, 0.6))

	zone.queue_free()

