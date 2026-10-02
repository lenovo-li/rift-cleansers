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
	# 通用基础（16件）
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

	# 通用行为改变型（20件新增）
	"piercing_blade": {"name": "穿刺之刃", "desc": "投射物穿透第一个敌人，伤害-15%"},
	"chain_reaction": {"name": "连锁反应", "desc": "范围技能命中3+敌人时触发小范围二次爆炸"},
	"cooldown_return": {"name": "冷却返还", "desc": "击杀标记敌人返还20%技能冷却"},
	"aoe_proliferation": {"name": "范围扩散", "desc": "单体技能在目标周围产生30%伤害的小范围爆炸"},
	"duration_extension": {"name": "持续延长", "desc": "持续伤害技能持续时间+50%"},
	"echo_strikes": {"name": "回响打击", "desc": "技能命中后1秒再次触发40%伤害"},
	"multicast_gem": {"name": "多重施法宝石", "desc": "10%几率施放技能2次，冷却+50%"},
	"overclock_core": {"name": "超频核心", "desc": "技能冷却-30%，技能消耗5%当前生命"},
	"vampire_sigil": {"name": "吸血印记", "desc": "技能伤害的15%转化为生命"},
	"critical_focus": {"name": "暴击专注", "desc": "暴击率+8%，暴击伤害2.0x→2.5x"},
	"burst_amplifier": {"name": "爆发增幅器", "desc": "技能伤害+25%，但冷却+20%"},
	"rapid_fire": {"name": "急速射击", "desc": "技能冷却-25%，伤害-15%"},
	"elemental_focus": {"name": "元素专注", "desc": "技能附加的元素强度+50%"},
	"reaction_catalyst": {"name": "反应催化剂", "desc": "所有元素反应伤害+40%"},
	"resonance_crystal": {"name": "共鸣水晶", "desc": "元素共鸣效果提升一档"},
	"shockwave_ring": {"name": "冲击波戒指", "desc": "击退距离+40%，碎裂伤害+30%"},
	"ignition_core": {"name": "点燃核心", "desc": "重击触发爆燃的几率+50%"},
	"frost_shard": {"name": "霜冻碎片", "desc": "减速效果+25%，冰冻时间+1秒"},
	"storm_conductor": {"name": "风暴导体", "desc": "感电层数上限+5，雷电连锁距离+30%"},
	"toxic_vial": {"name": "剧毒瓶", "desc": "中毒伤害+40%，治疗降低效果翻倍"},

	# 元素伤害装备（9件新增）
	"fire_talisman": {"name": "烈焰护符", "desc": "火系技能伤害+25%"},
	"frost_ring": {"name": "霜冻戒指", "desc": "冰系技能伤害+25%"},
	"storm_core_element": {"name": "风暴核心", "desc": "雷系技能伤害+25%"},
	"shadow_emblem": {"name": "暗影徽记", "desc": "暗影技能伤害+25%"},
	"holy_symbol": {"name": "圣光圣徽", "desc": "圣光技能伤害+20%，治疗+15%"},
	"poison_fang": {"name": "毒牙", "desc": "毒系技能伤害+30%"},
	"wind_feather": {"name": "风之羽", "desc": "风系技能范围+25%"},
	"dual_element": {"name": "双元素核心", "desc": "火焰技能附加冰霜，冰霜技能附加火焰"},
	"tri_element": {"name": "三元素水晶", "desc": "所有技能附加微量三种元素"},
	# 铁卫
	"spiked_shield": {"name": "尖刺盾牌", "desc": "格挡时对攻击者造成60点反伤", "char": "iron_guard"},
	"berserker_helm": {"name": "狂战头盔", "desc": "生命<50%时伤害+40%", "char": "iron_guard"},
	"bulwark_sigil": {"name": "壁垒徽记", "desc": "格挡率+10%", "char": "iron_guard"},
	"rage_sigil": {"name": "狂怒印记", "desc": "怒气获取+50%", "char": "iron_guard"},
	"fortress_plate": {"name": "堡垒板甲", "desc": "每10点怒气受到伤害-2%（满怒-20%）", "char": "iron_guard"},
	"vital_bulwark": {"name": "生机壁垒", "desc": "格挡时回复3%最大生命", "char": "iron_guard"},
	"battle_badge": {"name": "战意徽章", "desc": "击杀获得15点怒气", "char": "iron_guard"},
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