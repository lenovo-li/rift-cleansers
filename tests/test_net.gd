extends RefCounted
## 联机纯逻辑：快照编解码、机器人与玩家查询不依赖网络。


class FakeEnemy extends RefCounted:
	var entity_id: int
	var global_position: Vector3
	var def: EnemyDef = EnemyDef.new()
	var elite_mod: String = ""
	var status: StatusEffects = StatusEffects.new()
	var current_health: float = 50.0
	var max_health: float = 100.0


func _enemy(id: int, pos: Vector3, type: String, elite: String) -> FakeEnemy:
	var e: FakeEnemy = FakeEnemy.new()
	e.entity_id = id
	e.global_position = pos
	e.def.enemy_id = type
	e.elite_mod = elite
	return e


func test_codec_roundtrip() -> String:
	var a: FakeEnemy = _enemy(1001, Vector3(12.345, 0, -67.891), "ghoul", "vampire")
	a.status.apply_burn(5.0, 1.0)
	var b: FakeEnemy = _enemy(4000000000, Vector3(-95.0, 0, 95.0), "corrupted_knight", "")
	b.status.apply_slow(0.5, 1.0)
	b.current_health = 100.0
	var buf: PackedByteArray = NetCodec.encode_enemies([a, b])
	if buf.size() != 2 * NetCodec.RECORD_SIZE:
		return "每只敌人应占 %d 字节" % NetCodec.RECORD_SIZE
	var d: Array[Dictionary] = NetCodec.decode_enemies(buf)
	if d[0].id != 1001 or d[1].id != 4000000000:
		return "id 应原样还原"
	if (d[0].pos as Vector3).distance_to(a.global_position * Vector3(1, 0, 1)) > 0.01:
		return "坐标误差应 < 1 厘米，实际 %s" % d[0].pos
	if d[0].type != "ghoul" or d[0].elite != "vampire" or not d[0].burning or d[0].slowed:
		return "类型/精英/状态解码错误: %s" % d[0]
	if d[1].type != "corrupted_knight" or not d[1].slowed or not is_equal_approx(d[1].hp, 1.0):
		return "Boss 解码错误: %s" % d[1]
	if absf(d[0].hp - 0.5) > 0.01:
		return "血量比例应约为 0.5"
	return ""


func test_codec_bandwidth_budget() -> String:
	# 400 只敌人 × 10 Hz 应低于 50 KB/s（文档 06：局域网原型可接受）
	var bytes_per_sec: int = 400 * NetCodec.RECORD_SIZE * 10
	if bytes_per_sec > 50000:
		return "敌群快照带宽 %d B/s 超出预算" % bytes_per_sec
	return ""


func test_all_enemy_types_encodable() -> String:
	for id: String in ["zombie", "skeleton", "imp", "ghoul", "necromancer", "bloater", "corrupted_knight"]:
		if not NetCodec.TYPE_IDS.has(id):
			return "快照类型表缺少 %s" % id
	for mod: String in SpawnDirector.ELITE_MODS:
		if not NetCodec.ELITE_IDS.has(mod):
			return "快照精英表缺少 %s" % mod
	return ""
