class_name SfxManager extends RefCounted
## 一次性音效播放 v3：程序化合成 + 分类管理 + 对象池 + 可选 3D 空间化。
## 性能优化：
##   - 对象池复用播放器节点，避免每次 play() 都 new + add_child + queue_free
##   - 最大同时播放数限制（MAX_VOICES），超过时静默丢弃
##   - 同类音效最小间隔控制，避免命中多敌时叠噪
## 空间化：
##   - 默认用 AudioStreamPlayer（2D，不衰减）
##   - 传入 use_3d=true 时用 AudioStreamPlayer3D，自定义衰减曲线（max_distance=40m）
##   - 适合 Boss 技能、爆炸等需要方位感的大音效

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

	# 16 个新技能专属音效（每个 3 变体）
	"sk_earthquake": ["sk_earthquake", 80, -4.0, Vector2(0.95, 1.05)],
	"sk_iron_wall": ["sk_iron_wall", 100, -3.0, Vector2(0.95, 1.05)],
	"sk_war_cry": ["sk_war_cry", 90, -2.0, Vector2(0.95, 1.05)],
	"sk_flame_cleave": ["sk_flame_cleave", 70, -4.0, Vector2(0.95, 1.05)],
	"sk_thunderstorm": ["sk_thunderstorm", 100, -3.0, Vector2(0.95, 1.05)],
	"sk_frost_barrier": ["sk_frost_barrier", 90, -4.0, Vector2(0.95, 1.05)],
	"sk_arcane_barrage": ["sk_arcane_barrage", 60, -4.0, Vector2(0.95, 1.05)],
	"sk_lava_blast": ["sk_lava_blast", 90, -2.0, Vector2(0.95, 1.05)],
	"sk_eviscerate": ["sk_eviscerate", 70, -4.0, Vector2(0.95, 1.05)],
	"sk_shadow_clone": ["sk_shadow_clone", 90, -3.0, Vector2(0.95, 1.05)],
	"sk_backstab": ["sk_backstab", 60, -5.0, Vector2(0.95, 1.05)],
	"sk_poison_blade": ["sk_poison_blade", 80, -4.0, Vector2(0.95, 1.05)],
	"sk_guardian_angel": ["sk_guardian_angel", 100, -3.0, Vector2(0.95, 1.05)],
	"sk_purify": ["sk_purify", 90, -3.0, Vector2(0.95, 1.05)],
	"sk_resurrection": ["sk_resurrection", 120, -2.0, Vector2(0.95, 1.05)],
	"sk_holy_wrath": ["sk_holy_wrath", 90, -2.0, Vector2(0.95, 1.05)],

	# 游戏进度
	"level_up": ["level_up", 200, 0.0, Vector2(1.0, 1.0)],
	"wave_start": ["wave_start", 150, -1.0, Vector2(1.0, 1.0)],
	"wave_complete": ["wave_complete", 180, 0.0, Vector2(1.0, 1.0)],
	"boss_roar": ["boss_roar", 300, -1.0, Vector2(0.95, 1.05)],

	# 拾取（经验 / 金币类掉落频繁，间隔短、音量低）
	"item_pickup": ["item_pickup", 80, -2.0, Vector2(0.98, 1.02)],
	"coin_pickup": ["coin_pickup", 60, -4.0, Vector2(0.95, 1.08)],

	# UI
	"ui_hover": ["ui_hover", 40, -6.0, Vector2(1.0, 1.0)],
	"ui_click": ["ui_click", 50, -4.0, Vector2(1.0, 1.0)],
	"ui_open": ["ui_open", 100, -3.0, Vector2(1.0, 1.0)],
	"ui_close": ["ui_close", 100, -3.0, Vector2(1.0, 1.0)],
}
const VARIANTS: int = 5
## 同时存在的播放器上限（500 敌人同时挨打时不让音频线程爆掉）
const MAX_VOICES: int = 24
const POOL_SIZE: int = 16  # 2D 播放器池大小

static var _last_played_ms: Dictionary = {}  # 类别 -> 上次播放时间
static var _streams: Dictionary = {}  # 类别 -> Array[AudioStream]（首次使用时加载）
static var _voices: int = 0
static var _pool_2d: Array[AudioStreamPlayer] = []
static var _pool_3d: Array[AudioStreamPlayer3D] = []
static var _pool_host: Node = null  # 对象池挂在哪个场景节点下
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

	# 确保对象池已初始化
	_ensure_pool(parent)

	# 从池中获取空闲播放器
	var player: AudioStreamPlayer = _acquire_2d()
	if player == null:
		# 池满，创建临时播放器
		player = AudioStreamPlayer.new()
		player.bus = Settings.SFX_BUS
		player.finished.connect(func() -> void:
			_voices -= 1
			player.queue_free())
		parent.add_child(player)

	player.stream = streams.pick_random()
	player.volume_db = float(cfg[2])
	var pitch: Vector2 = cfg[3]
	player.pitch_scale = randf_range(pitch.x, pitch.y)
	_voices += 1
	player.play()
	return player


## 播放定位音效（3D空间化）。适用于需要方位感的大音效：Boss 咆哮、爆炸、陨石。
## position 为世界坐标。联机时只在主机转发类别，客户端播放为 2D（不定位）。
static func play_at(parent: Node, category: String, position: Vector3) -> AudioStreamPlayer3D:
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
		recorder.call(category)  # 联机：客户端收到后用 play() 播放为 2D

	_ensure_pool(parent)
	var player: AudioStreamPlayer3D = _acquire_3d()
	if player == null:
		# 池满，创建临时播放器
		player = AudioStreamPlayer3D.new()
		player.bus = Settings.SFX_BUS
		player.max_distance = 50.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		player.unit_size = 12.0  # 12 米内无衰减，俯视角相机距离 ~28 米时 -1.5dB
		player.panning_strength = 1.5  # 加强左右声道差异
		player.finished.connect(func() -> void:
			_voices -= 1
			player.queue_free())
		parent.add_child(player)

	player.global_position = position
	player.stream = streams.pick_random()
	player.volume_db = float(cfg[2])
	var pitch: Vector2 = cfg[3]
	player.pitch_scale = randf_range(pitch.x, pitch.y)
	_voices += 1
	player.play()
	return player


static func _ensure_pool(parent: Node) -> void:
	var host: Node = parent.get_tree().current_scene if parent.get_tree().current_scene else parent
	if _pool_host == null or not is_instance_valid(_pool_host) or _pool_host != host:
		_pool_host = host
		_pool_2d.clear()
		_pool_3d.clear()


static func _acquire_2d() -> AudioStreamPlayer:
	# 查找空闲播放器
	for p in _pool_2d:
		if not p.playing:
			return p
	# 池未满，创建新播放器
	if _pool_2d.size() < POOL_SIZE:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = Settings.SFX_BUS
		p.process_mode = Node.PROCESS_MODE_ALWAYS  # UI 音效在暂停时也能播
		p.finished.connect(func() -> void: _voices -= 1)
		_pool_host.add_child(p)
		_pool_2d.append(p)
		return p
	return null


static func _acquire_3d() -> AudioStreamPlayer3D:
	for p in _pool_3d:
		if not p.playing:
			return p
	# 3D 池按需创建，上限 8 个
	if _pool_3d.size() < 8:
		var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		p.bus = Settings.SFX_BUS
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.max_distance = 50.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		p.unit_size = 12.0
		p.panning_strength = 1.5
		p.finished.connect(func() -> void: _voices -= 1)
		_pool_host.add_child(p)
		_pool_3d.append(p)
		return p
	return null


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
