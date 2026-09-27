extends Node
## 音效管理器 - 播放一次性音效

const IMPACT_SOUNDS: Array[String] = [
	"res://assets/sfx/kenney_impact-sounds/Audio/impactMetal_light_000.ogg",
	"res://assets/sfx/kenney_impact-sounds/Audio/impactMetal_light_001.ogg",
	"res://assets/sfx/kenney_impact-sounds/Audio/impactMetal_light_002.ogg",
	"res://assets/sfx/kenney_impact-sounds/Audio/impactMetal_light_003.ogg",
	"res://assets/sfx/kenney_impact-sounds/Audio/impactMetal_light_004.ogg",
]

const WHOOSH_SOUNDS: Array[String] = [
	"res://assets/sfx/kenney_impact-sounds/Audio/impactSoft_medium_000.ogg",
	"res://assets/sfx/kenney_impact-sounds/Audio/impactSoft_medium_001.ogg",
	"res://assets/sfx/kenney_impact-sounds/Audio/impactSoft_medium_002.ogg",
]


## 播放命中音效（随机选一个）
static func play_hit(parent: Node, position: Vector3, volume_db: float = 0.0) -> void:
	if IMPACT_SOUNDS.is_empty():
		return
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = load(IMPACT_SOUNDS.pick_random())
	player.volume_db = volume_db
	player.max_distance = 30.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	parent.add_child(player)
	player.global_position = position
	player.play()
	await player.finished
	player.queue_free()


## 播放挥舞音效
static func play_whoosh(parent: Node, position: Vector3, volume_db: float = -6.0) -> void:
	if WHOOSH_SOUNDS.is_empty():
		return
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = load(WHOOSH_SOUNDS.pick_random())
	player.volume_db = volume_db
	player.max_distance = 20.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	parent.add_child(player)
	player.global_position = position
	player.play()
	await player.finished
	player.queue_free()
