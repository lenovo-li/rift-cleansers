class_name PlayerQuery extends RefCounted
## 场景中所有玩家（"players" 组）的查询：多人时敌人、危险区、拾取物都用它，不再写死 PlayerM1。


static func all(tree: SceneTree) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for n: Node in tree.get_nodes_in_group("players"):
		result.append(n as Node3D)
	return result


static func alive(tree: SceneTree) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for n: Node in tree.get_nodes_in_group("players"):
		if not n.get("is_dead"):
			result.append(n as Node3D)
	return result


## 最近的存活玩家；没有时返回 null。
static func nearest_alive(tree: SceneTree, pos: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d: float = INF
	for p: Node3D in alive(tree):
		var d: float = p.global_position.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = p
	return best


## XZ 平面半径内的存活玩家。
static func alive_in_radius(tree: SceneTree, pos: Vector3, radius: float) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for p: Node3D in alive(tree):
		var d: Vector3 = p.global_position - pos
		d.y = 0.0
		if d.length() <= radius:
			result.append(p)
	return result
