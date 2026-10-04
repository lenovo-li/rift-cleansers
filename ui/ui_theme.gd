class_name UiTheme extends RefCounted
## 全局 UI 主题：main_theme.tres（九宫格按钮/面板）+ Fusion Pixel 12px 中文像素字体。
## 像素字体需要关闭抗锯齿和微调才清晰；.import 文件不进版本库，所以在这里用代码设置，不依赖导入选项。

const THEME_PATH: String = "res://assets/ui/main_theme.tres"

static var _theme: Theme = null
static var _sound_hook_installed: bool = false


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
## 同时全局监听按钮添加，自动连接点击音效（只安装一次）。
static func install(tree: SceneTree) -> void:
	tree.root.theme = get_theme()
	# 全局按钮点击音效：只安装一次，避免重复连接
	if not _sound_hook_installed:
		_sound_hook_installed = true
		tree.node_added.connect(func(node: Node) -> void:
			var btn: BaseButton = node as BaseButton
			if btn != null and not btn.has_meta("_ui_sound_connected"):
				btn.set_meta("_ui_sound_connected", true)
				# 立即播放（不用 deferred：按下后面板可能马上被释放）
				btn.pressed.connect(func() -> void:
					# 跳过自己处理音效的按钮（如升级面板的刷新按钮）
					if is_instance_valid(btn) and not btn.has_meta("no_auto_sound"):
						SfxManager.play(btn, "ui_click"))
		)



## 手柄导航：让 root 下第一个可用的按钮获得焦点（之后十字键 / 摇杆移动焦点，A 确认）。
## 用 call_deferred 调用，等面板加进场景树、布局完成后再抓焦点。
static func focus_first(root: Node) -> void:
	if root == null or not root.is_inside_tree():
		return
	for n: Node in root.find_children("*", "BaseButton", true, false):
		var b: BaseButton = n as BaseButton
		if b.is_visible_in_tree() and not b.disabled and b.focus_mode != Control.FOCUS_NONE:
			b.grab_focus()
			return
