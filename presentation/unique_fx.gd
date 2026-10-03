class_name UniqueFx extends RefCounted
## 16 个新技能的专属特效（网格来自 tools/blender/build_skill_vfx.py 生成的 skill_vfx_kit.glb）。
## 每个特效 = 一个根节点 + 若干网格，由 SkillVfx._run 每帧驱动；段位 1/3/5/8 逐档加部件、换形态。
## 联机：主机录制一个 ["ufx", id, origin, facing, tier, data] 事件，客户端整段回放；内部借用的 SkillVfx 原语一律静音。

const KIT: String = "skill_vfx_kit"
const IDS: Array[String] = ["earthquake", "iron_wall", "war_cry", "flame_cleave", "thunderstorm", "frost_barrier",
	"arcane_barrage", "lava_blast", "eviscerate", "shadow_clone", "backstab", "poison_blade",
	"guardian_angel", "purify", "resurrection", "holy_wrath"]
## 联机只传表现需要的字段
const DATA_KEYS: Array[String] = ["impacts", "center", "links", "healed", "radius", "duration", "aura_duration",
	"executed", "killed", "revived"]
const LAVA: Color = Color(1.0, 0.45, 0.1)
const GOLD: Color = Color(1.0, 0.82, 0.4)
const HOLY: Color = Color(1.0, 0.94, 0.65)
const FROST: Color = Color(0.6, 0.9, 1.0)
const STORM: Color = Color(0.65, 0.75, 1.0)
const ARCANE: Color = Color(0.75, 0.5, 1.0)
const SHADOW: Color = Color(0.55, 0.3, 0.95)
const BLOOD: Color = Color(1.0, 0.12, 0.2)
const VENOM: Color = Color(0.45, 1.0, 0.3)


static func play(parent: Node, caster: Node3D, id: String, origin: Vector3, facing: Vector3, tier: int, r: Dictionary) -> void:
	var data: Dictionary = {"slot": int(caster.get("net_slot"))}
	for k: String in DATA_KEYS:
		if r.has(k):
			data[k] = r[k]
	SkillVfx.record(["ufx", id, origin, facing, tier, data])
	replay(parent, id, origin, facing, tier, data)


## 播放（客户端回放直接调这个）。
static func replay(parent: Node, id: String, origin: Vector3, facing: Vector3, tier: int, d: Dictionary) -> void:
	if not VfxKit.enabled() or parent == null or not parent.is_inside_tree():
		return
	var was: bool = SkillVfx._mute
	SkillVfx._mute = true
	var f: Vector3 = Vector3(facing.x, 0.0, facing.z).normalized() if Vector3(facing.x, 0, facing.z).length() > 0.01 else Vector3.FORWARD
	_dispatch(parent, id, origin, f, tier, d)
	SkillVfx._mute = was


static func _dispatch(p: Node, id: String, o: Vector3, f: Vector3, t: int, d: Dictionary) -> void:
	match id:
		"earthquake": _earthquake(p, o, t, d)
		"iron_wall": _iron_wall(p, o, t, d)
		"war_cry": _war_cry(p, o, t, d)
		"flame_cleave": _flame_cleave(p, o, f, t)
		"thunderstorm": _thunderstorm(p, o, t, d)
		"frost_barrier": _frost_barrier(p, o, t, d)
		"arcane_barrage": _arcane_barrage(p, o, f, t, d)
		"lava_blast": _lava_blast(p, o, t, d)
		"eviscerate": _eviscerate(p, o, t, d)
		"shadow_clone": _shadow_clone(p, o, t, d)
		"backstab": _backstab(p, o, f, t, d)
		"poison_blade": _poison_blade(p, o, t, d)
		"guardian_angel": _guardian_angel(p, o, t, d)
		"purify": _purify(p, o, t, d)
		"resurrection": _resurrection(p, o, t, d)
		"holy_wrath": _holy_wrath(p, o, t, d)


# ---------------- 工具 ----------------

## 特效根节点（放在 pos，地面高度）。
static func _root(parent: Node, pos: Vector3) -> Node3D:
	var root: Node3D = Node3D.new()
	parent.add_child(root)
	root.global_position = Vector3(pos.x, 0.0, pos.z)
	return root


## 在根节点下放一个 skill_vfx_kit 网格（part 以 "kit:" 开头时取 vfx_kit 的网格）。scale 先于旋转作用。
static func _add(root: Node3D, part: String, shader: String, tint: Color, local: Vector3 = Vector3.ZERO,
		rot: Basis = Basis.IDENTITY, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m: Mesh = VfxKit.mesh(part.substr(4)) if part.begins_with("kit:") else ModelLibrary.mesh(KIT, part)
	if m == null:
		return null
	var mi: MeshInstance3D = VfxKit.spawn(root, m, shader, tint)
	if mi != null:
		mi.transform = Transform3D(rot * Basis.from_scale(scale), local)
	return mi


static func _fade(mi: GeometryInstance3D, v: float) -> void:
	if is_instance_valid(mi):
		mi.set_instance_shader_parameter("fade", clampf(v, 0.0, 1.0))


static func _progress(mi: GeometryInstance3D, v: float) -> void:
	if is_instance_valid(mi):
		mi.set_instance_shader_parameter("progress", v)


static func _out(x: float) -> float:  # ease-out 三次
	var c: float = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - c, 3.0)


