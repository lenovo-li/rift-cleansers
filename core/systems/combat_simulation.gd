class_name CombatSimulation extends Node
## 战斗模拟器 - 处理所有伤害、治疗、状态效果

signal entity_damaged(entity_id: int, damage: float, source_id: int)
signal entity_died(entity_id: int, killer_id: int)

var entities: Dictionary = {}  # entity_id -> EntityState


class EntityState:
	var entity_id: int
	var health: float
	var max_health: float
	var team: int
	var is_alive: bool = true


func register_entity(id: int, max_hp: float, team: int) -> void:
	var state: EntityState = EntityState.new()
	state.entity_id = id
	state.health = max_hp
	state.max_health = max_hp
	state.team = team
	entities[id] = state


func apply_damage(target_id: int, damage: float, source_id: int) -> void:
	if not entities.has(target_id):
		return
	
	var target: EntityState = entities[target_id]
	if not target.is_alive:
		return
	
	target.health -= damage
	entity_damaged.emit(target_id, damage, source_id)
	
	if target.health <= 0.0:
		target.health = 0.0
		target.is_alive = false
		entity_died.emit(target_id, source_id)


func get_entity_health(entity_id: int) -> float:
	if entities.has(entity_id):
		return entities[entity_id].health
	return 0.0


func is_entity_alive(entity_id: int) -> bool:
	if entities.has(entity_id):
		return entities[entity_id].is_alive
	return false
