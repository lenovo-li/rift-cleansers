extends Node3D
## 延时爆炸：先在地面显示逐渐填满的红圈（可读的预警），fuse 秒后对圈内玩家造成伤害。
## 用于爆裂小鬼的死亡爆炸——近战击杀后有时间走出圈外。

var radius: float = 2.5
var damage: float = 25.0
var fuse: float = 0.7
var source_name: String = "爆炸"
var _elapsed: float = 0.0
var _player: Node3D = null
var _fill: MeshInstance3D = null


func setup(p_radius: float, p_damage: float, p_fuse: float, p_source_name: String, player: Node3D) -> void:
	radius = p_radius
	damage = p_damage
	fuse = p_fuse
	source_name = p_source_name
	_player = player


func _ready() -> void:
	add_child(_disc(radius, Color(1, 0.3, 0.1, 0.18), 0.03))
	_fill = _disc(radius, Color(1, 0.35, 0.1, 0.45), 0.05)
	_fill.scale = Vector3(0.05, 1, 0.05)
	add_child(_fill)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var k: float = clampf(_elapsed / fuse, 0.05, 1.0)
	_fill.scale = Vector3(k, 1, k)
	if _elapsed < fuse:
		return
	if _player != null and is_instance_valid(_player):
		var d: Vector3 = _player.global_position - global_position
		d.y = 0.0
		if d.length() <= radius:
			_player.take_damage(damage, source_name)
	SkillVfx.pulse_ring(get_parent(), global_position, radius, Color(1, 0.5, 0.1, 0.6), 0.25)
	queue_free()


static func _disc(r: float, color: Color, y: float) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.03
	cyl.radial_segments = 24
	mi.mesh = cyl
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position.y = y
	return mi
