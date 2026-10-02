class_name Elements extends RefCounted
## 七大元素（文档 11）：fire 火 / ice 冰 / lightning 雷 / wind 风 / poison 毒 / shadow 暗影 / holy 圣光。
## 技能元素表是唯一来源：共鸣、协同、UI 和反应都读这里。空字符串 = 物理技能（无元素）。
## 命中时 apply()：先按目标已有元素自动反应（Reactions.resolve），未被消耗再附着新元素。

const ALL: Array[String] = ["fire", "ice", "lightning", "wind", "poison", "shadow", "holy"]
const NAMES: Dictionary = {
	"fire": "火焰", "ice": "冰霜", "lightning": "雷电", "wind": "风", "poison": "剧毒", "shadow": "暗影", "holy": "圣光",
}
const COLORS: Dictionary = {
	"fire": Color(1.0, 0.45, 0.15), "ice": Color(0.55, 0.88, 1.0), "lightning": Color(0.65, 0.6, 1.0),
	"wind": Color(0.45, 1.0, 0.8), "poison": Color(0.55, 0.95, 0.25), "shadow": Color(0.62, 0.32, 1.0),
	"holy": Color(1.0, 0.88, 0.45),
}
## 每次命中附着的默认元素强度
const DEFAULT_INTENSITY: float = 25.0

const SKILL_ELEMENTS: Dictionary = {
	# 铁卫
	"shield_bash": "", "whirlwind": "wind", "taunt": "", "charge": "fire", "ground_slam": "",
	"reflect_aura": "", "iron_wall": "", "war_cry": "shadow", "earthquake": "", "flame_cleave": "fire",
	# 元素术士
	"fireball": "fire", "ice_lance": "ice", "frost_nova": "ice", "chain_lightning": "lightning",
	"meteor": "fire", "storm_field": "lightning", "firestorm": "fire", "ice_wall": "ice",
	"tornado": "wind", "acid_rain": "poison",
	# 影行者
	"shadow_step": "shadow", "fan_of_knives": "", "death_mark": "shadow", "blade_flurry": "",
	"smoke_bomb": "shadow", "execute": "shadow", "shadow_clone": "shadow", "lethal_strike": "",
	"venom_blades": "poison", "shadow_nova": "shadow",
	# 牧师
	"holy_nova": "holy", "smite": "holy", "sanctuary": "holy", "divine_shield": "holy",
	"blessing": "holy", "divine_intervention": "holy", "purify": "holy", "judgment": "holy",
	"holy_fire": "fire", "hammer_of_light": "holy",
	# 通用
	"wind_blade": "wind", "toxic_cloud": "poison", "life_drain": "shadow", "thunder_strike": "lightning",
	"cyclone": "wind",
}
## 个别技能的元素强度（重击类更高）。未列出的用 DEFAULT_INTENSITY。
const SKILL_INTENSITY: Dictionary = {
	"meteor": 45.0, "frost_nova": 30.0, "ice_wall": 35.0, "judgment": 40.0, "thunder_strike": 35.0,
	"storm_field": 15.0, "toxic_cloud": 15.0, "acid_rain": 15.0, "sanctuary": 10.0, "firestorm": 20.0,
	"holy_fire": 20.0, "whirlwind": 15.0,
}


static func of(skill_id: String) -> String:
	return str(SKILL_ELEMENTS.get(skill_id, ""))


static func intensity_of(skill_id: String) -> float:
	return float(SKILL_INTENSITY.get(skill_id, DEFAULT_INTENSITY))


static func display_name(element: String) -> String:
	return str(NAMES.get(element, "物理"))


static func color(element: String) -> Color:
	return COLORS.get(element, Color(0.85, 0.85, 0.85))


## 命中附着元素 + 自动反应。返回反应结果（可能为空）。
## mods 除 Reactions 的参数外还支持：dot_mult（持续伤害）、dot_duration_mult、slow_mult、poison_mult、shock_cap。
static func apply(target: Variant, element: String, intensity: float, damage: float, candidates: Array,
		mods: Dictionary = {}) -> Dictionary:
	var s: StatusEffects = Reactions.status_of(target)
	if s == null or element.is_empty() or not is_instance_valid(target) or not target.is_alive:
		return {}
	var r: Dictionary = Reactions.resolve(target, element, damage, candidates, mods)
	if r.get("consumed", false) or not target.is_alive:
		return r
	attach(s, element, intensity, damage, mods)
	if element == "ice":
		var f: Dictionary = Reactions.freeze(target, mods)
		if r.is_empty():
			r = f
	return r


## 只附着元素与对应的基础状态，不反应。
static func attach(s: StatusEffects, element: String, intensity: float, damage: float, mods: Dictionary = {}) -> void:
	var dot: float = float(mods.get("dot_mult", 1.0))
	var dur: float = float(mods.get("dot_duration_mult", 1.0))
	match element:
		"fire":
			s.apply_burn(maxf(6.0, damage * 0.12) * dot, 3.0 * dur, intensity)
		"ice":
			s.apply_slow(minf(0.6, 0.3 * float(mods.get("slow_mult", 1.0))), 2.0, intensity)
		"lightning":
			s.apply_shocked(1, 4.0, intensity, int(mods.get("shock_cap", 10)))
		"poison":
			s.apply_poisoned(maxf(5.0, damage * 0.15) * dot * float(mods.get("poison_mult", 1.0)), 4.0 * dur,
					minf(0.9, 0.5 * float(mods.get("poison_heal_mult", 1.0))), intensity)
		"shadow":
			s.apply_weakened(0.15, 3.0)
