class_name SkillVfx extends RefCounted
## 技能视觉特效助手

const CONE_COLOR: Color = Color(0.3, 0.6, 1.0, 0.4)
const WHIRL_COLOR: Color = Color(0.3, 1.0, 0.4, 0.3)
const FLAME_COLOR: Color = Color(1.0, 0.35, 0.05, 0.4)

## 联机：主机设置后，每次调用特效都会把参数交给 recorder(event: Array)，由 NetSession 转发给客户端回放。
static var recorder: Callable = Callable()


## 为 true 时 record 不录制：特效内部调用其他已录制特效（如飞行物落地的冲击波）时用，
## 客户端回放外层事件时会自己播放内层效果，避免重复。
static var _mute: bool = false


static func record(event: Array) -> void:
	if recorder.is_valid() and not _mute:
		recorder.call(event)


## 每帧驱动一个特效根节点：step(elapsed, delta) 返回 false 时提前结束；结束后释放 root。
static func _run(root: Node, duration: float, step: Callable) -> void:
	var elapsed: float = 0.0
	while elapsed < duration and is_instance_valid(root) and root.is_inside_tree():
		await root.get_tree().process_frame
		if not is_instance_valid(root):
			return
		var dt: float = root.get_process_delta_time()
		elapsed += dt
		if not step.call(elapsed, dt):
			break
	if is_instance_valid(root):
		root.queue_free()


## 在 groups 里找离 pos 最近（水平距离）且存活的节点。
static func _resolve(tree: SceneTree, groups: Array, pos: Vector3, max_dist: float = 2.5) -> Node3D:
	var best: Node3D = null
	var best_d: float = max_dist * max_dist
	for g: String in groups:
		for n: Node in tree.get_nodes_in_group(g):
			var n3: Node3D = n as Node3D
			if n3 == null or ("is_alive" in n3 and not n3.is_alive) or ("is_dead" in n3 and n3.is_dead):
				continue
			var d: Vector3 = (n3.global_position - pos) * Vector3(1, 0, 1)
			if d.length_squared() < best_d:
				best_d = d.length_squared()
				best = n3
	return best


static func _player_by_slot(tree: SceneTree, slot: int) -> Node3D:
	for p: Node in tree.get_nodes_in_group("players"):
		if int(p.get("net_slot")) == slot:
			return p as Node3D
	return null


