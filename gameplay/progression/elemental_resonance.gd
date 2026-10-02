class_name ElementalResonance extends RefCounted
## 元素共鸣（文档 11）：已学技能中同元素技能数量 → 共鸣等级。
## 2 个：小共鸣（该元素伤害 +15%）；3 个：中共鸣（+30% + 特殊效果）；4+：大共鸣（+50% + 强化效果）。
## 雷 +15/35/55%，圣光 +12/25/40%。共鸣水晶：已有共鸣的元素提升一档。
## 技能元素读 Elements.SKILL_ELEMENTS（唯一来源）。

const NONE: int = 0
const MINOR: int = 2
const MAJOR: int = 3
const PERFECT: int = 4

const DAMAGE_MULTS: Dictionary = {
	"fire": [1.15, 1.30, 1.50], "ice": [1.15, 1.30, 1.50], "lightning": [1.15, 1.35, 1.55],
	"wind": [1.15, 1.30, 1.50], "poison": [1.15, 1.30, 1.50], "shadow": [1.15, 1.30, 1.50],
	"holy": [1.12, 1.25, 1.40],
}
## 特殊效果说明（UI 用）：[中共鸣, 大共鸣]
const SPECIAL_DESC: Dictionary = {
	"fire": ["爆燃伤害 +50%", "燃烧伤害 +30%"],
	"ice": ["冰冻所需强度 60→45", "碎裂波及周围"],
	"lightning": ["连锁 +1", "反应冷却 -30%"],
	"wind": ["扩散范围与伤害 +30%", "击退 +30%"],
	"poison": ["中毒伤害 +30%", "治疗削减翻倍"],
	"shadow": ["对标记目标暴击率 +20%", "处决阈值 +5%"],
	"holy": ["治疗 +20%", "净化时灼烧周围敌人"],
}


## 统计已学技能的元素数量：{element: count}
static func element_counts(skill_ids: Array[String]) -> Dictionary:
	var counts: Dictionary = {}
	for sid: String in skill_ids:
		var e: String = Elements.of(sid)
		if not e.is_empty():
			counts[e] = int(counts.get(e, 0)) + 1
	return counts


## 计算共鸣等级：{element: MINOR/MAJOR/PERFECT}（未达到 2 个的元素不出现）。boost：共鸣水晶。
static func calculate(skill_ids: Array[String], boost: bool = false) -> Dictionary:
	var out: Dictionary = {}
	var counts: Dictionary = element_counts(skill_ids)
	for e: String in counts:
		var lv: int = level_for_count(int(counts[e]))
		if lv != NONE:
			out[e] = mini(PERFECT, lv + 1) if boost else lv
	return out


static func level_for_count(count: int) -> int:
	if count >= 4:
		return PERFECT
	if count >= 3:
		return MAJOR
	if count >= 2:
		return MINOR
	return NONE


static func damage_mult(element: String, level: int) -> float:
	if level < MINOR or not DAMAGE_MULTS.has(element):
		return 1.0
	return float(DAMAGE_MULTS[element][level - MINOR])


static func level_name(level: int) -> String:
	match level:
		MINOR: return "小共鸣"
		MAJOR: return "中共鸣"
		PERFECT: return "大共鸣"
	return ""


## 共鸣描述（HUD 用），例如「火焰·中共鸣：伤害+30%，爆燃伤害 +50%」。
static func describe(element: String, level: int) -> String:
	var text: String = "%s·%s：伤害+%d%%" % [Elements.display_name(element), level_name(level),
			roundi((damage_mult(element, level) - 1.0) * 100.0)]
	var specials: Array = SPECIAL_DESC.get(element, [])
	if level >= MAJOR and specials.size() > 0:
		text += "，" + str(specials[0])
	if level >= PERFECT and specials.size() > 1:
		text += "，" + str(specials[1])
	return text
