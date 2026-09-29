class_name Boss extends Enemy
## 腐化骑士（文档 05 §1.6）三阶段：
## 1（100%-60%）近战 + 定期召唤小怪；2（60%-30%）增加冲锋（1 秒红色箭头预警）；
## 3（30%-0%）狂暴：攻速 +50%，每 5 秒召唤 1 只精英。召唤共 4 波、每波 5 只。

signal phase_changed(phase: int)
signal summon_requested(enemy_id: String, count: int, elite_mod: String, center: Vector3)

const SUMMON_INTERVAL: float = 12.0
const SUMMON_WAVES: int = 4
const SUMMON_SIZE: int = 5
const CHARGE_INTERVAL: float = 6.0
const CHARGE_WINDUP: float = 1.0
const CHARGE_SPEED: float = 26.0
const ELITE_INTERVAL: float = 5.0

var phase: int = 1
var _summon_timer: float = 4.0
var _waves_done: int = 0
var _charge_timer: float = CHARGE_INTERVAL
var _charge_state: int = 0  # 0 无 1 预警 2 冲锋
var _charge_time: float = 0.0
var _charge_dir: Vector3 = Vector3.ZERO
var _charge_hit: bool = false
var _elite_timer: float = ELITE_INTERVAL
var _telegraph: MeshInstance3D = null


## 血量比例 -> 阶段。
static func phase_for_ratio(ratio: float) -> int:
	if ratio > 0.6:
		return 1
	if ratio > 0.3:
		return 2
	return 3


func _ready() -> void:
	super._ready()
	knockback_resist = 0.9
	add_to_group("boss")


func health_ratio() -> float:
	return current_health / max_health


func _behavior_velocity(delta: float, dir: Vector3, dist: float) -> Vector3:
	var new_phase: int = phase_for_ratio(health_ratio())
	if new_phase != phase:
		phase = new_phase
		phase_changed.emit(phase)
	if phase == 3:
		attack_timer -= delta * 0.5  # 攻速 +50%
		_elite_timer -= delta
		if _elite_timer <= 0.0:
			_elite_timer = ELITE_INTERVAL
			summon_requested.emit("skeleton", 1, SpawnDirector.ELITE_MODS.pick_random(), global_position)
	if _waves_done < SUMMON_WAVES:
		_summon_timer -= delta
		if _summon_timer <= 0.0:
			_summon_timer = SUMMON_INTERVAL
			_waves_done += 1
			summon_requested.emit("zombie" if _waves_done % 2 == 1 else "skeleton", SUMMON_SIZE, "", global_position)
	if phase >= 2:
		var v: Variant = _charge(delta, dir)
		if v != null:
			return v
	return dir * move_speed() if dist > def.attack_range * def.body_scale * 0.8 else Vector3.ZERO


## 冲锋：预警 1 秒（地面红色箭头指向冲锋方向）→ 高速直线冲撞。返回 null 表示不在冲锋中。
func _charge(delta: float, dir: Vector3) -> Variant:
	match _charge_state:
		0:
			_charge_timer -= delta
			if _charge_timer > 0.0:
				return null
			_charge_state = 1
			_charge_time = CHARGE_WINDUP
			_charge_dir = dir
			_show_telegraph(true)
			return Vector3.ZERO
		1:
			_charge_time -= delta
			if _charge_time > 0.0:
				return Vector3.ZERO
			_charge_state = 2
			_charge_time = def.special_range / CHARGE_SPEED
			_charge_hit = false
			_show_telegraph(false)
			return _charge_dir * CHARGE_SPEED
		_:
			_charge_time -= delta
			if not _charge_hit and global_position.distance_to(target_player.global_position) < 2.5:
				_charge_hit = true
				target_player.take_damage(def.special_value, self)
			if _charge_time <= 0.0:
				_charge_state = 0
				_charge_timer = CHARGE_INTERVAL * (0.7 if phase == 3 else 1.0)
			return _charge_dir * CHARGE_SPEED


func _show_telegraph(visible_now: bool) -> void:
	if _telegraph == null:
		_telegraph = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(2.0, 0.05, def.special_range)
		_telegraph.mesh = box
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0.1, 0.1, 0.45)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_telegraph.material_override = mat
		_telegraph.top_level = true
		add_child(_telegraph)
	_telegraph.visible = visible_now
	if visible_now:
		var center: Vector3 = global_position + _charge_dir * def.special_range * 0.5
		_telegraph.global_transform = Transform3D(Basis.looking_at(_charge_dir, Vector3.UP), Vector3(center.x, 0.05, center.z))


## Boss 不会被击退打断冲锋。
func apply_knockback(impulse: Vector3) -> void:
	if _charge_state == 0:
		super.apply_knockback(impulse)


func die() -> void:
	if _telegraph != null:
		_telegraph.visible = false
	super.die()