static func _back(x: float) -> float:  # 冲过头再回弹
	var c: float = clampf(x, 0.0, 1.0) - 1.0
	return 1.0 + 2.7 * c * c * c + 1.7 * c * c


## 外圈的方向（角度 a）：-Z 绕 Y 旋转 a。网格前方 -Z 时 Basis(UP, a) 让它朝外。
static func _dir(a: float) -> Vector3:
	return Vector3(-sin(a), 0.0, -cos(a))


static func _quiet(fn: Callable) -> void:  # 在 _run 的回调里调用 SkillVfx 原语时静音（此时外层 _mute 已恢复）
	var was: bool = SkillVfx._mute
	SkillVfx._mute = true
	fn.call()
	SkillVfx._mute = was


## 根节点下所有网格一起淡出。
static func _fade_all(root: Node3D, v: float) -> void:
	for c: Node in root.get_children():
		if c is GeometryInstance3D:
			_fade(c, v)


# ============================================================ 铁卫

## 地震：三圈（5 段四圈）岩板由内向外依次从地下顶起（回弹），停留后沉回；8 段中心熔岩喷涌。
static func _earthquake(p: Node, o: Vector3, t: int, _d: Dictionary) -> void:
	var root: Node3D = _root(p, o)
	var rings: int = 3 if t < 5 else 4
	var slabs: Array[MeshInstance3D] = []
	for ring in rings:
		var count: int = 8 + ring * 4
		var r: float = 2.0 + ring * 2.5
		for k in count:
			var a: float = (k + 0.5 * (ring % 2)) / float(count) * TAU
			var s: MeshInstance3D = _add(root, "QuakeSlab" if (t < 3 or (k + ring) % 3 != 0) else "QuakePillar_B",
					"solid", Color(1.0, 0.85, 0.7) if t < 8 else Color(1.0, 0.7, 0.5), _dir(a) * r + Vector3.DOWN * 1.2,
					Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, randf_range(-0.35, -0.1)),
					Vector3.ONE * randf_range(0.9, 1.3) * (1.0 + 0.12 * ring))
			if s:
				s.set_meta("delay", ring * 0.16 + randf() * 0.05)
				slabs.append(s)
	var dur: float = 1.9 + rings * 0.16
	SkillVfx._run(root, dur, func(el: float, _dt: float) -> bool:
		for s: MeshInstance3D in slabs:
			var dl: float = s.get_meta("delay")
			if el < dl + 0.3:
				s.position.y = -1.2 + 1.2 * _back((el - dl) / 0.3)
			elif el > dur - 0.5:
				s.position.y = -1.2 * _out((el - (dur - 0.5)) / 0.5)
		return true)
	_quiet(func() -> void:
		SkillVfx.burst(p, "dust", o, 2.2)
		SkillVfx.crack_decal(p, o, 4.0 + rings * 2.0, LAVA if t >= 5 else Color(0.8, 0.6, 0.4), dur)
		if t >= 8:
			SkillVfx.burst(p, "fire", o + Vector3.UP * 0.5, 2.0, LAVA)
			SkillVfx.pillar(p, o, 0.8, 5.0, Color(LAVA, 0.9)))


## 铁壁：一圈塔盾从天而降砸进地面围住施法者，持续期间跟随；5 段双层，8 段镀金。
static func _iron_wall(p: Node, o: Vector3, t: int, d: Dictionary) -> void:
	var root: Node3D = _root(p, o)
	var caster: Node3D = SkillVfx._player_by_slot(p.get_tree(), int(d.get("slot", 0)))
	var layers: int = 1 if t < 5 else 2
	var dur: float = float(d.get("aura_duration", 8.0))
	var tint: Color = GOLD if t >= 8 else Color(0.85, 0.9, 1.0)
	for layer in layers:
		var count: int = 8 if layer == 0 else 10
		for k in count:
			var a: float = (k + 0.5 * layer) / float(count) * TAU
			_add(root, "IronBulwark", "solid", tint, _dir(a) * (1.6 + layer * 0.55) + Vector3.UP * 6.0,
					Basis(Vector3.UP, a), Vector3.ONE * (1.0 if layer == 0 else 0.8))
	SkillVfx._run(root, dur, func(el: float, _dt: float) -> bool:
		if is_instance_valid(caster):
			root.global_position = Vector3(caster.global_position.x, 0.0, caster.global_position.z)
		var i: int = 0
		for c: Node in root.get_children():
			var drop: float = clampf((el - i * 0.025) / 0.18, 0.0, 1.0)
			(c as Node3D).position.y = 6.0 * (1.0 - drop * drop)
			i += 1
		root.rotation.y += _dt * (0.25 if t >= 3 else 0.0)
		if el > dur - 0.4:
			_fade_all(root, (dur - el) / 0.4)
		return true)
	_quiet(func() -> void:
		SkillVfx.shockwave(p, o, 2.6, Color(tint, 1.0), 0.35)
		SkillVfx.burst(p, "spark", o + Vector3.UP * 0.5, 1.4, tint))


