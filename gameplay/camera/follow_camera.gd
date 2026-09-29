extends Camera3D
## 俯视跟随相机：只跟随目标位置，不跟随目标旋转。支持重击时的短暂震屏。
## 在编辑器中摆好的相机相对目标的偏移会被保留下来。

@export var target_path: NodePath = NodePath("../PlayerM1")
@export var shake_decay: float = 3.0

var _target: Node3D = null
var _offset: Vector3 = Vector3.ZERO
var _trauma: float = 0.0


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	if _target != null:
		_offset = global_position - _target.global_position


func shake(strength: float) -> void:
	_trauma = minf(1.0, _trauma + strength)


func _process(delta: float) -> void:
	if _target == null:
		return
	var jitter: Vector3 = Vector3.ZERO
	if _trauma > 0.0:
		var amount: float = _trauma * _trauma * 0.6
		jitter = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * amount
		_trauma = maxf(0.0, _trauma - shake_decay * delta)
	global_position = _target.global_position + _offset + jitter
