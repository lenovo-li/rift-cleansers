extends Control
## 灰盒 HUD：生命/护盾/怒气/经验条、时间、技能栏（冷却）、装备与被动列表、Boss 血条、提示消息。
## 全部用代码搭建，数据每帧从玩家、会话、生成器读取。

const SKILL_KEYS: Array[String] = ["空格", "Q", "E", "R", "F", "C"]  # 默认键（技能栏数量）；显示用 key_label()


## 技能栏第 i 格当前绑定的按键名（设置里可改键）。
static func key_label(i: int) -> String:
	if Settings.pad_connected():
		return Settings.PAD_NAMES["skill_%d" % i]
	var code: int = Settings.key_of("skill_%d" % i)
	return "空格" if code == KEY_SPACE else Settings.key_name(code)
const BAR_WIDTH: float = 360.0

var player: Node = null
var session: GameSession = null
var spawner: Node = null
var net: NetSession = null

var _hp_bar: ProgressBar
var _shield_label: Label
var _rage_bar: ProgressBar
var _exp_bar: ProgressBar
var _info_label: Label
var _items_label: RichTextLabel
var _skill_panels: Array[Dictionary] = []
var _boss_box: VBoxContainer
var _boss_bar: ProgressBar
var _boss_label: Label
var _boss_indicator: Control  # Boss 屏幕外箭头指示器
var _boss_indicator_arrow: Polygon2D
var _boss_position: Vector3 = Vector3.ZERO  # 当前 Boss 的位置
var _boss_indicator_time: float = 0.0  # 箭头显示时长（Boss 出现后 10 秒内显示）
const BOSS_INDICATOR_DURATION: float = 10.0
var _toast: Label
var _toast_time: float = 0.0
var _team_label: Label
var _downed_label: Label
var _debug_label: Label
var _vignette: ColorRect
var _vignette_mat: ShaderMaterial
var _hurt_pulse: float = 0.0
var _level_flash: ColorRect


func _ready() -> void:
	UiTheme.install(get_tree())
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 最底层：暗角和升级闪光，不挡其他 HUD
	_vignette = ColorRect.new()
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = preload("res://presentation/shaders/vignette.gdshader")
	_vignette.material = _vignette_mat
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)
	_level_flash = ColorRect.new()
	_level_flash.color = Color(1.0, 0.85, 0.4, 0.0)
	_level_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_level_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_level_flash)
	var top_left: VBoxContainer = VBoxContainer.new()
	top_left.position = Vector2(16, 16)
	top_left.add_theme_constant_override("separation", 4)
	add_child(top_left)
	_hp_bar = _bar(top_left, Color(0.85, 0.2, 0.2))
	_shield_label = _label(top_left, 16)
	_rage_bar = _bar(top_left, Color(1.0, 0.55, 0.1), 10.0)
	_exp_bar = _bar(top_left, Color(0.3, 0.6, 1.0), 10.0)
	_info_label = _label(top_left, 18)

	_items_label = _rich_label(self, 16)
	_place(_items_label, Vector4(1, 0, 1, 0), Vector4(-300, 16, -16, 416))
	_items_label.text = ""

	_build_skill_bar()
	_build_boss_bar()

	_team_label = _label(top_left, 16)
	_downed_label = _label(self, 36)
	_place(_downed_label, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-400, 80, 400, 160))
	_downed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_downed_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	_debug_label = _label(self, 15)
	_place(_debug_label, Vector4(1, 1, 1, 1), Vector4(-460, -260, -16, -16))
	_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_debug_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_debug_label.visible = false

	_toast = _label(self, 30)
	_place(_toast, Vector4(0.5, 0, 0.5, 0), Vector4(-500, 150, 500, 210))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 6)


func _bar(parent: Node, color: Color, height: float = 22.0) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(BAR_WIDTH, height)
	bar.show_percentage = false
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	return bar