## 战吼：向外扩散的声浪环（多圈依次放大淡出），5 段加地面獠牙。
static func _war_cry(p: Node, o: Vector3, t: int, _d: Dictionary) -> void:
	var root: Node3D = _root(p, o)
	var waves: int = 2 if t < 3 else (3 if t < 8 else 4)
	var fangs: Array[MeshInstance3D] = []
	if t >= 5:
		for k in 8:
			var fang: MeshInstance3D = _add(root, "RoarFang", "solid", GOLD, _dir(k / 8.0 * TAU) * 2.8 + Vector3.DOWN * 1.1,
					Basis(Vector3.UP, k / 8.0 * TAU))
			if fang:
				fangs.append(fang)
	var rings: Array[MeshInstance3D] = []
	for w in waves:
		var wv: MeshInstance3D = _add(root, "RoarWave", "beam", Color(1.0, 0.75, 0.35) if w % 2 == 0 else Color(1.0, 0.5, 0.2))
		if wv:
			wv.scale = Vector3(0.01, 1.0, 0.01)
			rings.append(wv)
	var dur: float = 0.6 + waves * 0.15
	SkillVfx._run(root, dur, func(el: float, _dt: float) -> bool:
		for w in rings.size():
			var t_w: float = clampf((el - w * 0.15) / 0.5, 0.0, 1.0)
			var s: float = 0.3 + (5.0 + w * 1.5) * _out(t_w)
			rings[w].scale = Vector3(s, 1.0 + 1.5 * (1.0 - t_w), s)
			_fade(rings[w], 0.0 if t_w <= 0.0 else 1.0 - t_w)
		for fg: MeshInstance3D in fangs:
			if el < 0.3:
				fg.position.y = -1.1 + 1.1 * _back(el / 0.3)
			elif el > dur - 0.4:
				_fade(fg, (dur - el) / 0.4)
		return true)
	_quiet(func() -> void:
		SkillVfx.burst(p, "magic", o + Vector3.UP * 1.8, 1.6, Color(1.0, 0.7, 0.3))
		SkillVfx.shockwave(p, o, 6.0, Color(1.0, 0.6, 0.2, 0.9), 0.5))


## 烈焰斩：月牙刀光扫过，3 段双刀，5 段加火焰爆发，8 段三刀。
static func _flame_cleave(p: Node, o: Vector3, f: Vector3, t: int) -> void:
	var root: Node3D = _root(p, o)
	var rot: Basis = VfxKit.facing_basis(f)
	var count: int = 1 if t < 3 else (2 if t < 8 else 3)
	var dur: float = 0.4
	for k in count:
		var offset: Vector3 = Vector3.ZERO if count == 1 else (rot * Vector3((k - 1) * 0.8, 0, 0))
		var c: MeshInstance3D = _add(root, "FlameCrescent", "slash", LAVA, offset, rot,
				Vector3.ONE * (1.3 if k == 0 else 1.0))
		if c:
			c.set_meta("idx", k)
	SkillVfx._run(root, dur, func(el: float, _dt: float) -> bool:
		var prog: float = clampf(el / dur, 0.0, 1.0)
		for c: Node in root.get_children():
			var k: int = (c as Node3D).get_meta("idx", 0)
			_progress(c, clampf(prog - k * 0.1, 0.0, 1.0))
			_fade(c, 1.0 - prog * prog)
		return true)
	_quiet(func() -> void:
		if t >= 5:
			SkillVfx.burst(p, "fire", o + f * 1.5 + Vector3.UP * 0.4, 2.0, LAVA))


# ============================================================ 元素术士

## 雷暴：雷云悬浮在上空旋转，每隔一段时间劈下闪电（多道随机位置），持续施法时间。
static func _thunderstorm(p: Node, o: Vector3, t: int, d: Dictionary) -> void:
	var root: Node3D = _root(p, o)
	var dur: float = float(d.get("duration", 1.4))
	var cloud: MeshInstance3D = _add(root, "ThunderCloud", "solid", Color(0.3, 0.35, 0.45, 0.7), Vector3.UP * 5.0, Basis.IDENTITY,
			Vector3(6.0, 1.8, 6.0) * (1.0 if t < 8 else 1.4))
	var bolt_count: int = 3 if t < 5 else (5 if t < 8 else 7)
	var bolt_interval: float = 0.35  # 固定间隔 0.35 秒一道闪电
	var next_bolt: float = 0.0  # 下一道闪电的时间点
	SkillVfx._run(root, dur, func(el: float, dt: float) -> bool:
		if cloud:
			cloud.rotation.y += dt * 0.5
			_fade(cloud, 1.0 if el < dur - 0.4 else (dur - el) / 0.4)
		# 持续期间不断劈闪电，施放时立即劈第一道
		if el >= next_bolt and next_bolt < dur:
			var offset: Vector3 = Vector3(randf_range(-7, 7), 0, randf_range(-7, 7))
			var bolt: MeshInstance3D = _add(root, "ThunderBolt", "beam", STORM, offset, Basis.IDENTITY, Vector3.ONE * 1.2)
			if bolt:
				bolt.set_meta("spawn_t", el)
			_quiet(func() -> void: SkillVfx.burst(p, "magic", o + offset, 1.2, STORM))
			next_bolt += bolt_interval
		for c: Node in root.get_children():
			if c.has_meta("spawn_t"):
				var age: float = el - (c as Node3D).get_meta("spawn_t")
				_fade(c, max(0.0, 1.0 - age / 0.35))
				if age > 0.35:
					c.queue_free()
		return true)


