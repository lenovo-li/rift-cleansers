class_name ItemCatalog extends RefCounted
## 被动模块与装备的名称和说明（文档 05 §1.3、§1.4）。效果规则在 CharacterStats 和玩家里实现。

const PASSIVES: Dictionary = {
	"block_recovery": {"name": "格挡回复", "desc": "格挡时获得10点护盾"},
	"rage_damage": {"name": "狂怒强化", "desc": "怒气>80时伤害+30%"},
	"revenge": {"name": "复仇", "desc": "受击后5秒内攻速+20%"},
	"rally": {"name": "集结", "desc": "嘲讽范围+30%"},
}

const EQUIPMENT: Dictionary = {
	"spiked_shield": {"name": "尖刺盾牌", "desc": "格挡时对攻击者造成60点反伤"},
	"berserker_helm": {"name": "狂战头盔", "desc": "生命<50%时伤害+40%"},
	"magnetic_boots": {"name": "磁力战靴", "desc": "被你击退的敌人随后被拉回身边"},
	"flame_core": {"name": "烈焰核心", "desc": "自动攻击附加燃烧（重击可引爆）"},
	"leech_gauntlet": {"name": "汲取手套", "desc": "自动攻击吸血15%"},
	"adrenaline_injector": {"name": "肾上腺注射", "desc": "闪避冷却-30%"},
}


static func passive_name(id: String) -> String:
	return PASSIVES.get(id, {}).get("name", id)


static func equipment_name(id: String) -> String:
	return EQUIPMENT.get(id, {}).get("name", id)


static func equipment_desc(id: String) -> String:
	return EQUIPMENT.get(id, {}).get("desc", "")
