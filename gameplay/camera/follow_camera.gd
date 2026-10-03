extends Camera3D
## 俯视跟随相机：只跟随目标位置，不跟随目标旋转。支持重击时的短暂震屏。
## 在编辑器中摆好的相机相对目标的偏移会被保留下来。
## 滚轮缩放：最近可到 0.5 倍距离，最远为当前设定距离（1.0 倍），平滑插值过渡。

@export var target_path: NodePath = NodePath("../PlayerM1")
@export var shake_decay: float = 3.0
@export var zoom_step: float = 0.1     # 每档滚轮缩放 10%（1.0 → 0.9 → 0.8 ... → 0.5，共 6 档）
@export var min_zoom: float = 0.5      # 最小缩放倍率（最近）
@export var max_zoom: float = 1.0      # 最大缩放倍率（最远，默认距离）
@export var zoom_smoothness: float = 8.0  # 缩放插值速度

var _target: Node3D = null
var _offset: Vector3 = Vector3.ZERO
var _base_offset: Vector3 = Vector3.ZERO  # 初始偏移（作为 max_zoom 时的距离）
var _trauma: float = 0.0
var _zoom_target: float = 1.0  # 目标缩放倍率
var _zoom_current: float = 1.0 # 当前缩放倍率（平滑插值）


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	if _target != null:
		_offset = global_position - _target.global_position
		_base_offset = _offset


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_target = clampf(_zoom_target - zoom_step, min_zoom, max_zoom)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_target = clampf(_zoom_target + zoom_step, min_zoom, max_zoom)
			get_viewport().set_input_as_handled()


func shake(strength: float) -> void:
	_trauma = minf(1.0, _trauma + strength)


func _process(delta: float) -> void:
	if _target == null:
		return
	# 平滑插值到目标缩放
	_zoom_current = lerpf(_zoom_current, _zoom_target, clampf(delta * zoom_smoothness, 0.0, 1.0))
	_offset = _base_offset * _zoom_current

	var jitter: Vector3 = Vector3.ZERO
	if _trauma > 0.0:
		var amount: float = _trauma * _trauma * 0.6
		jitter = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * amount
		_trauma = maxf(0.0, _trauma - shake_decay * delta)
	global_position = _target.global_position + _offset + jitter