## 冰霜护盾：一圈冰晶板从地面升起围绕施法者，持续期间缓慢旋转；8 段加半球罩。
static func _frost_barrier(p: Node, o: Vector3, t: int, d: Dictionary) -> void:
	var root: Node3D = _root(p, o)
	var caster: Node3D = SkillVfx._player_by_slot(p.get_tree(), int(d.get("slot", 0)))
	var dur: float = float(d.get("aura_duration", 8.0))
	var count: int = 8 if t < 8 else 12
	for k in count:
		var a: float = k / float(count) * TAU
		_add(root, "FrostHex", "solid", FROST, _dir(a) * 2.5 + Vector3.DOWN * 1.5,
				Basis(Vector3.UP, a + PI * 0.5) * Basis(Vector3.RIGHT, randf_range(-0.15, 0.15)))
	var dome: MeshInstance3D = null
	if t >= 8:
		dome = _add(root, "FrostDome_B", "fresnel", Color(FROST, 0.4), Vector3.ZERO, Basis.IDENTITY, Vector3.ONE * 2.4)
		if dome:
			dome.scale = Vector3.ZERO
	SkillVfx._run(root, dur, func(el: float, dt: float) -> bool:
		if is_instance_valid(caster):
			root.global_position = Vector3(caster.global_position.x, 0.0, caster.global_position.z)
		root.rotation.y += dt * 0.3
		var i: int = 0
		for c: Node in root.get_children():
			if c == dome:
				continue
			var rise_t: float = clampf((el - i * 0.03) / 0.25, 0.0, 1.0)
			(c as Node3D).position.y = -1.5 + 2.3 * _back(rise_t)
			i += 1
		if dome:
			var dome_t: float = clampf(el / 0.4, 0.0, 1.0)
			dome.scale = Vector3.ONE * 2.4 * _out(dome_t)
			_fade(dome, 0.6)
		if el > dur - 0.4:
			_fade_all(root, (dur - el) / 0.4)
		return true)
	_quiet(func() -> void: SkillVfx.shockwave(p, o, 3.0, FROST, 0.35))


## 奥术弹幕：多颗紫色水晶碎片依次从施法者位置飞向目标点，命中后爆炸。
static func _arcane_barrage(p: Node, o: Vector3, _f: Vector3, t: int, d: Dictionary) -> void:
	var root: Node3D = _root(p, o)
	var impacts: Array = d.get("impacts", [])
	var count: int = maxi(int(d.get("projectiles", impacts.size())), impacts.size())
	if count == 0:
		return
	const HALO_R: float = 1.3
	const HALO_H: float = 2.4
	const CHARGE: float = 0.35  # 蓄力：水晶在头顶排成一圈旋转
	const GAP: float = 0.07     # 依次甩出的间隔
	const FLIGHT: float = 0.38
	var size: float = 2.2 if t < 5 else 3.0
	var shards: Array[MeshInstance3D] = []
	for k in count:
		var target: Vector3 = impacts[k] if k < impacts.size() else o + _dir(k / float(count) * TAU) * 9.0
		var sh: MeshInstance3D = _add(root, "ArcaneShard", "solid", ARCANE, Vector3.UP * HALO_H, Basis.IDENTITY, Vector3.ZERO)
		if sh == null:
			continue
		sh.set_meta("k", k)
		sh.set_meta("target", target - root.global_position + Vector3.UP * 0.6)
		sh.set_meta("side", randf_range(-2.5, 2.5))  # 弧线向左/右弯，同一个目标的几发不重叠
		shards.append(sh)
	var dur: float = CHARGE + GAP * count + FLIGHT + 0.1
	SkillVfx._run(root, dur, func(el: float, _dt: float) -> bool:
		for sh: MeshInstance3D in shards:
			if not is_instance_valid(sh):
				continue
			var k: int = sh.get_meta("k")
			var a: float = k / float(count) * TAU + el * 5.0
			var halo: Vector3 = _dir(a) * HALO_R + Vector3.UP * HALO_H
			var launch: float = CHARGE + GAP * k
			if el < launch:
				# 蓄力：从 0 放大，绕头顶旋转，尖端朝外
				sh.position = halo
				sh.basis = VfxKit.aim_basis(_dir(a)) * Basis.from_scale(Vector3.ONE * size * _out(el / 0.2))
				continue
			var ft: float = (el - launch) / FLIGHT
			var target: Vector3 = sh.get_meta("target")
			if ft >= 1.0:
				_quiet(func() -> void:
					SkillVfx.burst(p, "magic", root.global_position + target, 1.3, ARCANE)
					SkillVfx.pulse_ring(p, root.global_position + target, 1.2, Color(ARCANE, 0.8), 0.25))
				sh.queue_free()
				continue
			# 二次贝塞尔：头顶 → 斜上方控制点 → 目标
			var ctrl: Vector3 = (halo + target) * 0.5 + Vector3.UP * 2.5 + (target - halo).cross(Vector3.UP).normalized() * float(sh.get_meta("side"))
			var e: float = ft * ft  # 先慢后快
			var pos: Vector3 = halo.lerp(ctrl, e).lerp(ctrl.lerp(target, e), e)
			var nxt: Vector3 = halo.lerp(ctrl, minf(e + 0.05, 1.0)).lerp(ctrl.lerp(target, minf(e + 0.05, 1.0)), minf(e + 0.05, 1.0))
			sh.position = pos
			sh.basis = VfxKit.aim_basis(nxt - pos) * Basis.from_scale(Vector3(size * 0.8, size * 0.8, size * 1.6))  # 飞行时拉长
		return true)
	_quiet(func() -> void: SkillVfx.rune(p, o, 2.0, Color(ARCANE, 0.85), "flash", CHARGE + 0.3))


