class_name ElementalResonance extends RefCounted
## 元素共鸣系统：同类元素技能达到一定数量时，获得被动增益。
## 2个同元素技能：小共鸣（+15%该元素伤害）
## 3个同元素技能：中共鸣（+30%该元素伤害+特殊效果）
## 4+个同元素技能：大共鸣（+50%该元素伤害+强化特殊效果）

enum ResonanceLevel {
	NONE = 0,
	MINOR = 2,   # 2个技能
	MAJOR = 3,   # 3个技能
	PERFECT = 4, # 4+个技能
}

enum Element {
	NONE,
	FIRE,
	ICE,
	LIGHTNING,
	WIND,
	POISON,
	SHADOW,
	HOLY,
}

# 技能元素映射
const SKILL_ELEMENTS: Dictionary = {
	# 火系
	"fireball": Element.FIRE,
	"meteor": Element.FIRE,
	"charge": Element.FIRE,

	# 冰系
	"ice_lance": Element.ICE,
	"frost_nova": Element.ICE,

	# 雷系
	"chain_lightning": Element.LIGHTNING,
	"storm_field": Element.LIGHTNING,

	# 暗影系
	"shadow_step": Element.SHADOW,
	"death_mark": Element.SHADOW,
	"smoke_bomb": Element.SHADOW,
	"execute": Element.SHADOW,

	# 圣光系
	"holy_nova": Element.HOLY,
	"smite": Element.HOLY,
	"sanctuary": Element.HOLY,
	"divine_shield": Element.HOLY,
	"blessing": Element.HOLY,
	"divine_intervention": Element.HOLY,

	# 物理/通用（无共鸣）
	"shield_bash": Element.NONE,
	"whirlwind": Element.NONE,
	"taunt": Element.NONE,
	"ground_slam": Element.NONE,
	"fan_of_knives": Element.NONE,
	"blade_flurry": Element.NONE,
	"reflect_aura": Element.NONE,
}


## 计算元素共鸣状态
static func calculate_resonance(skill_ids: Array[String]) -> Dictionary:
	var element_counts: Dictionary = {}

	for sid: String in skill_ids:
		var elem: Element = SKILL_ELEMENTS.get(sid, Element.NONE)
		if elem != Element.NONE:
			element_counts[elem] = element_counts.get(elem, 0) + 1

	var resonances: Dictionary = {}
	for elem: Element in element_counts:
		var count: int = element_counts[elem]
		if count >= ResonanceLevel.MINOR:
			resonances[elem] = _get_resonance_level(count)

	return resonances  # {Element -> ResonanceLevel}


static func _get_resonance_level(count: int) -> ResonanceLevel:
	if count >= 4:
		return ResonanceLevel.PERFECT
	elif count >= 3:
		return ResonanceLevel.MAJOR
	elif count >= 2:
		return ResonanceLevel.MINOR
	return ResonanceLevel.NONE


## 获取共鸣加成
static func get_resonance_bonuses(resonances: Dictionary) -> Dictionary:
	var bonuses: Dictionary = {
		"fire_damage_mult": 1.0,
		"ice_damage_mult": 1.0,
		"lightning_damage_mult": 1.0,
		"shadow_damage_mult": 1.0,
		"holy_damage_mult": 1.0,
		"special_effects": [],
	}

	for elem: Element in resonances:
		var level: ResonanceLevel = resonances[elem]
		match elem:
			Element.FIRE:
				bonuses.fire_damage_mult = _fire_resonance_mult(level)
				if level >= ResonanceLevel.MAJOR:
					bonuses.special_effects.append("fire_resonance_ignite_chance")
				if level >= ResonanceLevel.PERFECT:
					bonuses.special_effects.append("fire_resonance_burn_spread")

			Element.ICE:
				bonuses.ice_damage_mult = _ice_resonance_mult(level)
				if level >= ResonanceLevel.MAJOR:
					bonuses.special_effects.append("ice_resonance_freeze_buildup")
				if level >= ResonanceLevel.PERFECT:
					bonuses.special_effects.append("ice_resonance_shatter_aoe")

			Element.LIGHTNING:
				bonuses.lightning_damage_mult = _lightning_resonance_mult(level)
				if level >= ResonanceLevel.MAJOR:
					bonuses.special_effects.append("lightning_resonance_chain_bonus")
				if level >= ResonanceLevel.PERFECT:
					bonuses.special_effects.append("lightning_resonance_overload_cd")

			Element.SHADOW:
				bonuses.shadow_damage_mult = _shadow_resonance_mult(level)
				if level >= ResonanceLevel.MAJOR:
					bonuses.special_effects.append("shadow_resonance_crit_bonus")
				if level >= ResonanceLevel.PERFECT:
					bonuses.special_effects.append("shadow_resonance_execute_threshold")

			Element.HOLY:
				bonuses.holy_damage_mult = _holy_resonance_mult(level)
				if level >= ResonanceLevel.MAJOR:
					bonuses.special_effects.append("holy_resonance_heal_bonus")
				if level >= ResonanceLevel.PERFECT:
					bonuses.special_effects.append("holy_resonance_purify_damage")

	return bonuses


static func _fire_resonance_mult(level: ResonanceLevel) -> float:
	match level:
		ResonanceLevel.MINOR: return 1.15   # +15%
		ResonanceLevel.MAJOR: return 1.30   # +30%
		ResonanceLevel.PERFECT: return 1.50 # +50%
	return 1.0

static func _ice_resonance_mult(level: ResonanceLevel) -> float:
	match level:
		ResonanceLevel.MINOR: return 1.15
		ResonanceLevel.MAJOR: return 1.30
		ResonanceLevel.PERFECT: return 1.50
	return 1.0

static func _lightning_resonance_mult(level: ResonanceLevel) -> float:
	match level:
		ResonanceLevel.MINOR: return 1.15
		ResonanceLevel.MAJOR: return 1.35   # 雷系稍高
		ResonanceLevel.PERFECT: return 1.55
	return 1.0

static func _shadow_resonance_mult(level: ResonanceLevel) -> float:
	match level:
		ResonanceLevel.MINOR: return 1.15
		ResonanceLevel.MAJOR: return 1.30
		ResonanceLevel.PERFECT: return 1.50
	return 1.0

static func _holy_resonance_mult(level: ResonanceLevel) -> float:
	match level:
		ResonanceLevel.MINOR: return 1.12   # 圣光偏辅助，伤害加成略低
		ResonanceLevel.MAJOR: return 1.25
		ResonanceLevel.PERFECT: return 1.40
	return 1.0


## 获取元素名称（用于UI显示）
static func element_name(elem: Element) -> String:
	match elem:
		Element.FIRE: return "火焰"
		Element.ICE: return "冰霜"
		Element.LIGHTNING: return "雷电"
		Element.WIND: return "风"
		Element.POISON: return "毒"
		Element.SHADOW: return "暗影"
		Element.HOLY: return "圣光"
	return "无"


## 获取共鸣等级名称
static func resonance_name(level: ResonanceLevel) -> String:
	match level:
		ResonanceLevel.MINOR: return "小共鸣"
		ResonanceLevel.MAJOR: return "中共鸣"
		ResonanceLevel.PERFECT: return "大共鸣"
	return "无"
