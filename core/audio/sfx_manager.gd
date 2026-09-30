class_name SfxManager extends RefCounted
## 一次性音效播放。俯视角相机离战场约 28 米，3D 定位音效会被距离衰减到听不见，
## 所以这里用不定位的 AudioStreamPlayer。
## 按类别选音（Kenney Impact Sounds，每类 5 个变体随机），同类音效有最小间隔，避免命中多个敌人时叠成噪音。

const AUDIO_DIR: String = "res://assets/sfx/kenney_impact-sounds/Audio/"
## 类别 -> [文件前缀, 最小间隔毫秒, 音量 dB, 音高范围]
const CATEGORIES: Dictionary = {
	"hit": ["impactMetal_light", 60, -6.0, Vector2(0.92, 1.08)],
	"whoosh": ["impactSoft_medium", 0, -2.0, Vector2(0.92, 1.08)],
	"heavy": ["impactPunch_heavy", 80, -1.0, Vector2(0.9, 1.05)],
	"slam": ["impactWood_heavy", 100, 0.0, Vector2(0.7, 0.85)],
	"shatter": ["impactGlass_medium", 90, -4.0, Vector2(0.95, 1.15)],
	"explode": ["impactPlate_heavy", 90, -2.0, Vector2(0.75, 0.9)],
	"block": ["impactMetal_heavy", 120, -3.0, Vector2(1.1, 1.25)],
	"evolve": ["impactBell_heavy", 300, -3.0, Vector2(1.0, 1.1)],
	"pickup": ["impactGlass_light", 150, -6.0, Vector2(1.2, 1.4)],
	"death": ["impactSoft_heavy", 45, -9.0, Vector2(0.85, 1.1)],
	"hurt": ["impactPunch_medium", 150, -5.0, Vector2(0.85, 0.95)],
}
const VARIANTS: int = 5
## 同时存在的播放器上限（500 敌人同时挨打时不让音频线程爆掉）
const MAX_VOICES: int = 24

static var _last_played_ms: Dictionary = {}  # 类别 -> 上次播放时间
static var _streams: Dictionary = {}  # 类别 -> Array[AudioStream]（首次使用时加载）
static var _voices: int = 0
## 联机：主机设置后，实际播放的音效类别会交给 recorder(category) 转发给客户端。
static var recorder: Callable = Callable()


## 命中音效。返回创建的播放器；被节流时返回 null。
static func play_hit(parent: Node) -> AudioStreamPlayer:
	return play(parent, "hit")


## 挥舞/施法音效。
static func play_whoosh(parent: Node) -> AudioStreamPlayer:
	return play(parent, "whoosh")


static func play(parent: Node, category: String) -> AudioStreamPlayer:
	if parent == null or not parent.is_inside_tree() or not CATEGORIES.has(category):
		return null
	var cfg: Array = CATEGORIES[category]
	var now: int = Time.get_ticks_msec()
	if int(cfg[1]) > 0 and now - int(_last_played_ms.get(category, -100000)) < int(cfg[1]):
		return null
	if _voices >= MAX_VOICES:
		return null
	var streams: Array = _load(category)
	if streams.is_empty():
		return null
	_last_played_ms[category] = now
	if recorder.is_valid():
		recorder.call(category)
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = streams.pick_random()
	player.volume_db = float(cfg[2])
	player.bus = Settings.SFX_BUS
	var pitch: Vector2 = cfg[3]
	player.pitch_scale = randf_range(pitch.x, pitch.y)
	_voices += 1
	player.finished.connect(func() -> void:
		_voices -= 1
		player.queue_free())
	parent.add_child(player)
	player.play()
	return player


static func _load(category: String) -> Array:
	if not _streams.has(category):
		var list: Array = []
		for i in VARIANTS:
			var path: String = "%s%s_%03d.ogg" % [AUDIO_DIR, CATEGORIES[category][0], i]
			if ResourceLoader.exists(path):
				list.append(load(path))
		_streams[category] = list
	return _streams[category]


## 场景重载时播放器随场景释放，计数归零。
static func reset_voices() -> void:
	_voices = 0
