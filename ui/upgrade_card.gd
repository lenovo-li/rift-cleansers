extends PanelContainer
## 升级三选一的单张卡牌：按键号、类型标签、圆形徽记（名称首字）、标题、描述。
## 颜色按选项类型区分；进化档位（★）用金色边框。悬浮放大、按下缩小。
## 子节点都是代码创建的（没有 owner），所以用成员变量引用，不能用 find_child。

signal clicked

const CARD_SIZE: Vector2 = Vector2(280, 360)
const TYPE_INFO: Dictionary = {
	"skill_new": ["新技能", Color(0.35, 0.75, 1.0)],
	"skill_up": ["技能升级", Color(0.45, 0.6, 1.0)],
	"passive": ["被动", Color(0.75, 0.45, 1.0)],
	"heal": ["治疗", Color(0.35, 0.9, 0.5)],
}
const EVOLVE_COLOR: Color = Color(1.0, 0.8, 0.3)

var _style: StyleBoxFlat
var _key: Label
var _badge: Label
var _icon_style: StyleBoxFlat
var _icon_text: Label
var _title: Label
var _desc: Label
var _hover: bool = false
var _pressed: bool = false


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	pivot_offset = CARD_SIZE * 0.5
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.09, 0.1, 0.14, 0.96)
	_style.set_corner_radius_all(12)
	_style.set_border_width_all(3)
	_style.shadow_color = Color(0, 0, 0, 0.5)
	_style.shadow_size = 10
	_style.content_margin_left = 18
	_style.content_margin_right = 18
	_style.content_margin_top = 14
	_style.content_margin_bottom = 18
	add_theme_stylebox_override("panel", _style)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)
	_key = _label(top, 28, Color(1.0, 0.85, 0.4))
	_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_badge = _label(top, 16, Color.WHITE)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# 圆形徽记
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(center)
	var icon: PanelContainer = PanelContainer.new()
	icon.custom_minimum_size = Vector2(96, 96)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_style = StyleBoxFlat.new()
	_icon_style.set_corner_radius_all(48)
	_icon_style.set_border_width_all(3)
	icon.add_theme_stylebox_override("panel", _icon_style)
	center.add_child(icon)
	_icon_text = _label(icon, 44, Color.WHITE)
	_icon_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title = _label(box, 24, Color(0.95, 0.97, 1.0))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var line: ColorRect = ColorRect.new()
	line.custom_minimum_size = Vector2(0, 2)
	line.color = Color(1, 1, 1, 0.15)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)
	_desc = _label(box, 18, Color(0.82, 0.86, 0.92))
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## 填入选项（UpgradeSystem 的 {type, id, title, desc}）；index 从 0 开始。
func set_choice(choice: Dictionary, index: int) -> void:
	var type: String = choice.get("type", "")
	var info: Array = TYPE_INFO.get(type, ["", Color(0.5, 0.6, 0.8)])
	var desc: String = choice.get("desc", "")
	var evolve: bool = desc.begins_with("★")
	var color: Color = EVOLVE_COLOR if evolve else info[1]
	_key.text = str(index + 1)
	_badge.text = "进化！" if evolve else info[0]
	_badge.add_theme_color_override("font_color", color)
	# 类型已由标签说明，标题去掉「新技能：」「被动：」前缀
	var title: String = choice.get("title", "")
	for prefix: String in ["新技能：", "被动："]:
		title = title.trim_prefix(prefix)
	_title.text = title
	_desc.text = desc
	_icon_text.text = "+" if type == "heal" else _glyph(choice)
	_icon_style.bg_color = color.darkened(0.55)
	_icon_style.border_color = color
	_style.border_color = color
	_style.bg_color = Color(0.09, 0.1, 0.14, 0.96).lerp(color.darkened(0.7), 0.25)
	_hover = false
	_pressed = false


## 徽记文字：技能 / 被动名称的第一个字。
static func _glyph(choice: Dictionary) -> String:
	var id: String = choice.get("id", "")
	var name: String = ItemCatalog.passive_name(id) if choice.get("type", "") == "passive" else SkillFactory.display_name(id)
	return name.substr(0, 1) if not name.is_empty() else "?"


func _process(delta: float) -> void:
	var target: float = (1.07 if _hover else 1.0) * (0.95 if _pressed else 1.0)
	scale = scale.lerp(Vector2.ONE * target, clampf(delta * 14.0, 0.0, 1.0))
	_style.shadow_size = 18 if _hover else 10


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_pressed = true
	elif _pressed:
		_pressed = false
		if _hover:
			clicked.emit()
	accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hover = true
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = false
		_pressed = false