static func _make_material(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat



static func _add_material(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = _make_material(color)
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.no_depth_test = false
	return mat


## 盾击 / 斩击：身前一道月牙刀光从一侧扫到另一侧，地面同时扫过一道淡一些的弧光。
## 盾击、影行者普攻、刀扇（扇形时）共用。
static func shield_bash(parent: Node, origin: Vector3, facing: Vector3, radius: float, color: Color = CONE_COLOR) -> void:
	record(["cone", origin, facing, radius, color])
	if not VfxKit.enabled() or parent == null or not parent.is_inside_tree():
		return
	var root: Node3D = Node3D.new()
	parent.add_child(root)
	root.global_transform = Transform3D(VfxKit.facing_basis(facing), Vector3(origin.x, 0.0, origin.z))
	var tint: Color = Color(color, minf(1.0, color.a * 2.2))
	var arcs: Array[MeshInstance3D] = []
	# 腰部高度、略微倾斜的主刀光（随机左右倾，连续挥砍不会完全一样）
	var high: MeshInstance3D = VfxKit.spawn(root, "SlashArc", "slash", tint)
	if high != null:
		high.transform = Transform3D(Basis(Vector3.FORWARD, randf_range(-0.25, 0.25)).scaled(Vector3.ONE * radius), Vector3(0, 0.9, 0))
		arcs.append(high)
	var low: MeshInstance3D = VfxKit.spawn(root, "SlashArc", "slash", Color(tint, tint.a * 0.45))
	if low != null:
		low.transform = Transform3D(Basis.from_scale(Vector3(radius * 1.1, 1.0, radius * 1.1)), Vector3(0, 0.08, 0))
		arcs.append(low)
	var sweep: Callable = func(v: float) -> void:
		for mi: MeshInstance3D in arcs:
			if is_instance_valid(mi):
				mi.set_instance_shader_parameter("progress", v)
	var tw: Tween = root.create_tween()
	tw.tween_method(sweep, 0.0, 1.0, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(root.queue_free)


## 跟随施法者的持续光环（anchored 区域）。style 与四档进化（tier 1/3/5/8）：
## whirl   旋风带 + 环绕巨剑：3 段巨剑更亮；5 段第三道外圈旋风 + 4 把剑；8 段剑身转为火焰、沿圈喷火
## blades  飞刀环：3 段 8 把；5 段内外两圈反向；8 段刀身血红、沿圈溅火花
## storm   法阵 + 落雷：3 段落雷更密；5 段反向旋转的第二层法阵；8 段落雷变粗并周期性冲击波
## reflect 护罩 + 法阵：3 段格栅护罩；5 段环绕盾纹（对应光环伤害）；8 段 6 面盾纹 + 外圈能量环
static func whirlwind(parent: Node, caster: Node3D, radius: float, duration: float, color: Color = WHIRL_COLOR,
		style: String = "whirl", tier: int = 1) -> void:
	record(["whirl", int(caster.get("net_slot")), radius, duration, color, style, tier])
	if not VfxKit.enabled() or parent == null or not parent.is_inside_tree():
		return
	var root: Node3D = Node3D.new()
	parent.add_child(root)
	root.global_position = Vector3(caster.global_position.x, 0.0, caster.global_position.z)
	var tint: Color = Color(color, 1.0)
	var spin: float = 5.0
	var counter: Array[Node3D] = []  # 反向旋转的子节点
	match style:
		"whirl":
			var rings: int = 3 if tier >= 5 else 2
			for i in rings:
				var sw: MeshInstance3D = VfxKit.spawn(root, "Swirl", "slash",
						Color(Color(1.0, 0.55, 0.2) if tier >= 8 and i == rings - 1 else tint, 0.8 - 0.2 * i))
				if sw != null:
					var s: float = 1.0 - 0.2 * i if i < 2 else 1.18
					sw.transform = Transform3D(Basis(Vector3.UP, PI * i).scaled(Vector3(radius, 1.0 + 0.3 * i, radius) * s),
							Vector3(0, 0.15 + 0.35 * mini(i, 1), 0))
					sw.set_instance_shader_parameter("progress", -1.0)
			var swords: int = 4 if tier >= 5 else 2
			for i in swords:
				var sword: MeshInstance3D = VfxKit.spawn(root, "Greatsword", "solid",
						Color(1.0, 0.6, 0.3) if tier >= 8 else Color(0.9, 1.0, 0.95))
				if sword != null:
					var a: float = TAU * i / swords
					var out: Vector3 = Vector3(sin(a), 0, cos(a))
					# 剑尖朝外、剑身平躺，随根节点旋转扫过一圈
					sword.transform = Transform3D(Basis.looking_at(out, Vector3.UP).scaled(Vector3.ONE * radius * 0.42),
							out * radius * 0.15 + Vector3(0, 0.9, 0))
					sword.set_instance_shader_parameter("glow", 2.2 if tier >= 3 else 1.2)
			spin = 9.0 if tier < 8 else 11.0
		"blades":
			var sw: MeshInstance3D = VfxKit.spawn(root, "Swirl", "slash", Color(tint, 0.5))
			if sw != null:
				sw.transform = Transform3D(Basis.from_scale(Vector3(radius, 0.8, radius)), Vector3(0, 0.3, 0))
				sw.set_instance_shader_parameter("progress", -1.0)
			var blade_tint: Color = Color(1.0, 0.35, 0.4) if tier >= 8 else Color(0.95, 0.9, 1.0)
			var n: int = 8 if tier >= 3 else 6
			for ring in (2 if tier >= 5 else 1):
				var holder: Node3D = root
				if ring == 1:
					holder = Node3D.new()
					root.add_child(holder)
					counter.append(holder)
				for i in n:
					var dagger: MeshInstance3D = VfxKit.spawn(holder, "Dagger", "solid", blade_tint)
					if dagger != null:
						var a: float = TAU * (i + 0.5 * ring) / n
						var out: Vector3 = Vector3(sin(a), 0, cos(a))
						var tangent: Vector3 = Vector3.UP.cross(out) * (1.0 if ring == 0 else -1.0)
						dagger.transform = Transform3D(Basis.looking_at(tangent, Vector3.UP).scaled(Vector3.ONE * 1.3),
								out * radius * (0.8 if ring == 0 else 0.45) + Vector3(0, 1.0 - 0.3 * ring, 0))
						dagger.set_instance_shader_parameter("glow", 1.4 if tier < 8 else 2.4)
			spin = 7.0
		"storm":
			for layer in (2 if tier >= 5 else 1):
				var holder: Node3D = root
				if layer == 1:
					holder = Node3D.new()
					root.add_child(holder)
					counter.append(holder)
				var rune: MeshInstance3D = VfxKit.spawn(holder, VfxKit.decal_mesh(), "decal", Color(tint, 0.9 - 0.3 * layer),
						"rune_circle" if layer == 0 else "glow_ring")
				if rune != null:
					var rr: float = radius * (1.0 if layer == 0 else 0.6)
					rune.transform = Transform3D(Basis.from_scale(Vector3(rr, 1.0, rr)), Vector3(0, 0.06 + 0.02 * layer, 0))
					rune.set_instance_shader_parameter("pulse", 0.25)
			var sw: MeshInstance3D = VfxKit.spawn(root, "Swirl", "slash", Color(tint, 0.35 if tier < 3 else 0.55))
			if sw != null:
				sw.transform = Transform3D(Basis.from_scale(Vector3(radius, 2.2, radius)), Vector3(0, 0.2, 0))
				sw.set_instance_shader_parameter("progress", -1.0)
			spin = 1.2
		"reflect":
			var dome: MeshInstance3D = VfxKit.spawn(root, "Dome", "fresnel", tint)
			if dome != null:
				dome.transform = Transform3D(Basis.from_scale(Vector3(radius, radius * 0.75, radius)), Vector3.ZERO)
			if tier >= 3:
				var lattice: MeshInstance3D = VfxKit.spawn(root, "LatticeDome", "fresnel", Color(tint, 0.9))
				if lattice != null:
					lattice.transform = Transform3D(Basis.from_scale(Vector3(radius, radius * 0.75, radius) * 1.02), Vector3.ZERO)
			var rune: MeshInstance3D = VfxKit.spawn(root, VfxKit.decal_mesh(), "decal", Color(tint, 0.7), "pulse_sigil")
			if rune != null:
				rune.transform = Transform3D(Basis.from_scale(Vector3(radius, 1.0, radius)), Vector3(0, 0.06, 0))
			if tier >= 5:
				var shields: int = 6 if tier >= 8 else 3
				for i in shields:
					var sh: MeshInstance3D = VfxKit.spawn(root, "ShieldRune", "solid", Color(1.0, 0.85, 0.45))
					if sh != null:
						var a: float = TAU * i / shields
						var out: Vector3 = Vector3(sin(a), 0, cos(a))
						sh.transform = Transform3D(Basis.looking_at(-out, Vector3.UP).scaled(Vector3.ONE * 1.4),
								out * radius * 1.05 + Vector3(0, 1.0, 0))
						sh.set_instance_shader_parameter("glow", 1.6)
			if tier >= 8:
				var outer: MeshInstance3D = VfxKit.spawn(root, VfxKit.decal_mesh(), "decal", Color(1.0, 0.55, 0.25, 0.8), "glow_ring")
				if outer != null:
					outer.transform = Transform3D(Basis.from_scale(Vector3(radius, 1, radius) * 1.3), Vector3(0, 0.07, 0))
					outer.set_instance_shader_parameter("pulse", 0.3)
			spin = 0.8 if tier < 5 else 1.6
	var fx_timer: Array[float] = [0.0, 0.0]
	var caster_id: int = caster.get_instance_id()  # 施法者可能中途离开（断线），不直接捕获
	var step: Callable = func(t: float, dt: float) -> bool:
		var cs: Node3D = instance_from_id(caster_id) as Node3D
		if cs == null or not cs.is_inside_tree():
			return false
		root.global_position = Vector3(cs.global_position.x, 0.0, cs.global_position.z)
		root.rotate_y(dt * spin)
		for h: Node3D in counter:
			h.rotate_y(-dt * spin * 2.5)
		var f: float = clampf(t / 0.2, 0.0, 1.0) * clampf((duration - t) / 0.4, 0.0, 1.0)
		for c: Node in root.find_children("*", "GeometryInstance3D", true, false):
			(c as GeometryInstance3D).set_instance_shader_parameter("fade", f)
		fx_timer[0] -= dt
		fx_timer[1] -= dt
		match style:
			"storm":
				if fx_timer[0] <= 0.0:
					fx_timer[0] = randf_range(0.12, 0.3) * (0.6 if tier >= 3 else 1.0)
					var a: float = randf() * TAU
					var p: Vector3 = root.global_position + Vector3(cos(a), 0, sin(a)) * radius * sqrt(randf())
					var bolt: Color = Color(0.85, 0.85, 1.0, 1.0) if tier >= 8 else Color(0.75, 0.8, 1.0, 1.0)
					_arc_impl(parent, p + Vector3(randf_range(-0.8, 0.8), 4.5, randf_range(-0.8, 0.8)), p + Vector3(0, 0.1, 0), bolt, false)
					if tier >= 8:
						_arc_impl(parent, p + Vector3(randf_range(-0.8, 0.8), 4.5, randf_range(-0.8, 0.8)), p + Vector3(0, 0.1, 0), bolt, false)
					ParticleFx.burst(parent, "spark", p + Vector3(0, 0.3, 0), 0.6 if tier < 8 else 0.9, Color(0.7, 0.8, 1.0))
				if tier >= 8 and fx_timer[1] <= 0.0:
					fx_timer[1] = 1.0
					_shockwave_local(parent, root.global_position, radius, Color(0.6, 0.7, 1.0, 0.8), 0.5)
			"whirl":
				if tier >= 8 and fx_timer[0] <= 0.0:
					fx_timer[0] = 0.1
					var a: float = randf() * TAU
					ParticleFx.burst(parent, "fire", root.global_position + Vector3(cos(a), 0.5, sin(a)) * radius * 0.85, 0.4,
							Color(1.0, 0.5, 0.15))
			"blades":
				if tier >= 8 and fx_timer[0] <= 0.0:
					fx_timer[0] = 0.15
					var a: float = randf() * TAU
					ParticleFx.burst(parent, "spark", root.global_position + Vector3(cos(a), 1.0, sin(a)) * radius * 0.8, 0.5,
							Color(1.0, 0.4, 0.45))
			"reflect":
				if tier >= 5 and fx_timer[0] <= 0.0:
					fx_timer[0] = 0.5  # 与光环伤害节奏一致
					_shockwave_local(parent, root.global_position, radius, Color(1.0, 0.8, 0.35, 0.6), 0.4)
		return true
	_run(root, duration, step)


## 不录制的冲击波（持续特效内部周期性播放；客户端回放外层特效时自己播放）。
static func _shockwave_local(parent: Node, center: Vector3, radius: float, color: Color, duration: float) -> void:
	var was: bool = _mute
	_mute = true
	shockwave(parent, center, radius, color, duration)
	_mute = was


## 地面区域（非跟随）。kind：flame 地裂 + 持续火苗；frost 冰刺丛；smoke 烟团；holy 旋转法阵 + 光柱；slam 地裂尘土。
## 线段形区域（盾击 8 段火焰带、火球燃烧线）沿线段铺一条并在线上冒火。
static func ground_zone(parent: Node, a: Vector3, b: Vector3, half_width: float, duration: float, color: Color = FLAME_COLOR,
		kind: String = "") -> void:
	record(["zone", a, b, half_width, duration, color, kind])
	if not VfxKit.enabled() or parent == null or not parent.is_inside_tree():
		return
	var dir: Vector3 = (b - a) * Vector3(1, 0, 1)
	var length: float = dir.length()
	var line: bool = length >= 0.01
	var root: Node3D = Node3D.new()
	parent.add_child(root)
	var mid: Vector3 = (a + b) * 0.5
	root.global_transform = Transform3D(VfxKit.facing_basis(dir) if line else Basis.IDENTITY, Vector3(mid.x, 0.0, mid.z))
	# 底色：淡淡的加色圆盘 / 长条
	var base: MeshInstance3D = MeshInstance3D.new()
	if line:
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(half_width * 2.0, 0.04, length + half_width * 2.0)
		base.mesh = box
	else:
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = half_width
		cyl.bottom_radius = half_width
		cyl.height = 0.04
		cyl.radial_segments = 40
		base.mesh = cyl
	var base_mat: StandardMaterial3D = _add_material(Color(color, color.a * 0.5))
	base.material_override = base_mat
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(base)
	base.position = Vector3(0, 0.04, 0)
	var tint: Color = Color(color, 1.0)
	var decor: Array[Node3D] = []
	if not line:
		match kind:
			"flame", "slam":
				var crack: MeshInstance3D = VfxKit.spawn(root, VfxKit.decal_mesh(), "decal",
						Color(1.0, 0.4, 0.1, 0.5) if kind == "flame" else Color(0.8, 0.55, 0.3, 0.22), "crack")
				if crack != null:
					crack.transform = Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3(half_width, 1, half_width) * 1.1),
							Vector3(0, 0.07, 0))
			"frost":
				var n: int = clampi(int(half_width * 2.5), 5, 12)
				for i in n:
					var sp: MeshInstance3D = VfxKit.spawn(root, "IceSpikes", "solid", Color(0.85, 0.95, 1.0))
					if sp == null:
						continue
					var ang: float = TAU * i / n + randf_range(-0.2, 0.2)
					var r: float = half_width * randf_range(0.35, 0.85)
					var s: float = randf_range(0.5, 0.9)
					sp.transform = Transform3D(Basis(Vector3.UP, randf() * TAU), Vector3(cos(ang), 0, sin(ang)) * r)
					sp.scale = Vector3(s, 0.01, s)
					sp.set_instance_shader_parameter("glow", 0.9)
					sp.create_tween().tween_property(sp, "scale", Vector3(s, s, s), 0.3).set_delay(i * 0.02) \
							.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			"smoke":
				for i in 7:
					var puff: MeshInstance3D = VfxKit.spawn(root, "SmokePuff", "solid", Color(0.75, 0.7, 0.85, 0.75))
					if puff == null:
						continue
					var ang: float = TAU * i / 7.0 + randf_range(-0.3, 0.3)
					var r: float = 0.0 if i == 0 else half_width * randf_range(0.35, 0.8)
					var s: float = randf_range(0.9, 1.4) * (1.3 if i == 0 else 1.0)
					puff.transform = Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * 0.05), Vector3(cos(ang), 0, sin(ang)) * r)
					puff.set_instance_shader_parameter("glow", 0.15)
					puff.create_tween().tween_property(puff, "scale", Vector3.ONE * s, 0.35).set_trans(Tween.TRANS_BACK) \
							.set_ease(Tween.EASE_OUT)
					decor.append(puff)
			"holy":
				var rune: MeshInstance3D = VfxKit.spawn(root, VfxKit.decal_mesh(), "decal", Color(tint, 0.9), "rune_circle")
				if rune != null:
					rune.transform = Transform3D(Basis.from_scale(Vector3(half_width, 1, half_width)), Vector3(0, 0.07, 0))
					decor.append(rune)
				var column: MeshInstance3D = VfxKit.spawn(root, "Beam", "beam", Color(tint, 0.12))
				if column != null:
					column.transform = Transform3D(Basis.from_scale(Vector3(half_width, 5.0, half_width)), Vector3.ZERO)
	var fx_timer: Array[float] = [0.0]
	var step: Callable = func(t: float, dt: float) -> bool:
		var f: float = clampf((duration - t) / minf(0.6, duration * 0.5), 0.0, 1.0)
		base_mat.albedo_color.a = color.a * 0.5 * f
		for c: Node in root.get_children():
			if c is GeometryInstance3D and c != base:
				(c as GeometryInstance3D).set_instance_shader_parameter("fade", f)
		for i in decor.size():
			var d: Node3D = decor[i]
			if is_instance_valid(d):
				d.rotate_y(dt * (0.5 if kind == "holy" else 0.3 * (1 if i % 2 else -1)))
		fx_timer[0] -= dt
		if fx_timer[0] <= 0.0 and f > 0.5:
			var p: Vector3
			if line:
				p = a.lerp(b, randf()) + dir.cross(Vector3.UP).normalized() * randf_range(-half_width, half_width) * 0.6
			else:
				var ang: float = randf() * TAU
				p = Vector3(mid.x, 0, mid.z) + Vector3(cos(ang), 0, sin(ang)) * half_width * sqrt(randf()) * 0.85
			match kind:
				"flame":
					fx_timer[0] = 0.12 if line else 0.18
					ParticleFx.burst(parent, "fire", p + Vector3(0, 0.3, 0), 0.45, Color(1.0, 0.5, 0.15))
				"frost":
					fx_timer[0] = 0.4
					ParticleFx.burst(parent, "shard", p + Vector3(0, 0.4, 0), 0.35, Color(0.7, 0.9, 1.0))
				"smoke":
					fx_timer[0] = 0.3
					ParticleFx.burst(parent, "smoke", p + Vector3(0, 0.6, 0), 0.9, Color(0.4, 0.36, 0.48, 0.6))
				"holy":
					fx_timer[0] = 0.22
					ParticleFx.burst(parent, "star", p + Vector3(0, 0.2, 0), 0.4, Color(1.0, 0.92, 0.55))
				_:
					fx_timer[0] = 999.0
		return true
	_run(root, duration, step)


