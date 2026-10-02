class_name SkillFactory extends RefCounted
## 技能工厂：按 id 创建技能实例。
## 铁卫：shield_bash, whirlwind, taunt, charge, ground_slam, reflect_aura
## 元素术士：fireball, ice_lance, frost_nova, chain_lightning, meteor, storm_field
## 影行者：shadow_step, fan_of_knives, death_mark, blade_flurry, smoke_bomb, execute
## 牧师：holy_nova, smite, sanctuary, divine_shield, blessing, divine_intervention

const SKILL_IDS: Array[String] = [
	"shield_bash", "whirlwind", "taunt", "charge", "ground_slam", "reflect_aura",
]


static func create(skill_id: String) -> Skill:
	match skill_id:
		"shield_bash": return ShieldBash.new()
		"whirlwind": return Whirlwind.new()
		"taunt": return Taunt.new()
		"charge": return Charge.new()
		"ground_slam": return GroundSlam.new()
		"reflect_aura": return ReflectAura.new()
		"earthquake": return Earthquake.new()
		"iron_wall": return IronWall.new()
		"war_cry": return WarCry.new()
		"flame_cleave": return FlameCleave.new()
		"fireball": return Fireball.new()
		"ice_lance": return IceLance.new()
		"frost_nova": return FrostNova.new()
		"chain_lightning": return ChainLightning.new()
		"meteor": return Meteor.new()
		"storm_field": return StormField.new()
		"thunderstorm": return Thunderstorm.new()
		"frost_barrier": return FrostBarrier.new()
		"arcane_barrage": return ArcaneBarrage.new()
		"lava_blast": return LavaBlast.new()
		"shadow_step": return ShadowStep.new()
		"fan_of_knives": return FanOfKnives.new()
		"death_mark": return DeathMark.new()
		"blade_flurry": return BladeFlurry.new()
		"smoke_bomb": return SmokeBomb.new()
		"execute": return Execute.new()
		"eviscerate": return Eviscerate.new()
		"shadow_clone": return ShadowClone.new()
		"backstab": return Backstab.new()
		"poison_blade": return PoisonBlade.new()
		"holy_nova": return HolyNova.new()
		"smite": return Smite.new()
		"sanctuary": return Sanctuary.new()
		"divine_shield": return DivineShield.new()
		"blessing": return Blessing.new()
		"divine_intervention": return DivineIntervention.new()
		"guardian_angel": return GuardianAngel.new()
		"purify": return Purify.new()
		"resurrection": return Resurrection.new()
		"holy_wrath": return HolyWrath.new()
	push_error("未知技能: %s" % skill_id)
	return null


static func display_name(skill_id: String) -> String:
	var s: Skill = create(skill_id)
	return s.display_name if s != null else skill_id
