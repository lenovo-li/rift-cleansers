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

static var _applied_keys: Dictionary = {}  # 动作 -> 当前由设置写入的 InputEventKey（改键时只替换这一个）


static func defaults() -> Dictionary:
	var keys: Dictionary = {}
	for a: String in DEFAULT_KEYS:
		keys[a] = int(DEFAULT_KEYS[a])
	return {"master": 1.0, "music": 0.8, "sfx": 1.0, "damage_numbers": true, "screen_shake": true, "keys": keys}


## 当前设置（缺的字段补默认值）。
static func data() -> Dictionary:
	var save: Dictionary = SaveData.data()
	var s: Dictionary = save.get("settings", {})
	var d: Dictionary = defaults()
	for k: String in d:
		if not s.has(k) or typeof(s[k]) != typeof(d[k]):
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
			# 第一次应用：去掉 project.godot 里与默认主键相同的那一个，避免重复
			for ev: InputEvent in InputMap.action_get_events(action):
				if ev is InputEventKey and (ev as InputEventKey).physical_keycode == int(DEFAULT_KEYS[action]):
					InputMap.action_erase_event(action, ev)
		var e: InputEventKey = InputEventKey.new()
		e.physical_keycode = int(keys.get(action, DEFAULT_KEYS[action])) as Key
		InputMap.action_add_event(action, e)
		_applied_keys[action] = e
