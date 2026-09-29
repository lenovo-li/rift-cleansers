extends SceneTree
## 完整 10 分钟模拟：简单机器人（绕圈风筝 + 自动施放 + 自动选升级 + 捡装备）跑完整局，
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
	_player.auto_cast = true
	_session.game_over.connect(_on_game_over)
	print("[full] seed=%d" % sim_seed)


func _process(delta: float) -> bool:
	if _done:
		return true
	if not _session.is_running:
		return false
	var t: float = _session.get_game_time()
	_drive_bot(delta)
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


## 机器人：优先去捡装备；被围超过 12 只时后撤闪避；否则靠近最近的敌人并绕着它横移。
func _drive_bot(_delta: float) -> void:
	var pos: Vector3 = _player.global_position
	var loot: Node = _scene.get_node("LootManager")
	for p: Node in loot.get_children():
		if p.get("kind") == "equipment":
			_player.move_override = (p.global_position - pos) * Vector3(1, 0, 1)
			return
	var nearest: Node3D = null
	var nearest_d: float = INF
	var crowd: int = 0
	var crowd_center: Vector3 = Vector3.ZERO
	for e: Node in get_nodes_in_group("enemies"):
		var d: float = (e as Node3D).global_position.distance_to(pos)
		if d < nearest_d:
			nearest_d = d
			nearest = e
		if d < 3.0:
			crowd += 1
			crowd_center += (e as Node3D).global_position
	if crowd > 12:
		_player.move_override = (pos - crowd_center / crowd) * Vector3(1, 0, 1) + Vector3(0.001, 0, 0)
		if _player.dodge_cooldown_remaining <= 0.0:
			_player.dodge()
	elif _spawner.boss != null:
		# Boss 出现后集中打 Boss
		var to_b: Vector3 = (_spawner.boss.global_position - pos) * Vector3(1, 0, 1)
		_player.move_override = to_b if to_b.length() > 4.0 else to_b.cross(Vector3.UP).normalized()
	elif nearest != null:
		# 远了就靠近，近了就绕着最近的敌人横移（半速不可控，这里用切向 + 轻微后撤）
		var to_e: Vector3 = (nearest.global_position - pos) * Vector3(1, 0, 1)
		var tangent: Vector3 = to_e.cross(Vector3.UP).normalized()
		_player.move_override = to_e if nearest_d > 3.0 else tangent - to_e.normalized() * 0.3
	else:
		_player.move_override = Vector3.ZERO


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