## 熔岩爆发：火山口 + 熔岩喷泉从地面喷出，5 段三柱，8 段更大范围。
static func _lava_blast(p: Node, o: Vector3, t: int, _d: Dictionary) -> void:
	var root: Node3D = _root(p, o)
	var dur: float = 1.2
	var crater: MeshInstance3D = _add(root, "LavaCrater", "solid", Color.WHITE, Vector3.ZERO, Basis.IDENTITY,
			Vector3.ONE * (3.5 if t < 8 else 5.0))
	var geyser_count: int = 1 if t < 5 else 3
	var geysers: Array[MeshInstance3D] = []
	for k in geyser_count:
		var offset: Vector3 = Vector3.ZERO if k == 0 else Vector3(randf_range(-1.8, 1.8), 0, randf_range(-1.8, 1.8))
		var g: MeshInstance3D = _add(root, "LavaGeyser", "beam", LAVA, offset, Basis.IDENTITY, Vector3(1, 0.01, 1))
		if g:
			g.set_meta("idx", k)
			geysers.append(g)
	SkillVfx._run(root, dur, func(el: float, _dt: float) -> bool:
		for g: MeshInstance3D in geysers:
			var k: int = g.get_meta("idx")
			var t_g: float = clampf((el - k * 0.15) / 0.3, 0.0, 1.0)
			g.scale.y = 1.6 * _out(t_g) if t_g < 1.0 else max(0.01, 1.6 - (el - k * 0.15 - 0.3) * 2.0)
		if crater:
			_fade(crater, 1.0 if el < dur - 0.5 else (dur - el) / 0.5)
		return true)
	_quiet(func() -> void:
		SkillVfx.burst(p, "fire", o + Vector3.UP * 0.8, 3.0, LAVA)
		SkillVfx.crack_decal(p, o, 4.0 if t < 8 else 5.5, LAVA, dur))


# ============================================================ 影行者

## 剔骨：三道暗影爪痕扫过目标，5 段加血液飞溅，8 段处决时爆红光柱。
static func _eviscerate(p: Node, _o: Vector3, t: int, d: Dictionary) -> void:
	if not d.has("center"):
		return
	# 俯视镜头：爪痕平放在离地 1 米处、朝镜头倾斜一点；竖起来的话只看得到一条边
	var root: Node3D = _root(p, d.center)
	var hits: int = 2 if t < 3 else (3 if t < 8 else 4)  # 段位越高爪痕越多
	var tint: Color = BLOOD if bool(d.get("executed", false)) else Color(1.0, 0.35, 0.5)
	var base_yaw: float = randf() * TAU
	var parts: Array[MeshInstance3D] = []
	for k in hits:
		var rot: Basis = Basis(Vector3.UP, base_yaw + k * TAU / hits * 0.37) * Basis(Vector3.RIGHT, -0.35)
		var claw: MeshInstance3D = _add(root, "ShadowClaw", "slash", tint, Vector3.UP * 1.0, rot, Vector3.ZERO)
		if claw:
			claw.set_meta("delay", k * 0.09)
			parts.append(claw)
	var spray: MeshInstance3D = null
	if t >= 5:
		spray = _add(root, "BloodSpray", "solid", BLOOD, Vector3.UP * 1.0, Basis.IDENTITY, Vector3.ZERO)
	var dur: float = 0.09 * hits + 0.45
	SkillVfx._run(root, dur, func(el: float, _dt: float) -> bool:
		for c: MeshInstance3D in parts:
			var lt: float = (el - float(c.get_meta("delay"))) / 0.3
			if lt < 0.0:
				continue
			c.scale = Vector3.ONE * 2.6 * (1.0 + 0.25 * _out(lt))
			_progress(c, clampf(lt, 0.0, 1.0))
			_fade(c, clampf(1.6 - lt, 0.0, 1.0))
		if spray:
			var st: float = clampf((el - 0.12) / 0.45, 0.0, 1.0)
			spray.scale = Vector3.ONE * (0.01 + 3.2 * _out(st))
			spray.position.y = 1.0 - 0.8 * st * st
			_fade(spray, 1.0 - st)
		return true)
	_quiet(func() -> void:
		SkillVfx.burst(p, "spark", d.center + Vector3.UP * 1.0, 1.2, tint)
		if t >= 8 and bool(d.get("executed", false)):
			SkillVfx.pillar(p, d.center, 1.2, 5.0, Color(BLOOD, 0.95)))

