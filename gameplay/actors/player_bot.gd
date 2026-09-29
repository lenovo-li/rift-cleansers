class_name PlayerBot extends RefCounted
## 简单机器人：掉线托管、--bot 测试和完整模拟共用。只写 player.move_override，施放交给 _auto_cast。
## 优先级：救倒地队友 > 捡装备 > 被围时后撤闪避 > 打 Boss > 贴近最近敌人横移。

const CROWD_RADIUS: float = 3.0
const CROWD_LIMIT: int = 12


func think(player: Node3D, enemies: Array) -> void:
	var pos: Vector3 = player.global_position
	var tree: SceneTree = player.get_tree()
	for other: Node in tree.get_nodes_in_group("players"):
		if other != player and other.get("is_dead"):
			player.move_override = _toward(pos, (other as Node3D).global_position, 1.2)
			return
	for p: Node in tree.get_nodes_in_group("pickups"):
		if p.get("kind") == "equipment" and not player.stats.has_equipment(p.get("item_id")):
			player.move_override = _toward(pos, (p as Node3D).global_position, 0.0)
			return
	var nearest: Node3D = null
	var nearest_d: float = INF
	var crowd: int = 0
	var crowd_center: Vector3 = Vector3.ZERO
	var boss: Node3D = null
	for e: Node in enemies:
		var e3: Node3D = e as Node3D
		var d: float = e3.global_position.distance_to(pos)
		if e is Boss:
			boss = e3
		if d < nearest_d:
			nearest_d = d
			nearest = e3
		if d < CROWD_RADIUS:
			crowd += 1
			crowd_center += e3.global_position
	if crowd > CROWD_LIMIT:
		player.move_override = (pos - crowd_center / crowd) * Vector3(1, 0, 1) + Vector3(0.001, 0, 0)
		if player.dodge_cooldown_remaining <= 0.0:
			player.dodge()
	elif boss != null:
		var to_b: Vector3 = (boss.global_position - pos) * Vector3(1, 0, 1)
		player.move_override = to_b if to_b.length() > 4.0 else to_b.cross(Vector3.UP).normalized()
	elif nearest != null:
		var to_e: Vector3 = (nearest.global_position - pos) * Vector3(1, 0, 1)
		var tangent: Vector3 = to_e.cross(Vector3.UP).normalized()
		player.move_override = to_e if nearest_d > 3.0 else tangent - to_e.normalized() * 0.3
	else:
		player.move_override = Vector3.ZERO


static func _toward(from: Vector3, to: Vector3, stop: float) -> Vector3:
	var d: Vector3 = (to - from) * Vector3(1, 0, 1)
	return d if d.length() > stop else Vector3.ZERO