## 一次性扩散圆盘：从 0 扩到 radius 并淡出（嘲讽、震地、爆燃、碎裂、治疗、爆炸等）。
static func pulse_ring(parent: Node, center: Vector3, radius: float, color: Color, duration: float = 0.35) -> void:
	record(["ring", center, radius, color, duration])
	if not VfxKit.enabled() or parent == null or not parent.is_inside_tree():
		return
	# Blender 渲染的多层能量环贴图，从小扩到 radius
	var mi: MeshInstance3D = VfxKit.decal(parent, "glow_ring", center, radius * 0.1, Color(color, minf(1.0, color.a * 2.0)))
	if mi == null:
		return
	mi.global_position.y = 0.08
	var fade: Callable = func(v: float) -> void: VfxKit.set_fade(mi, v)
	var tween: Tween = mi.create_tween().set_parallel(true)
	tween.tween_property(mi, "scale", Vector3(radius, 1.0, radius), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(fade, 1.0, 0.0, duration).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(mi.queue_free)


## 冲锋拖尾：起点到终点的发光长条，快速淡出。
static func dash_trail(parent: Node, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	record(["trail", a, b, width, color])
	if parent == null or not parent.is_inside_tree() or a.distance_to(b) < 0.1:
		return
	var mi: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(width, 0.05, a.distance_to(b))
	mi.mesh = box
	var mat: StandardMaterial3D = _add_material(color)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var mid: Vector3 = (a + b) * 0.5
	mi.global_transform = Transform3D(VfxKit.aim_basis(b - a), Vector3(mid.x, maxf(mid.y, 0.06), mid.z))
	var tween: Tween = mi.create_tween().set_parallel(true)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.tween_property(mi, "scale", Vector3(0.3, 1.0, 1.0), 0.4)
	tween.chain().tween_callback(mi.queue_free)


## 天降光柱（牧师惩击）：滚动能量的光柱从宽到窄收束，底部闪一下法阵。
static func pillar(parent: Node, pos: Vector3, radius: float, height: float, color: Color) -> void:
	record(["pillar", pos, radius, height, color])
	if parent == null or not parent.is_inside_tree():
		return
	var beam: MeshInstance3D = VfxKit.spawn(parent, "Beam", "beam", Color(color, 1.0))
	if beam == null:
		return
	beam.global_transform = Transform3D(Basis.from_scale(Vector3(radius * 1.6, height * 1.6, radius * 1.6)), Vector3(pos.x, 0.0, pos.z))
	var rune: MeshInstance3D = VfxKit.decal(parent, "rune_circle", pos, radius * 2.5, Color(color, 0.9))
	var tw: Tween = beam.create_tween().set_parallel(true)
	tw.tween_property(beam, "scale", Vector3(radius * 0.25, height * 1.6, radius * 0.25), 0.5).set_ease(Tween.EASE_IN) \
			.set_trans(Tween.TRANS_QUAD)
	tw.tween_method(func(v: float) -> void: VfxKit.set_fade(beam, v), 1.0, 0.0, 0.5).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(beam.queue_free)
	VfxKit.fade_out(rune, 0.6)


# ---------- M3：打击感特效（全部经 record 录制，联机客户端同样回放） ----------

const ShockwaveShader: Shader = preload("res://presentation/shaders/shockwave.gdshader")
const DissolveShader: Shader = preload("res://presentation/shaders/dissolve.gdshader")
const MAX_GHOSTS: int = 40

static var _shock_mat: ShaderMaterial = null
static var _dissolve_mat: ShaderMaterial = null
static var _ghosts: int = 0


static func _noise_tex() -> NoiseTexture2D:
	return VfxKit.noise()


## 冲击波环：从中心扩散到 radius，带噪声扰动（震地、盾击 5 段、爆燃、Boss 阶段）。
static func shockwave(parent: Node, center: Vector3, radius: float, color: Color, duration: float = 0.45) -> void:
	record(["shock", center, radius, color, duration])
	if parent == null or not parent.is_inside_tree():
		return
	if _shock_mat == null:
		_shock_mat = ShaderMaterial.new()
		_shock_mat.shader = ShockwaveShader
		_shock_mat.set_shader_parameter("noise_tex", _noise_tex())
	var mi: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(radius * 2.2, radius * 2.2)
	mi.mesh = plane
	mi.material_override = _shock_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = Vector3(center.x, 0.1, center.z)
	mi.set_instance_shader_parameter("wave_color", color)
	mi.set_instance_shader_parameter("progress", 0.0)
	var tw: Tween = mi.create_tween()
	# 线性时间；半径的 ease-out 在 shader 里做，淡出不会被提前
	tw.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter("progress", v), 0.0, 1.0, duration)
	tw.tween_callback(mi.queue_free)


## 粒子爆发（见 ParticleFx.PRESETS）。
static func burst(parent: Node, preset: String, pos: Vector3, scale: float = 1.0, color: Color = Color(0, 0, 0, 0)) -> void:
	record(["burst", preset, pos, scale, color])
	ParticleFx.burst(parent, preset, pos, scale, color)


## 锯齿电弧（盾击 3 段连锁、连锁闪电）：a 到 b 之间的折线（离地 1 米），闪两下后消失，两端溅火花。
static func arc(parent: Node, a: Vector3, b: Vector3, color: Color) -> void:
	record(["arc", a, b, color])
	_arc_impl(parent, a + Vector3(0, 1, 0), b + Vector3(0, 1, 0), color, true)


## 不录制的电弧（端点已是世界坐标）。雷暴光环的随机落雷也用它。
static func _arc_impl(parent: Node, a: Vector3, b: Vector3, color: Color, sparks: bool) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var root: Node3D = Node3D.new()
	parent.add_child(root)
	var mat: StandardMaterial3D = _add_material(color)
	var n: int = clampi(int(a.distance_to(b) / 1.2), 4, 8)
	var points: Array[Vector3] = [a]
	var side: Vector3 = (b - a).cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	for i in range(1, n):
		points.append(a.lerp(b, float(i) / n) + side * randf_range(-0.5, 0.5) + Vector3(0, randf_range(-0.2, 0.2), 0))
	points.append(b)
	for i in points.size() - 1:
		var seg: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.1, 0.1, points[i].distance_to(points[i + 1]))
		seg.mesh = box
		seg.material_override = mat
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(seg)
		seg.global_transform = Transform3D(VfxKit.aim_basis(points[i + 1] - points[i]), (points[i] + points[i + 1]) * 0.5)
	if sparks:
		ParticleFx.burst(parent, "spark", b, 0.5, Color(color, 1.0))
	var tw: Tween = root.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.2, 0.05)
	tw.tween_property(mat, "albedo_color:a", color.a, 0.05)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.15)
	tw.tween_callback(root.queue_free)


