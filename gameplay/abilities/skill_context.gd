class_name SkillContext extends RefCounted
## 技能施放上下文：施法者位置与朝向、候选目标，以及技能新产生的地面效果。
## 目标对象需提供：global_position、is_alive、take_damage(float)、apply_knockback(Vector3)。

## 施法者（需有 global_position）。持续跟随类效果用它作为锚点，可为 null。
var caster: Object = null
var origin: Vector3 = Vector3.ZERO
var facing: Vector3 = Vector3.FORWARD
var targets: Array = []
var new_zones: Array[GroundZone] = []


## XZ 平面上的单位朝向；朝向为零时退回 Vector3.FORWARD。
func flat_facing() -> Vector3:
	var f: Vector3 = Vector3(facing.x, 0.0, facing.z)
	return Vector3.FORWARD if f.length_squared() < 0.0001 else f.normalized()


func alive_targets() -> Array:
	var result: Array = []
	for t: Variant in targets:
		if is_instance_valid(t) and t.is_alive:
			result.append(t)
	return result
