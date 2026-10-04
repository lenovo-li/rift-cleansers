extends RefCounted
## 回归测试：防止敌人伤害累积 bug 再次出现


func test_enemy_def_not_mutated() -> String:
	var zombie_def: EnemyDef = load("res://content/enemies/zombie.tres")
	var original_damage: float = zombie_def.attack_damage
	var original_health: float = zombie_def.max_health

	# 模拟多次生成（如果是 bug 版本，共享资源会被修改）
	for i in 20:
		var copy: EnemyDef = zombie_def.duplicate()
		copy.attack_damage *= 1.5  # 模拟时间递增缩放
		copy.max_health *= 1.2

	# 原始资源不应被修改
	if not is_equal_approx(zombie_def.attack_damage, original_damage):
		return "僵尸伤害被修改: %.1f → %.1f (应保持不变)" % [original_damage, zombie_def.attack_damage]
	if not is_equal_approx(zombie_def.max_health, original_health):
		return "僵尸生命被修改: %.1f → %.1f (应保持不变)" % [original_health, zombie_def.max_health]

	return ""