## 敌人死亡：原地留下一个溶解中的残影 + 碎屑。同时存在的残影有上限，超出时只放碎屑。
## 不录制：联机客户端收到 "dead" 事件时用自己的敌人视图网格播放同一效果。
static func death(parent: Node, pos: Vector3, mesh: Mesh, height: float, color: Color, elite: bool, scale: float = 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mid: Vector3 = pos + Vector3(0, maxf(height, 0.8 * scale), 0)
	ParticleFx.burst(parent, "debris", mid, 1.3 if elite else 0.8, color.darkened(0.2))
	if elite:
		ParticleFx.burst(parent, "star", mid, 1.2, color)
	if mesh == null or _ghosts >= MAX_GHOSTS or DisplayServer.get_name() == "headless":
		return
	if _dissolve_mat == null:
		_dissolve_mat = ShaderMaterial.new()
		_dissolve_mat.shader = DissolveShader
		_dissolve_mat.set_shader_parameter("noise_tex", _noise_tex())
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _dissolve_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, height, 0)
	mi.scale = Vector3.ONE * scale
	# 低模（ArrayMesh）自带顶点色，不再叠加代表色；灰盒胶囊没有顶点色，用代表色
	mi.set_instance_shader_parameter("base_color", color if mesh is PrimitiveMesh else Color.WHITE)
	_ghosts += 1
	var tw: Tween = mi.create_tween().set_parallel(true)
	tw.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter("progress", v), 0.0, 1.0, 0.35)
	tw.tween_property(mi, "scale", Vector3(1.15, 0.7, 1.15) * scale, 0.35)
	tw.chain().tween_callback(func() -> void:
		_ghosts -= 1
		mi.queue_free())


static func reset_counters() -> void:
	_ghosts = 0


## 震屏。slot >= 0 时只震该槽位玩家的屏幕（联机时由主机转发给对应客户端）。
static func shake(tree: SceneTree, strength: float, _slot: int = -1) -> void:
	shake_local(tree, strength)


static func shake_local(tree: SceneTree, strength: float) -> void:
	if tree == null or tree.root == null:
		return
	var cam: Camera3D = tree.root.get_viewport().get_camera_3d()
	if cam and cam.has_method("shake"):
		cam.shake(strength)


## 盾击四段视觉进化（文档 05 §5「四档视觉成长」）：
## 1 段 小而清楚：蓝色刀光 + 火花；3 段 更亮 + 连锁电弧（由技能结果给出）；
## 5 段 形态质变：刀光变大 + 蓝色冲击波；8 段 环境级：橙红刀光 + 火焰 + 大冲击波。
static func shield_bash_tiered(parent: Node, origin: Vector3, facing: Vector3, radius: float, tier: int,
		hit_points: Array, chain_links: Array) -> void:
	var cone: Color = CONE_COLOR
	match tier:
		3: cone = Color(0.45, 0.75, 1.0, 0.55)
		5: cone = Color(0.55, 0.85, 1.0, 0.6)
		8: cone = Color(1.0, 0.5, 0.15, 0.6)
	shield_bash(parent, origin, facing, radius, cone)
	for p: Vector3 in hit_points:
		burst(parent, "spark", p + Vector3(0, 1, 0), 1.0 if tier < 8 else 1.3,
				Color(1.0, 0.6, 0.2) if tier >= 8 else Color(0.7, 0.9, 1.0))
	for link: Array in chain_links:
		arc(parent, link[0], link[1], Color(0.6, 0.85, 1.0, 0.9))
	if tier >= 5:
		shockwave(parent, origin + facing * radius * 0.6, radius * 1.5,
				Color(1.0, 0.55, 0.2, 1.0) if tier >= 8 else Color(0.5, 0.8, 1.0, 1.0))
	if tier >= 8:
		for i in 3:
			burst(parent, "fire", origin + facing * radius * (0.3 + 0.3 * i), 1.0)


