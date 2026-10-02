class_name Settings extends RefCounted
## 玩家设置（存在 SaveData 的 "settings" 下）：音量、伤害数字、震屏、按键。
## apply() 把设置应用到音频总线、DamageNumbers、SkillVfx 和 InputMap；进菜单和改设置时调用。

const MUSIC_BUS: String = "Music"
const SFX_BUS: String = "SFX"
## 可改键的动作（顺序即设置界面的顺序）和显示名
const ACTIONS: Array[String] = ["move_up", "move_down", "move_left", "move_right", "dash",
	"skill_0", "skill_1", "skill_2", "skill_3", "skill_4", "skill_5", "pause"]
const ACTION_NAMES: Dictionary = {
	"move_up": "向上移动", "move_down": "向下移动", "move_left": "向左移动", "move_right": "向右移动", "dash": "闪避",
	"skill_0": "技能 1", "skill_1": "技能 2", "skill_2": "技能 3", "skill_3": "技能 4", "skill_4": "技能 5",
	"skill_5": "技能 6", "pause": "暂停 / 菜单",
}
## 默认按键（physical keycode）。方向键作为移动的备用键保留在 project.godot 里，不参与改键。
const DEFAULT_KEYS: Dictionary = {
	"move_up": KEY_W, "move_down": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "dash": KEY_SHIFT,
	"skill_0": KEY_SPACE, "skill_1": KEY_Q, "skill_2": KEY_E, "skill_3": KEY_R, "skill_4": KEY_F, "skill_5": KEY_C,
	"pause": KEY_ESCAPE,
}

## 画质档位：低 = 无阴影 / 无泛光 / 0.75 渲染缩放 / 少粒子；中 = 柔和阴影 + FXAA；高 = 高质量阴影 + 4x MSAA。
enum { QUALITY_LOW, QUALITY_MEDIUM, QUALITY_HIGH }
const QUALITY_NAMES: Array[String] = ["低", "中", "高"]
const FPS_CAPS: Array[int] = [0, 60, 120, 144, 240]  # 0 = 不限

static var _applied_keys: Dictionary = {}  # 动作 -> 当前由设置写入的 InputEventKey（改键时只替换这一个）
static var _applied_display: Array = []  # 上次应用的 [fullscreen, vsync]，相同则不动窗口（避免每次进场景都重置窗口大小）


static func defaults() -> Dictionary:
	var keys: Dictionary = {}
	for a: String in DEFAULT_KEYS:
		keys[a] = int(DEFAULT_KEYS[a])
	return {"master": 1.0, "music": 0.8, "sfx": 1.0, "damage_numbers": true, "screen_shake": true, "keys": keys,
		"quality": QUALITY_HIGH, "fullscreen": false, "vsync": true, "max_fps": 0, "auto_cast": false}


## 当前设置（缺的字段补默认值）。
static func data() -> Dictionary:
	var save: Dictionary = SaveData.data()
	var s: Dictionary = save.get("settings", {})
	var d: Dictionary = defaults()
	for k: String in d:
		if s.has(k) and d[k] is int and s[k] is float:
			s[k] = int(s[k])  # JSON 读回来的整数是 float
		elif not s.has(k) or typeof(s[k]) != typeof(d[k]):
			s[k] = d[k]
	for a: String in DEFAULT_KEYS:
		if not (s.keys as Dictionary).has(a):
			s.keys[a] = int(DEFAULT_KEYS[a])
	save["settings"] = s
	return s


static func get_value(key: String) -> Variant:
	return data()[key]


static func set_value(key: String, value: Variant) -> void:
	data()[key] = value
	apply()


static func key_of(action: String) -> int:
	return int((data().keys as Dictionary).get(action, DEFAULT_KEYS.get(action, 0)))


## 改键。若新键已被其他动作占用，两者互换。返回被换走的动作（没有则为空）。
static func bind(action: String, keycode: int) -> String:
	var keys: Dictionary = data().keys
	var swapped: String = ""
	for other: String in keys:
		if other != action and int(keys[other]) == keycode:
			keys[other] = int(keys[action])
			swapped = other
	keys[action] = keycode
	apply()
	return swapped


static func reset_to_defaults() -> void:
	SaveData.data()["settings"] = defaults()
	apply()


static func save() -> void:
	SaveData.save_file()


static func key_name(keycode: int) -> String:
	return OS.get_keycode_string(keycode) if keycode != 0 else "-"


static func apply() -> void:
	var s: Dictionary = data()
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_set_volume("Master", float(s.master))
	_set_volume(MUSIC_BUS, float(s.music))
	_set_volume(SFX_BUS, float(s.sfx))
	DamageNumbers.enabled = bool(s.damage_numbers)
	SkillVfx.shake_enabled = bool(s.screen_shake)
	_apply_keys(s.keys)
	_apply_display(s)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.current_scene != null:
		apply_quality(tree.current_scene)


