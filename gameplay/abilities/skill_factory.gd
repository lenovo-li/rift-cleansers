class_name SkillFactory extends RefCounted
## 技能工厂：按 id 创建技能实例。
## 铁卫：shield_bash, whirlwind, taunt, charge, ground_slam, reflect_aura
## 元素术士：fireball, ice_lance, frost_nova, chain_lightning, meteor, storm_field

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
		"fireball": return Fireball.new()
		"ice_lance": return IceLance.new()
		"frost_nova": return FrostNova.new()
		"chain_lightning": return ChainLightning.new()
		"meteor": return Meteor.new()
		"storm_field": return StormField.new()
	push_error("未知技能: %s" % skill_id)
	return null


static func display_name(skill_id: String) -> String:
	var s: Skill = create(skill_id)
	return s.display_name if s != null else skill_id
