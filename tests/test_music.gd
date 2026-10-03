extends RefCounted
## 动态音乐：状态切换规则（回差）和双播放器交叉淡入淡出。

const MusicScript: GDScript = preload("res://presentation/music_manager.gd")


func _make() -> Node:
	var m: Node = MusicScript.new()
	m.map_id = "ashen_city"
	m._ready()  # 测试里不进场景树，手动初始化
	return m


func test_state_hysteresis() -> String:
	var m: Node = _make()
	var err: String = ""
	m.update_state(5, false)  # 4-5 只在回差区间，保持探索
	if m._state != m.State.EXPLORE:
		err = "回差区间内不应切到战斗曲"
	m.update_state(6, false)
	if err.is_empty() and m._state != m.State.BATTLE:
		err = "敌人达到 BATTLE_THRESHOLD 应切到战斗曲"
	m.update_state(4, false)
	if err.is_empty() and m._state != m.State.BATTLE:
		err = "战斗中掉到回差区间应保持战斗曲"
	m.update_state(2, false)
	if err.is_empty() and m._state != m.State.EXPLORE:
		err = "敌人降到 EXPLORE_THRESHOLD 以下应回到探索曲"
	m.update_state(0, true)
	if err.is_empty() and m._state != m.State.BOSS:
		err = "Boss 在场应切到 Boss 曲"
	m.free()
	return err


func test_crossfade_swaps_players() -> String:
	var m: Node = _make()
	var before: int = m._active_idx
	m._process(MusicScript.FADE_TIME + 0.1)  # 走完开局淡入
	m.update_state(10, false)
	if m._active_idx == before:
		m.free()
		return "切换曲目时应换到另一个播放器"
	m._process(MusicScript.FADE_TIME * 0.5)
	var mid_new: float = m._players[m._active_idx].volume_db
	var mid_old: float = m._players[1 - m._active_idx].volume_db
	m._process(MusicScript.FADE_TIME)
	var err: String = ""
	if not (mid_new > -80.0 and mid_old > -80.0):
		err = "过渡中途两首都应在播放（新 %.1f 旧 %.1f dB）" % [mid_new, mid_old]
	elif m._is_transitioning or not is_equal_approx(m._players[m._active_idx].volume_db, m._get_target_volume()):
		err = "过渡结束后新曲应在目标音量"
	m.free()
	return err
