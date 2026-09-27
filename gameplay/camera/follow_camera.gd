extends Camera3D
## 俯视跟随相机：只跟随目标位置，不跟随目标旋转。
## 在编辑器中摆好的相机相对目标的偏移会被保留下来。

@export var target_path: NodePath = NodePath("../PlayerM1")

var _target: Node3D = null
var _offset: Vector3 = Vector3.ZERO


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	if _target != null:
		_offset = global_position - _target.global_position


func _process(_delta: float) -> void:
	if _target != null:
		global_position = _target.global_position + _offset