## 陨石落地爆炸（冲击波 + 火焰爆裂 + 焦黑地裂 + 可选的第二圈冲击波）。
static func meteor_impact(parent: Node, center: Vector3, radius: float, second_wave: bool) -> void:
	shockwave(parent, center, radius, Color(1.0, 0.4, 0.1, 1.0), 0.5)
	burst(parent, "fire", center + Vector3(0, 0.8, 0), radius * 0.15, Color(1.0, 0.5, 0.1))
	burst(parent, "debris", center + Vector3(0, 0.5, 0), radius * 0.2, Color(0.35, 0.25, 0.2))
	crack_decal(parent, center, radius * 0.9, Color(1.0, 0.45, 0.1), 2.5)
	if second_wave:
		await parent.get_tree().create_timer(0.25).timeout
		if is_instance_valid(parent):
			shockwave(parent, center, radius * 1.6, Color(1.0, 0.5, 0.2, 0.6), 0.4)


# ---------- 技能特效精修：Blender 生成的特效网格（vfx_kit.glb）+ 着色器 ----------

## 飞行物：kind -> 飞行速度（米/秒）。伤害在施放瞬间已结算，这里只是表现，飞行时间都很短。
const MISSILE_SPEED: Dictionary = {"fire": 34.0, "ice": 46.0, "knife": 40.0, "bolt": 55.0, "crystal": 50.0, "holy": 42.0}


## 地裂焦痕：先亮后暗、慢慢消失（陨石、火球落点）。
static func crack_decal(parent: Node, pos: Vector3, radius: float, color: Color, duration: float) -> void:
	record(["crack", pos, radius, color, duration])
	if not VfxKit.enabled():
		return
	var mi: MeshInstance3D = VfxKit.decal(parent, "crack", pos, radius, Color(color, 0.45))
	if mi == null:
		return
	mi.rotate_y(randf() * TAU)
	var tw: Tween = mi.create_tween()
	tw.tween_method(func(v: float) -> void: VfxKit.set_fade(mi, v), 1.0, 0.35, duration * 0.3)
	tw.tween_method(func(v: float) -> void: VfxKit.set_fade(mi, v), 0.35, 0.0, duration * 0.7)
	tw.tween_callback(mi.queue_free)


## 飞行物：从 a 飞到 b，落地播放命中效果。kind：
## fire 火球 / ice 冰枪 / knife 飞刀 / bolt 法球 / crystal 元素水晶（术士普攻）/ holy 圣光十字（牧师普攻）。
## size 为命中效果的大小（火球爆炸半径等）；tier 1-8 放大飞行物、拖尾和落地效果。
## 落地效果不单独录制，客户端回放飞行物时自己播放。
static func missile(parent: Node, kind: String, a: Vector3, b: Vector3, color: Color, size: float = 1.0, tier: int = 1) -> void:
	record(["missile", kind, a, b, color, size, tier])
	if not VfxKit.enabled() or parent == null or not parent.is_inside_tree() or a.distance_to(b) < 0.1:
		return
	var travel: float = a.distance_to(b) / float(MISSILE_SPEED.get(kind, 40.0))
	var root: Node3D = Node3D.new()
	parent.add_child(root)
	root.global_transform = Transform3D(VfxKit.aim_basis(b - a), a)
	var tint: Color = Color(color, 1.0)
	var grow: float = 1.0 + 0.12 * (tier - 1) if tier > 1 else 1.0  # 8 段约 1.8 倍
	var body: MeshInstance3D = null
	var extra: MeshInstance3D = null
	var trail_len: float = 2.0
	var trail_r: float = 0.2
	match kind:
		"fire":
			body = VfxKit.spawn(root, VfxKit.sphere(), "fresnel", tint)
			if body != null:
				body.scale = Vector3.ONE * 0.38 * grow
			if tier >= 5:
				# 5 段起火球外裹一层逆向旋转的火焰风带
				extra = VfxKit.spawn(root, "Swirl", "slash", Color(1.0, 0.6, 0.2, 0.9))
				if extra != null:
					extra.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(0.55, 0.8, 0.55) * grow), Vector3(0, 0, 0.3))
					extra.set_instance_shader_parameter("progress", -1.0)
			trail_len = 3.0 * grow
			trail_r = 0.3 * grow
		"ice":
			body = VfxKit.spawn(root, "IceLance", "solid", Color(0.85, 0.97, 1.0))
			if body != null:
				body.scale = Vector3.ONE * 1.1 * grow
				body.set_instance_shader_parameter("glow", 1.2 + 0.15 * tier)
			trail_len = 2.5 * grow
			trail_r = 0.12 * grow
		"knife":
			body = VfxKit.spawn(root, "Dagger", "solid", tint)
			if body != null:
				body.scale = Vector3.ONE * 1.2 * minf(grow, 1.4)
				body.set_instance_shader_parameter("glow", 1.0 + 0.2 * tier)
			trail_len = 1.4
			trail_r = 0.06
		"crystal":
			body = VfxKit.spawn(root, "Crystal", "solid", tint)
			if body != null:
				body.scale = Vector3.ONE * 2.0
				body.set_instance_shader_parameter("glow", 2.6)
			trail_len = 2.4
			trail_r = 0.16
		"holy":
			body = VfxKit.spawn(root, "HolyCross", "solid", Color(1.0, 0.95, 0.8))
			if body != null:
				body.scale = Vector3.ONE * 1.7
				body.set_instance_shader_parameter("glow", 2.4)
			trail_len = 2.0
			trail_r = 0.2
		_:
			body = VfxKit.spawn(root, VfxKit.sphere(), "fresnel", tint)
			if body != null:
				body.scale = Vector3.ONE * 0.2
			trail_len = 1.6
			trail_r = 0.12
	# 拖尾：光柱网格躺倒，从飞行物向后（+Z）延伸，越往后越淡
	var trail: MeshInstance3D = VfxKit.spawn(root, "Beam", "beam", Color(tint, 0.9))
	if trail != null:
		trail.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(trail_r, trail_len, trail_r)), Vector3.ZERO)
	var puffs: Array[int] = [0]
	var puff_count: float = 3.0 + (3.0 if tier >= 5 else 0.0)
	var fly: Callable = func(t: float) -> void:
		if not is_instance_valid(root):
			return
		root.global_position = a.lerp(b, t)
		if body != null:
			match kind:
				"knife": body.rotation.z = t * 14.0      # 沿飞行方向滚转
				"crystal": body.rotation.z = t * 9.0
				"holy": body.rotation.y = t * 10.0       # 平躺的十字自转
		if extra != null:
			extra.rotation.y = -t * 12.0
		if kind == "fire" and int(t * puff_count) > puffs[0]:
			puffs[0] = int(t * puff_count)
			ParticleFx.burst(parent, "fire", root.global_position, 0.35 * grow, Color(1.0, 0.55, 0.15))
	var tw: Tween = root.create_tween()
	tw.tween_method(fly, 0.0, 1.0, travel)
	tw.tween_callback(func() -> void:
		root.queue_free()
		_missile_impact(parent, kind, b, color, size, tier))


