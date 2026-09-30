extends Node3D
## 膨胀怪死亡后留下的减速毒区：玩家站在里面会被减速并持续受伤。地面上有明确的色块提示。

const TICK: float = 0.5
const DPS: float = 10.0

var radius: float = 3.5
var slow_factor: float = 0.5
var duration: float = 4.0
var _elapsed: float = 0.0
var _tick_timer: float = 0.0
var _mat: StandardMaterial3D = null
var _color: Color = Color(0.6, 0.65, 0.1, 0.35)
## 客户端回放用：只显示、不结算伤害。
var visual_only: bool = false


func setup(p_radius: float, p_slow: float, p_duration: float, color: Color) -> void:
	radius = p_radius
	slow_factor = p_slow
	duration = p_duration
	_color = color


func _ready() -> void:
	add_to_group("danger")  # 机器人躲避（PlayerBot._evade）
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.05
	mi.mesh = cyl
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = _color
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = _mat
	mi.position.y = 0.03
	add_child(mi)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		queue_free()
		return
	_mat.albedo_color.a = _color.a * (1.0 - _elapsed / duration * 0.6)
	_tick_timer += delta
	if visual_only or _tick_timer < TICK:
		return
	_tick_timer -= TICK
	for p: Node3D in PlayerQuery.alive_in_radius(get_tree(), global_position, radius):
		p.take_damage(DPS * TICK, "膨胀怪毒区")
		p.apply_slow(slow_factor, 1.0)
