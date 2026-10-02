class_name SkillSynergy extends RefCounted
## 技能协同系统：同标签技能相互强化。
## 每个技能附带1-2个标签，装备同标签技能越多，该类技能越强。

enum SynergyTag {
	NONE,
	AOE,            # 范围伤害
	SINGLE_TARGET,  # 单体高伤
	DOT,            # 持续伤害
	BURST,          # 爆发伤害
	CROWD_CONTROL,  # 控制
	MOBILITY,       # 机动性
	DEFENSIVE,      # 防御
	SUPPORT,        # 辅助
	SUMMONING,      # 召唤
	CHAIN,          # 连锁
}

# 技能标签映射
const SKILL_TAGS: Dictionary = {
	# 铁卫
	"shield_bash": [SynergyTag.SINGLE_TARGET, SynergyTag.CROWD_CONTROL],
	"whirlwind": [SynergyTag.AOE, SynergyTag.DOT],
	"taunt": [SynergyTag.CROWD_CONTROL, SynergyTag.DEFENSIVE],
	"charge": [SynergyTag.MOBILITY, SynergyTag.SINGLE_TARGET],
	"ground_slam": [SynergyTag.AOE, SynergyTag.CROWD_CONTROL],
	"reflect_aura": [SynergyTag.DEFENSIVE],

	# 元素术士
	"fireball": [SynergyTag.SINGLE_TARGET, SynergyTag.DOT],
	"ice_lance": [SynergyTag.SINGLE_TARGET, SynergyTag.CROWD_CONTROL],
	"frost_nova": [SynergyTag.AOE, SynergyTag.CROWD_CONTROL],
	"chain_lightning": [SynergyTag.CHAIN, SynergyTag.BURST],
	"meteor": [SynergyTag.AOE, SynergyTag.BURST],
	"storm_field": [SynergyTag.AOE, SynergyTag.DOT],

	# 影行者
	"shadow_step": [SynergyTag.MOBILITY, SynergyTag.BURST],
	"fan_of_knives": [SynergyTag.AOE],
	"death_mark": [SynergyTag.SINGLE_TARGET, SynergyTag.BURST],
	"blade_flurry": [SynergyTag.AOE, SynergyTag.BURST],
	"smoke_bomb": [SynergyTag.CROWD_CONTROL, SynergyTag.DEFENSIVE],
	"execute": [SynergyTag.SINGLE_TARGET, SynergyTag.BURST],

	# 牧师
	"holy_nova": [SynergyTag.AOE, SynergyTag.SUPPORT],
	"smite": [SynergyTag.SINGLE_TARGET, SynergyTag.BURST],
	"sanctuary": [SynergyTag.AOE, SynergyTag.SUPPORT],
	"divine_shield": [SynergyTag.DEFENSIVE, SynergyTag.SUPPORT],
	"blessing": [SynergyTag.SUPPORT],
	"divine_intervention": [SynergyTag.SUPPORT, SynergyTag.BURST],
}


## 计算协同加成
static func calculate_synergy_bonuses(skill_ids: Array[String]) -> Dictionary:
	var tag_counts: Dictionary = {}

	for sid: String in skill_ids:
		var tags: Array = SKILL_TAGS.get(sid, [])
		for tag in tags:
			tag_counts[tag] = tag_counts.get(tag, 0) + 1

	var bonuses: Dictionary = {
		"aoe_damage": 1.0,
		"single_target_damage": 1.0,
		"dot_damage": 1.0,
		"burst_damage": 1.0,
		"cc_duration": 1.0,
		"mobility_cooldown": 1.0,
		"defensive_strength": 1.0,
		"support_strength": 1.0,
		"chain_count": 0,
	}

	for tag in tag_counts:
		var count: int = tag_counts[tag]
		match tag:
			SynergyTag.AOE:
				bonuses.aoe_damage = 1.0 + 0.08 * count  # 每个+8%
			SynergyTag.SINGLE_TARGET:
				bonuses.single_target_damage = 1.0 + 0.10 * count  # 每个+10%
			SynergyTag.DOT:
				bonuses.dot_damage = 1.0 + 0.12 * count  # 每个+12%
			SynergyTag.BURST:
				bonuses.burst_damage = 1.0 + 0.10 * count  # 每个+10%
			SynergyTag.CROWD_CONTROL:
				bonuses.cc_duration = 1.0 + 0.15 * count  # 每个+15%持续时间
			SynergyTag.MOBILITY:
				bonuses.mobility_cooldown = 1.0 / (1.0 + 0.10 * count)  # 每个-10%冷却
			SynergyTag.DEFENSIVE:
				bonuses.defensive_strength = 1.0 + 0.15 * count
			SynergyTag.SUPPORT:
				bonuses.support_strength = 1.0 + 0.12 * count
			SynergyTag.CHAIN:
				bonuses.chain_count = count  # 每个连锁技能+1最大连锁数

	return bonuses


## 获取标签名称（用于UI显示）
static func tag_name(tag: SynergyTag) -> String:
	match tag:
		SynergyTag.AOE: return "范围伤害"
		SynergyTag.SINGLE_TARGET: return "单体伤害"
		SynergyTag.DOT: return "持续伤害"
		SynergyTag.BURST: return "爆发伤害"
		SynergyTag.CROWD_CONTROL: return "控制"
		SynergyTag.MOBILITY: return "机动性"
		SynergyTag.DEFENSIVE: return "防御"
		SynergyTag.SUPPORT: return "辅助"
		SynergyTag.SUMMONING: return "召唤"
		SynergyTag.CHAIN: return "连锁"
	return "无"


## 检查技能是否有某个标签
static func has_tag(skill_id: String, tag: SynergyTag) -> bool:
	var tags: Array = SKILL_TAGS.get(skill_id, [])
	return tag in tags


## 获取技能的所有标签
static func get_tags(skill_id: String) -> Array:
	return SKILL_TAGS.get(skill_id, [])
