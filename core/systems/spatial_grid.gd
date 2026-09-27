class_name SpatialGrid extends RefCounted
## 均匀空间网格（XZ 平面），用于范围查询。
## 每帧 clear() 后重新 insert()，再做任意次 query_circle()。

var cell_size: float
var cells: Dictionary = {}  # Vector2i -> Array[int]
var entity_positions: Dictionary = {}  # int -> Vector3


func _init(p_cell_size: float = 10.0) -> void:
	assert(p_cell_size > 0.0)
	cell_size = p_cell_size


func clear() -> void:
	cells.clear()
	entity_positions.clear()


func insert(entity_id: int, position: Vector3) -> void:
	var key: Vector2i = _cell_key(position)
	if not cells.has(key):
		cells[key] = []
	cells[key].append(entity_id)
	entity_positions[entity_id] = position


func query_circle(center: Vector3, radius: float) -> Array[int]:
	var results: Array[int] = []
	var radius_sq: float = radius * radius
	var min_cell: Vector2i = _cell_key(center - Vector3(radius, 0.0, radius))
	var max_cell: Vector2i = _cell_key(center + Vector3(radius, 0.0, radius))
	for cx in range(min_cell.x, max_cell.x + 1):
		for cz in range(min_cell.y, max_cell.y + 1):
			var key: Vector2i = Vector2i(cx, cz)
			if not cells.has(key):
				continue
			for entity_id: int in cells[key]:
				var pos: Vector3 = entity_positions[entity_id]
				var dx: float = pos.x - center.x
				var dz: float = pos.z - center.z
				if dx * dx + dz * dz <= radius_sq:
					results.append(entity_id)
	return results


func size() -> int:
	return entity_positions.size()


func _cell_key(position: Vector3) -> Vector2i:
	return Vector2i(int(floor(position.x / cell_size)), int(floor(position.z / cell_size)))
