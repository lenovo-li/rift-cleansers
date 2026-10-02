class_name GameCursor extends RefCounted
## 游戏内鼠标光标：战斗中是十字准星（瞄准陨石落点等），打开任何界面时恢复系统箭头。
## 游戏场景每帧调用 set_combat(没有界面打开)；只在状态变化时才真正切换。

const SIZE: int = 32

static var _crosshair: ImageTexture = null
static var _combat: bool = false


static func set_combat(on: bool) -> void:
	if on == _combat:
		return
	_combat = on
	if on:
		if _crosshair == null:
			_crosshair = _build()
		Input.set_custom_mouse_cursor(_crosshair, Input.CURSOR_ARROW, Vector2(SIZE, SIZE) * 0.5)
	else:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)


static func is_combat() -> bool:
	return _combat


## 程序化画准星：外圈 + 四段短线 + 中心点，白色带黑描边，暖色调和陨石呼应。
static func _build() -> ImageTexture:
	var img: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: Vector2 = Vector2(SIZE, SIZE) * 0.5 - Vector2(0.5, 0.5)
	var fill: Color = Color(1.0, 0.92, 0.75)
	for y in SIZE:
		for x in SIZE:
			var p: Vector2 = Vector2(x, y) - c
			var d: float = p.length()
			var ring: bool = absf(d - 10.0) < 1.0
			var tick: bool = (absf(p.x) < 1.0 and absf(p.y) > 4.0 and absf(p.y) < 15.0) \
					or (absf(p.y) < 1.0 and absf(p.x) > 4.0 and absf(p.x) < 15.0)
			var dot: bool = d < 1.6
			if ring or tick or dot:
				img.set_pixel(x, y, fill)
	# 黑色描边：透明像素邻接到亮像素就涂黑
	var out: Image = img.duplicate() as Image
	for y in SIZE:
		for x in SIZE:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + o
				if q.x >= 0 and q.y >= 0 and q.x < SIZE and q.y < SIZE and img.get_pixelv(q).a > 0.0:
					out.set_pixel(x, y, Color(0, 0, 0, 0.85))
					break
	return ImageTexture.create_from_image(out)
