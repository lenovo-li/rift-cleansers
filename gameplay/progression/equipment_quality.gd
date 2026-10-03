class_name EquipmentQuality extends RefCounted
## 装备品质：普通 / 优秀 / 稀有 / 史诗 / 传说（0-4）。
## 掉落品质按游戏时间和来源（时间表 / 精英 / Boss）掷骰；重复拾取升一档，传说后继续拾取 = 强化 +1。
## 品质带来的全局加成见 CharacterStats.equipment_quality_bonuses。

const COMMON: int = 0
const LEGENDARY: int = 4
const NAMES: Array[String] = ["普通", "优秀", "稀有", "史诗", "传说"]
const COLORS: Array[Color] = [
	Color(0.85, 0.85, 0.85),  # 白
	Color(0.3, 0.9, 0.35),    # 绿
	Color(0.3, 0.6, 1.0),     # 蓝
	Color(0.75, 0.35, 1.0),   # 紫
	Color(1.0, 0.75, 0.15),   # 金
]
## 基础掉落权重（普通→传说），随时间向高品质偏移
const BASE_WEIGHTS: Array[float] = [50.0, 30.0, 14.0, 5.0, 1.0]
## 来源加成：精英 +1 档保底概率、Boss 至少史诗
enum Source { SCHEDULE, ELITE, BOSS }


static func color(quality: int) -> Color:
	return COLORS[clampi(quality, 0, LEGENDARY)]


static func quality_name(quality: int) -> String:
	return NAMES[clampi(quality, 0, LEGENDARY)]


## 掷骰掉落品质。t = 游戏时间（秒）：每分钟把权重往高品质挪一点，18 分钟时传说约 15%。
static func roll(t: float, source: int, rng: RandomNumberGenerator) -> int:
	var minutes: float = t / 60.0
	var weights: Array[float] = []
	for q in BASE_WEIGHTS.size():
		# 高品质权重按时间放大，低品质按时间缩小
		var shift: float = 1.0 + minutes * 0.12 * float(q)
		var decay: float = maxf(0.15, 1.0 - minutes * 0.04 * float(LEGENDARY - q))
		weights.append(BASE_WEIGHTS[q] * shift * (decay if q < 2 else 1.0))
	var total: float = 0.0
	for w: float in weights:
		total += w
	var r: float = rng.randf() * total
	var quality: int = COMMON
	for q in weights.size():
		r -= weights[q]
		if r <= 0.0:
			quality = q
			break
	match source:
		Source.ELITE:
			quality = maxi(quality, 1)
		Source.BOSS:
			quality = maxi(quality, 3)
	return clampi(quality, COMMON, LEGENDARY)


## 拾取提示文本
static func pickup_text(item_name: String, quality: int, enhance: int, first: bool) -> String:
	if first:
		return "获得%s装备：%s" % [quality_name(quality), item_name]
	if quality >= LEGENDARY and enhance > 0:
		return "%s 强化 +%d" % [item_name, enhance]
	return "%s 品质提升 → %s" % [item_name, quality_name(quality)]
