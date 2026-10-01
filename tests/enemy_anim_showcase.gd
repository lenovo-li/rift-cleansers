extends SceneTree
## 敌人 / Boss 顶点动画截图（需要真实渲染，不要加 --headless）：
##   godot --path . --script res://tests/enemy_anim_showcase.gd -- --out=C:/tmp/enemy_anim
## 所有敌人排成一排原地走路，依次截：走路两帧、挥击、施法、蓄力、砸地、受击。

const SpawnerScript: GDScript = preload("res://gameplay/spawn/enemy_spawner.gd")
## [镜头名, 动作, 截图时刻（动作开始后秒数）]
const SHOTS: Array = [
	["walk_a", -1, 0.0], ["walk_b", -1, 0.18], ["swing", EnemyAnimator.Kind.SWING, 0.2],
	["cast", EnemyAnimator.Kind.CAST, 0.25], ["windup", EnemyAnimator.Kind.WINDUP, 0.3],
	["slam", EnemyAnimator.Kind.SLAM, 0.42], ["hurt", -2, 0.04],
]

var _out: String = "user://enemy_anim"
var _views: Array = []  # [MeshInstance3D, EnemyAnimator]
var _i: int = -1
var _t: float = 0.0
var _warm: float = 0.0


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(_out)
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.21, 0.25)
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	env.environment.ambient_light_energy = 0.6
	world.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var ids: Array = SpawnerScript.DEFS.keys() + SpawnerScript.BOSS_DEFS.keys()
	for k in ids.size():
		var def: EnemyDef = SpawnerScript.DEFS.get(ids[k], SpawnerScript.BOSS_DEFS.get(ids[k]))
		var mi: MeshInstance3D = MeshInstance3D.new()
		Enemy.apply_look(mi, def, "")
		world.add_child(mi)
		var boss: bool = SpawnerScript.BOSS_DEFS.has(ids[k])
		var n: int = SpawnerScript.DEFS.size()
		mi.position = Vector3((k - n) * 5.0 + 3.0, 0, -6.0) if boss else Vector3(k * 2.2, 0, 0)
		mi.rotation.y = deg_to_rad(-35)
		_views.append([mi, EnemyAnimator.new(mi, def.move_speed), def.move_speed])
	var cam: Camera3D = Camera3D.new()
	world.add_child(cam)
	var mid: float = (SpawnerScript.DEFS.size() - 1) * 1.1
	cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(mid, 4.5, 9.5)).looking_at(Vector3(mid, 1.2, -2.0), Vector3.UP)
	cam.fov = 50


func _process(delta: float) -> bool:
	var walking: bool = _i < 0 or int(SHOTS[_i][1]) == -1
	for v: Array in _views:
		(v[1] as EnemyAnimator).update(delta, Vector3(0, 0, -float(v[2])) if walking else Vector3.ZERO)
	if _i < 0:
		_warm += delta
		if _warm > 1.0:
			_next()
		return false
	_t += delta
	if _t >= float(SHOTS[_i][2]):
		var img: Image = root.get_viewport().get_texture().get_image()
		img.save_png("%s/%02d_%s.png" % [_out, _i, SHOTS[_i][0]])
		_next()
		if _i >= SHOTS.size():
			print("[enemy_anim] done")
			return true
	return false


func _next() -> void:
	_i += 1
	_t = 0.0
	if _i >= SHOTS.size():
		return
	var action: int = int(SHOTS[_i][1])
	for v: Array in _views:
		var a: EnemyAnimator = v[1]
		if action >= 0:
			a.attack(action, 0.6 if action != EnemyAnimator.Kind.SLAM else 0.8)
		elif action == -2:
			a.hit()
