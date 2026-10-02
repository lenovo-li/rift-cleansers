class_name EquipmentEffects extends RefCounted
## 文档 10 §4 / 文档 11「元素增幅装备」的规则：按技能元素与协同标签计算伤害、冷却、范围倍率和元素参数。
## 纯函数（只读 CharacterStats），施法前由 PlayerM1 调用；施法后的行为型效果（回响、扩散等）见 post_cast_plan。

const ELEMENT_DAMAGE: Dictionary = {
	"fire_talisman": ["fire", 1.25], "frost_ring": ["ice", 1.25], "storm_core": ["lightning", 1.25],
	"shadow_emblem": ["shadow", 1.25], "holy_symbol": ["holy", 1.2], "poison_fang": ["poison", 1.3],
}


## 技能伤害倍率（装备部分，不含 CharacterStats.damage_multiplier 里的通用加成）。
static func damage_mult(stats: CharacterStats, skill_id: String) -> float:
	var mult: float = 1.0
	var elem: String = Elements.of(skill_id)
	for id: String in ELEMENT_DAMAGE:
		if stats.has_equipment(id) and ELEMENT_DAMAGE[id][0] == elem:
			mult *= float(ELEMENT_DAMAGE[id][1])
	if stats.has_equipment("burst_amplifier"):
		mult *= 1.25
	if stats.has_equipment("rapid_fire"):
		mult *= 0.85
	if stats.has_equipment("piercing_blade") and SkillSynergy.has_tag(skill_id, "single"):
		mult *= 0.9
	return mult


## 技能冷却倍率（装备部分）。
static func cooldown_mult(stats: CharacterStats, _skill_id: String) -> float:
	var mult: float = 1.0
	if stats.has_equipment("overclock_core"):
		mult *= 0.7
	if stats.has_equipment("burst_amplifier"):
		mult *= 1.2
	if stats.has_equipment("rapid_fire"):
		mult *= 0.75
	return mult


static func area_mult(stats: CharacterStats, skill_id: String) -> float:
	return 1.25 if stats.has_equipment("wind_feather") and Elements.of(skill_id) == "wind" else 1.0


static func heal_mult(stats: CharacterStats) -> float:
	return 1.15 if stats.has_equipment("holy_symbol") else 1.0


## 传给 Elements / Reactions 的参数。
static func element_mods(stats: CharacterStats, skill_id: String) -> Dictionary:
	var m: Dictionary = {}
	if stats.has_equipment("elemental_focus"):
		m.intensity_mult = 1.5
	if stats.has_equipment("reaction_catalyst"):
		m.reaction_mult = 1.4
	if stats.has_equipment("ignition_core"):
		m.ignite_mult = 1.5
	if stats.has_equipment("frost_shard"):
		m.slow_mult = 1.25
		m.freeze_bonus = 1.0
	if stats.has_equipment("freeze_catalyst"):
		m.freeze_bonus = float(m.get("freeze_bonus", 0.0)) + 1.0
		m.freeze_threshold = 45.0
	if stats.has_equipment("storm_conductor"):
		m.shock_cap = 15
		m.chain_range_mult = 1.3
	if stats.has_equipment("toxic_vial"):
		m.poison_mult = 1.4
		m.poison_heal_mult = 2.0
	if stats.has_equipment("overload_amplifier"):
		m.overload_mult = 1.3
		m.overload_radius_mult = 1.5
	if stats.has_equipment("melt_core"):
		m.melt_bonus = 0.5
	if stats.has_equipment("chain_conductor"):
		m.chain_range_mult = 1.3
	if stats.has_equipment("swirl_amplifier"):
		m.swirl_mult = 1.5
	if stats.has_equipment("annihilate_orb"):
		m.annihilate_min = 2
		m.reaction_mult = float(m.get("reaction_mult", 1.0)) * 1.3
	if stats.has_equipment("duration_extension") and SkillSynergy.has_tag(skill_id, "dot"):
		m.dot_duration_mult = 1.5
	return m


## 装备附加的额外元素：双元素核心（火↔冰 40%）、三元素水晶（火冰雷各 20%）、元素融合（术士专属，同双元素）。
static func extra_elements(stats: CharacterStats, element: String, intensity: float) -> Array:
	var out: Array = []
	if stats.has_equipment("dual_element") or stats.has_equipment("elemental_fusion"):
		if element == "fire":
			out.append(["ice", intensity * 0.4])
		elif element == "ice":
			out.append(["fire", intensity * 0.4])
	if stats.has_equipment("tri_element") and not element.is_empty():
		for e: String in ["fire", "ice", "lightning"]:
			if e != element:
				out.append([e, intensity * 0.2])
	return out


## 连锁 +N（连锁导体）、击退/碎裂倍率（冲击波戒指、碎裂手套）
static func chain_bonus(stats: CharacterStats) -> int:
	return 2 if stats.has_equipment("chain_conductor") else 0


static func knockback_mult(stats: CharacterStats) -> float:
	return 1.4 if stats.has_equipment("shockwave_ring") else 1.0


static func shatter_mult(stats: CharacterStats) -> float:
	var m: float = 1.3 if stats.has_equipment("shockwave_ring") else 1.0
	return m * (1.5 if stats.has_equipment("shatter_gauntlet") else 1.0)
