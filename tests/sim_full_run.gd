extends SceneTree
## 完整 10 分钟模拟：PlayerBot（贴近横移 + 自动施放 + 自动选升级 + 捡装备）跑完整局，
## 验证时间线（等级、敌人数量、装备、精英、Boss）没有运行时错误，并输出每 30 秒的状态。
## 用法: godot --headless --fixed-fps 60 --path . --script res://tests/sim_full_run.gd -- --seed=N
## 退出码 0 = 跑到结束且无异常（胜负都算），1 = 卡住或超时。

const MAX_SECONDS: float = 720.0

var _scene: Node = null
var _session: GameSession = null
var _player: Node = null
var _spawner: Node = null
var _next_report: float = 30.0
var _done: bool = false
var _max_enemies: int = 0
var _elites_seen: Dictionary = {}


func _init() -> void:
	var sim_seed: int = 12345
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			sim_seed = int(arg.get_slice("=", 1))
	seed(sim_seed)
	_scene = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	_scene.auto_pick_upgrades = true
	root.add_child(_scene)
	_session = _scene.get_node("GameSession") as GameSession
	_player = _scene.get_node("PlayerM1")
	_spawner = _scene.get_node("EnemySpawner")
	_player.ai_controlled = true
	_player.bot = PlayerBot.new()
	_session.game_over.connect(_on_game_over)
	print("[full] seed=%d" % sim_seed)


func _process(_delta: float) -> bool:
	if _done:
		return true
	if not _session.is_running:
		return false
	var t: float = _session.get_game_time()
	var enemies: Array = get_nodes_in_group("enemies")
	_max_enemies = maxi(_max_enemies, enemies.size())
	for e: Node in enemies:
		if e is Enemy and (e as Enemy).is_elite():
			_elites_seen[e.get_instance_id()] = true
	if t >= _next_report:
		_report(t, enemies.size())
		_next_report += 30.0
	if t >= MAX_SECONDS:
		print("[full] FAIL: 超过 %.0f 秒仍未结束" % MAX_SECONDS)
		_done = true
		quit(1)
	return false


func _report(t: float, enemy_count: int) -> void:
	var skills: PackedStringArray = []
	for id: String in SkillFactory.SKILL_IDS:
		var s: Skill = _player.ability_system.get_skill(id)
		if s != null:
			skills.append("%s%d" % [id.substr(0, 4), s.level])
	print("[full] t=%3.0fs Lv%d hp=%.0f enemies=%d kills=%d equip=%d elites=%d skills=%s" % [
		t, _session.get_player_level(), _player.get_health(), enemy_count, _spawner.kills,
		_player.stats.equipment.size(), _elites_seen.size(), ",".join(skills)])
	var dmg: PackedStringArray = []
	for k: String in _player.damage_taken_by_source:
		dmg.append("%s=%d" % [k, _player.damage_taken_by_source[k]])
	print("[full]        taken: %s" % ", ".join(dmg))
	var boss: Boss = _spawner.boss
	if boss != null:
		print("[full]        boss hp=%.0f/%.0f phase=%d dist=%.1f" % [boss.current_health, boss.max_health, boss.phase,
			boss.global_position.distance_to(_player.global_position)])
	_player.damage_taken_by_source.clear()


func _on_game_over(reason: String, victory: bool) -> void:
	_report(_session.get_game_time(), get_nodes_in_group("enemies").size())
	print("[full] END victory=%s reason=%s time=%.0fs level=%d max_enemies=%d" % [
		victory, reason, _session.get_game_time(), _session.get_player_level(), _max_enemies])
	_done = true
	paused = false
	quit(0)
