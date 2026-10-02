class_name SkillSynergy extends RefCounted
## 技能协同（文档 11）：每个技能 1-2 个标签，已学技能中同标签越多，带该标签的技能越强。
## 范围 +8%/个、单体 +10%/个、持续 +12%/个（持续伤害）、爆发 +10%/个、控制 +15%/个（控制时长）、
## 机动 -10%/个冷却、防御 +15%/个（护盾/减伤）、辅助 +12%/个（治疗）、连锁 +1 跳/个、召唤 +10%/个。

const NAMES: Dictionary = {
	"aoe": "范围", "single": "单体", "dot": "持续", "burst": "爆发", "cc": "控制",
	"mobility": "机动", "defensive": "防御", "support": "辅助", "chain": "连锁", "summon": "召唤",
}

const SKILL_TAGS: Dictionary = {
	# 铁卫
	"shield_bash": ["single", "cc"], "whirlwind": ["aoe", "dot"], "taunt": ["cc", "defensive"],
	"charge": ["mobility", "single"], "ground_slam": ["aoe", "cc"], "reflect_aura": ["defensive"],
	"iron_wall": ["defensive", "cc"], "war_cry": ["aoe", "support"], "earthquake": ["aoe", "cc"],
	"flame_cleave": ["aoe", "burst"],
	# 元素术士
	"fireball": ["single", "dot"], "ice_lance": ["single", "cc"], "frost_nova": ["aoe", "cc"],
	"chain_lightning": ["chain", "burst"], "meteor": ["aoe", "burst"], "storm_field": ["aoe", "dot"],
	"firestorm": ["aoe", "dot"], "ice_wall": ["cc", "defensive"], "tornado": ["aoe", "cc"],
	"acid_rain": ["aoe", "dot"],
	# 影行者
	"shadow_step": ["mobility", "burst"], "fan_of_knives": ["aoe"], "death_mark": ["single", "burst"],
	"blade_flurry": ["aoe", "burst"], "smoke_bomb": ["cc", "defensive"], "execute": ["single", "burst"],
	"shadow_clone": ["summon", "aoe"], "lethal_strike": ["single", "burst"], "venom_blades": ["aoe", "dot"],
	"shadow_nova": ["aoe", "cc"],
	# 牧师
	"holy_nova": ["aoe", "support"], "smite": ["single", "burst"], "sanctuary": ["aoe", "support"],
	"divine_shield": ["defensive", "support"], "blessing": ["support"], "divine_intervention": ["support", "burst"],
	"purify": ["support", "aoe"], "judgment": ["aoe", "burst"], "holy_fire": ["aoe", "dot"],
	"hammer_of_light": ["chain", "cc"],
	# 通用
	"wind_blade": ["single", "mobility"], "toxic_cloud": ["aoe", "dot"], "life_drain": ["single", "support"],
	"thunder_strike": ["burst", "chain"], "cyclone": ["cc", "aoe"],
}

const PER_TAG: Dictionary = {
	"aoe": 0.08, "single": 0.10, "dot": 0.12, "burst": 0.10, "cc": 0.15,
	"mobility": 0.10, "defensive": 0.15, "support": 0.12, "summon": 0.10,
}
## 直接乘进技能伤害的标签
const DAMAGE_TAGS: Array[String] = ["aoe", "single", "burst", "summon"]


static func get_tags(skill_id: String) -> Array:
	return SKILL_TAGS.get(skill_id, [])


static func has_tag(skill_id: String, tag: String) -> bool:
	return tag in get_tags(skill_id)


static func tag_name(tag: String) -> String:
	return str(NAMES.get(tag, tag))


## 已学技能的标签计数：{tag: count}
static func tag_counts(skill_ids: Array[String]) -> Dictionary:
	var counts: Dictionary = {}
	for sid: String in skill_ids:
		for tag: String in get_tags(sid):
			counts[tag] = int(counts.get(tag, 0)) + 1
	return counts


## 某个标签当前的加成倍率（count 个技能带该标签）。机动返回冷却倍率（<1）。
static func tag_mult(tag: String, count: int) -> float:
	if count <= 0:
		return 1.0
	if tag == "mobility":
		return 1.0 / (1.0 + PER_TAG.mobility * count)
	return 1.0 + float(PER_TAG.get(tag, 0.0)) * count


## skill_id 在已学技能 owned 下获得的协同加成：
## {damage, dot, cc, cooldown, defensive, support, chain}
static func bonuses_for(skill_id: String, owned: Array[String]) -> Dictionary:
	var counts: Dictionary = tag_counts(owned)
	var out: Dictionary = {"damage": 1.0, "dot": 1.0, "cc": 1.0, "cooldown": 1.0, "defensive": 1.0,
			"support": 1.0, "chain": 0}
	for tag: String in get_tags(skill_id):
		var n: int = int(counts.get(tag, 0))
		if tag in DAMAGE_TAGS:
			out.damage *= tag_mult(tag, n)
		match tag:
			"dot": out.dot = tag_mult(tag, n)
			"cc": out.cc = tag_mult(tag, n)
			"mobility": out.cooldown = tag_mult(tag, n)
			"defensive": out.defensive = tag_mult(tag, n)
			"support": out.support = tag_mult(tag, n)
			"chain": out.chain = n
	return out


## HUD 用：已学技能里计数 ≥2 的标签描述列表。
static func describe(owned: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var counts: Dictionary = tag_counts(owned)
	for tag: String in counts:
		var n: int = int(counts[tag])
		if n >= 2:
			out.append("%s×%d" % [tag_name(tag), n])
	return out
