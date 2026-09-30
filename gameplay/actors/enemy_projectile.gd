extends Node3D
## 食尸鬼的酸液弹：直线飞行，命中玩家造成伤害并减速。速度较慢，可以走位躲开。

const SPEED: float = 9.0
const LIFETIME: float = 2.5
const HIT_RADIUS: float = 0.9

var _source: Node = null
var _dir: Vector3 = Vector3.FORWARD
var _damage: float = 10.0
var _life: float = LIFETIME
var _source_name: String = "酸液"
## 客户端回放用：只显示、不结算伤害。
var visual_only: bool = false


func setup(source: Node, dir: Vector3, damage: float, color: Color) -> void:
	_source = source
	_dir = dir
	_damage = damage
	if source != null and source.has_method("get_display_name"):
		_source_name = "%s的酸液" % source.get_display_name()
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	mi.mesh = sphere
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	add_child(mi)


func _ready() -> void:
	add_to_group("enemy_projectiles")


func direction() -> Vector3:
	return _dir


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	global_position += _dir * SPEED * delta
	if visual_only:
		return
	# 命中任意存活玩家（来源可能已死亡，用名字记录死因）
	for p: Node3D in PlayerQuery.alive_in_radius(get_tree(), global_position, HIT_RADIUS):
		p.take_damage(_damage, _source_name)
		p.apply_slow(0.3, 1.5)
		queue_free()
		return