func _label(parent: Node, font_size: int) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## 右对齐的富文本标签（装备列表按品质着色）。
func _rich_label(parent: Node, font_size: int) -> RichTextLabel:
	var l: RichTextLabel = RichTextLabel.new()
	l.bbcode_enabled = true
	l.scroll_active = false
	l.add_theme_font_size_override("normal_font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## 显式设置锚点（左、上、右、下）和偏移，不依赖父节点在 _ready 时的尺寸。
static func _place(c: Control, anchors: Vector4, offsets: Vector4) -> void:
	c.anchor_left = anchors.x
	c.anchor_top = anchors.y
	c.anchor_right = anchors.z
	c.anchor_bottom = anchors.w
	c.offset_left = offsets.x
	c.offset_top = offsets.y
	c.offset_right = offsets.z
	c.offset_bottom = offsets.w


## 受伤：暗角脉冲，伤害越大越明显。
func flash_hurt(amount: float) -> void:
	_hurt_pulse = maxf(_hurt_pulse, clampf(amount / 60.0, 0.25, 0.8))


func flash_level_up() -> void:
	_level_flash.color.a = 0.14
	var tw: Tween = _level_flash.create_tween()
	tw.tween_property(_level_flash, "color:a", 0.0, 0.5)


func show_toast(text: String, seconds: float = 2.5) -> void:
	_toast.text = text
	_toast_time = seconds
	_toast.modulate.a = 1.0


func _build_skill_bar() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	_place(row, Vector4(0.5, 1, 0.5, 1), Vector4(-3 * 124, -110, 3 * 124, -16))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for i in SKILL_KEYS.size():  # 每个角色都是 6 个技能
		var panel: PanelContainer = PanelContainer.new()
		panel.custom_minimum_size = Vector2(116, 90)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.1, 0.14, 0.85)
		style.set_border_width_all(2)
		style.border_color = Color(0.4, 0.5, 0.7)
		panel.add_theme_stylebox_override("panel", style)
		row.add_child(panel)
		var box: VBoxContainer = VBoxContainer.new()
		panel.add_child(box)
		var key: Label = _label(box, 14)
		key.text = "[%s]" % key_label(i)
		key.name = "key_label_%d" % i
		var name_label: Label = _label(box, 16)
		var cd: ProgressBar = ProgressBar.new()
		cd.custom_minimum_size = Vector2(100, 8)
		cd.show_percentage = false
		cd.max_value = 1.0
		box.add_child(cd)
		_skill_panels.append({"panel": panel, "style": style, "name": name_label, "cd": cd})