## 暗影分身：施法者的紫色剪影分身（用角色自己的模型），绕施法者游走，每 0.6 秒挥出一道暗影斩；
## 持续整个技能时长。5 段两个分身，8 段三个且斩击变红。
static func _shadow_clone(p: Node, o: Vector3, t: int, d: Dictionary) -> void:
	var root: Node3D = _root(p, o)
	var caster: Node3D = SkillVfx._player_by_slot(p.get_tree(), int(d.get("slot", 0)))
	var body: Mesh = caster.get("ghost_mesh") if is_instance_valid(caster) else null
	var count: int = 1 if t < 5 else (2 if t < 8 else 3)
	var dur: float = float(d.get("duration", 8.0))
	var orbit: float = float(d.get("radius", 3.5)) * 0.45
	var slash_tint: Color = BLOOD if t >= 8 else SHADOW
	var clones: Array[MeshInstance3D] = []
	for k in count:
		var c: MeshInstance3D = VfxKit.spawn(root, body, "fresnel", Color(SHADOW, 1.0)) if body != null \
				else _add(root, "ShadowVeil", "fresnel", SHADOW)
		if c:
			c.set_meta("phase", k / float(count) * TAU)
			clones.append(c)
	var slashes: Array[MeshInstance3D] = []
	var next_slash: Array = [0.15]  # 数组包一层：lambda 里只能改容器内容
	SkillVfx._run(root, dur, func(el: float, dt: float) -> bool:
		if is_instance_valid(caster):
			root.global_position = Vector3(caster.global_position.x, 0.0, caster.global_position.z)
		var appear: float = _out(el / 0.3)
		var vanish: float = clampf((dur - el) / 0.4, 0.0, 1.0)
		for c: MeshInstance3D in clones:
			var a: float = float(c.get_meta("phase")) + el * 1.6
			c.position = _dir(a) * orbit * appear + Vector3.UP * (0.15 * sin(el * 4.0 + a))
			c.basis = Basis(Vector3.UP, a + PI * 0.5)  # 面朝绕行方向
			_fade(c, 0.9 * minf(appear, vanish) * (0.75 + 0.25 * sin(el * 9.0 + a)))  # 轻微闪烁
		if el >= next_slash[0] and el < dur - 0.4:
			next_slash[0] += 0.6
			for c: MeshInstance3D in clones:
				var s: MeshInstance3D = _add(root, "kit:SlashArc", "slash", slash_tint, c.position + Vector3.UP * 0.9,
						c.basis * Basis(Vector3.FORWARD, randf_range(-0.6, 0.6)), Vector3.ONE * 1.6)
				if s:
					s.set_meta("born", el)
					slashes.append(s)
		for s: MeshInstance3D in slashes:
			if is_instance_valid(s):
				var age: float = (el - float(s.get_meta("born"))) / 0.25
				_progress(s, age)
				if age >= 1.0:
					s.queue_free()
		return true)
	_quiet(func() -> void:
		SkillVfx.burst(p, "smoke", o + Vector3.UP * 1.0, 1.8, Color(0.3, 0.2, 0.45, 0.8))
		SkillVfx.rune(p, o, orbit + 1.0, Color(SHADOW, 0.8), "flash", 0.6))

## 背刺：巨大匕首从背后刺穿目标 + 血液飞溅，3 段金光爆闪，8 段击杀时红柱。
static func _backstab(p: Node, _o: Vector3, f: Vector3, t: int, d: Dictionary) -> void:
	if not d.has("center"):
		return
	# 根节点放在目标脚下，下面全部用局部坐标。vfx_kit 的 Dagger 刀尖朝 -Z，aim_basis(facing) 让刀尖指向 facing。
	var root: Node3D = _root(p, d.center)
	var facing: Vector3 = f if f.length_squared() > 0.01 else Vector3.FORWARD
	var start: Vector3 = -facing * 3.0 + Vector3.UP * 1.3   # 目标背后
	var stop: Vector3 = facing * 1.2 + Vector3.UP * 1.0     # 刀尖穿出目标前方
	var size: float = 4.0 if t < 5 else 5.5
	var dagger: MeshInstance3D = _add(root, "kit:Dagger", "solid", Color(0.75, 0.2, 0.35) if t < 8 else BLOOD,
			start, VfxKit.aim_basis(facing), Vector3.ZERO)
	var trail: MeshInstance3D = _add(root, "kit:SlashArc", "slash", Color(SHADOW, 1.0), Vector3.UP * 1.1,
			VfxKit.facing_basis(facing), Vector3(0.6, 1.0, 2.2))
	var spray: MeshInstance3D = _add(root, "BloodSpray", "solid", BLOOD, Vector3.UP * 1.0, VfxKit.facing_basis(facing), Vector3.ZERO)
	var dur: float = 0.55
	SkillVfx._run(root, dur, func(el: float, _dt: float) -> bool:
		var thrust: float = _out(clampf(el / 0.16, 0.0, 1.0))
		if dagger:
			dagger.position = start.lerp(stop, thrust)
			dagger.basis = VfxKit.aim_basis(facing) * Basis.from_scale(Vector3.ONE * size * clampf(el / 0.06, 0.2, 1.0))
			_fade(dagger, clampf((dur - el) / 0.2, 0.0, 1.0))
		if trail:
			_progress(trail, clampf(el / 0.2, 0.0, 1.0))
		if spray:
			var st: float = clampf((el - 0.14) / 0.35, 0.0, 1.0)
			spray.position = Vector3.UP * 1.0 + facing * 1.2 * st
			spray.scale = Vector3.ONE * (0.01 + 3.0 * _out(st))
			_fade(spray, 1.0 - st)
		return true)
	_quiet(func() -> void:
		SkillVfx.pulse_ring(p, d.center, 1.5, Color(BLOOD, 0.9), 0.3)
		if t >= 3:
			SkillVfx.rune(p, d.center, 1.3, Color(1.0, 0.85, 0.35, 0.95), "flash", 0.35)
		if t >= 8 and int(d.get("killed", 0)) > 0:
			SkillVfx.pillar(p, d.center, 1.2, 5.0, Color(BLOOD, 0.95)))

