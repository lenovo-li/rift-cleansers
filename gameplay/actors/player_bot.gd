class_name PlayerBot extends RefCounted
## 简单机器人：掉线托管、--bot 测试和完整模拟共用。只写 player.move_override，施放交给 _auto_cast。
## 优先级：躲预警/投射物/冲锋 > 救倒地队友 > 捡装备 > 被围时后撤闪避 > 打 Boss > 贴近最近敌人横移。

const CROWD_RADIUS: float = 3.0
const CROWD_LIMIT: int = 12
## 与预警圈边缘保持的额外距离（米）
const DANGER_MARGIN: float = 0.6
## 只躲这么远以内正在飞来的投射物（米）
const PROJECTILE_LOOKAHEAD: float = 6.0


var _last_pos: Vector3 = Vector3.INF
var _stuck_time: float = 0.0
var _detour_time: float = 0.0
var _detour_dir: Vector3 = Vector3.ZERO


func think(player: Node3D, enemies: Array) -> void:
	_decide(player, enemies)
	_unstick(player)


## 脱困：想移动却 0.5 秒几乎没动（被墙挡住），就沿墙横移 0.8 秒。
func _unstick(player: Node3D) -> void:
	var dt: float = player.get_physics_process_delta_time()
	var pos: Vector3 = player.global_position
	if _detour_time > 0.0:
		_detour_time -= dt
		player.move_override = _detour_dir
		_last_pos = pos
		return
	var wants: bool = player.move_override.length_squared() > 0.01
	if wants and _last_pos != Vector3.INF and pos.distance_to(_last_pos) < 0.02:
		_stuck_time += dt
	else:
		_stuck_time = 0.0
	_last_pos = pos
	if _stuck_time > 0.5:
		_stuck_time = 0.0
		_detour_time = 0.8
		var side: float = 1.0 if randf() < 0.5 else -1.0
		_detour_dir = player.move_override.normalized().cross(Vector3.UP) * side
		player.move_override = _detour_dir


## 躲避：走出地面预警圈/毒区，横移避开飞来的酸液弹和 Boss 冲锋线。返回躲避方向（零 = 安全）。
## 来不及走出即将爆炸的圈、或站在冲锋线上时翻滚。
func _evade(player: Node3D, enemies: Array) -> Vector3:
	var pos: Vector3 = player.global_position
	var tree: SceneTree = player.get_tree()
	var push: Vector3 = Vector3.ZERO
	var urgent: bool = false
	for d: Node in tree.get_nodes_in_group("danger"):
		var off: Vector3 = (pos - (d as Node3D).global_position) * Vector3(1, 0, 1)
		var r: float = float(d.get("radius")) + DANGER_MARGIN
		if off.length() < r:
			var away: Vector3 = off.normalized() if off.length() > 0.05 else Vector3.RIGHT
			push += away * (r - off.length() + 0.5)
			if d.has_method("time_left") and d.time_left() < (r - off.length()) / player.move_speed:
				urgent = true
	for pr: Node in tree.get_nodes_in_group("enemy_projectiles"):
		var dir: Vector3 = pr.direction()
		var rel: Vector3 = (pos - (pr as Node3D).global_position) * Vector3(1, 0, 1)
		var ahead: float = rel.dot(dir)
		if ahead <= 0.0 or ahead > PROJECTILE_LOOKAHEAD:
			continue
		var lateral: Vector3 = rel - dir * ahead
		if lateral.length() < 1.4:
			push += (lateral.normalized() if lateral.length() > 0.05 else dir.cross(Vector3.UP)) * 1.5
	for e: Node in enemies:
		if not (e is Boss):
			continue
		var w: Dictionary = (e as Boss).charge_warning()
		if w.is_empty():
			continue
		var rel: Vector3 = (pos - w.origin) * Vector3(1, 0, 1)
		var along: float = rel.dot(w.dir)
		var lateral: Vector3 = rel - w.dir * along
		if along > -1.0 and along < float(w.length) + 2.0 and lateral.length() < 3.0:
			push += (lateral.normalized() if lateral.length() > 0.05 else w.dir.cross(Vector3.UP)) * 3.0
			urgent = urgent or lateral.length() < 1.5
	if urgent and push != Vector3.ZERO and player.dodge_cooldown_remaining <= 0.0:
		player.facing = push.normalized()
		player.dodge()
	return push


func _decide(player: Node3D, enemies: Array) -> void:
	var pos: Vector3 = player.global_position
	var tree: SceneTree = player.get_tree()
	var evade: Vector3 = _evade(player, enemies)
	if evade != Vector3.ZERO:
		player.move_override = evade
		return
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
		var is_melee: bool = player.attack_kind != "bolt"
		if is_melee:
			player.move_override = to_e if nearest_d > 3.0 else tangent - to_e.normalized() * 0.3
		else:
			# 远程：保持 7 米距离（太远 -> 靠近，太近 -> 后退）
			var kite_d: float = 7.0
			if nearest_d > kite_d + 2.0:
				player.move_override = to_e.normalized()
			elif nearest_d < kite_d - 1.0:
				player.move_override = -to_e.normalized()
			else:
				player.move_override = tangent
	else:
		player.move_override = Vector3.ZERO


static func _toward(from: Vector3, to: Vector3, stop: float) -> Vector3:
	var d: Vector3 = (to - from) * Vector3(1, 0, 1)
	return d if d.length() > stop else Vector3.ZERO
