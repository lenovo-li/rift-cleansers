extends Node3D
## 地面拾取物：装备（金色方块 + 光柱，需走过去拾取）或治疗球（绿色，靠近时被吸过来）。

signal collected(pickup: Node3D)

const COLLECT_RADIUS: float = 1.6
const ORB_MAGNET_RADIUS: float = 5.0
const ORB_LIFETIME: float = 30.0

var kind: String = "heal"  # heal / equipment
var item_id: String = ""
var amount: float = 0.0
var player: Node3D = null
var _time: float = 0.0
var _body: MeshInstance3D = null


func setup(p_kind: String, p_item_id: String, p_amount: float, p_player: Node3D) -> void:
	kind = p_kind
	item_id = p_item_id
	amount = p_amount
	player = p_player


func _ready() -> void:
	var is_equipment: bool = kind == "equipment"
	var color: Color = Color(1.0, 0.8, 0.2) if is_equipment else Color(0.3, 1.0, 0.4)
	_body = MeshInstance3D.new()
	if is_equipment:
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.8, 0.8, 0.8)
		_body.mesh = box
	else:
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.3
		sphere.height = 0.6
		_body.mesh = sphere
	_body.material_override = _glow(color, 1.0)
	add_child(_body)
	if is_equipment:
		var beam: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.25
		cyl.bottom_radius = 0.25
		cyl.height = 8.0
		beam.mesh = cyl
		beam.position.y = 4.0
		beam.material_override = _glow(Color(color, 0.25), 0.25)
		add_child(beam)


func _process(delta: float) -> void:
	_time += delta
	_body.position.y = 0.8 + sin(_time * 3.0) * 0.2
	_body.rotate_y(delta * 2.0)
	if kind == "heal" and _time > ORB_LIFETIME:
		queue_free()
		return
	if player == null or not is_instance_valid(player):
		return
	var d: Vector3 = player.global_position - global_position
	d.y = 0.0
	var dist: float = d.length()
	if kind == "heal" and dist < ORB_MAGNET_RADIUS and dist > 0.01:
		global_position += d / dist * minf(dist, 14.0 * delta)
	if dist < COLLECT_RADIUS:
		collected.emit(self)
		queue_free()


static func _glow(color: Color, alpha: float) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(color, alpha)
	mat.emission_enabled = true
	mat.emission = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