static func _missile_impact(parent: Node, kind: String, p: Vector3, color: Color, size: float, tier: int) -> void:
	if not is_instance_valid(parent):
		return
	var was: bool = _mute
	_mute = true
	match kind:
		"fire":
			shockwave(parent, p, size, Color(1.0, 0.45, 0.1, 1.0), 0.3)
			crack_decal(parent, p, size * 0.7, Color(1.0, 0.45, 0.1), 1.5)
			ParticleFx.burst(parent, "fire", p + Vector3(0, 0.3, 0), 0.9 + 0.08 * tier, Color(1.0, 0.55, 0.15))
			ParticleFx.burst(parent, "smoke", p + Vector3(0, 0.6, 0), 0.8, Color(0.3, 0.25, 0.22, 0.6))
			if tier >= 3:
				rune(parent, p, size * 0.9, Color(1.0, 0.45, 0.1, 0.8), "expand", 0.4, "rune_circle")
			if tier >= 8:
				shockwave(parent, p, size * 1.5, Color(1.0, 0.7, 0.2, 0.8), 0.45)
				ParticleFx.burst(parent, "debris", p + Vector3(0, 0.4, 0), 0.8, Color(0.3, 0.2, 0.15))
		"ice":
			ParticleFx.burst(parent, "shard", p, 0.8 + 0.06 * tier, Color(0.7, 0.92, 1.0))
			pulse_ring(parent, p, 1.2 + 0.1 * tier, Color(0.6, 0.9, 1.0, 0.5), 0.25)
			if tier >= 3:
				spike_ring(parent, p * Vector3(1, 0, 1), 1.4 if tier < 8 else 2.2, "ice", 5 if tier < 8 else 8)
		"knife":
			ParticleFx.burst(parent, "spark", p, 0.5, Color(color, 1.0) if tier >= 8 else Color(0.9, 0.9, 1.0))
		"crystal":
			ParticleFx.burst(parent, "shard", p, 0.35, Color(color, 1.0))
		"holy":
			ParticleFx.burst(parent, "star", p, 0.35, Color(1.0, 0.92, 0.55))
		_:
			ParticleFx.burst(parent, "magic", p, 0.35, Color(color, 1.0))
	_mute = was

## 陨石术：落点出现越来越亮的红色法阵，陨石拖着火尾从高空斜落，delay 秒后正好落地（爆炸由 meteor_impact 播放）。
## 四档：3 段法阵外多一圈能量环；5 段两块小陨石伴随落下；8 段法阵与火尾转为金白色（第二圈冲击波由 meteor_impact 播放）。
static func meteor_fall(parent: Node, center: Vector3, radius: float, delay: float, tier: int = 1) -> void:
	record(["meteor", center, radius, delay, tier])
	if not VfxKit.enabled() or parent == null or not parent.is_inside_tree():
		return
	var hot: Color = Color(1.0, 0.75, 0.35, 1.0) if tier >= 8 else Color(1.0, 0.3, 0.1, 1.0)
	var rune: MeshInstance3D = VfxKit.decal(parent, "rune_circle", center, radius, hot)
	if rune != null:
		rune.set_instance_shader_parameter("pulse", 0.4)
	if tier >= 3:
		var ring: MeshInstance3D = VfxKit.decal(parent, "glow_ring", center, radius * 1.2, Color(hot, 0.6))
		if ring != null:
			ring.set_instance_shader_parameter("pulse", 0.6)
			VfxKit.fade_out(ring, delay + 0.2, 0.8)
	if tier >= 5:
		for i in 2:
			var off: Vector3 = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * radius * 0.5
			_meteor_rock(parent, center + off, center + off + Vector3(-5.0 + 2.0 * i, 16.0, 4.0 - 3.0 * i), delay * (0.8 + 0.1 * i),
					0.45, hot)
	var start: Vector3 = center + Vector3(-5.0, 18.0, 4.0)
	var mover: Node3D = Node3D.new()
	parent.add_child(mover)
	mover.global_transform = Transform3D(VfxKit.aim_basis(center - start), start)
	var rock: MeshInstance3D = VfxKit.spawn(mover, "Meteor", "solid", Color(1.0, 0.9, 0.85))
	if rock != null:
		rock.scale = Vector3.ONE * clampf(radius * 0.28, 0.8, 1.8)
		rock.set_instance_shader_parameter("glow", 0.8)
	var trail: MeshInstance3D = VfxKit.spawn(mover, "Beam", "beam", Color(1.0, 0.8, 0.4, 1.0) if tier >= 8 else Color(1.0, 0.45, 0.1, 1.0))
	if trail != null:
		var r: float = clampf(radius * 0.25, 0.7, 1.5) * (1.3 if tier >= 8 else 1.0)
		trail.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(r, 9.0, r)), Vector3.ZERO)
	var puffs: Array[int] = [0]
	var fall: Callable = func(t: float) -> void:
		if not is_instance_valid(mover):
			return
		mover.global_position = start.lerp(center, t)
		if rock != null:
			rock.rotate_object_local(Vector3(0.6, 1.0, 0.3).normalized(), 0.12)
		if int(t * 6.0) > puffs[0]:
			puffs[0] = int(t * 6.0)
			ParticleFx.burst(parent, "fire", mover.global_position, 0.6, Color(1.0, 0.5, 0.15))
	var glow: Callable = func(t: float) -> void:
		if is_instance_valid(rune):
			VfxKit.set_fade(rune, lerpf(0.25, 1.0, t))
			rune.rotate_y(0.03)
	var tw: Tween = mover.create_tween().set_parallel(true)
	tw.tween_method(fall, 0.0, 1.0, delay).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_method(glow, 0.0, 1.0, delay)
	tw.chain().tween_callback(func() -> void:
		mover.queue_free()
		if is_instance_valid(rune):
			VfxKit.fade_out(rune, 0.25))


## 伴随小陨石（不录制，由 meteor_fall 调用）：从 start 落到 end，落地一小团火。
static func _meteor_rock(parent: Node, end: Vector3, start: Vector3, time: float, size: float, color: Color) -> void:
	var mover: Node3D = Node3D.new()
	parent.add_child(mover)
	mover.global_transform = Transform3D(VfxKit.aim_basis(end - start), start)
	var rock: MeshInstance3D = VfxKit.spawn(mover, "Meteor", "solid", Color(1.0, 0.9, 0.85))
	if rock != null:
		rock.scale = Vector3.ONE * size
	var trail: MeshInstance3D = VfxKit.spawn(mover, "Beam", "beam", color)
	if trail != null:
		trail.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(0.35, 5.0, 0.35)), Vector3.ZERO)
	var fall: Callable = func(t: float) -> void:
		mover.global_position = start.lerp(end, t)
		if rock != null:
			rock.rotate_object_local(Vector3(1.0, 0.4, 0.2).normalized(), 0.18)
	var tw: Tween = mover.create_tween()
	tw.tween_method(fall, 0.0, 1.0, time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		mover.queue_free()
		ParticleFx.burst(parent, "fire", end + Vector3(0, 0.4, 0), 0.7, Color(1.0, 0.5, 0.15))
		ParticleFx.burst(parent, "debris", end + Vector3(0, 0.3, 0), 0.5, Color(0.3, 0.22, 0.18)))


