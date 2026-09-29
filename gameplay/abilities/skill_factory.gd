class_name SkillFactory extends RefCounted
## 铁卫的 6 个主技能（文档 05 §1.2）：id -> 实例。顺序即 HUD 技能栏顺序。

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
	push_error("未知技能: %s" % skill_id)
	return null


static func display_name(skill_id: String) -> String:
	var s: Skill = create(skill_id)
	return s.display_name if s != null else skill_id
