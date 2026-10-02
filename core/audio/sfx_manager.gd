class_name SfxManager extends RefCounted
## 一次性音效播放 v2：程序化合成 + FluidSynth 管弦乐层，分层设计，响度归一化。
## 俯视角相机离战场约 28 米，3D 定位音效会被距离衰减到听不见，所以这里用不定位的 AudioStreamPlayer。
## 按类别选音（每类 5 个变体随机），同类音效有最小间隔，避免命中多个敌人时叠成噪音。

const AUDIO_DIR: String = "res://assets/sfx/generated/"

## 类别 -> [文件前缀, 最小间隔毫秒, 音量 dB, 音高范围]
const CATEGORIES: Dictionary = {
	# 敌人音效
	"hit": ["enemy_hit", 50, -5.0, Vector2(0.95, 1.05)],
	"death": ["enemy_death", 40, -8.0, Vector2(0.92, 1.08)],
	"explode": ["elite_death", 90, -3.0, Vector2(0.95, 1.05)],

	# 玩家受击
	"hurt": ["player_hurt", 150, -4.0, Vector2(0.95, 1.05)],
	"block": ["shield_block", 120, -2.0, Vector2(0.95, 1.05)],

	# 普通攻击（根据角色 attack_kind 选择）
	"auto_pulse": ["auto_pulse", 0, -3.0, Vector2(0.98, 1.02)],
	"auto_slash": ["auto_slash", 0, -3.0, Vector2(0.98, 1.02)],
	"auto_bolt_crystal": ["auto_crystal", 0, -3.0, Vector2(0.98, 1.02)],
	"auto_bolt_holy": ["auto_holy", 0, -2.0, Vector2(1.0, 1.0)],

	# 技能音效
	"fire_cast": ["fire_cast", 80, -2.0, Vector2(0.98, 1.02)],
	"fire_impact": ["fire_impact", 90, -1.0, Vector2(0.95, 1.05)],
	"ice_cast": ["ice_cast", 80, -3.0, Vector2(0.98, 1.02)],
	"ice_shatter": ["ice_shatter", 90, -2.0, Vector2(0.95, 1.05)],
	"lightning_cast": ["lightning_cast", 70, -2.0, Vector2(0.98, 1.02)],
	"lightning_hit": ["lightning_hit", 80, -2.0, Vector2(0.95, 1.05)],
	"shield_up": ["shield_up", 120, -2.0, Vector2(1.0, 1.0)],
	"explosion_heavy": ["explosion_heavy", 100, 0.0, Vector2(0.92, 1.08)],
	"crit_hit": ["crit_hit", 90, -1.0, Vector2(0.95, 1.05)],
	"heal_cast": ["heal_cast", 150, -3.0, Vector2(1.0, 1.0)],
	"holy_buff": ["holy_buff", 200, -2.0, Vector2(1.0, 1.0)],
	"evolve": ["evolve_magic", 300, -2.0, Vector2(1.0, 1.0)],
	"pickup": ["pickup_magic", 150, -4.0, Vector2(1.0, 1.0)],

	# 技能别名映射（向后兼容）
	"heavy": ["explosion_heavy", 80, 0.0, Vector2(0.92, 1.08)],
	"slam": ["explosion_heavy", 100, 0.0, Vector2(0.85, 0.95)],
	"shatter": ["ice_shatter", 90, -2.0, Vector2(0.95, 1.05)],
	"whoosh": ["auto_slash", 0, -2.0, Vector2(0.95, 1.05)],
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


## 挥舞音效（没有专属施法音的物理技能用）。
static func play_whoosh(parent: Node) -> AudioStreamPlayer:
	return play(parent, "whoosh")


## 普攻音效：kind 为 pulse / slash / bolt，远程普攻再按 bolt_fx（crystal / holy）区分。
static func play_attack(parent: Node, kind: String, bolt_fx: String) -> AudioStreamPlayer:
	match kind:
		"pulse": return play(parent, "auto_pulse")
		"slash": return play(parent, "auto_slash")
	return play(parent, "auto_bolt_holy" if bolt_fx == "holy" else "auto_bolt_crystal")


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
