extends SceneTree
## 角色身体动作近景截图（需要真实渲染，不要加 --headless）：
##   godot --path . --script res://tests/pose_showcase.gd -- --char=iron_guard --out=C:/tmp/pose
## 依次截：跑动两帧、每个动作的中段、受击、倒地。

const SHOTS: Array = [
	["run_a", "", 0.0], ["run_b", "", 0.0],
	["swing", "swing", 0.12], ["swing_hit", "swing", 0.19], ["bash", "bash", 0.12], ["cast", "cast", 0.15],
	["raise", "raise", 0.2], ["slam_up", "slam", 0.18], ["slam_down", "slam", 0.28], ["spin", "spin", 0.3],
	["hurt", "", 0.0], ["down", "", 0.0],
]

var _char: String = "iron_guard"
var _out: String = "user://pose_shots"
var _scene: Node = null
var _player: Node3D = null
var _cam: Camera3D = null
var _i: int = -1
var _t: float = 0.0
var _started: bool = false


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--char="):
			_char = arg.get_slice("=", 1)
		elif arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(_out)
	Talents.enabled = false
	NetConfig.character_id = _char
	_scene = (load("res://scenes/game_scene.tscn") as PackedScene).instantiate()
	_scene.auto_pick_upgrades = true
	_scene.record_runs = false
	root.add_child(_scene)
	_player = _scene.get_node("PlayerM1")
	_cam = _scene.get_node("Camera")


func _process(delta: float) -> bool:
	_player.stats.health = _player.stats.max_health
	_player.attack_timer = 99.0  # 不自动普攻，只看手动动作
	for e: Node in get_nodes_in_group("enemies"):
		e.queue_free()
	_cam.set_process(false)
	_cam.set_physics_process(false)
	var p: Vector3 = _player.global_position
	# 从角色左前方 3/4 角度近看（角色朝 -Z）
	_cam.global_transform = Transform3D(Basis.IDENTITY, p + Vector3(2.6, 1.9, -3.4)).looking_at(p + Vector3(0, 1.0, 0), Vector3.UP)
	_t += delta
	if not _started:
		if _t > 0.8:
			_started = true
			_next()
		return false
	var shot: Array = SHOTS[_i]
	var name: String = shot[0]
	# 跑动镜头：原地跑（每帧把玩家拉回原点，速度照算）
	if name.begins_with("run"):
		_player.move_override = Vector3(0, 0, -1)
	else:
		_player.move_override = Vector3.ZERO
	var wait: float = float(shot[2])
	if name == "run_a":
		wait = 0.6
	elif name == "run_b":
		wait = 0.72
	elif name == "hurt":
		wait = 0.05
	elif name == "down":
		wait = 0.6
	if _t >= wait:
		var img: Image = root.get_viewport().get_texture().get_image()
		img.save_png("%s/%s_%02d_%s.png" % [_out, _char, _i, name])
		if name == "down":
			_player.is_dead = false
		_next()
		if _i >= SHOTS.size():
			print("[pose] done")
			return true
	return false


func _next() -> void:
	_i += 1
	_t = 0.0
	if _i >= SHOTS.size():
		return
	var shot: Array = SHOTS[_i]
	var name: String = shot[0]
	_player.rotation.y = 0.0
	if not String(shot[1]).is_empty():
		_player.play_pose(shot[1])
	elif name == "hurt":
		_player.flash_hurt()
	elif name == "down":
		_player.is_dead = true