## 附着在目标身上的持续效果。kind：shield 神圣护盾罩；bless 祝福（环绕光点 + 脚下法阵）；mark 死亡标记（头顶倒悬血刃）。
## pos 为施放时目标位置，按位置找回目标节点（主机上是玩家/敌人，客户端上是玩家/敌人视图）。
## 四档：shield 3 段脚下盾纹、5 段外层格栅；bless 3 段圣光纹、5 段 5 颗光点、8 段头顶光冠；mark 5 段减速环、8 段大血刃。
static func buff(parent: Node, kind: String, pos: Vector3, duration: float, color: Color, tier: int = 1) -> void:
	record(["buff", kind, pos, duration, color, tier])
	if not VfxKit.enabled() or parent == null or not parent.is_inside_tree():
		return
	var target: Node3D = _resolve(parent.get_tree(), ["players"] if kind != "mark" else ["enemies", "enemy_views"], pos)
	if target == null:
		return
	var root: Node3D = Node3D.new()
	parent.add_child(root)
	root.global_position = Vector3(pos.x, 0.0, pos.z)
	var tint: Color = Color(color, 1.0)
	var spin: float = 1.0
	var motes: Array[MeshInstance3D] = []
	var head: MeshInstance3D = null
	var crown: MeshInstance3D = null
	match kind:
		"shield":
			var shells: Array = ["Dome", "LatticeDome"] if tier >= 5 else ["Dome"]
			for part: String in shells:
				var dome: MeshInstance3D = VfxKit.spawn(root, part, "fresnel", tint if part == "Dome" else Color(0.85, 0.95, 1.0))
				if dome != null:
					var s: Vector3 = Vector3(1.3, 1.6, 1.3) * (1.0 if part == "Dome" else 1.03)
					dome.scale = Vector3.ONE * 0.1
					dome.create_tween().tween_property(dome, "scale", s, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if tier >= 3:
				var sigil: MeshInstance3D = VfxKit.spawn(root, VfxKit.decal_mesh(), "decal", Color(tint, 0.6), "pulse_sigil")
				if sigil != null:
					sigil.transform = Transform3D(Basis.from_scale(Vector3(1.4, 1, 1.4)), Vector3(0, 0.06, 0))
			spin = 0.6
		"bless":
			var rune: MeshInstance3D = VfxKit.spawn(root, VfxKit.decal_mesh(), "decal", Color(tint, 0.6),
					"holy_sigil" if tier >= 3 else "rune_circle")
			if rune != null:
				rune.transform = Transform3D(Basis.from_scale(Vector3(1.1, 1, 1.1)), Vector3(0, 0.06, 0))
			if tier >= 8:
				crown = VfxKit.spawn(root, "Halo", "solid", Color(1.0, 0.9, 0.6))
				if crown != null:
					crown.transform = Transform3D(Basis.from_scale(Vector3.ONE * 1.1), Vector3(0, 2.4, 0))
					crown.set_instance_shader_parameter("glow", 2.0)
			for i in (5 if tier >= 5 else 3):
				var m: MeshInstance3D = VfxKit.spawn(root, VfxKit.sphere(), "fresnel", tint)
				if m != null:
					var a: float = TAU * i / (5.0 if tier >= 5 else 3.0)
					m.transform = Transform3D(Basis.from_scale(Vector3.ONE * 0.12), Vector3(cos(a), 1.0, sin(a)) * Vector3(0.9, 1, 0.9))
					motes.append(m)
			spin = 2.5
		"mark":
			var rune: MeshInstance3D = VfxKit.spawn(root, VfxKit.decal_mesh(), "decal", Color(tint, 0.8), "rune_circle")
			if rune != null:
				rune.transform = Transform3D(Basis.from_scale(Vector3(0.9, 1, 0.9)), Vector3(0, 0.06, 0))
				rune.set_instance_shader_parameter("pulse", 0.3)
			head = VfxKit.spawn(root, "Dagger", "solid", tint)
			if head != null:
				# 刀尖朝下悬在头顶
				head.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).scaled(Vector3.ONE * 1.1), Vector3(0, 2.9, 0))
				head.set_instance_shader_parameter("glow", 2.0 + 0.3 * tier)
				if tier >= 8:
					head.scale *= 1.5
			if tier >= 5:
				# 5 段减速：脚下多一圈冰蓝色能量环
				var slow: MeshInstance3D = VfxKit.spawn(root, VfxKit.decal_mesh(), "decal", Color(0.6, 0.8, 1.0, 0.7), "glow_ring")
				if slow != null:
					slow.transform = Transform3D(Basis.from_scale(Vector3(1.2, 1, 1.2)), Vector3(0, 0.07, 0))
			spin = 2.0
	# 按实例 id 跟随：目标（敌人 / 敌人视图）随时可能被释放，lambda 不直接捕获它
	var target_id: int = target.get_instance_id()
	var step: Callable = func(t: float, dt: float) -> bool:
		var tg: Node3D = instance_from_id(target_id) as Node3D
		if tg == null or not tg.is_inside_tree() or ("is_alive" in tg and not tg.is_alive) \
				or ("is_dead" in tg and tg.is_dead):
			return false
		root.global_position = Vector3(tg.global_position.x, 0.0, tg.global_position.z)
		root.rotate_y(dt * spin)
		var f: float = clampf(t / 0.2, 0.0, 1.0) * clampf((duration - t) / 0.5, 0.0, 1.0)
		for c: Node in root.get_children():
			if c is GeometryInstance3D:
				(c as GeometryInstance3D).set_instance_shader_parameter("fade", f)
		for i in motes.size():
			motes[i].position.y = 1.0 + 0.35 * sin(t * 3.0 + i * 2.1)
		if head != null:
			head.position.y = 2.9 + 0.12 * sin(t * 4.0)
		if crown != null:
			crown.rotate_y(-dt * spin * 1.6)
		return true
	_run(root, duration, step)


## 瞬移 / 冲锋残影：沿 a→b 留下 count 个发光的角色剪影，依次淡出（影步、冲锋）。
static func afterimage(parent: Node, slot: int, a: Vector3, b: Vector3, color: Color, count: int = 4) -> void:
	record(["ghost", slot, a, b, color, count])
	if not VfxKit.enabled() or parent == null or not parent.is_inside_tree():
		return
	var player: Node3D = _player_by_slot(parent.get_tree(), slot)
	var src: MeshInstance3D = player.get_node_or_null("Mesh") as MeshInstance3D if player != null else null
	if src == null or src.mesh == null:
		return
	for i in count:
		var t: float = float(i) / maxf(1.0, count - 1.0)
		ghost_at(parent, src.mesh, a.lerp(b, t), b - a, color, 0.25 + 0.2 * t)


## 单个残影（不录制）。玩家高速移动时本地也会调用。
static func ghost_at(parent: Node, mesh: Mesh, pos: Vector3, dir: Vector3, color: Color, life: float) -> void:
	var g: MeshInstance3D = VfxKit.spawn(parent, mesh, "fresnel", Color(color, 1.0))
	if g == null:
		return
	g.global_transform = Transform3D(VfxKit.facing_basis(dir), Vector3(pos.x, 0.0, pos.z))
	var tw: Tween = g.create_tween()
	tw.tween_method(func(v: float) -> void: VfxKit.set_fade(g, v), 0.9, 0.0, life)
	tw.tween_callback(g.queue_free)


## 处决：目标身上交叉两道血红刀光（X 形），第二刀略晚。
static func execute_slash(parent: Node, center: Vector3, facing: Vector3, radius: float, color: Color) -> void:
	record(["xslash", center, facing, radius, color])
	if not VfxKit.enabled() or parent == null or not parent.is_inside_tree():
		return
	var root: Node3D = Node3D.new()
	parent.add_child(root)
	root.global_transform = Transform3D(VfxKit.facing_basis(facing), Vector3(center.x, 1.2, center.z))
	for i in 2:
		var pivot: Node3D = Node3D.new()
		root.add_child(pivot)
		pivot.rotation.z = 0.9 if i == 0 else -0.9
		var arc_mi: MeshInstance3D = VfxKit.spawn(pivot, "SlashArc", "slash", Color(color, 1.0))
		if arc_mi == null:
			continue
		# 弧线最前端（半径处）正好落在目标身上
		arc_mi.transform = Transform3D(Basis.from_scale(Vector3.ONE * radius), Vector3(0, 0, radius))
		arc_mi.set_instance_shader_parameter("progress", 0.0)
		var sweep: Callable = func(v: float) -> void: arc_mi.set_instance_shader_parameter("progress", v)
		var tw: Tween = arc_mi.create_tween()
		tw.tween_interval(0.09 * i)
		tw.tween_method(sweep, 0.0, 1.0, 0.25)
	var life: Tween = root.create_tween()
	life.tween_interval(0.45)
	life.tween_callback(root.queue_free)