## 毒刃：毒液滴从施法者飞向目标链，命中后炸开绿色毒雾，8 段留下持续毒云。
static func _poison_blade(p: Node, o: Vector3, t: int, d: Dictionary) -> void:
	var root: Node3D = _root(p, o)
	var links: Array = d.get("links", [])
	var dur: float = 0.08 * links.size() + 0.5
	var drops: Array[MeshInstance3D] = []
	var size: float = 3.2 if t < 5 else 4.2
	SkillVfx._run(root, dur, func(el: float, _dt: float) -> bool:
		var idx: int = int(el / 0.08)
		var prev_idx: int = int((el - _dt) / 0.08)
		if idx > prev_idx and idx <= links.size():
			var link: Array = links[idx - 1]
			if link.size() >= 2:
				var target: Vector3 = link[1]
				var dir: Vector3 = (target - o).normalized()
				var drop: MeshInstance3D = _add(root, "PoisonDrop", "solid", VENOM, o + Vector3.UP * 1.3,
						VfxKit.aim_basis(dir), Vector3.ONE * size)
				if drop:
					drop.set_meta("target", target)
					drop.set_meta("spawn_t", el)
					drop.set_meta("duration", o.distance_to(target) / 16.0)
					drop.rotation.y = randf() * TAU
					drops.append(drop)
				# 绿色拖尾让飞行轨迹更明显
				_quiet(func() -> void: SkillVfx.dash_trail(p, o + Vector3.UP * 1.3, target + Vector3.UP * 0.5, 0.25, Color(VENOM, 0.5)))
		for dr: MeshInstance3D in drops:
			if not is_instance_valid(dr):
				continue
			var age: float = el - dr.get_meta("spawn_t")
			var flight_dur: float = dr.get_meta("duration")
			if age <= flight_dur:
				dr.global_position = o + Vector3.UP * 1.3 + (dr.get_meta("target") - o) * (age / flight_dur)
				dr.rotation.y += _dt * 8.0
			else:
				_quiet(func() -> void:
					SkillVfx.burst(p, "smoke", dr.get_meta("target") + Vector3.UP * 0.5, 1.2, Color(VENOM, 0.85))
					SkillVfx.pulse_ring(p, dr.get_meta("target"), 1.0, Color(VENOM, 0.7), 0.25))
				dr.queue_free()
		return true)


# ============================================================ 牧师

## 守护天使：一对光翼在施法者位置展开，持续期间缓慢扇动，5 段更大，8 段金色光环。
static func _guardian_angel(p: Node, o: Vector3, t: int, d: Dictionary) -> void:
	var root: Node3D = _root(p, o)
	var dur: float = float(d.get("aura_duration", 10.0))
	var scale_base: float = 1.8 if t < 5 else 2.3  # 俯视镜头约 28 米远，翼展要 6-8 米才看得出形状
	for side in [-1, 1]:
		# HolyWing 模型是右翼（+X 方向展开），左翼通过 scale.x = -1 镜像
		# 翅膀竖在 XZ 平面，Godot 的 Y 轴朝上，所以不旋转，直接放在背后肩高位置
		var pivot: Node3D = Node3D.new()
		pivot.name = "WingPivot_%d" % side
		pivot.position = Vector3(side * 0.25, 1.4, 0.3)  # 肩后（+Z 是角色背后：截图时角色朝 -Z）
		root.add_child(pivot)
		var wing: MeshInstance3D = _add(pivot, "HolyWing", "solid", HOLY, Vector3.ZERO, Basis.IDENTITY,
				Vector3(side * scale_base, scale_base, scale_base))
		if wing:
			pivot.set_meta("side", side)
			pivot.set_meta("wing", wing)
	SkillVfx._run(root, dur, func(el: float, _dt: float) -> bool:
		for c: Node in root.get_children():
			if not c.has_meta("side"):
				continue
			var side: int = c.get_meta("side", 1)
			var flap: float = sin(el * 2.5) * 0.18
			# 扇动：绕 Y 轴旋转（翅膀根部向前/向后摆动）
			(c as Node3D).rotation.y = side * (0.3 + flap)
		if el > dur - 0.5:
			_fade_all(root, (dur - el) / 0.5)
		return true)
	_quiet(func() -> void: SkillVfx.rune(p, o, 2.2, HOLY, "expand", 0.5, "holy_sigil"))
	if t >= 8:
		_quiet(func() -> void: SkillVfx.burst(p, "star", o + Vector3.UP * 2.0, 1.5, HOLY))

