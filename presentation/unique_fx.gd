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


# ============================================================ 元素术士 + 影行者 + 牧师（占位实现，后续优化）

static func _thunderstorm(p: Node, o: Vector3, _t: int, _d: Dictionary) -> void:
	_quiet(func() -> void: SkillVfx.burst(p, "magic", o + Vector3.UP * 3.0, 8.0, STORM))

static func _frost_barrier(p: Node, o: Vector3, _t: int, _d: Dictionary) -> void:
	_quiet(func() -> void: SkillVfx.shockwave(p, o, 2.5, FROST, 0.4))

static func _arcane_barrage(p: Node, o: Vector3, _f: Vector3, _t: int, d: Dictionary) -> void:
	for pos: Vector3 in d.get("impacts", []):
		_quiet(func() -> void: SkillVfx.burst(p, "magic", pos + Vector3.UP * 0.5, 0.8, ARCANE))

static func _lava_blast(p: Node, o: Vector3, _t: int, _d: Dictionary) -> void:
	_quiet(func() -> void: SkillVfx.burst(p, "fire", o + Vector3.UP * 0.8, 3.0, LAVA))

static func _eviscerate(p: Node, _o: Vector3, _t: int, d: Dictionary) -> void:
	if d.has("center"):
		_quiet(func() -> void: SkillVfx.burst(p, "smoke", d.center + Vector3.UP * 0.5, 1.0, BLOOD))

static func _shadow_clone(p: Node, o: Vector3, _t: int, _d: Dictionary) -> void:
	_quiet(func() -> void: SkillVfx.burst(p, "smoke", o + Vector3.UP * 1.0, 1.2, SHADOW))

static func _backstab(p: Node, _o: Vector3, _f: Vector3, _t: int, d: Dictionary) -> void:
	if d.has("center"):
		_quiet(func() -> void: SkillVfx.burst(p, "smoke", d.center + Vector3.UP * 0.6, 0.8, BLOOD))

static func _poison_blade(p: Node, _o: Vector3, _t: int, d: Dictionary) -> void:
	for link: Array in d.get("links", []):
		if link.size() >= 2:
			_quiet(func() -> void: SkillVfx.burst(p, "smoke", link[1] + Vector3.UP * 0.5, 0.6, VENOM))

static func _guardian_angel(p: Node, o: Vector3, _t: int, _d: Dictionary) -> void:
	_quiet(func() -> void: SkillVfx.rune(p, o, 2.0, HOLY, "expand", 0.5, "holy_sigil"))

static func _purify(p: Node, o: Vector3, _t: int, _d: Dictionary) -> void:
	_quiet(func() -> void:
		SkillVfx.burst(p, "star", o + Vector3.UP * 0.5, 2.0, HOLY)
		SkillVfx.shockwave(p, o, 3.0, HOLY, 0.6))

static func _resurrection(p: Node, _o: Vector3, _t: int, d: Dictionary) -> void:
	for pos: Vector3 in d.get("healed", []):
		_quiet(func() -> void: SkillVfx.pillar(p, pos, 0.8, 4.0, HOLY))

static func _holy_wrath(p: Node, _o: Vector3, _t: int, d: Dictionary) -> void:
	if d.has("center"):
		_quiet(func() -> void:
			SkillVfx.burst(p, "magic", d.center + Vector3.UP * 0.5, 2.0, HOLY)
			SkillVfx.shockwave(p, d.center, 2.5, HOLY, 0.5))


