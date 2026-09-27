extends Node3D
## M0 测试场景 - 性能监控

@onready var _fps_label: Label = $UI/HUD/FPS
@onready var _frame_label: Label = $UI/HUD/Frame
@onready var _physics_label: Label = $UI/HUD/Physics
@onready var _enemy_label: Label = $UI/HUD/Enemy

var _frame_times: Array[float] = []
const SAMPLES: int = 60


func _process(_delta: float) -> void:
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	
	var frame_time: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_frame_times.append(frame_time)
	if _frame_times.size() > SAMPLES:
		_frame_times.pop_front()
	
	var avg: float = 0.0
	for t in _frame_times:
		avg += t
	avg /= _frame_times.size()
	_frame_label.text = "Frame: %.2fms (avg %.2fms)" % [frame_time, avg]
	
	_physics_label.text = "Physics: %.2fms" % (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	
	var enemy_count: int = 0
	if has_node("EnemyManager"):
		enemy_count = get_node("EnemyManager").get_enemy_count()
	_enemy_label.text = "Enemies: %d" % enemy_count
