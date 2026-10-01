class_name EnemyAnimator extends RefCounted
## 敌人 / Boss 的顶点动画驱动：每帧把跑动相位、移动强度、攻击进度、受击、闪白写进网格的实例参数，
## 由 model_anim.gdshader 摆动四肢（模型必须是 build_models.py 带动作分区导出的 glb）。
## 主机的 Enemy 和客户端的 EnemyViewPool 共用，客户端按位置变化推算速度，没有攻击动作。

enum Kind { SWING, CAST, WINDUP, SLAM }

const STRIDE: float = 0.9          # 体型 1.0 时每步前进的距离（米），相位按移动距离累加
const ATTACK_TIME: float = 0.45
const HURT_DECAY: float = 4.5
const FLASH_DECAY: float = 12.0

var _mi: MeshInstance3D = null
var _stride: float = STRIDE
var _speed: float = 3.0
var _phase: float = 0.0
var _move: float = 0.0
var _atk_t: float = -1.0
var _atk_len: float = ATTACK_TIME
var _kind: int = Kind.SWING
var _hurt: float = 0.0
var _flash: float = 0.0
var _hold_flash: bool = false
var _seed: float = 0.0


## max_speed：满强度跑动时的速度（米/秒），用于把速度换算成 0-1 的移动强度。
func _init(mi: MeshInstance3D, max_speed: float) -> void:
	_mi = mi
	_stride = STRIDE * maxf(mi.scale.x, 0.3)
	_speed = maxf(max_speed, 0.5)
	_seed = randf() * 100.0
	_push()


## 播放攻击动作。duration < 0 时用默认时长。
func attack(kind: int = Kind.SWING, duration: float = -1.0) -> void:
	_kind = kind
	_atk_len = duration if duration > 0.0 else ATTACK_TIME
	_atk_t = 0.0


func hit() -> void:
	_hurt = 1.0
	_flash = 1.0


## 持续闪白（小鬼蓄力），false 时恢复按受击衰减。
func hold_flash(on: bool) -> void:
	_hold_flash = on
	if on:
		_flash = 0.8


func update(delta: float, velocity: Vector3) -> void:
	var speed: float = Vector2(velocity.x, velocity.z).length()
	_phase = fmod(_phase + speed * delta / _stride * PI, TAU * 64.0)
	_move = lerpf(_move, clampf(speed / _speed, 0.0, 1.0), clampf(delta * 8.0, 0.0, 1.0))
	if _atk_t >= 0.0:
		_atk_t += delta
		if _atk_t >= _atk_len:
			_atk_t = -1.0
	_hurt = maxf(0.0, _hurt - delta * HURT_DECAY)
	if not _hold_flash:
		_flash = maxf(0.0, _flash - delta * FLASH_DECAY)
	_push()


var _last_b: Vector4 = Vector4(-1, -1, -1, -1)


## 500 只敌人时每次设置实例参数都有开销：anim_a 每帧都在变，anim_b（闪白、攻击类型）只在变化时才写。
func _push() -> void:
	var atk: float = clampf(_atk_t / _atk_len, 0.0, 1.0) if _atk_t >= 0.0 else 0.0
	_mi.set_instance_shader_parameter("anim_a", Vector4(_phase, _move, atk, _hurt))
	var b: Vector4 = Vector4(_flash, float(_kind), _seed, 0.0)
	if b != _last_b:
		_last_b = b
		_mi.set_instance_shader_parameter("anim_b", b)
