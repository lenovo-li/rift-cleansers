class_name TalentPanel extends Control
## 天赋树浮层（主菜单）：显示当前角色的 7 个天赋、等级、下一级花费，点击升级；可重置返还全部碎片。
## 顶部可切换角色；关闭时发出 closed。

signal closed

var char_id: String = CharacterCatalog.DEFAULT_ID
var _list: VBoxContainer
var _header: Label


static func build(p_char_id: String) -> TalentPanel:
	var panel: TalentPanel = TalentPanel.new()
	panel.char_id = p_char_id
	return panel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box: VBoxContainer = VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -360
	box.offset_right = 360
	box.offset_top = -330
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_header = Label.new()
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.add_theme_font_size_override("font_size", 26)
	box.add_child(_header)
	var chars: HBoxContainer = HBoxContainer.new()
	chars.alignment = BoxContainer.ALIGNMENT_CENTER
	chars.add_theme_constant_override("separation", 8)
	box.add_child(chars)
	for id: String in CharacterCatalog.ids():
		var b: Button = Button.new()
		b.text = CharacterCatalog.get_def(id).name
		b.custom_minimum_size = Vector2(110, 36)
		b.pressed.connect(func() -> void:
			char_id = id
			_refresh())
		chars.add_child(b)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	box.add_child(_list)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 16)
	box.add_child(bottom)
	var reset: Button = Button.new()
	reset.text = "重置（返还碎片）"
	reset.custom_minimum_size = Vector2(200, 44)
	reset.pressed.connect(func() -> void:
		Talents.refund(char_id)
		_refresh())
	bottom.add_child(reset)
	var back: Button = Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(160, 44)
	back.pressed.connect(func() -> void:
		closed.emit()
		queue_free())
	bottom.add_child(back)
	_refresh()


func _refresh() -> void:
	_header.text = "天赋 · %s    碎片 %d" % [CharacterCatalog.get_def(char_id).name, SaveData.shards()]
	for c: Node in _list.get_children():
		c.queue_free()
	var ranks: Dictionary = Talents.ranks(char_id)
	var tree: Dictionary = Talents.tree(char_id)
	for id: String in tree:
		var t: Dictionary = tree[id]
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_list.add_child(row)
		var label: Label = Label.new()
		var r: int = Talents.rank_of(ranks, id)
		label.text = "%s%s  %d/%d    %s" % ["★ " if Talents.SIGNATURE.has(char_id) and Talents.SIGNATURE[char_id].id == id else "",
				t.name, r, int(t.max), t.desc]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 18)
		row.add_child(label)
		var cost: int = Talents.next_cost(char_id, id)
		var buy: Button = Button.new()
		buy.custom_minimum_size = Vector2(150, 36)
		buy.text = "已满级" if cost < 0 else "升级（%d）" % cost
		buy.disabled = cost < 0 or SaveData.shards() < cost
		buy.pressed.connect(func() -> void:
			Talents.buy(char_id, id)
			_refresh())
		row.add_child(buy)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()
