class_name ReflectAura extends Skill
## 反射光环：一段时间内减伤并把承受伤害按比例反射给攻击者。
## 光环数值由调用方写入施法者（CharacterStats.set_aura），技能本身只返回参数。
## Lv1: 持续5秒，反射50%，减伤20%
## Lv3: 反射80%
## Lv5: 光环范围内每0.5秒造成伤害（半径3.5米，20DPS）
## Lv8: 持续1.6x，减伤40%

const BASE_DURATION: float = 5.0
const AURA_RADIUS: float = 3.5
const AURA_DPS: float = 20.0


func _init() -> void:
	skill_id = "reflect_aura"
	display_name = "反射光环"
	max_level = 999


func get_tier_thresholds() -> Array[int]:
	return [1, 3, 5, 8]


func get_cooldown() -> float:
	return 14.0


func cast(ctx: SkillContext) -> Dictionary:
	var tier: int = get_tier()
	var duration: float = BASE_DURATION * (1.6 if tier >= 8 else 1.0)
	var reflect: float = 0.8 if tier >= 3 else 0.5
	var reduction: float = 0.4 if tier >= 8 else 0.2
	if tier >= 5:
		var zone: GroundZone = GroundZone.new(ctx.origin, ctx.origin, AURA_RADIUS * ctx.area_mult,
				AURA_DPS * ctx.damage_mult, duration)
		zone.anchor = ctx.caster
		zone.kind = "aura"
		ctx.new_zones.append(zone)
	return {
		"hits": 0, "damage": 0.0, "tier": tier,
		"aura_duration": duration, "reflect": reflect, "reduction": reduction,
	}
