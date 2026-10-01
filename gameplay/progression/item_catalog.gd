class_name ItemCatalog extends RefCounted
## 被动模块与装备的名称和说明（文档 05 §1.3、§1.4）。效果规则在 CharacterStats 和玩家里实现。
## 装备带 "char" 的是角色专属，只会掉给该角色（equipment_pool）；其余为通用。

const PASSIVES: Dictionary = {
	"block_recovery": {"name": "格挡回复", "desc": "格挡时获得10点护盾"},
	"rage_damage": {"name": "狂怒强化", "desc": "怒气>80时伤害+30%"},
	"revenge": {"name": "复仇", "desc": "受击后5秒内攻速+20%"},
	"rally": {"name": "集结", "desc": "嘲讽范围+30%"},
}

const EQUIPMENT: Dictionary = {
	# 通用（16 件）
	"swift_gloves": {"name": "迅捷手套", "desc": "自动攻击间隔-20%"},
	"crit_amulet": {"name": "暴击护符", "desc": "暴击率+12%"},
	"war_drum": {"name": "战鼓", "desc": "所有伤害+15%"},
	"glass_cannon": {"name": "玻璃大炮", "desc": "伤害+30%，最大生命-20%"},
	"hp_pendant": {"name": "生命吊坠", "desc": "最大生命+25%"},
	"shield_core": {"name": "护盾核心", "desc": "每4秒获得25点护盾"},
	"thorn_mail": {"name": "荆棘甲", "desc": "受到伤害的25%反弹给攻击者"},
	"iron_skin": {"name": "铁皮", "desc": "受到伤害-10%"},
	"regen_ring": {"name": "再生戒指", "desc": "每秒额外回复6点生命"},
	"second_wind": {"name": "回光返照", "desc": "受到致命伤时免死一次，回复30%生命"},
	"sprint_boots": {"name": "疾跑靴", "desc": "移动速度+18%"},
	"adrenaline_injector": {"name": "肾上腺注射", "desc": "闪避冷却-30%"},
	"exp_tome": {"name": "经验古籍", "desc": "经验获取+25%（联机时全队生效）"},
	"cd_crystal": {"name": "冷却水晶", "desc": "技能冷却-12%"},
	"range_lens": {"name": "范围透镜", "desc": "技能范围+20%"},
	"magnetic_boots": {"name": "磁力战靴", "desc": "被你击退的敌人随后被拉回身边"},
	# 铁卫
	"spiked_shield": {"name": "尖刺盾牌", "desc": "格挡时对攻击者造成60点反伤", "char": "iron_guard"},
	"berserker_helm": {"name": "狂战头盔", "desc": "生命<50%时伤害+40%", "char": "iron_guard"},
	"bulwark_sigil": {"name": "壁垒徽记", "desc": "格挡率+10%", "char": "iron_guard"},
	"rage_sigil": {"name": "狂怒印记", "desc": "怒气获取+50%", "char": "iron_guard"},
	# 元素术士
	"flame_core": {"name": "烈焰核心", "desc": "自动攻击附加燃烧（重击可引爆）", "char": "elementalist"},
	"arcane_tome": {"name": "奥术秘典", "desc": "技能伤害+20%", "char": "elementalist"},
	"mana_prism": {"name": "法力棱镜", "desc": "技能冷却-15%", "char": "elementalist"},
	# 影行者
	"assassin_mark": {"name": "刺客印记", "desc": "暴击率+15%", "char": "shadow_walker"},
	"backstab_dagger": {"name": "背刺匕首", "desc": "暴击伤害 2 倍 → 2.6 倍", "char": "shadow_walker"},
	"night_cloak": {"name": "夜行斗篷", "desc": "闪避无敌时间+0.3秒", "char": "shadow_walker"},
	# 牧师
	"holy_relic": {"name": "圣物", "desc": "治疗与护盾效果+25%", "char": "cleric"},
	"grace_staff": {"name": "恩典法杖", "desc": "技能范围+25%", "char": "cleric"},
	"leech_gauntlet": {"name": "汲取手套", "desc": "自动攻击吸血15%", "char": "cleric"},
}


static func passive_name(id: String) -> String:
	return PASSIVES.get(id, {}).get("name", id)


static func equipment_name(id: String) -> String:
	return EQUIPMENT.get(id, {}).get("name", id)


static func equipment_desc(id: String) -> String:
	return EQUIPMENT.get(id, {}).get("desc", "")


## 该角色能否使用（拾取）这件装备：通用装备谁都能用，专属装备只给对应角色。
static func can_use(id: String, char_id: String) -> bool:
	var owner: String = EQUIPMENT.get(id, {}).get("char", "")
	return owner.is_empty() or owner == char_id


## 角色能掉落的装备：通用 + 该角色专属。char_id 为空时返回全部（测试用）。
static func equipment_pool(char_id: String = "") -> Array[String]:
	var pool: Array[String] = []
	for id: String in EQUIPMENT:
		var owner: String = EQUIPMENT[id].get("char", "")
		if char_id.is_empty() or owner.is_empty() or owner == char_id:
			pool.append(id)
	return pool