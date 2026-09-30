class_name EnemyViewPool extends Node3D
## 客户端敌人显示：按主机快照维护一组 MeshInstance3D（与主机敌人共用网格/材质缓存）。
## 不运行 AI 和物理，只做位置平滑、受击闪白和飘字（按血量比例下降估算伤害）；快照里 1 秒没再出现的敌人视为已消失。

const SpawnerScript: GDScript = preload("res://gameplay/spawn/enemy_spawner.gd")
const STALE_MS: int = 1000
const SMOOTHING: float = 12.0
const SNAP_DISTANCE: float = 6.0

var _views: Dictionary = {}  # id -> {node, target, hp, seen, flash}
var _defs: Dictionary = {}   # type -> EnemyDef


func _ready() -> void:
	for id: String in SpawnerScript.DEFS:
		_defs[id] = SpawnerScript.DEFS[id]
	_defs["corrupted_knight"] = SpawnerScript.BOSS_DEF


func count() -> int:
	return _views.size()


func apply(records: Array[Dictionary]) -> void:
	var now: int = Time.get_ticks_msec()
	for r: Dictionary in records:
		var v: Dictionary = _views.get(r.id, {})
		if v.is_empty():
			v = _create(r)
			_views[r.id] = v
		v.target = r.pos
		v.seen = now
		if r.hp < v.hp - 0.001:
			v.flash = 0.08
			DamageNumbers.spawn(get_parent(), r.pos, (float(v.hp) - float(r.hp)) * float(v.max_hp))
		v.hp = r.hp


## killed = 主机通知的死亡（播放死亡特效）；超时移除则直接消失。
func remove(id: int, killed: bool = false) -> void:
	var v: Dictionary = _views.get(id, {})
	if v.is_empty():
		return
	var mi: MeshInstance3D = v.node
	if killed:
		SkillVfx.death(get_parent(), v.target, mi.mesh, float(v.height), (v.base as StandardMaterial3D).albedo_color, bool(v.elite))
		SfxManager.play(get_parent(), "explode" if v.elite else "death")
	mi.queue_free()
	_views.erase(id)


func _create(r: Dictionary) -> Dictionary:
	var def: EnemyDef = _defs.get(r.type, _defs["zombie"])
	var elite: bool = not String(r.elite).is_empty()
	var s: float = def.body_scale * (Enemy.ELITE_SCALE if elite else 1.0)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = Enemy._cached_mesh(s)
	var base: StandardMaterial3D = Enemy.shared_material(Enemy.ELITE_COLORS[r.elite] if elite else def.color)
	mi.material_override = base
	mi.add_to_group("enemy_views")
	add_child(mi)
	mi.global_position = r.pos + Vector3(0, 0.8 * s, 0)
	var is_boss: bool = r.type == "corrupted_knight"
	return {"node": mi, "target": r.pos, "hp": r.hp, "seen": Time.get_ticks_msec(), "flash": 0.0,
		"base": base, "height": 0.8 * s, "is_boss": is_boss, "elite": elite or is_boss,
		"max_hp": def.max_health * (Enemy.ELITE_HEALTH_MULT if elite else 1.0)}


func _process(delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	var k: float = clampf(delta * SMOOTHING, 0.0, 1.0)
	var flash_mat: StandardMaterial3D = Enemy.flash_material()
	for id: int in _views.keys():
		var v: Dictionary = _views[id]
		if now - int(v.seen) > STALE_MS:
			remove(id)
			continue
		var mi: MeshInstance3D = v.node
		var target: Vector3 = (v.target as Vector3) + Vector3(0, v.height, 0)
		if mi.global_position.distance_to(target) > SNAP_DISTANCE:
			mi.global_position = target
		else:
			mi.global_position = mi.global_position.lerp(target, k)
		if float(v.flash) > 0.0:
			v.flash = float(v.flash) - delta
			mi.material_override = flash_mat if float(v.flash) > 0.0 else v.base


## Boss 冲锋预警（主机录下的 telegraph 事件）。
func show_telegraph(center: Vector3, dir: Vector3, length: float, duration: float) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(2.0, 0.05, length)
	mi.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.1, 0.1, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	add_child(mi)
	mi.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3(center.x, 0.05, center.z))
	get_tree().create_timer(duration).timeout.connect(mi.queue_free)
