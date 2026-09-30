extends Node
## 背景音乐管理器：根据游戏状态（探索/战斗/Boss）自动切换三首循环音乐，淡入淡出平滑过渡。
## 音乐由 tools/audio/synth_music.py 程序化合成，无版权问题，可无缝循环。

enum State { EXPLORE, BATTLE, BOSS }

const TRACKS: Dictionary = {
	State.EXPLORE: preload("res://assets/audio/music/explore.wav"),
	State.BATTLE: preload("res://assets/audio/music/battle.wav"),
	State.BOSS: preload("res://assets/audio/music/boss.wav"),
}
const FADE_TIME: float = 2.0

var _player: AudioStreamPlayer = null
var _state: State = State.EXPLORE
var _target_volume: float = 0.0
var _fade_timer: float = 0.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = -80.0
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_play(State.EXPLORE)


func _process(delta: float) -> void:
	if _fade_timer > 0.0:
		_fade_timer -= delta
		var t: float = 1.0 - clampf(_fade_timer / FADE_TIME, 0.0, 1.0)
		_player.volume_db = lerpf(-80.0, _target_volume, t)


## 根据附近敌人数量和 Boss 存在情况切换状态（由 GameScene 每秒调用一次）。
func update_state(enemy_count: int, has_boss: bool) -> void:
	var new_state: State = State.BOSS if has_boss else (State.BATTLE if enemy_count > 5 else State.EXPLORE)
	if new_state != _state:
		_state = new_state
		_play(new_state)


func _play(state: State) -> void:
	_player.stream = TRACKS[state]
	_player.play()
	_target_volume = -10.0 if state == State.EXPLORE else -12.0  # 音乐压在音效下面
	_fade_timer = FADE_TIME


## 停止音乐（游戏结束/暂停）。
func stop() -> void:
	_player.stop()
