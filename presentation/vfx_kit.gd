class_name VfxKit extends RefCounted
## 技能特效资源：assets/models/vfx_kit.glb 里的特效网格 + Blender 渲染的地面贴图（tools/blender/build_vfx.py 生成）
## + presentation/shaders/vfx_*.gdshader。材质按着色器（地面贴图按贴图）共享，颜色、透明度走 instance uniform，不破坏批处理。
## 网格约定：平面特效躺在地面（XZ）；SlashArc/Dagger/IceLance/Greatsword 的前方是 -Z；Beam/Dome 底在 y=0、半径 1。

const KIT: String = "vfx_kit"
const TEX_DIR: String = "res://assets/textures/vfx/"
const SHADERS: Dictionary = {
	"slash": preload("res://presentation/shaders/vfx_slash.gdshader"),
	"fresnel": preload("res://presentation/shaders/vfx_fresnel.gdshader"),
	"beam": preload("res://presentation/shaders/vfx_beam.gdshader"),
	"solid": preload("res://presentation/shaders/vfx_solid.gdshader"),
	"decal": preload("res://presentation/shaders/vfx_decal.gdshader"),
}

static var _materials: Dictionary = {}  # "slash" / "decal:rune_circle" ... -> ShaderMaterial
static var _noise: NoiseTexture2D = null
static var _quad: QuadMesh = null


## 无头模拟（测试、服务器压力）里不创建特效节点。
static func enabled() -> bool:
	return DisplayServer.get_name() != "headless"


static func mesh(part: String) -> Mesh:
	return ModelLibrary.mesh(KIT, part)


static func material(shader: String, mask: String = "") -> ShaderMaterial:
	var key: String = shader + ":" + mask
	if not _materials.has(key):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = SHADERS[shader]
		if shader in ["slash", "fresnel", "beam"]:
			mat.set_shader_parameter("noise_tex", noise())
		if not mask.is_empty():
			mat.set_shader_parameter("mask_tex", load(TEX_DIR + mask + ".png"))
		_materials[key] = mat
	return _materials[key]


static func noise() -> NoiseTexture2D:
	if _noise == null:
		_noise = NoiseTexture2D.new()
		_noise.width = 128
		_noise.height = 128
		_noise.seamless = true
		var fn: FastNoiseLite = FastNoiseLite.new()
		fn.frequency = 0.06
		_noise.noise = fn
	return _noise


## 在 parent 下放一个特效网格（part 为 vfx_kit 里的网格名，或直接传 Mesh）。找不到网格时返回 null。
static func spawn(parent: Node, part: Variant, shader: String, tint: Color, mask: String = "") -> MeshInstance3D:
	var m: Mesh = part if part is Mesh else mesh(String(part))
	if m == null or parent == null or not parent.is_inside_tree():
		return null
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = material(shader, mask)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.set_instance_shader_parameter("tint", tint)
	return mi


## 边长 2、朝上的方片（地面贴图用；缩放 = 半径）。
static func decal_mesh() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(2, 2)
		_quad.orientation = PlaneMesh.FACE_Y
	return _quad


static var _sphere: SphereMesh = null


## 半径 1 的低面数球（飞行物核心、光点）。
static func sphere() -> SphereMesh:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 1.0
		_sphere.height = 2.0
		_sphere.radial_segments = 16
		_sphere.rings = 8
	return _sphere


## 地面贴图（rune_circle / crack）：半径 radius 的水平方片。
static func decal(parent: Node, mask: String, pos: Vector3, radius: float, tint: Color) -> MeshInstance3D:
	var mi: MeshInstance3D = spawn(parent, decal_mesh(), "decal", tint, mask)
	if mi != null:
		mi.global_position = Vector3(pos.x, 0.06, pos.z)
		mi.scale = Vector3(radius, 1.0, radius)
	return mi


static func set_fade(mi: GeometryInstance3D, v: float) -> void:
	if is_instance_valid(mi):
		mi.set_instance_shader_parameter("fade", v)


## 渐隐后释放：duration 秒内 fade 从 from 到 0。
static func fade_out(mi: GeometryInstance3D, duration: float, from: float = 1.0) -> void:
	if not is_instance_valid(mi):
		return
	var tw: Tween = mi.create_tween()
	tw.tween_method(func(v: float) -> void: set_fade(mi, v), from, 0.0, duration)
	tw.tween_callback(mi.queue_free)


## 水平面上朝向 dir 的基（网格前方 -Z 对齐 dir）。
static func facing_basis(dir: Vector3) -> Basis:
	var d: Vector3 = Vector3(dir.x, 0.0, dir.z)
	if d.length_squared() < 0.0001:
		d = Vector3.FORWARD
	return Basis.looking_at(d.normalized(), Vector3.UP)


## 空间任意方向的基（飞行物：前方 -Z 指向 dir）。
static func aim_basis(dir: Vector3) -> Basis:
	if dir.length_squared() < 0.0001:
		return Basis.IDENTITY
	var up: Vector3 = Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.RIGHT
	return Basis.looking_at(dir.normalized(), up)


static func clear() -> void:
	_materials.clear()
