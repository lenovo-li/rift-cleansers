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
	var cloud: MeshInstance3D = _add(root, "ThunderCloud", "solid", Color(0.25, 0.3, 0.5), Vector3.UP * 8.5, Basis.IDENTITY, Vector3(8, 1.2, 8))
	var bolt_count: int = 3 if t < 5 else (5 if t < 8 else 7)
	var bolt_interval: float = dur / float(bolt_count)
	SkillVfx._run(root, dur, func(el: float, dt: float) -> bool:
		if cloud:
			cloud.rotation.y += dt * 0.4
			_fade(cloud, 1.0 if el < dur - 0.3 else (dur - el) / 0.3)
		var bolt_idx: int = int(el / bolt_interval)
		var prev_idx: int = int((el - dt) / bolt_interval)
		if bolt_idx > prev_idx and bolt_idx < bolt_count:
			var offset: Vector3 = Vector3(randf_range(-7, 7), 0, randf_range(-7, 7))
			var bolt: MeshInstance3D = _add(root, "ThunderBolt", "beam", STORM, offset)
			if bolt:
				bolt.set_meta("spawn_t", el)
			_quiet(func() -> void: SkillVfx.burst(p, "magic", o + offset, 1.0, STORM))
		for c: Node in root.get_children():
			if c.has_meta("spawn_t"):
				var age: float = el - (c as Node3D).get_meta("spawn_t")
				_fade(c, max(0.0, 1.0 - age / 0.3))
				if age > 0.3:
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
		dome = _add(root, "FrostDome_B", "fresnel", FROST, Vector3.ZERO, Basis.IDENTITY, Vector3.ONE * 2.4)
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
	var dur: float = 0.1 * impacts.size() + 0.6
	var shards: Array[MeshInstance3D] = []
	SkillVfx._run(root, dur, func(el: float, _dt: float) -> bool:
		var idx: int = int(el / 0.1)
		var prev_idx: int = int((el - _dt) / 0.1)
		if idx > prev_idx and idx <= impacts.size():
			var target: Vector3 = impacts[idx - 1]
			var dir: Vector3 = (target - o).normalized()
			var shard: MeshInstance3D = _add(root, "ArcaneShard", "solid", ARCANE, o + Vector3.UP * 1.5,
					VfxKit.aim_basis(dir), Vector3.ONE * (1.0 if t < 5 else 1.3))
			if shard:
				shard.set_meta("target", target)
				shard.set_meta("spawn_t", el)
				shard.set_meta("duration", o.distance_to(target) / 18.0)
				shards.append(shard)
		for sh: MeshInstance3D in shards:
			if not is_instance_valid(sh):
				continue
			var age: float = el - sh.get_meta("spawn_t")
			var flight_dur: float = sh.get_meta("duration")
			if age <= flight_dur:
				var prog: float = age / flight_dur
				sh.global_position = o + Vector3.UP * 1.5 + (sh.get_meta("target") - o) * prog
			else:
				_quiet(func() -> void: SkillVfx.burst(p, "magic", sh.get_meta("target") + Vector3.UP * 0.5, 0.8, ARCANE))
				sh.queue_free()
		return true)


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
	var root: Node3D = _root(p, d.center)
	var dur: float = 0.5
	var claw: MeshInstance3D = _add(root, "ShadowClaw", "slash", Color(0.9, 0.2, 0.3), Vector3.ZERO,
			Basis(Vector3.UP, randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.5), Vector3.ONE * 1.6)
	SkillVfx._run(root, dur, func(el: float, _dt: float) -> bool:
		if claw:
			_progress(claw, clampf(el / 0.35, 0.0, 1.0))
			_fade(claw, 1.0 - el / dur)
		return true)
	if t >= 5:
		var spray: MeshInstance3D = _add(root, "BloodSpray", "solid", BLOOD, Vector3.UP * 1.0)
		if spray:
			SkillVfx._run(spray, 0.4, func(el: float, _dt: float) -> bool:
				spray.position.y = 1.0 - el * 1.5
				spray.scale = Vector3.ONE * (1.0 + el * 2.0)
				_fade(spray, 1.0 - el / 0.4)
				return true)
	if t >= 8 and d.get("executed", false):
		_quiet(func() -> void: SkillVfx.pillar(p, d.center, 1.2, 5.0, Color(BLOOD, 0.95)))

## 暗影分身：暗影雾气在施法者位置爆开，3 段持续更久，5 段双重，8 段三重雾团。
static func _shadow_clone(p: Node, o: Vector3, t: int, _d: Dictionary) -> void:
	var root: Node3D = _root(p, o)
	var count: int = 1 if t < 5 else (2 if t < 8 else 3)
	var dur: float = 0.6
	for k in count:
		var veil: MeshInstance3D = _add(root, "ShadowVeil", "fresnel", SHADOW, Vector3(k * 0.5, 0, 0))
		if veil:
			veil.set_meta("idx", k)
	SkillVfx._run(root, dur, func(el: float, _dt: float) -> bool:
		for c: Node in root.get_children():
			var k: int = (c as Node3D).get_meta("idx", 0)
			var t_v: float = clampf((el - k * 0.08) / 0.5, 0.0, 1.0)
			(c as Node3D).scale = Vector3.ONE * (0.8 + 0.7 * _out(t_v))
			_fade(c, 0.7 * (1.0 - t_v))
		return true)
	_quiet(func() -> void: SkillVfx.burst(p, "smoke", o + Vector3.UP * 1.2, 1.5, SHADOW))

## 背刺：爪痕从背后刺穿目标 + 血液飞溅，3 段金光爆闪，8 段处决时红柱。
static func _backstab(p: Node, _o: Vector3, f: Vector3, t: int, d: Dictionary) -> void:
	if not d.has("center"):
		return
	var root: Node3D = _root(p, d.center)
	var dur: float = 0.4
	var rot: Basis = VfxKit.aim_basis(f) * Basis(Vector3.RIGHT, PI * 0.5)
	var claw: MeshInstance3D = _add(root, "ShadowClaw", "slash", Color(0.9, 0.5, 0.6), Vector3.ZERO, rot, Vector3.ONE * 1.0)
	var spray: MeshInstance3D = _add(root, "BloodSpray", "solid", BLOOD, Vector3.UP * 0.8, Basis.IDENTITY, Vector3.ONE * 0.8)
	SkillVfx._run(root, dur, func(el: float, _dt: float) -> bool:
		if claw:
			_progress(claw, clampf(el / 0.3, 0.0, 1.0))
			_fade(claw, 1.0 - el / dur)
		if spray:
			_fade(spray, 1.0 - el / dur)
		return true)
	if t >= 3:
		_quiet(func() -> void: SkillVfx.rune(p, d.center, 1.2, Color(1.0, 0.8, 0.3, 0.9), "flash", 0.3))
	if t >= 8 and d.get("killed", 0) > 0:
		_quiet(func() -> void: SkillVfx.pillar(p, d.center, 0.9, 4.0, Color(BLOOD, 0.9)))

## 毒刃：毒液滴从施法者飞向目标链，命中后炸开绿色毒雾，8 段留下持续毒云。
static func _poison_blade(p: Node, o: Vector3, t: int, d: Dictionary) -> void:
	var root: Node3D = _root(p, o)
	var links: Array = d.get("links", [])
	var dur: float = 0.08 * links.size() + 0.5
	var drops: Array[MeshInstance3D] = []
	SkillVfx._run(root, dur, func(el: float, _dt: float) -> bool:
		var idx: int = int(el / 0.08)
		var prev_idx: int = int((el - _dt) / 0.08)
		if idx > prev_idx and idx <= links.size():
			var link: Array = links[idx - 1]
			if link.size() >= 2:
				var target: Vector3 = link[1]
				var dir: Vector3 = (target - o).normalized()
				var drop: MeshInstance3D = _add(root, "PoisonDrop", "solid", VENOM, o + Vector3.UP * 1.3,
						VfxKit.aim_basis(dir), Vector3.ONE * 1.2)
				if drop:
					drop.set_meta("target", target)
					drop.set_meta("spawn_t", el)
					drop.set_meta("duration", o.distance_to(target) / 16.0)
					drop.rotation.y = randf() * TAU
					drops.append(drop)
		for dr: MeshInstance3D in drops:
			if not is_instance_valid(dr):
				continue
			var age: float = el - dr.get_meta("spawn_t")
			var flight_dur: float = dr.get_meta("duration")
			if age <= flight_dur:
				dr.global_position = o + Vector3.UP * 1.3 + (dr.get_meta("target") - o) * (age / flight_dur)
				dr.rotation.y += _dt * 8.0
			else:
				_quiet(func() -> void: SkillVfx.burst(p, "smoke", dr.get_meta("target") + Vector3.UP * 0.5, 0.7, VENOM))
				dr.queue_free()
		return true)


# ============================================================ 牧师

## 守护天使：一对光翼在施法者位置展开，持续期间缓慢扇动，5 段更大，8 段金色光环。
static func _guardian_angel(p: Node, o: Vector3, t: int, d: Dictionary) -> void:
	var root: Node3D = _root(p, o)
	var dur: float = float(d.get("aura_duration", 10.0))
	var scale_base: float = 1.0 if t < 5 else 1.3
	for side in [-1, 1]:
		var wing: MeshInstance3D = _add(root, "HolyWing", "solid", HOLY, Vector3(side * 0.6, 1.5, -0.3),
				Basis(Vector3.UP, PI if side < 0 else 0.0), Vector3(side, 1, 1) * scale_base)
		if wing:
			wing.set_meta("side", side)
	SkillVfx._run(root, dur, func(el: float, dt: float) -> bool:
		for c: Node in root.get_children():
			var side: int = (c as Node3D).get_meta("side", 1)
			var flap: float = sin(el * 3.0) * 0.15
			(c as Node3D).rotation.z = side * (0.2 + flap)
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
static func _resurrection(p: Node, _o: Vector3, t: int, d: Dictionary) -> void:
	var guarded: Array = d.get("guarded", [])
	if guarded.is_empty():
		guarded = [o]
	for pos: Vector3 in guarded:
		var root: Node3D = _root(p, pos)
		var dur: float = 1.6
		var spire: MeshInstance3D = _add(root, "ResurrectionSpire", "beam", HOLY, Vector3.ZERO, Basis.IDENTITY,
				Vector3.ONE * (0.8 if t < 5 else 1.0))
		if spire:
			spire.scale.y = 0.01
		SkillVfx._run(root, dur, func(el: float, _dt: float) -> bool:
			if spire:
				var rise_t: float = clampf(el / 0.6, 0.0, 1.0)
				spire.scale.y = (0.8 if t < 5 else 1.2) * _out(rise_t)
				if el > dur - 0.5:
					_fade(spire, (dur - el) / 0.5)
			return true)
		_quiet(func() -> void: SkillVfx.burst(p, "star", pos + Vector3.UP * 1.8, 1.5, HOLY))
		if t >= 8:
			_quiet(func() -> void: SkillVfx.pillar(p, pos, 1.2, 8.0, Color(HOLY, 0.9)))

## 圣怒：圣剑从天而降插入目标位置，5 段三剑，8 段加金色符文爆炸。
static func _holy_wrath(p: Node, _o: Vector3, t: int, d: Dictionary) -> void:
	if not d.has("center"):
		return
	var root: Node3D = _root(p, d.center)
	var dur: float = 0.8
	var count: int = 1 if t < 5 else 3
	for k in count:
		var offset: Vector3 = Vector3.ZERO if k == 0 else Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
		var blade: MeshInstance3D = _add(root, "HolyBlade", "solid", HOLY, offset + Vector3.UP * 7.0,
				Basis.IDENTITY, Vector3.ONE * (1.0 if k == 0 else 0.8))
		if blade:
			blade.set_meta("idx", k)
			blade.set_meta("offset", offset)
	SkillVfx._run(root, dur, func(el: float, _dt: float) -> bool:
		for c: Node in root.get_children():
			var k: int = (c as Node3D).get_meta("idx", 0)
			var drop_t: float = clampf((el - k * 0.12) / 0.25, 0.0, 1.0)
			var offset: Vector3 = (c as Node3D).get_meta("offset", Vector3.ZERO)
			(c as Node3D).position = offset + Vector3.UP * (7.0 * (1.0 - drop_t * drop_t))
			if drop_t >= 1.0:
				_fade(c, max(0.0, 1.0 - (el - k * 0.12 - 0.25) / 0.4))
		return true)
	_quiet(func() -> void:
		SkillVfx.burst(p, "magic", d.center + Vector3.UP * 0.5, 2.5, HOLY)
		SkillVfx.shockwave(p, d.center, 3.0, HOLY, 0.6))
	if t >= 8:
		_quiet(func() -> void: SkillVfx.rune(p, d.center, 3.5, Color(HOLY, 0.95), "flash", 0.8, "holy_sigil"))



