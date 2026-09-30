class_name UiTheme extends RefCounted
## 全局 UI 主题：main_theme.tres（九宫格按钮/面板）+ Fusion Pixel 12px 中文像素字体。
## 像素字体需要关闭抗锯齿和微调才清晰；.import 文件不进版本库，所以在这里用代码设置，不依赖导入选项。

const THEME_PATH: String = "res://assets/ui/main_theme.tres"

static var _theme: Theme = null


static func get_theme() -> Theme:
	if _theme == null:
		_theme = load(THEME_PATH) as Theme
		var font: FontFile = _theme.default_font as FontFile
		if font != null:
			font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			font.hinting = TextServer.HINTING_NONE
			font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			font.multichannel_signed_distance_field = false
			font.allow_system_fallback = true  # 字库里没有的字（极少数生僻字、表情）退回系统字体
	return _theme


## 设为根窗口主题：之后所有 Control（菜单、HUD、面板）默认都用它。
static func install(tree: SceneTree) -> void:
	tree.root.theme = get_theme()
