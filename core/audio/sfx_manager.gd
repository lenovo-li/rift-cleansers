class_name SfxManager extends RefCounted
## 一次性音效播放。俯视角相机离战场约 28 米，3D 定位音效会被距离衰减到听不见，
## 所以这里用不定位的 AudioStreamPlayer。
## 同类音效有最小间隔，避免一次命中多个敌人时叠成噪音。

const HIT_STREAMS: Array[AudioStream] = [
	preload("res://assets/sfx/kenney_impact-sounds/Audio/impactMetal_light_000.ogg"),
	preload("res://assets/sfx/kenney_impact-sounds/Audio/impactMetal_light_001.ogg"),
	preload("res://assets/sfx/kenney_impact-sounds/Audio/impactMetal_light_002.ogg"),
	preload("res://assets/sfx/kenney_impact-sounds/Audio/impactMetal_light_003.ogg"),
	preload("res://assets/sfx/kenney_impact-sounds/Audio/impactMetal_light_004.ogg"),
]

const WHOOSH_STREAMS: Array[AudioStream] = [
	preload("res://assets/sfx/kenney_impact-sounds/Audio/impactSoft_medium_000.ogg"),
	preload("res://assets/sfx/kenney_impact-sounds/Audio/impactSoft_medium_001.ogg"),
	preload("res://assets/sfx/kenney_impact-sounds/Audio/impactSoft_medium_002.ogg"),
]

const HIT_MIN_INTERVAL_MS: int = 60
const WHOOSH_MIN_INTERVAL_MS: int = 0

static var _last_played_ms: Dictionary = {}  # 类别 -> 上次播放时间
## 联机：主机设置后，实际播放的音效类别会交给 recorder(category) 转发给客户端。
static var recorder: Callable = Callable()


## 命中音效。返回创建的播放器；被节流时返回 null。
static func play_hit(parent: Node, volume_db: float = -4.0) -> AudioStreamPlayer:
	return _play(parent, "hit", HIT_STREAMS, HIT_MIN_INTERVAL_MS, volume_db)


## 挥舞/施法音效。
static func play_whoosh(parent: Node, volume_db: float = -2.0) -> AudioStreamPlayer:
	return _play(parent, "whoosh", WHOOSH_STREAMS, WHOOSH_MIN_INTERVAL_MS, volume_db)


static func _play(parent: Node, category: String, streams: Array[AudioStream],
		min_interval_ms: int, volume_db: float) -> AudioStreamPlayer:
	if parent == null or not parent.is_inside_tree() or streams.is_empty():
		return null
	var now: int = Time.get_ticks_msec()
	if min_interval_ms > 0 and now - int(_last_played_ms.get(category, -100000)) < min_interval_ms:
		return null
	_last_played_ms[category] = now
	if recorder.is_valid():
		recorder.call(category)
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = streams.pick_random()
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.92, 1.08)
	player.finished.connect(player.queue_free)
	parent.add_child(player)
	player.play()
	return player
