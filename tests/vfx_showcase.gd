extends SceneTree
## 技能特效截图巡检（需要真实渲染，不要加 --headless）：
##   godot --path . --script res://tests/vfx_showcase.gd -- --char=iron_guard --level=5 --out=C:/tmp/vfx
## 依次施放该角色 6 个技能（每个前刷一圈敌人），在施放后若干时刻截图，外加一张跑动截图。

var _char: String = "iron_guard"
var _level: int = 5
var _out: String = "user://vfx_shots"
var _scene: Node = null
var _player: Node = null
var _skills: Array[String] = []
var _index: int = -1
var _t: float = 0.0
var _shots: Array[float] = [0.15, 0.5]
var _shot_i: int = 0
var _attack_t: float = 0.0
## 开局时场景根下已有的子节点（地图、刷怪器、相机等），清理残留特效时保留
var _baseline: Dictionary = {}
## --only=id1,id2：只截这些技能（迭代单个特效时用）
var _only: PackedStringArray = []
const SLOT_TIME: float = 2.4


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--char="):
			_char = arg.get_slice("=", 1)
		elif arg.begins_with("--level="):
			_level = int(arg.get_slice("=", 1))
		elif arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
		elif arg.begins_with("--only="):
			_only = arg.get_slice("=", 1).split(",")
	DirAccess.make_dir_recursive_absolute(_out)
	Talents.enabled = false
	NetConfig.character_id = _char
	_scene = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	_scene.auto_pick_upgrades = true
	_scene.record_runs = false
	root.add_child(_scene)
	_player = _scene.get_node("PlayerM1")


## 玩家 _ready 之后（第一帧）才有 ability_system。
func _setup_skills() -> void:
	for c: Node in _scene.get_children():
		_baseline[c.get_instance_id()] = true
	var cdef: Dictionary = CharacterCatalog.get_def(_char)
	for id: String in cdef.skills:
		if _only.is_empty() or id in _only:
			_skills.append(id)
		if _player.ability_system.get_skill(id) == null:
			_player.ability_system.add_skill(SkillFactory.create(id))
		_player.ability_system.set_level(id, _level)


func _spawn_ring() -> void:
	var spawner: Node = _scene.get_node("EnemySpawner")
	var p: Vector3 = _player.global_position
	for i in 10:
		var a: float = TAU * i / 10.0
		spawner.spawn_enemy("zombie", [], p + Vector3(sin(a), 0, -cos(a)) * 5.0 + Vector3(0, 0, -2.0), 0.5)


func _shot(tag: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.resize(img.get_width() / 2, img.get_height() / 2)
	img.save_png("%s/%s_L%d_%s.png" % [_out, _char, _level, tag])


func _process(delta: float) -> bool:
	_player.stats.health = _player.stats.max_health
	_t += delta
	if _skills.is_empty():
		_setup_skills()
	if _index < 0:
		# 热身：先跑一段看身体动作，再站定让普攻打一圈敌人
		_player.move_override = Vector3(1, 0, -0.3) if _t < 1.6 else Vector3.ZERO
		if _t > 1.5 and _shot_i == 0:
			_shot("run")
			_shot_i = 1
			_spawn_ring()
		# 普攻：敌人刷出后主动打一次，再按普攻特效的时间点截图
		if _shot_i == 1 and _t > 1.8:
			_player.auto_attack()
			_player.attack_timer = 99.0
			_shot_i = 2
			_attack_t = _t
		if _shot_i >= 2 and _shot_i < 5 and _t > _attack_t + 0.06 * (_shot_i - 1):
			_shot("attack_%d" % _shot_i)
			_shot_i += 1
		if _t > 2.6:
			_player.move_override = Vector3.ZERO
			_next()
		return false
	if _shot_i < _shots.size() and _t >= _shots[_shot_i]:
		_shot("%d_%s_%d" % [_index, _skills[_index], _shot_i])
		_shot_i += 1
	if _t >= SLOT_TIME:
		_next()
		if _index >= _skills.size():
			print("[vfx] done -> ", ProjectSettings.globalize_path(_out))
			return true
	return false


func _next() -> void:
	_index += 1
	_t = 0.0
	_shot_i = 0
	if _index >= _skills.size():
		return
	# 清理上一个技能的残留：敌人尸体、地面区域、特效节点
	for e: Node in get_nodes_in_group("enemies"):
		e.queue_free()
	_player.ability_system.zones.clear()
	_player.ability_system.strikes.clear()
	# 特效节点都挂在场景根下：开局时记下原有子节点，之后新增的一律当残留特效删掉
	for c: Node in _scene.get_children():
		if not _baseline.has(c.get_instance_id()):
			c.queue_free()
	_spawn_ring()
	var id: String = _skills[_index]
	_player.ability_system.set_cooldown_remaining(id, 0.0)
	_player.facing = Vector3.FORWARD
	_player.rotation.y = 0.0
	var r: Dictionary = _player.cast_skill(id)
	print("[vfx] cast %s -> %s" % [id, "ok" if not r.is_empty() else "FAILED"])