## 净化：莲花从地面绽放并旋转，同时扩散冲击波，5 段双层莲花，8 段加圣光柱。
static func _purify(p: Node, o: Vector3, t: int, _d: Dictionary) -> void:
	var root: Node3D = _root(p, o)
	var dur: float = 0.9
	var lotus1: MeshInstance3D = _add(root, "PurifyLotus", "solid", HOLY, Vector3.ZERO, Basis.IDENTITY, Vector3.ONE * 0.5)
	var lotus2: MeshInstance3D = null
	if t >= 5:
		lotus2 = _add(root, "PurifyLotus", "solid", Color(HOLY, 0.7), Vector3.ZERO, Basis.IDENTITY, Vector3.ONE * 0.3)
	SkillVfx._run(root, dur, func(el: float, _dt: float) -> bool:
		var prog: float = el / dur
		if lotus1:
			lotus1.rotation.y = prog * TAU
			lotus1.scale = Vector3.ONE * (0.5 + 4.5 * _out(prog))
			_fade(lotus1, 1.0 - prog)
		if lotus2:
			lotus2.rotation.y = -prog * TAU * 1.5
			lotus2.scale = Vector3.ONE * (0.3 + 4.2 * _out(prog))
			_fade(lotus2, 1.0 - prog)
		return true)
	_quiet(func() -> void:
		SkillVfx.burst(p, "star", o + Vector3.UP * 0.5, 2.5, HOLY)
		SkillVfx.shockwave(p, o, 3.5, HOLY, 0.7))
	if t >= 8:
		_quiet(func() -> void: SkillVfx.pillar(p, o, 1.0, 6.0, Color(HOLY, 0.85)))

## 复活术：在每个目标位置升起光柱 + 翅膀，5 段更高更亮，8 段金色冲天光束。
static func _resurrection(p: Node, o: Vector3, t: int, d: Dictionary) -> void:
	var healed: Array = d.get("healed", [])
	if healed.is_empty():
		healed = [o]
	for pos: Vector3 in healed:
		var root: Node3D = _root(p, pos)
		var dur: float = 1.8
		var h: float = 1.2 if t < 5 else 1.6
		var spire: MeshInstance3D = _add(root, "ResurrectionSpire", "beam", HOLY, Vector3.ZERO, Basis.IDENTITY, Vector3.ONE)
		var wings: MeshInstance3D = _add(root, "HolyWing", "solid", Color(HOLY, 0.9), Vector3.UP * 0.8, Basis.IDENTITY, Vector3.ZERO)
		if spire:
			spire.scale = Vector3(1.5, 0.01, 1.5)
		SkillVfx._run(root, dur, func(el: float, _dt: float) -> bool:
			var rise_t: float = clampf(el / 0.7, 0.0, 1.0)
			var fade_t: float = clampf((dur - el) / 0.6, 0.0, 1.0)
			if spire:
				spire.scale.y = h * _out(rise_t)
				_fade(spire, fade_t)
			if wings:
				wings.scale = Vector3.ONE * 2.2 * _out(rise_t * 0.8)
				wings.rotation.y = el * 1.2
				_fade(wings, fade_t * 0.85)
			return true)
		_quiet(func() -> void:
			SkillVfx.burst(p, "star", pos + Vector3.UP * 1.5, 1.8, HOLY)
			SkillVfx.pulse_ring(p, pos, 2.0, Color(HOLY, 0.85), 0.5))
		if t >= 8:
			_quiet(func() -> void: SkillVfx.pillar(p, pos, 1.4, 9.0, Color(HOLY, 0.95)))

## 圣怒：圣剑从天而降插入目标位置，5 段三剑，8 段加金色符文爆炸。
static func _holy_wrath(p: Node, _o: Vector3, t: int, d: Dictionary) -> void:
	if not d.has("center"):
		return
	var root: Node3D = _root(p, d.center)
	var dur: float = 1.0
	var count: int = 1 if t < 5 else 3
	var blade_size: float = 3.0 if t < 5 else 3.8
	for k in count:
		var offset: Vector3 = Vector3.ZERO if k == 0 else Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
		var blade: MeshInstance3D = _add(root, "HolyBlade", "solid", HOLY, offset + Vector3.UP * 9.0,
				Basis.IDENTITY, Vector3.ONE * blade_size * (1.0 if k == 0 else 0.75))
		if blade:
			blade.set_meta("idx", k)
			blade.set_meta("offset", offset)
			blade.set_meta("size", blade_size * (1.0 if k == 0 else 0.75))
	SkillVfx._run(root, dur, func(el: float, _dt: float) -> bool:
		for c: Node in root.get_children():
			var k: int = (c as Node3D).get_meta("idx", 0)
			var drop_t: float = clampf((el - k * 0.15) / 0.35, 0.0, 1.0)
			var offset: Vector3 = (c as Node3D).get_meta("offset", Vector3.ZERO)
			var sz: float = (c as Node3D).get_meta("size", 1.0)
			var h: float = 9.0 * (1.0 - drop_t * drop_t * drop_t)
			(c as Node3D).position = offset + Vector3.UP * maxf(h, 0.15)
			# 剑插入地面后留一小段，然后淡出
			if drop_t >= 1.0:
				(c as Node3D).scale = Vector3.ONE * sz * (1.0 if h > 0.2 else clampf((h - 0.1) / 0.1, 0.3, 1.0))
				_fade(c, clampf(1.2 - (el - k * 0.15 - 0.35) / 0.45, 0.0, 1.0))
		return true)
	_quiet(func() -> void:
		SkillVfx.burst(p, "magic", d.center + Vector3.UP * 0.5, 2.8, HOLY)
		SkillVfx.shockwave(p, d.center, 3.5, HOLY, 0.7))
	if t >= 8:
		_quiet(func() -> void: SkillVfx.rune(p, d.center, 4.0, Color(HOLY, 0.95), "flash", 0.9, "holy_sigil"))