static func quality() -> int:
	return clampi(int(data().quality), QUALITY_LOW, QUALITY_HIGH)


## 画质：视口抗锯齿 / 渲染缩放，以及场景里的阴影和泛光。游戏场景搭好地图后也会调用一次。
static func apply_quality(scene: Node) -> void:
	var q: int = quality()
	var vp: Viewport = scene.get_viewport()
	if vp != null:
		vp.msaa_3d = Viewport.MSAA_4X if q == QUALITY_HIGH else Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q == QUALITY_MEDIUM else Viewport.SCREEN_SPACE_AA_DISABLED
		vp.scaling_3d_scale = 0.75 if q == QUALITY_LOW else 1.0
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_HIGH if q == QUALITY_HIGH else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	ParticleFx.density = 0.5 if q == QUALITY_LOW else 1.0
	var sun: DirectionalLight3D = scene.get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.shadow_enabled = q != QUALITY_LOW
	var we: WorldEnvironment = scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null:
		we.environment.glow_enabled = q != QUALITY_LOW


## 全屏 / 垂直同步 / 帧率上限。无界面模式（测试）不动窗口。
static func _apply_display(s: Dictionary) -> void:
	Engine.max_fps = int(s.max_fps)
	if DisplayServer.get_name() == "headless":
		return
	var want: Array = [bool(s.fullscreen), bool(s.vsync)]
	if want == _applied_display:
		return
	if _applied_display.is_empty() and not want[0]:
		pass  # 首次且窗口模式：保持 project.godot 的默认窗口（最大化），不去改
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want[0] else DisplayServer.WINDOW_MODE_MAXIMIZED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if want[1] else DisplayServer.VSYNC_DISABLED)
	_applied_display = want


## 手柄（Xbox 布局）：左摇杆 / 十字键移动，A 闪避，X/Y/B/LB/RB/RT 六个技能，Start 菜单。
## UI 导航（ui_accept / ui_cancel / 方向）用 Godot 自带的手柄映射。
const PAD_BUTTONS: Dictionary = {
	"dash": JOY_BUTTON_A, "skill_0": JOY_BUTTON_X, "skill_1": JOY_BUTTON_Y, "skill_2": JOY_BUTTON_B,
	"skill_3": JOY_BUTTON_LEFT_SHOULDER, "skill_4": JOY_BUTTON_RIGHT_SHOULDER, "pause": JOY_BUTTON_START,
	"move_up": JOY_BUTTON_DPAD_UP, "move_down": JOY_BUTTON_DPAD_DOWN,
	"move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT,
}
const PAD_AXES: Dictionary = {  # 动作 -> [轴, 方向]
	"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
	"skill_5": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}
## 手柄按钮的显示名（HUD 提示用）
const PAD_NAMES: Dictionary = {"dash": "A", "skill_0": "X", "skill_1": "Y", "skill_2": "B", "skill_3": "LB",
	"skill_4": "RB", "skill_5": "RT", "pause": "Start"}


static func _add_pad_events(action: String) -> void:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			return  # 已有（project.godot 里配过）
	if PAD_BUTTONS.has(action):
		var b: InputEventJoypadButton = InputEventJoypadButton.new()
		b.device = -1
		b.button_index = PAD_BUTTONS[action]
		InputMap.action_add_event(action, b)
	if PAD_AXES.has(action):
		var m: InputEventJoypadMotion = InputEventJoypadMotion.new()
		m.device = -1
		m.axis = PAD_AXES[action][0]
		m.axis_value = PAD_AXES[action][1]
		InputMap.action_add_event(action, m)


## 当前是否有手柄连接（HUD 提示据此显示手柄按键）。
static func pad_connected() -> bool:
	return not Input.get_connected_joypads().is_empty()


static func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


static func _set_volume(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))


## 每个动作的主键由设置决定；project.godot 里的其他键（方向键等）保留。
static func _apply_keys(keys: Dictionary) -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var old: InputEventKey = _applied_keys.get(action)
		if old != null:
			InputMap.action_erase_event(action, old)
		else:
			# 第一次应用：去掉 project.godot 里与默认主键相同的那一个，避免重复；并加上手柄绑定（固定，不参与改键）
			for ev: InputEvent in InputMap.action_get_events(action):
				if ev is InputEventKey and (ev as InputEventKey).physical_keycode == int(DEFAULT_KEYS[action]):
					InputMap.action_erase_event(action, ev)
			_add_pad_events(action)
		var e: InputEventKey = InputEventKey.new()
		e.physical_keycode = int(keys.get(action, DEFAULT_KEYS[action])) as Key
		InputMap.action_add_event(action, e)
		_applied_keys[action] = e