## 冰霜新星：一圈冰刺从地面刺出再缩回（兼容旧调用）。
static func frost_burst(parent: Node, center: Vector3, radius: float) -> void:
	spike_ring(parent, center, radius, "ice")


## 一圈尖刺从地面刺出再缩回。style：ice 冰刺（冰霜新星、冰枪落点）/ rock 岩刺（震地、盾击 8 段、处决）。
static func spike_ring(parent: Node, center: Vector3, radius: float, style: String = "ice", count: int = 0) -> void:
	record(["spikes", center, radius, style, count])
	if not VfxKit.enabled() or parent == null or not parent.is_inside_tree():
		return
	var ice: bool = style == "ice"
	var n: int = count if count > 0 else clampi(int(radius * 2.2), 8, 16)
	for i in n:
		var sp: MeshInstance3D = VfxKit.spawn(parent, "IceSpikes" if ice else "RockSpikes", "solid",
				Color(0.85, 0.96, 1.0) if ice else Color(1.0, 0.92, 0.85))
		if sp == null:
			continue
		var a: float = TAU * i / n + randf_range(-0.15, 0.15)
		var r: float = radius * randf_range(0.55, 0.95)
		var s: float = randf_range(0.8, 1.3) * (1.0 if ice else 1.2)
		sp.global_transform = Transform3D(Basis(Vector3.UP, randf() * TAU), center * Vector3(1, 0, 1) + Vector3(cos(a), 0, sin(a)) * r)
		sp.scale = Vector3(s, 0.01, s)
		sp.set_instance_shader_parameter("glow", 1.0 if ice else 0.15)
		var tw: Tween = sp.create_tween()
		tw.tween_interval(r / radius * 0.12)
		tw.tween_property(sp, "scale", Vector3(s, s * 1.2, s), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.5 if ice else 0.7)
		tw.tween_property(sp, "scale", Vector3(s, 0.01, s), 0.3).set_ease(Tween.EASE_IN)
		tw.tween_callback(sp.queue_free)
	if not ice:
		ParticleFx.burst(parent, "debris", center + Vector3(0, 0.4, 0), radius * 0.2, Color(0.45, 0.35, 0.25))


## 地面法阵动画。mode：expand 从小扩大并淡出（施法、爆发）；implode 从大收缩到中心（嘲讽拉拢）；
## flash 原地亮起、旋转后淡出（标记、落点）。mask 为地面贴图名（rune_circle / holy_sigil / pulse_sigil / glow_ring）。
static func rune(parent: Node, center: Vector3, radius: float, color: Color, mode: String = "expand", duration: float = 0.5,
		mask: String = "rune_circle") -> void:
	record(["rune", center, radius, color, mode, duration, mask])
	if not VfxKit.enabled() or parent == null or not parent.is_inside_tree():
		return
	var mi: MeshInstance3D = VfxKit.decal(parent, mask, center, radius, Color(color, 1.0))
	if mi == null:
		return
	mi.rotate_y(randf() * TAU)
	var from_s: float = 0.3
	var to_s: float = 1.0
	match mode:
		"implode":
			from_s = 1.5
			to_s = 0.15
		"flash":
			from_s = 0.85
			to_s = 1.05
	mi.scale = Vector3(radius * from_s, 1, radius * from_s)
	var a: float = color.a
	var fade: Callable = func(v: float) -> void:
		# 0→1：前 20% 淡入，后面淡出；同时自转
		VfxKit.set_fade(mi, a * (clampf(v / 0.2, 0.0, 1.0) if mode != "expand" else 1.0) * clampf((1.0 - v) / 0.6, 0.0, 1.0))
		mi.rotate_y(0.04 if mode != "implode" else -0.08)
	var tw: Tween = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius * to_s, 1, radius * to_s), duration) \
			.set_ease(Tween.EASE_IN if mode == "implode" else Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(fade, 0.0, 1.0, duration)
	tw.chain().tween_callback(mi.queue_free)


## 铁卫普攻：脚下盾纹扩散 + 一圈盾徽向外推开。count 面盾徽；tint 为盾纹颜色（烈焰核心时橙色）。
static func shield_pulse(parent: Node, center: Vector3, radius: float, tint: Color, count: int = 6) -> void:
	record(["spulse", center, radius, tint, count])
	if not VfxKit.enabled() or parent == null or not parent.is_inside_tree():
		return
	var sigil: MeshInstance3D = VfxKit.decal(parent, "pulse_sigil", center, radius * 0.3, Color(tint, 0.8))
	if sigil != null:
		var sfade: Callable = func(v: float) -> void: VfxKit.set_fade(sigil, v)
		var st: Tween = sigil.create_tween().set_parallel(true)
		st.tween_property(sigil, "scale", Vector3(radius, 1, radius), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		st.tween_method(sfade, 1.0, 0.0, 0.35).set_ease(Tween.EASE_IN)
		st.chain().tween_callback(sigil.queue_free)
	var spin: float = randf() * TAU
	for i in count:
		var sh: MeshInstance3D = VfxKit.spawn(parent, "ShieldRune", "solid", Color(tint.lerp(Color.WHITE, 0.4), 1.0))
		if sh == null:
			continue
		var a: float = spin + TAU * i / count
		var out: Vector3 = Vector3(sin(a), 0, cos(a))
		var base: Vector3 = center * Vector3(1, 0, 1) + Vector3(0, 0.9, 0)
		sh.global_transform = Transform3D(Basis.looking_at(-out, Vector3.UP), base + out * radius * 0.3)
		sh.set_instance_shader_parameter("glow", 1.5)
		var move: Callable = func(v: float) -> void:
			sh.global_position = base + out * radius * lerpf(0.3, 0.95, v)
			VfxKit.set_fade(sh, 1.0 - v * v)
		var tw: Tween = sh.create_tween()
		tw.tween_method(move, 0.0, 1.0, 0.32).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(sh.queue_free)


## 着色器预热：进场时把每种特效材质 × 网格在地面下方各画几帧，避免第一次施放时编译着色器卡顿。
static func warmup(parent: Node, at: Vector3) -> void:
	if not VfxKit.enabled() or parent == null or not parent.is_inside_tree():
		return
	var root: Node3D = Node3D.new()
	parent.add_child(root)
	root.global_position = at + Vector3(0, -3.0, 0)
	var parts: Array = ["SlashArc", "Swirl", "Beam", "Dagger", "Greatsword", "Meteor", "IceLance", "IceSpikes", "Dome",
		"SmokePuff", "ShieldRune", "Crystal", "HolyCross", "Halo", "RockSpikes", "LatticeDome"]
	var i: int = 0
	for part: String in parts:
		for shader: String in ["slash", "fresnel", "beam", "solid"]:
			var mi: MeshInstance3D = VfxKit.spawn(root, part, shader, Color.WHITE)
			if mi != null:
				mi.position = Vector3((i % 8) * 0.3, 0, (i / 8) * 0.3)
				mi.set_instance_shader_parameter("fade", 0.0)
			i += 1
	for mask: String in ["rune_circle", "crack", "pulse_sigil", "holy_sigil", "glow_ring"]:
		var d: MeshInstance3D = VfxKit.spawn(root, VfxKit.decal_mesh(), "decal", Color.WHITE, mask)
		if d != null:
			d.set_instance_shader_parameter("fade", 0.0)
	for s: MeshInstance3D in [VfxKit.spawn(root, VfxKit.sphere(), "fresnel", Color.WHITE)]:
		if s != null:
			s.set_instance_shader_parameter("fade", 0.0)
	for preset: String in ParticleFx.PRESETS:
		ParticleFx.burst(parent, preset, root.global_position, 0.3)
	# 冲击波、电弧、普通加色材质
	_shockwave_local(parent, root.global_position, 1.0, Color(1, 1, 1, 0.0), 0.2)
	_arc_impl(parent, root.global_position, root.global_position + Vector3(1, 0, 0), Color(1, 1, 1, 0.0), false)
	for f in 4:
		await parent.get_tree().process_frame
	if is_instance_valid(root):
		root.queue_free()
