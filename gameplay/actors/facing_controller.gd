extends RefCounted
class_name FacingController
## 角色朝向控制器：解耦移动方向和攻击朝向，支持多种模式

enum Mode {
	MOVE_DIRECTION,      # 默认：朝向移动方向
	LOCK_ENEMY,          # 锁定最近敌人
	SMART_CAST,          # 施法时智能朝向敌人
	MOUSE_AIM,           # 鼠标/右摇杆瞄准
	KEEP_FACING          # 保持当前朝向（后退不转身）
}

var mode: Mode = Mode.SMART_CAST
var current_facing: Vector3 = Vector3.FORWARD
var locked_target: Node3D = null
var _last_move_dir: Vector3 = Vector3.ZERO


## 更新朝向，返回新的 facing 向量
func update(delta: float, player_pos: Vector3, move_dir: Vector3, enemies: Array, is_casting: bool = false) -> Vector3:
	match mode:
		Mode.MOVE_DIRECTION:
			return _update_move_direction(move_dir)

		Mode.LOCK_ENEMY:
			return _update_lock_enemy(player_pos, enemies)

		Mode.SMART_CAST:
			return _update_smart_cast(player_pos, move_dir, enemies, is_casting)

		Mode.MOUSE_AIM:
			return _update_mouse_aim(player_pos)

		Mode.KEEP_FACING:
			return _update_keep_facing(move_dir)

	return current_facing


## 模式1：原版行为，朝向移动方向
func _update_move_direction(move_dir: Vector3) -> Vector3:
	if move_dir.length_squared() > 0.01:
		current_facing = move_dir.normalized()
		_last_move_dir = current_facing
	return current_facing


## 模式2：自动锁定最近的敌人
func _update_lock_enemy(player_pos: Vector3, enemies: Array) -> Vector3:
	# 如果锁定目标还活着且在范围内，保持锁定
	if locked_target != null and is_instance_valid(locked_target):
		if "is_alive" in locked_target and locked_target.is_alive:
			var dist: float = locked_target.global_position.distance_to(player_pos)
			if dist < 20.0:  # 锁定范围
				var dir: Vector3 = (locked_target.global_position - player_pos) * Vector3(1, 0, 1)
				if dir.length_squared() > 0.01:
					current_facing = dir.normalized()
					return current_facing

	# 寻找新目标
	locked_target = _find_nearest_enemy(player_pos, enemies, 15.0)
	if locked_target != null:
		var dir: Vector3 = (locked_target.global_position - player_pos) * Vector3(1, 0, 1)
		if dir.length_squared() > 0.01:
			current_facing = dir.normalized()

	return current_facing


## 模式3：智能施法 - 移动时跟随移动方向，施法瞬间朝向最近敌人
func _update_smart_cast(player_pos: Vector3, move_dir: Vector3, enemies: Array, is_casting: bool) -> Vector3:
	# 移动时更新朝向
	if move_dir.length_squared() > 0.01:
		_last_move_dir = move_dir.normalized()

	# 施法时，如果附近有敌人，自动朝向最近的
	if is_casting:
		var nearest: Node3D = _find_nearest_enemy(player_pos, enemies, 12.0)
		if nearest != null:
			var dir: Vector3 = (nearest.global_position - player_pos) * Vector3(1, 0, 1)
			if dir.length_squared() > 0.01:
				current_facing = dir.normalized()
				return current_facing

	# 否则保持移动方向
	current_facing = _last_move_dir if _last_move_dir.length_squared() > 0.01 else current_facing
	return current_facing


## 模式4：鼠标/右摇杆瞄准（3D俯视角）
func _update_mouse_aim(player_pos: Vector3) -> Vector3:
	# TODO: 需要相机引用来做射线投射
	# 暂时返回当前朝向，实际使用时需要传入相机
	return current_facing


## 模式5：保持朝向 - 后退时不转身（类似魂系锁定）
func _update_keep_facing(move_dir: Vector3) -> Vector3:
	# 只有前进时才改变朝向，后退/侧移保持原朝向
	if move_dir.length_squared() > 0.01:
		var dot: float = move_dir.normalized().dot(current_facing)
		# 如果移动方向与当前朝向夹角小于90度（向前方移动），则更新朝向
		if dot > 0.3:  # 给一点容差
			current_facing = move_dir.normalized()
			_last_move_dir = current_facing

	return current_facing


## 查找最近的存活敌人
func _find_nearest_enemy(player_pos: Vector3, enemies: Array, max_range: float) -> Node3D:
	var best: Node3D = null
	var best_dist_sq: float = max_range * max_range

	for enemy: Variant in enemies:
		if not (enemy is Node3D):
			continue
		if "is_alive" in enemy and not enemy.is_alive:
			continue

		var dist_sq: float = (enemy as Node3D).global_position.distance_squared_to(player_pos)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = enemy as Node3D

	return best


## 切换锁定目标（可绑定到按键）
func cycle_lock_target(player_pos: Vector3, enemies: Array, forward: bool = true) -> void:
	if enemies.is_empty():
		locked_target = null
		return

	# 找出所有有效目标并按距离排序
	var valid_targets: Array = []
	for enemy: Variant in enemies:
		if enemy is Node3D and "is_alive" in enemy and enemy.is_alive:
			var dist: float = (enemy as Node3D).global_position.distance_to(player_pos)
			if dist < 20.0:
				valid_targets.append({"node": enemy, "dist": dist})

	if valid_targets.is_empty():
		locked_target = null
		return

	valid_targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.dist < b.dist)

	# 找到当前锁定目标的索引
	var current_idx: int = -1
	for i in valid_targets.size():
		if valid_targets[i].node == locked_target:
			current_idx = i
			break

	# 切换到下一个/上一个
	if current_idx < 0:
		locked_target = valid_targets[0].node
	else:
		var next_idx: int = (current_idx + (1 if forward else -1)) % valid_targets.size()
		locked_target = valid_targets[next_idx].node


## 清除锁定
func clear_lock() -> void:
	locked_target = null


## 获取锁定状态文本（用于UI显示）
func get_lock_status() -> String:
	if mode == Mode.LOCK_ENEMY and locked_target != null and is_instance_valid(locked_target):
		if "get_display_name" in locked_target:
			return "锁定: %s" % locked_target.get_display_name()
		return "已锁定目标"
	return ""
