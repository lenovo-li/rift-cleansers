class_name LicensesPanel extends Control
## 「关于与许可证」浮层：游戏版本、Godot 引擎版权与许可证、third_party_licenses/*.yaml 登记的素材、各许可证全文。
## 许可证文件随导出打包（export_presets.cfg 的 include_filter）。

const YAML_DIR: String = "res://third_party_licenses"
## 附带全文的许可证文件 [标题, 路径]
const FULL_TEXTS: Array = [
	["Fusion Pixel Font（OFL-1.1）", "res://third_party_licenses/fusion_pixel_font/OFL.txt"],
	["Ark Pixel Font（OFL-1.1）", "res://third_party_licenses/fusion_pixel_font/ark-pixel/OFL.txt"],
	["Cubic 11（OFL-1.1）", "res://third_party_licenses/fusion_pixel_font/cubic-11/OFL.txt"],
	["Galmuri", "res://third_party_licenses/fusion_pixel_font/galmuri/LICENSE.txt"],
	["webrtc-native", "res://addons/webrtc_native/LICENSE.webrtc-native"],
	["libdatachannel", "res://addons/webrtc_native/LICENSE.libdatachannel"],
	["libjuice", "res://addons/webrtc_native/LICENSE.libjuice"],
	["libsrtp", "res://addons/webrtc_native/LICENSE.libsrtp"],
	["mbedtls", "res://addons/webrtc_native/LICENSE.mbedtls"],
	["usrsctp", "res://addons/webrtc_native/LICENSE.usrsctp"],
	["plog", "res://addons/webrtc_native/LICENSE.plog"],
]
const YAML_FIELDS: Array = [["author", "作者"], ["license", "许可证"], ["source_url", "来源"]]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 160
	box.offset_right = -160
	box.offset_top = 60
	box.offset_bottom = -40
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var title: Label = Label.new()
	title.text = "关于与许可证"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)
	var text: RichTextLabel = RichTextLabel.new()
	text.bbcode_enabled = false
	text.selection_enabled = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 16)
	text.text = build_text()
	box.add_child(text)
	var close_btn: Button = Button.new()
	close_btn.text = "返回"
	close_btn.custom_minimum_size = Vector2(180, 44)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(queue_free)
	box.add_child(close_btn)
	close_btn.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


static func build_text() -> String:
	var out: PackedStringArray = []
	out.append("裂界清扫者 %s" % ProjectSettings.get_setting("application/config/version", "0"))
	out.append("游戏代码、模型、音乐为原创。以下为使用的引擎与第三方资源。")
	out.append("")
	var info: Dictionary = Engine.get_version_info()
	out.append("== Godot Engine %s ==" % info.get("string", ""))
	out.append("本游戏使用 Godot Engine 制作（https://godotengine.org）。")
	out.append(Engine.get_license_text())  # 已含版权行
	out.append("")
	out.append("== 第三方资源 ==")
	for file_name: String in _yaml_files():
		var fields: Dictionary = parse_yaml_fields(FileAccess.get_file_as_string("%s/%s" % [YAML_DIR, file_name]))
		if fields.is_empty():
			continue
		out.append("· %s" % fields.get("asset_name", file_name))
		for pair: Array in YAML_FIELDS:
			if fields.has(pair[0]):
				out.append("    %s：%s" % [pair[1], fields[pair[0]]])
	for pair: Array in FULL_TEXTS:
		var body: String = FileAccess.get_file_as_string(pair[1])
		if body.is_empty():
			continue
		out.append("")
		out.append("== %s ==" % pair[0])
		out.append(body.strip_edges())
	return "\n".join(out)


static func _yaml_files() -> PackedStringArray:
	var files: PackedStringArray = []
	for f: String in DirAccess.get_files_at(YAML_DIR):
		if f.ends_with(".yaml"):
			files.append(f)
	files.sort()
	return files


## 只取顶层的「键: 值」单行字段（登记文件格式固定，不需要完整的 YAML 解析）。
static func parse_yaml_fields(text: String) -> Dictionary:
	var out: Dictionary = {}
	for line: String in text.split("\n"):
		if line.begins_with(" ") or line.begins_with("-") or not line.contains(":"):
			continue
		var idx: int = line.find(":")
		var value: String = line.substr(idx + 1).strip_edges()
		if not value.is_empty() and value != "|":
			out[line.substr(0, idx).strip_edges()] = value
	return out