extends SceneTree
## Boss 专项模拟：开局 3 秒直接刷出当前地图的 Boss，玩家（机器人）全技能 6 级，最多打 240 秒。
## 用于快速验证各 Boss 技能组合与词缀没有运行时错误，并粗看难度。
## 用法: godot --headless --fixed-fps 60 --path . --script res://tests/sim_boss.gd -- --map=frost_wastes [--char=cleric] [--affix=berserk|none]
## 退出码 0 = 击败 Boss 或玩家阵亡（都算跑通），1 = 超时仍未分出胜负。

const MAX_SECONDS: float = 240.0

var _scene: Node = null
var _session: GameSession = null
var _player: Node = null
var _spawner: Node = null
var _spawned: bool = false
var _done: bool = false
var _phases: Array[int] = []
var _next_report: float = 30.0


func _init() -> void:
	seed(7)
	var affix: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			NetConfig.map_id = arg.get_slice("=", 1)
		elif arg.begins_with("--char="):
			NetConfig.character_id = arg.get_slice("=", 1)
		elif arg.begins_with("--affix="):
			affix = arg.get_slice("=", 1)
	Talents.enabled = false  # 不受玩家存档的天赋影响
	_scene = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	_scene.auto_pick_upgrades = true
	_scene.record_runs = false
	root.add_child(_scene)
	_session = _scene.get_node("GameSession") as GameSession
	_player = _scene.get_node("PlayerM1")
	_spawner = _scene.get_node("EnemySpawner")
	_spawner.forced_boss_affix = affix
	_player.ai_controlled = true
	_player.bot = PlayerBot.new()
	_player.auto_cast = true
	_session.game_over.connect(_on_game_over)
	print("[boss] map=%s char=%s affix=%s" % [NetConfig.map_id, NetConfig.character_id, affix])


func _process(_delta: float) -> bool:
	if _done:
		return true
	if not _session.is_running:
		return false
	var t: float = _session.get_game_time()
	if not _spawned and t > 3.0:
		_spawned = true
		for id: String in _player.ability_system.pool():
			if _player.ability_system.get_skill(id) == null:
				_player.ability_system.add_skill(SkillFactory.create(id))
			_player.ability_system.set_level(id, 6)
		for id: String in ["berserker_helm", "leech_gauntlet", "adrenaline_injector"]:
			_player.stats.add_equipment(id)
		var b: Boss = _spawner.spawn_boss()
		b.phase_changed.connect(func(p: int) -> void: _phases.append(p))
		print("[boss] spawned %s hp=%.0f" % [b.get_display_name(), b.max_health])
	var boss: Boss = _spawner.boss
	if boss != null and t >= _next_report:
		_next_report += 30.0
		print("[boss] t=%3.0fs boss hp=%.0f/%.0f phase=%d  player hp=%.0f" % [t, boss.current_health, boss.max_health,
				boss.phase, _player.get_health()])
	if t >= MAX_SECONDS:
		print("[boss] TIMEOUT boss hp=%.0f" % (boss.current_health if boss else 0.0))
		_done = true
		quit(1)
	return false


func _on_game_over(reason: String, victory: bool) -> void:
	print("[boss] END victory=%s reason=%s time=%.0fs phases=%s" % [victory, reason, _session.get_game_time(), _phases])
	_done = true
	paused = false
	quit(0)
