extends Control
## 灰盒 HUD：生命/护盾/怒气/经验条、时间、技能栏（冷却）、装备与被动列表、Boss 血条、提示消息。
## 全部用代码搭建，数据每帧从玩家、会话、生成器读取。

const SKILL_KEYS: Array[String] = ["空格", "Q", "E", "R", "F", "C"]
const BAR_WIDTH: float = 360.0

var player: Node = null
var session: GameSession = null
var spawner: Node = null

var _hp_bar: ProgressBar
var _shield_label: Label
var _rage_bar: ProgressBar
var _exp_bar: ProgressBar
var _info_label: Label
var _items_label: Label
var _skill_panels: Array[Dictionary] = []
var _boss_box: VBoxContainer
var _boss_bar: ProgressBar
var _boss_label: Label
var _toast: Label
var _toast_time: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top_left: VBoxContainer = VBoxContainer.new()
	top_left.position = Vector2(16, 16)
	top_left.add_theme_constant_override("separation", 4)
	add_child(top_left)
	_hp_bar = _bar(top_left, Color(0.85, 0.2, 0.2))
	_shield_label = _label(top_left, 16)
	_rage_bar = _bar(top_left, Color(1.0, 0.55, 0.1), 10.0)
	_exp_bar = _bar(top_left, Color(0.3, 0.6, 1.0), 10.0)
	_info_label = _label(top_left, 18)

	_items_label = _label(self, 16)
	_place(_items_label, Vector4(1, 0, 1, 0), Vector4(-300, 16, -16, 416))
	_items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_build_skill_bar()
	_build_boss_bar()

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
	for i in SkillFactory.SKILL_IDS.size():
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
		key.text = "[%s]" % SKILL_KEYS[i]
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


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time / 0.5, 0.0, 1.0)
	if player == null or session == null:
		return
	var stats: CharacterStats = player.stats
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
	_info_label.text = "Lv%d   %d:%02d   击杀 %d   闪避[Shift] %s%s" % [level, int(t / 60.0), int(t) % 60,
			spawner.kills if spawner else 0, dodge, "   [自动施放]" if player.auto_cast else ""]
	_update_skills()
	_update_items(stats)
	_update_boss()


func _update_skills() -> void:
	var abilities: AbilitySystem = player.ability_system
	for i in SkillFactory.SKILL_IDS.size():
		var id: String = SkillFactory.SKILL_IDS[i]
		var p: Dictionary = _skill_panels[i]
		var skill: Skill = abilities.get_skill(id)
		if skill == null:
			p.name.text = "%s\n未习得" % SkillFactory.display_name(id)
			p.panel.modulate = Color(1, 1, 1, 0.35)
			p.cd.value = 0.0
			continue
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
			lines.append("%s" % ItemCatalog.equipment_name(id))
	if not stats.passives.is_empty():
		lines.append("被动")
		for id: String in stats.passives:
			lines.append("%s" % ItemCatalog.passive_name(id))
	lines.append("")
	lines.append("FPS %d   敌人 %d" % [Engine.get_frames_per_second(), spawner.get_enemy_count() if spawner else 0])
	_items_label.text = "\n".join(lines)


func _update_boss() -> void:
	var boss: Boss = spawner.boss if spawner else null
	_boss_box.visible = boss != null and is_instance_valid(boss) and boss.is_alive
	if _boss_box.visible:
		_boss_label.text = "%s  阶段 %d" % [boss.get_display_name(), boss.phase]
		_boss_bar.max_value = boss.max_health
		_boss_bar.value = boss.current_health
