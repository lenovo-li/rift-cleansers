class_name PlayerBot extends RefCounted
## 机器人：掉线托管、--bot 测试和完整模拟共用。只写 player.move_override，施放交给 _auto_cast。
## 优先级：躲预警/投射物/Boss 冲锋/小鬼冲刺 > 救倒地队友 > 捡装备 > 低血捡治疗球
## > 被围（或低血时半被围）按方向采样撤到最空的一边 > 打 Boss > 近战先切后排远程/治疗者，远程按最近敌人风筝。

const CROWD_RADIUS: float = 3.5
const CROWD_LIMIT: int = 8  # 降低阈值，更早撤退避免被围殴
## 与预警圈边缘保持的额外距离（米）
const DANGER_MARGIN: float = 0.8
## 只躲这么远以内正在飞来的投射物（米）
const PROJECTILE_LOOKAHEAD: float = 8.0  # 提前躲远程酸液
const LOW_HP_THRESHOLD: float = 0.4  # 血量低于 40% 主动找治疗球
const DASHER_EVADE_RANGE: float = 3.0  # 小鬼蓄力时提前拉开


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
	# 小鬼 / 沙甲虫：蓄力（变白）或冲刺中，站在冲刺线上就横移出去；贴脸冲刺时翻滚
	for e: Node in enemies:
		var ai: Enemy = e as Enemy
		if ai == null or ai.def == null or ai.def.behavior != EnemyDef.Behavior.DASHER or ai._dash_state not in [1, 2]:
			continue
		var rel: Vector3 = (pos - ai.global_position) * Vector3(1, 0, 1)
		var dir: Vector3 = ai._dash_dir
		var along: float = rel.dot(dir)
		var lateral: Vector3 = rel - dir * along
		if along > -0.5 and along < ai.def.special_range + 1.0 and lateral.length() < 1.6:
			push += (lateral.normalized() if lateral.length() > 0.05 else dir.cross(Vector3.UP)) * 2.0
			urgent = urgent or (ai._dash_state == 2 and along < DASHER_EVADE_RANGE)
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
	var low_hp: bool = player.stats.health < player.stats.max_health * LOW_HP_THRESHOLD
	var heal_target: Node3D = null
	var heal_d: float = 15.0
	for p: Node in tree.get_nodes_in_group("pickups"):
		if p.get("kind") == "equipment" and not player.stats.has_equipment(p.get("item_id")):
			player.move_override = _toward(pos, (p as Node3D).global_position, 0.0)
			return
		if low_hp and p.get("kind") == "heal":
			var hd: float = (p as Node3D).global_position.distance_to(pos)
			if hd < heal_d:
				heal_d = hd
				heal_target = p as Node3D
	var nearest: Node3D = null
	var nearest_d: float = INF
	var priority: Node3D = null  # 远程 / 治疗者：会躲在后排持续输出，近战角色应当先切掉
	var priority_d: float = 10.0
	var crowd: int = 0
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
		var ai: Enemy = e as Enemy
		if ai != null and ai.def != null and d < priority_d \
				and ai.def.behavior in [EnemyDef.Behavior.RANGED, EnemyDef.Behavior.HEALER]:
			priority_d = d
			priority = e3
	# 低血量：附近有治疗球就去捡（周围不算太挤时）
	if heal_target != null and crowd <= CROWD_LIMIT / 2:
		player.move_override = _toward(pos, heal_target.global_position, 0.0)
		return
	if crowd > CROWD_LIMIT or (low_hp and crowd > CROWD_LIMIT / 2):
		player.move_override = _safest_direction(pos, enemies, tree)
		if player.dodge_cooldown_remaining <= 0.0 and crowd > CROWD_LIMIT:
			player.facing = player.move_override
			player.dodge()
	elif boss != null:
		var to_b: Vector3 = (boss.global_position - pos) * Vector3(1, 0, 1)
		var keep: float = 2.5 if player.attack_kind != "bolt" else 6.0  # 近战贴身，远程保持距离
		player.move_override = to_b if to_b.length() > keep else to_b.cross(Vector3.UP).normalized()
	elif nearest != null:
		var is_melee: bool = player.attack_kind != "bolt"
		# 近战优先切后排远程 / 治疗者；远程保持按最近敌人风筝
		var target: Node3D = priority if is_melee and priority != null else nearest
		var target_d: float = target.global_position.distance_to(pos)
		var to_e: Vector3 = (target.global_position - pos) * Vector3(1, 0, 1)
		var tangent: Vector3 = to_e.cross(Vector3.UP).normalized()
		if is_melee:
			player.move_override = to_e if target_d > 3.0 else tangent - to_e.normalized() * 0.3
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


## 被围时的撤退方向：采样 12 个方向，按 4 米外落点附近的敌人、危险区和场地边界打分，取最空的一边。
static func _safest_direction(pos: Vector3, enemies: Array, tree: SceneTree) -> Vector3:
	var best: Vector3 = Vector3.RIGHT
	var best_score: float = -INF
	var dangers: Array[Node] = tree.get_nodes_in_group("danger")
	for i in 12:
		var a: float = TAU * i / 12.0
		var dir: Vector3 = Vector3(cos(a), 0, sin(a))
		var probe: Vector3 = pos + dir * 4.0
		var score: float = 0.0
		for e: Node in enemies:
			var d: float = (e as Node3D).global_position.distance_to(probe)
			if d < 6.0:
				score -= 6.0 - d
		for dg: Node in dangers:
			var d: float = (dg as Node3D).global_position.distance_to(probe)
			if d < float(dg.get("radius")) + 1.5:
				score -= 20.0
		if absf(probe.x) > 90.0 or absf(probe.z) > 90.0:
			score -= 30.0
		if score > best_score:
			best_score = score
			best = dir
	return best


static func _toward(from: Vector3, to: Vector3, stop: float) -> Vector3:
	var d: Vector3 = (to - from) * Vector3(1, 0, 1)
	return d if d.length() > stop else Vector3.ZERO