func _build_boss_bar() -> void:
	_boss_box = VBoxContainer.new()
	_place(_boss_box, Vector4(0.5, 0, 0.5, 0), Vector4(-350, 70, 350, 130))
	add_child(_boss_box)
	_boss_label = _label(_boss_box, 20)
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label.custom_minimum_size = Vector2(700, 0)
	_boss_bar = _bar(_boss_box, Color(0.7, 0.05, 0.15), 18.0)
	_boss_bar.custom_minimum_size = Vector2(700, 18)
	_boss_box.visible = false

	# Boss 屏幕外箭头指示器
	_boss_indicator = Control.new()
	_boss_indicator.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boss_indicator)
	_boss_indicator_arrow = Polygon2D.new()
	_boss_indicator_arrow.polygon = PackedVector2Array([Vector2(-20, -30), Vector2(20, -30), Vector2(0, 0)])
	_boss_indicator_arrow.color = Color(0.9, 0.1, 0.2, 0.85)
	_boss_indicator.add_child(_boss_indicator_arrow)
	_boss_indicator.visible = false


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time / 0.5, 0.0, 1.0)
	if player == null or session == null:
		return

	# Boss 箭头指示器倒计时
	if _boss_indicator_time > 0.0:
		_boss_indicator_time -= delta

	# 鼠标光标：瞄准模式显示准星，否则显示箭头
	if player.mouse_aim_active:
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	var stats: CharacterStats = player.stats
	# 低于 35% 生命时常驻暗角，越低越重；受伤脉冲叠加
	var low: float = clampf((0.35 - stats.health_ratio()) / 0.35, 0.0, 1.0) * 0.75
	_hurt_pulse = maxf(0.0, _hurt_pulse - delta * 2.5)
	_vignette_mat.set_shader_parameter("intensity", maxf(low, _hurt_pulse))
	_hp_bar.max_value = stats.max_health
	_hp_bar.value = stats.health
	_shield_label.text = "生命 %d/%d   护盾 %d   怒气 %d%s" % [stats.health, stats.max_health, stats.shield, stats.rage,
			"   [光环 %.1fs]" % stats.aura_remaining if stats.aura_remaining > 0.0 else ""]
	_rage_bar.value = stats.rage
	var level: int = session.get_player_level()
	_exp_bar.max_value = session.get_exp_required(level)
	_exp_bar.value = session.get_player_exp()
	var t: float = session.get_game_time()
	var dodge: String = "就绪" if player.dodge_cooldown_remaining <= 0.0 else "%.1fs" % player.dodge_cooldown_remaining
	_info_label.text = "Lv%d   %d:%02d   击杀 %d   闪避[%s] %s%s" % [level, int(t / 60.0), int(t) % 60,
			spawner.kills if spawner else 0, Settings.key_name(Settings.key_of("dash")), dodge, "   [自动施放]" if player.auto_cast else ""]
	_update_skills()
	_update_items(stats)
	_update_boss()
	_update_boss_indicator()
	_update_team()
	if _debug_label.visible:
		_debug_label.text = net.debug_text() if net != null else "[单人] F3 调试（联机时显示网络状态）"


func toggle_debug() -> void:
	_debug_label.visible = not _debug_label.visible


## 队友列表 + 自己倒地时的提示。
func _update_team() -> void:
	if player.is_dead:
		var multi: bool = PlayerQuery.all(get_tree()).size() > 1
		_downed_label.text = "你倒下了！" + ("等待队友救援  %d%%" % int(player.revive_progress * 100.0) if multi else "")
	else:
		_downed_label.text = ""
	var lines: PackedStringArray = []
	for p: Node in get_tree().get_nodes_in_group("players"):
		if p == player:
			continue
		var state: String = "倒地 %d%%" % int(p.revive_progress * 100.0) if p.is_dead else "%d/%d" % [p.stats.health, p.stats.max_health]
		lines.append("%s  %s%s" % [p.display_name, state, "  [AI]" if p.ai_controlled else ""])
	_team_label.text = "\n".join(lines)


func _update_skills() -> void:
	# 刷新按键标签（设置里改键后会变）
	for i in _skill_panels.size():
		var label: Label = _skill_panels[i].panel.find_child("key_label_%d" % i, false, false) as Label
		if label != null:
			label.text = "[%s]" % key_label(i)
	var abilities: AbilitySystem = player.ability_system
	for i in _skill_panels.size():
		var id: String = abilities.slot_id(i)
		var p: Dictionary = _skill_panels[i]
		var skill: Skill = abilities.get_skill(id) if not id.is_empty() else null
		if skill == null:
			p.name.text = "空栏位"
			p.panel.modulate = Color(1, 1, 1, 0.35)
			p.cd.value = 0.0
			p.style.border_color = Color(0.3, 0.3, 0.4)
			continue
		var elem: String = Elements.of(id)
		p.style.bg_color = Color(Elements.color(elem), 0.18) if not elem.is_empty() else Color(0.1, 0.1, 0.14, 0.8)
		p.panel.modulate = Color.WHITE
		var remaining: float = abilities.get_cooldown_remaining(id)
		p.name.text = "%s\nLv%d%s" % [skill.display_name, skill.level, "" if remaining <= 0.0 else "  %.1f" % remaining]
		p.cd.value = 1.0 - remaining / skill.get_cooldown()
		p.style.border_color = Color(0.5, 0.9, 1.0) if remaining <= 0.0 else Color(0.3, 0.3, 0.4)


