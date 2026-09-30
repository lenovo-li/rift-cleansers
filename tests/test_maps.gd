extends RefCounted
## 地图：每张地图的布局只用已定义碰撞盒的零件、零件在 glb 里存在、出生广场空旷、布局确定性。


func _layout(id: String) -> MapBase:
	var m: MapBase = MapBase.new()
	m.map_id = id
	m.def = MapCatalog.get_def(id)
	m.rng.seed = m.def.seed
	MapLayouts.build(m, m.def.layout)
	return m


func test_all_maps_layout_valid() -> String:
	for id: String in MapCatalog.ids():
		var def: Dictionary = MapCatalog.get_def(id)
		for key: String in ["name", "desc", "boss", "seed", "layout", "kit", "colliders", "env", "ground", "decor",
				"lights", "particles", "hazard"]:
			if not def.has(key):
				return "%s 缺少字段 %s" % [id, key]
		var m: MapBase = _layout(id)
		var err: String = ""
		for piece: String in m._placed:
			if not def.colliders.has(piece):
				err = "%s 的零件 %s 没有碰撞盒" % [id, piece]
			elif ModelLibrary.mesh(def.kit, piece) == null:
				err = "%s.glb 里没有零件 %s" % [def.kit, piece]
		if err.is_empty() and m._blockers.size() < 100:
			err = "%s 障碍太少（%d）" % [id, m._blockers.size()]
		if err.is_empty() and m.is_blocked(Vector3.ZERO, 3.0):
			err = "%s 出生点被挡住" % id
		if err.is_empty() and not m._placed.has(def.lights.piece):
			err = "%s 没有光源零件 %s" % [id, def.lights.piece]
		m.free()
		if not err.is_empty():
			return err
	return ""


func test_layout_is_deterministic() -> String:
	for id: String in MapCatalog.ids():
		var a: MapBase = _layout(id)
		var b: MapBase = _layout(id)
		var same: bool = a._blockers == b._blockers
		a.free()
		b.free()
		if not same:
			return "%s 布局不确定（主机和客户端会不一致）" % id
	return ""
