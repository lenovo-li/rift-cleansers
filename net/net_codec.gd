class_name NetCodec extends RefCounted
## 敌群快照的紧凑二进制编码（主机 → 客户端，10 Hz，不可靠）。纯逻辑，便于测试。
## 每只敌人 10 字节：id u32 | x s16 | z s16 | 类型 u4 + 精英 u2 + 燃烧 u1 + 减速 u1 | 血量比例 u8
## 坐标精度 1/100 米（范围 ±327 米，竞技场 ±100 米）。

const TYPE_IDS: Array[String] = ["zombie", "skeleton", "imp", "ghoul", "necromancer", "bloater", "corrupted_knight"]
const ELITE_IDS: Array[String] = ["", "teleporter", "vampire", "haste"]
const RECORD_SIZE: int = 10
const POS_SCALE: float = 100.0


static func encode_enemies(enemies: Array) -> PackedByteArray:
	var buf: PackedByteArray = PackedByteArray()
	buf.resize(enemies.size() * RECORD_SIZE)
	var o: int = 0
	for e: Variant in enemies:
		var pos: Vector3 = e.global_position
		buf.encode_u32(o, int(e.entity_id))
		buf.encode_s16(o + 4, clampi(roundi(pos.x * POS_SCALE), -32768, 32767))
		buf.encode_s16(o + 6, clampi(roundi(pos.z * POS_SCALE), -32768, 32767))
		var type_idx: int = maxi(0, TYPE_IDS.find(e.def.enemy_id))
		var elite_idx: int = maxi(0, ELITE_IDS.find(e.elite_mod))
		var flags: int = type_idx | (elite_idx << 4)
		if e.status.is_burning():
			flags |= 1 << 6
		if e.status.is_slowed():
			flags |= 1 << 7
		buf.encode_u8(o + 8, flags)
		buf.encode_u8(o + 9, clampi(roundi(e.current_health / e.max_health * 255.0), 0, 255))
		o += RECORD_SIZE
	return buf


## 解码为字典数组：{id, pos, type, elite, burning, slowed, hp}
static func decode_enemies(buf: PackedByteArray) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var n: int = buf.size() / RECORD_SIZE
	for i in n:
		var o: int = i * RECORD_SIZE
		var flags: int = buf.decode_u8(o + 8)
		result.append({
			"id": buf.decode_u32(o),
			"pos": Vector3(buf.decode_s16(o + 4) / POS_SCALE, 0.0, buf.decode_s16(o + 6) / POS_SCALE),
			"type": TYPE_IDS[mini(flags & 0xF, TYPE_IDS.size() - 1)],
			"elite": ELITE_IDS[(flags >> 4) & 0x3],
			"burning": (flags & (1 << 6)) != 0,
			"slowed": (flags & (1 << 7)) != 0,
			"hp": buf.decode_u8(o + 9) / 255.0,
		})
	return result