func _update_items(stats: CharacterStats) -> void:
	var lines: PackedStringArray = []
	if not stats.equipment.is_empty():
		lines.append("装备")
		for id: String in stats.equipment:
			var q: int = stats.equipment_quality(id)
			var enh: int = stats.equipment_enhance_level(id)
			var name: String = ItemCatalog.equipment_name(id)
			var suffix: String = " +%d" % enh if enh > 0 else ""
			lines.append("[color=#%s]%s%s[/color]" % [EquipmentQuality.color(q).to_html(false), name, suffix])
	if not stats.passives.is_empty():
		lines.append("被动")
		for id: String in stats.passives:
			lines.append("%s" % ItemCatalog.passive_name(id))
	lines.append("")
	lines.append("FPS %d   敌人 %d" % [Engine.get_frames_per_second(), spawner.get_enemy_count() if spawner else 0])
	var text: String = "[right]%s[/right]" % "\n".join(lines)
	if _items_label.text != text:  # 避免每帧重新解析 BBCode
		_items_label.text = text


func _update_boss() -> void:
	var info: Dictionary = spawner.get_boss_info() if spawner else {}
	_boss_box.visible = not info.is_empty()
	if _boss_box.visible:
		_boss_label.text = "%s  阶段 %d" % [info.name, info.phase]
		_boss_bar.max_value = info.max_hp
		_boss_bar.value = info.hp
		# 更新 Boss 位置
		if info.has("pos"):
			_boss_position = info.pos
	else:
		_boss_position = Vector3.ZERO


## Boss 屏幕外箭头指示器：Boss 出现后 10 秒内，如果 Boss 不在屏幕内，在屏幕边缘显示指向 Boss 的箭头
func _update_boss_indicator() -> void:
	if _boss_position == Vector3.ZERO or _boss_indicator_time <= 0.0:
		_boss_indicator.visible = false
		return

	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		_boss_indicator.visible = false
		return

	var screen_pos: Vector2 = cam.unproject_position(_boss_position)
	var viewport_size: Vector2 = get_viewport_rect().size

	# 检查 Boss 是否在屏幕内
	var margin: float = 100.0
	var in_screen: bool = screen_pos.x > -margin and screen_pos.x < viewport_size.x + margin \
						and screen_pos.y > -margin and screen_pos.y < viewport_size.y + margin

	# 检查 Boss 是否在镜头后方
	var cam_to_boss: Vector3 = _boss_position - cam.global_position
	var is_behind: bool = cam_to_boss.dot(-cam.global_transform.basis.z) < 0.0

	if in_screen and not is_behind:
		_boss_indicator.visible = false
		return

	# Boss 在屏幕外，显示箭头
	_boss_indicator.visible = true

	# 计算箭头位置：屏幕中心到 Boss 的方向，限制在屏幕边缘
	var center: Vector2 = viewport_size * 0.5
	var direction: Vector2 = (screen_pos - center).normalized()
	var edge_margin: float = 60.0

	# 计算箭头在屏幕边缘的位置
	var t_x: float = INF
	var t_y: float = INF

	if abs(direction.x) > 0.001:
		t_x = ((viewport_size.x - edge_margin if direction.x > 0 else edge_margin) - center.x) / direction.x

	if abs(direction.y) > 0.001:
		t_y = ((viewport_size.y - edge_margin if direction.y > 0 else edge_margin) - center.y) / direction.y

	var t: float = min(t_x, t_y)
	var arrow_pos: Vector2 = center + direction * t

	# 设置箭头位置和旋转
	_boss_indicator_arrow.position = arrow_pos
	_boss_indicator_arrow.rotation = direction.angle() - PI * 0.5  # 箭头尖默认朝 +y，转到朝外指向 Boss


## Boss 出现时调用，重置箭头计时
func on_boss_spawned() -> void:
	_boss_indicator_time = BOSS_INDICATOR_DURATION
