class_name Skill extends RefCounted
## 技能基类。子类覆盖 get_tier_thresholds / get_cooldown / cast。
## 技能只读写 SkillContext，不访问场景树：便于单元测试，也便于日后改为主机权威结算。

var skill_id: String = ""
var display_name: String = ""
var level: int = 1
var max_level: int = 8


func set_level(value: int) -> void:
	level = clampi(value, 1, max_level)


## 进化档位阈值（升序）。默认只有一档。
func get_tier_thresholds() -> Array[int]:
	return [1]


## 当前档位 = 不超过 level 的最大阈值。例如阈值 [1,3,5,8]、level 4 -> 档位 3。
func get_tier() -> int:
	var tier: int = 1
	for threshold: int in get_tier_thresholds():
		if level >= threshold:
			tier = threshold
	return tier


func get_cooldown() -> float:
	return 1.0


## 档位之间的普通等级：每级伤害 +10%（例如 Lv4 = 3 档 × 1.1）。由施法者乘进 SkillContext.damage_mult。
func level_bonus() -> float:
	return 1.0 + 0.1 * float(level - get_tier())


## 执行技能。返回结果字典，至少包含 hits(int) 和 damage(float)。
func cast(_ctx: SkillContext) -> Dictionary:
	return {"hits": 0, "damage": 0.0}
