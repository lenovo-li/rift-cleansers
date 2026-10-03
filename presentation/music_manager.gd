extends Node
## 背景音乐管理器 v2：动态音乐系统，根据战斗强度平滑过渡。
## 三个状态（探索/战斗/Boss）× 双层播放器交叉淡入淡出，避免切换时的断点感。
## 切换规则：Boss 在场 → Boss 曲；敌人 ≥ BATTLE_THRESHOLD → 战斗曲；≤ EXPLORE_THRESHOLD → 探索曲；中间保持不变。
## 每张地图一套：assets/audio/music/<地图 id>_{explore,battle,boss}.ogg，缺失时回退到灰烬王城。

enum State { EXPLORE, BATTLE, BOSS }

const MUSIC_DIR: String = "res://assets/audio/music/"
const FALLBACK_MAP: String = "ashen_city"
const TRACK_NAMES: Dictionary = {State.EXPLORE: "explore", State.BATTLE: "battle", State.BOSS: "boss"}
const FADE_TIME: float = 2.5  # 交叉淡入淡出时间
const EXTENSIONS: Array[String] = ["ogg", "wav"]

## 战斗强度阈值（附近敌人数量），中间留回差：4-5 只时保持当前曲目，避免在临界点来回切
const BATTLE_THRESHOLD: int = 6
const EXPLORE_THRESHOLD: int = 3

## 地图 id（进场前设置；为空时读 NetConfig.map_id）
var map_id: String = ""
var _players: Array[AudioStreamPlayer] = []  # 双层播放器用于交叉淡入淡出
var _active_idx: int = 0  # 当前播放的播放器索引
var _state: State = State.EXPLORE
var _streams: Dictionary = {}  # State -> AudioStream
var _transition_timer: float = 0.0
var _is_transitioning: bool = false
var _fade_from_db: float = -80.0  # 淡出的那首开始淡出时的音量


func _ready() -> void:
	if map_id.is_empty():
		map_id = NetConfig.map_id
	for state: State in TRACK_NAMES:
		var stream: AudioStream = load(track_path(map_id, state))
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		_streams[state] = stream

	# 创建双层播放器
	for i in 2:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.volume_db = -80.0
		player.bus = Settings.MUSIC_BUS
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)

	_play_on(_active_idx, State.EXPLORE, -80.0)
	_transition_timer = 0.0
	_is_transitioning = true  # 开局从静音淡入（另一个播放器没在播，淡出那半边无影响）


## 该地图该状态的曲目路径；地图没有专属曲目时用默认地图的。
static func track_path(p_map_id: String, state: State) -> String:
	for map: String in [p_map_id, FALLBACK_MAP]:
		for ext: String in EXTENSIONS:
			var path: String = "%s%s_%s.%s" % [MUSIC_DIR, map, TRACK_NAMES[state], ext]
			if ResourceLoader.exists(path):
				return path
	return "%s%s_%s.wav" % [MUSIC_DIR, FALLBACK_MAP, TRACK_NAMES[state]]


func _process(delta: float) -> void:
	if not _is_transitioning:
		return

	_transition_timer += delta
	var t: float = clampf(_transition_timer / FADE_TIME, 0.0, 1.0)
	var ease_t: float = t * t * (3.0 - 2.0 * t)  # smoothstep

	# 交叉淡入淡出
	var old_idx: int = 1 - _active_idx
	_players[_active_idx].volume_db = lerpf(-80.0, _get_target_volume(), ease_t)
	_players[old_idx].volume_db = lerpf(_fade_from_db, -80.0, ease_t)

	if _transition_timer >= FADE_TIME:
		_is_transitioning = false
		_players[old_idx].stop()


## 根据附近敌人数量和 Boss 存在情况切换状态（由 GameScene 每秒调用一次）。
func update_state(enemy_count: int, has_boss: bool) -> void:
	var new_state: State
	if has_boss:
		new_state = State.BOSS
	elif enemy_count >= BATTLE_THRESHOLD:
		new_state = State.BATTLE
	elif enemy_count <= EXPLORE_THRESHOLD:
		new_state = State.EXPLORE
	else:
		# 在阈值之间保持当前状态，避免频繁切换
		return

	if new_state != _state:
		_state = new_state
		_transition_to(new_state)


func _transition_to(state: State) -> void:
	if _is_transitioning:
		# 上一次过渡还没完：正在淡出的那首直接停掉，正在淡入的那首从当前音量开始淡出
		_players[1 - _active_idx].stop()
	_fade_from_db = _players[_active_idx].volume_db
	_active_idx = 1 - _active_idx
	_play_on(_active_idx, state, -80.0)
	_transition_timer = 0.0
	_is_transitioning = true


func _play_on(idx: int, state: State, start_volume_db: float) -> void:
	_players[idx].stream = _streams[state]
	_players[idx].volume_db = start_volume_db
	_players[idx].play()


func _get_target_volume() -> float:
	return -10.0 if _state == State.EXPLORE else -12.0  # 与 v1 相同：战斗曲更满，压低一点让音效在上面


## 停止音乐（游戏结束/暂停）。
func stop() -> void:
	for player in _players:
		player.stop()
	_is_transitioning = false
