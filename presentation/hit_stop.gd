class_name HitStop extends RefCounted
## 命中停顿：重击时把时间放慢到 5%，持续 0.02-0.08 秒（真实时间），制造力量感。
## 只在单人模式、有渲染时生效：联机时改变主机 time_scale 会让客户端和主机时间不一致；
## 无头模拟用固定帧率，改 time_scale 会影响结果。

const SLOW_SCALE: float = 0.05
const MAX_DURATION: float = 0.12

static var _until_ms: int = 0
static var _active: bool = false
## 设置界面开关（默认开）。
static var enabled: bool = true


static func trigger(tree: SceneTree, duration: float) -> void:
	if not enabled or tree == null or NetConfig.is_online() or DisplayServer.get_name() == "headless":
		return
	var until: int = Time.get_ticks_msec() + int(minf(duration, MAX_DURATION) * 1000.0)
	if until <= _until_ms:
		return
	_until_ms = until
	Engine.time_scale = SLOW_SCALE
	if _active:
		return
	_active = true
	# ignore_time_scale 的计时器按真实时间走
	_wait(tree)


static func _wait(tree: SceneTree) -> void:
	while Time.get_ticks_msec() < _until_ms:
		await tree.create_timer(0.01, true, false, true).timeout
	reset()


static func reset() -> void:
	_active = false
	_until_ms = 0
	Engine.time_scale = 1.0
