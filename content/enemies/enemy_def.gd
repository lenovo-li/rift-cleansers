class_name EnemyDef extends Resource
## 敌人数据定义（数据驱动，文档 05 §3.3）。每种敌人一个 .tres。

enum Behavior { CHASE, DASHER, RANGED, HEALER, BLOATER, BOSS }

@export var enemy_id: String = ""
@export var display_name: String = ""
@export var behavior: Behavior = Behavior.CHASE
@export var max_health: float = 60.0
@export var move_speed: float = 3.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.0
@export var attack_range: float = 1.5
@export var exp_reward: float = 2.0
@export var body_scale: float = 1.0
@export var color: Color = Color(1, 0.2, 0.2)
## 行为参数：DASHER 冲刺/爆炸，RANGED 射程，HEALER 治疗量，BLOATER 减速区。
@export var special_range: float = 0.0
@export var special_value: float = 0.0
@export var special_cooldown: float = 0.0
