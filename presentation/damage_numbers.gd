class_name DamageNumbers extends RefCounted
## 飘字：Label3D 池（上限 60），上浮 + 淡出。大伤害更大更黄，燃烧橙色，玩家受伤红色。
## 主机/单人在 Enemy.take_damage 里调用；联机客户端根据快照血量下降估算后调用。

const POOL_SIZE: int = 60
const LIFE: float = 0.7
const BIG_DAMAGE: float = 50.0

enum Kind { NORMAL, BIG, BURN, PLAYER }
const COLORS: Array[Color] = [Color(1, 1, 1), Color(1.0, 0.85, 0.2), Color(1.0, 0.55, 0.15), Color(1.0, 0.3, 0.3)]
const SIZES: Array[int] = [56, 84, 48, 72]

static var _pool: Array[Label3D] = []
static var _next: int = 0
static var _host: Node = null
## 设置界面开关（默认开）。
static var enabled: bool = true


static func spawn(parent: Node, pos: Vector3, amount: float, kind: int = -1) -> void:
	if not enabled or parent == null or not parent.is_inside_tree() or amount < 0.5:
		return
	if DisplayServer.get_name() == "headless":
		return
	if kind < 0:
		kind = Kind.BIG if amount >= BIG_DAMAGE else Kind.NORMAL
	var label: Label3D = _acquire(parent)
	label.text = str(roundi(amount))
	label.modulate = COLORS[kind]
	label.font_size = SIZES[kind]
	label.outline_size = 12
	var jitter: Vector3 = Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.3, 0.3))
	label.global_position = pos + Vector3(0, 2.2, 0) + jitter
	label.visible = true
	label.scale = Vector3.ONE * (1.4 if kind == Kind.BIG else 1.0)
	var tw: Tween = label.create_tween().set_parallel(true)
	tw.tween_property(label, "global_position:y", label.global_position.y + 1.6, LIFE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(label, "scale", Vector3.ONE, 0.15)
	tw.tween_property(label, "modulate:a", 0.0, LIFE * 0.5).set_delay(LIFE * 0.5)
	tw.chain().tween_callback(func() -> void: label.visible = false)


static func _acquire(parent: Node) -> Label3D:
	var host: Node = parent.get_tree().current_scene if parent.get_tree().current_scene else parent
	if _host != host or not is_instance_valid(_host):
		_host = host
		_pool.clear()
		_next = 0
	if _pool.size() < POOL_SIZE:
		var l: Label3D = Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = false
		l.pixel_size = 0.01
		l.outline_modulate = Color(0, 0, 0, 0.85)
		l.render_priority = 10
		_host.add_child(l)
		_pool.append(l)
		return l
	# 池满：复用最早的一个（中断它的动画）
	var reuse: Label3D = _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	return reuse
