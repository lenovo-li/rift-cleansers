class_name MapLayouts extends RefCounted
## 每张地图的确定性布局（只用 map.rng，主机和客户端一致）。零件名对应各自 glb 里的网格。


static func build(map: MapBase, layout: String) -> void:
	match layout:
		"frost": _frost(map)
		"desert": _desert(map)
		"forest": _forest(map)
		_: _ashen(map)


## 灰烬王城：中央王像 + 石柱环 → 半径 38 米的内城残墙（8 段、留缺口）→ 四角残塔 → 外圈散落 → 边缘城墙。
static func _ashen(m: MapBase) -> void:
	m.add("statue", Vector3(0, 0, -22), 0.0)
	for i in 10:
		var a: float = TAU * i / 10.0 + 0.3
		m.add("pillar" if i % 3 != 1 else "pillar_broken", Vector3(cos(a), 0, sin(a)) * 19.0, a)
	for i in 8:
		var a: float = TAU * i / 8.0 + PI / 8.0
		var tangent: float = -a + PI / 2.0
		var c: Vector3 = Vector3(cos(a), 0, sin(a)) * 38.0
		var side: Vector3 = Vector3(cos(a + PI / 2.0), 0, sin(a + PI / 2.0))
		m.add("wall", c - side * 3.2, tangent)
		m.add("wall_broken" if i % 2 == 0 else "wall", c + side * 3.6, tangent)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			m.add("tower", Vector3(sx * 64.0, 0, sz * 64.0), m.rng.randf() * TAU)
	var budget: Dictionary = {"rubble": 34, "pillar_broken": 18, "brazier": 14, "wall_broken": 10}
	for piece: String in budget:
		m.scatter({piece: budget[piece]}, 6.0 if piece != "brazier" else 3.0)
	for i in 4:
		var a: float = TAU * i / 4.0
		m.add("brazier", Vector3(cos(a), 0, sin(a)) * 30.0, 0.0)
	m.border("wall", "wall_broken")


## 霜冻冰原：中央冰图腾 + 6 根冰刺环 → 三道弧形冰墙 → 雪松林带（外圈密）→ 散落雪岩与冰晶 → 边缘冰墙。
static func _frost(m: MapBase) -> void:
	m.add("totem", Vector3(0, 0, -18), 0.0)
	for i in 6:
		var a: float = TAU * i / 6.0
		m.add("ice_spire", Vector3(cos(a), 0, sin(a)) * 22.0, a)
	for i in 3:
		var a: float = TAU * i / 3.0 + 0.5
		for k in 3:
			var aa: float = a + (k - 1) * 0.17
			m.add("frozen_wall", Vector3(cos(aa), 0, sin(aa)) * 42.0, -aa + PI / 2.0)
	for i in 70:
		var a: float = m.rng.randf() * TAU
		var r: float = m.rng.randf_range(50.0, 90.0)
		var p: Vector3 = Vector3(cos(a), 0, sin(a)) * r
		if absf(p.x) < 90.0 and absf(p.z) < 90.0 and m.free_for(p, 3.5):
			m.add("pine", p, m.rng.randf() * TAU)
	m.scatter({"ice_rock": 30, "ice_spire": 10}, 6.0)
	m.scatter({"crystal": 16}, 3.0)
	for i in 4:
		var a: float = TAU * i / 4.0 + PI / 4.0
		m.add("crystal", Vector3(cos(a), 0, sin(a)) * 28.0, 0.0)
	m.border("frozen_wall", "ice_rock")


## 沙海遗迹：中央方尖碑 + 砂岩柱廊（两条平行列）→ 四座台地岩 → 散落残墙/仙人掌/瓮 → 边缘砂岩墙。
static func _desert(m: MapBase) -> void:
	m.add("obelisk", Vector3(0, 0, -20), 0.0)
	for side: float in [-1.0, 1.0]:
		for i in 6:
			m.add("sand_pillar", Vector3(side * 16.0, 0, -30.0 + i * 12.0), 0.0)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			m.add("mesa_rock", Vector3(sx * 58.0, 0, sz * 58.0), m.rng.randf() * TAU)
			m.add("mesa_rock", Vector3(sx * 62.0, 0, sz * 52.0), m.rng.randf() * TAU)
	m.scatter({"sand_wall": 22, "mesa_rock": 14, "sand_pillar": 10}, 6.0)
	m.scatter({"cactus": 40}, 3.0)
	m.scatter({"urn": 12}, 3.0)
	for i in 4:
		var a: float = TAU * i / 4.0
		m.add("urn", Vector3(cos(a), 0, sin(a)) * 26.0, 0.0)
	m.border("sand_wall", "mesa_rock")


## 幽暗森林：中央立石阵（7 块环形）→ 巨菇指路 → 约 90 棵古树与暗松（沿坐标轴留 18 米宽的林间通道）→ 倒木苔石 → 边缘密林。
static func _forest(m: MapBase) -> void:
	for i in 7:
		var a: float = TAU * i / 7.0
		m.add("standing_stone", Vector3(cos(a), 0, sin(a)) * 17.0, -a)
	for i in 6:
		var a: float = TAU * i / 6.0 + 0.25
		m.add("glowshroom", Vector3(cos(a), 0, sin(a)) * 27.0, m.rng.randf() * TAU)
	# 4 条林间通道（沿坐标轴，宽 18 米）不种树，保证走得开
	for i in 220:
		var p: Vector3 = Vector3(m.rng.randf_range(-88, 88), 0, m.rng.randf_range(-88, 88))
		if absf(p.x) < 9.0 or absf(p.z) < 9.0 or not m.free_for(p, 4.5):
			continue
		if m.placed_count("oak") + m.placed_count("dark_pine") >= 90:
			break
		m.add("oak" if m.rng.randf() < 0.5 else "dark_pine", p, m.rng.randf() * TAU)
	m.scatter({"log": 18, "mossy_rock": 24}, 5.0)
	m.scatter({"glowshroom": 14}, 3.0)
	m.border("dark_pine", "oak")
