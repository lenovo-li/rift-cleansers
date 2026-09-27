# 《裂界清扫者》游戏技术架构

> 版本：v1.0  
> 日期：2026-09-27  
> 基于：Godot 4.7.2 + GDScript  
> 状态：设计完成，待实现

---

## 执行摘要

**架构原则**：
1. 战斗规则与视觉表现分离
2. 战斗规则与网络传输分离
3. 单人和多人共用核心逻辑
4. 内容数据驱动（Resource配置）
5. 所有实体有稳定ID
6. 随机数由种子控制

**核心模块**：GameSession → CombatSimulation → NetworkSession → PresentationLayer

---

## 1. 整体架构图

```
┌─────────────────────────────────────────────────────────────┐
│                        GameSession                           │
│  ┌────────────┐  ┌────────────┐  ┌─────────────┐           │
│  │ 会话状态    │  │ 时间控制    │  │ 胜负判定     │           │
│  │ 人数管理    │  │ 暂停处理    │  │ 奖励结算     │           │
│  └────────────┘  └────────────┘  └─────────────┘           │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ CombatSim    │   │ NetworkSess  │   │ Presentation │
│              │   │              │   │              │
│ • 属性计算   │   │ • RPC        │   │ • 粒子       │
│ • 伤害结算   │   │ • 快照同步   │   │ • 动画       │
│ • 状态效果   │   │ • 输入缓冲   │   │ • 音效       │
│ • 技能系统   │   │ • 校正插值   │   │ • UI         │
│ • AI逻辑     │   │              │   │ • 镜头       │
└──────────────┘   └──────────────┘   └──────────────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            ▼
                ┌──────────────────────┐
                │    ContentDatabase   │
                │  • 角色配置          │
                │  • 技能配置          │
                │  • 装备配置          │
                │  • 敌人配置          │
                │  • 地图配置          │
                └──────────────────────┘
```

---

## 2. 核心模块详解

### 2.1 GameSession（游戏会话）

**职责**：
- 管理游戏生命周期（开始/暂停/结束）
- 维护全局时间和随机种子
- 管理玩家列表和人数
- 判定胜负条件
- 处理奖励结算

**接口**：

```gdscript
class_name GameSession extends Node

## 会话状态
enum State { LOBBY, STARTING, PLAYING, PAUSED, VICTORY, DEFEAT }
var state: State = State.LOBBY

## 时间系统
var game_time: float = 0.0  # 游戏内时间（不受暂停影响）
var real_time: float = 0.0  # 真实时间
var time_scale: float = 1.0

## 随机数系统
var master_seed: int = 0
var random_streams: Dictionary = {}  # {"spawn": RandomNumberGenerator, "loot": ...}

## 玩家管理
var players: Array[PlayerState] = []
var player_count: int = 1

## 难度缩放
var difficulty_multiplier: float = 1.0

## 核心方法
func start_game(seed: int, player_data: Array) -> void
func pause_game() -> void
func resume_game() -> void
func end_game(victory: bool) -> void
func add_player(player_data: Dictionary) -> PlayerState
func remove_player(player_id: int) -> void
func get_random_stream(stream_name: String) -> RandomNumberGenerator
```

**数据结构**：

```gdscript
class_name PlayerState extends RefCounted

var peer_id: int  # 网络ID（单人模式为1）
var entity_id: int  # 游戏内稳定ID
var character_id: String  # "ironguard", "elementalist"
var position: Vector2
var health: float
var max_health: float
var shield: float
var attributes: Dictionary  # {"damage_mult": 1.5, "move_speed": 300, ...}
var skills: Array[SkillState]
var equipment: Array[EquipmentState]
var status_effects: Array[StatusEffect]
var level: int = 1
var experience: float = 0.0
var is_alive: bool = true
var is_ai_controlled: bool = false
```

### 2.2 CombatSimulation（战斗模拟）

**职责**：
- 执行所有战斗规则（不关心网络和表现）
- 管理实体生命周期
- 处理伤害、治疗、状态效果
- 驱动技能系统和AI
- 生成掉落和经验

**核心系统**：

#### AbilitySystem（技能系统）

```gdscript
class_name AbilitySystem extends Node

## 技能状态
class SkillState:
    var skill_id: String
    var level: int = 1
    var cooldown_remaining: float = 0.0
    var charges: int = 1
    var is_ready: bool = true

## 核心方法
func request_cast_skill(caster: Entity, skill_id: String, target_pos: Vector2) -> SkillCastResult
func update_cooldowns(delta: float) -> void
func can_cast(caster: Entity, skill_id: String) -> bool
func apply_skill_effect(skill_config: SkillResource, caster: Entity, targets: Array) -> void
```

**技能配置示例**：

```gdscript
# res://content/skills/lightning_chain.tres
class_name SkillResource extends Resource

@export var skill_id: String = "lightning_chain"
@export var display_name: String = "雷霆链"
@export var icon: Texture2D
@export var base_cooldown: float = 2.0
@export var base_damage: float = 100.0
@export var base_range: float = 600.0
@export var projectile_speed: float = 800.0
@export var chain_count: int = 2
@export var element_type: String = "lightning"
@export var tags: Array[String] = ["projectile", "chain", "electric"]
@export var evolution_levels: Dictionary = {
    1: {"chain_count": 2, "damage_mult": 1.0},
    3: {"chain_count": 3, "damage_mult": 1.2, "death_explosion": true},
    5: {"chain_count": 4, "damage_mult": 1.5, "dual_cast": true},
    8: {"storm_mode": true, "damage_mult": 2.0}
}
@export var network_strategy: String = "authoritative"  # authoritative/predicted/local
```

#### StatusEffectSystem（状态系统）

```gdscript
class_name StatusEffectSystem extends Node

class StatusEffect:
    var effect_id: String  # "fire_dot", "frozen", "shocked"
    var stacks: int = 1
    var max_stacks: int = 10
    var duration: float = 5.0
    var tick_interval: float = 1.0
    var tick_timer: float = 0.0
    var source_entity_id: int = 0

func apply_status(target: Entity, effect_id: String, source: Entity) -> void
func update_status_effects(entity: Entity, delta: float) -> void
func check_reaction(entity: Entity) -> ReactionResult  # 元素反应检测
```

#### DamageSystem（伤害系统）

```gdscript
class_name DamageSystem extends Node

class DamageInstance:
    var source_entity_id: int
    var target_entity_id: int
    var base_damage: float
    var damage_type: String  # "physical", "fire", "ice", "lightning"
    var is_crit: bool = false
    var can_lifesteal: bool = true
    var source_skill_id: String = ""

func calculate_damage(instance: DamageInstance) -> float
func apply_damage(instance: DamageInstance) -> DamageResult
func trigger_on_hit_effects(source: Entity, target: Entity, damage: float) -> void
```

**伤害计算流程**：

```
基础伤害 
  → 应用技能等级加成
  → 应用属性倍率（damage_mult）
  → 暴击判定
  → 应用敌人抗性（未来扩展）
  → 应用护盾吸收
  → 最终伤害
  → 触发吸血/反击/连锁效果
```

#### SpawnDirector（生成导演）

```gdscript
class_name SpawnDirector extends Node

## 刷怪预算
var spawn_budget: int = 100  # 当前场上敌人预算
var max_budget: int = 500    # 根据玩家人数调整

## 刷怪计划
var spawn_timeline: Array[SpawnEvent] = []

class SpawnEvent:
    var trigger_time: float
    var enemy_type: String
    var count: int
    var spawn_region: Rect2
    var formation: String  # "circle", "line", "swarm"
    var target_player: int = -1  # -1表示自动选择

func update(game_time: float, player_count: int) -> void
func spawn_wave(event: SpawnEvent) -> Array[Entity]
func adjust_budget_for_player_count(count: int) -> void
```

#### EnemySystem（敌人系统）

```gdscript
class_name EnemySystem extends Node

class EnemyState:
    var entity_id: int
    var enemy_type: String
    var position: Vector2
    var velocity: Vector2
    var health: float
    var max_health: float
    var ai_state: String  # "idle", "chasing", "attacking", "fleeing"
    var target_player_id: int
    var elite_modifiers: Array[String] = []  # ["teleporter", "vampire"]
    var swarm_id: int = -1  # 属于哪个群组（-1表示独立）

func update_ai(enemy: EnemyState, delta: float, players: Array[PlayerState]) -> void
func get_target_player(enemy: EnemyState, players: Array) -> PlayerState
func apply_elite_modifier_logic(enemy: EnemyState) -> void
```

### 2.3 NetworkSession（网络会话）

**职责**：
- 管理多人连接和RPC
- 缓冲和预测客户端输入
- 生成和同步状态快照
- 处理掉线和重连

**单人模式行为**：
- NetworkSession存在但不建立网络连接
- 输入直接传递给CombatSimulation
- 无快照序列化开销

**多人模式行为**：
- 主机运行完整CombatSimulation
- 客户端运行预测和插值
- 定期快照同步

```gdscript
class_name NetworkSession extends Node

var is_host: bool = false
var connected_peers: Dictionary = {}  # {peer_id: PeerInfo}

## 输入缓冲
var input_buffer: Array[InputFrame] = []

class InputFrame:
    var peer_id: int
    var tick: int
    var move_direction: Vector2
    var dash: bool
    var cast_skill: bool
    var skill_direction: Vector2

## 快照系统
func generate_snapshot() -> Dictionary
func apply_snapshot(snapshot: Dictionary) -> void
func send_snapshot_to_clients() -> void

## RPC定义
@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_input(input_data: Dictionary) -> void

@rpc("authority", "call_remote", "reliable")
func sync_game_state(snapshot: Dictionary) -> void

@rpc("any_peer", "call_remote", "reliable")
func request_reconnect(token: String) -> void
```

### 2.4 PresentationLayer（表现层）

**职责**：
- 渲染实体（不决定实体逻辑）
- 播放粒子和音效
- 驱动UI和镜头
- 显示伤害数字和浮动文本

**关键原则**：
- 表现层从CombatSimulation读取状态
- 表现层不修改战斗状态
- 粒子死亡不触发游戏逻辑

```gdscript
class_name PresentationLayer extends Node2D

var entity_views: Dictionary = {}  # {entity_id: EntityView}

class EntityView:
    var entity_id: int
    var sprite: Sprite2D
    var animation_player: AnimationPlayer
    var particles: Array[GPUParticles2D]
    var health_bar: ProgressBar

func sync_with_simulation(combat_sim: CombatSimulation) -> void
func spawn_entity_view(entity_id: int, entity_type: String, position: Vector2) -> EntityView
func update_entity_view(view: EntityView, state: Entity) -> void
func play_skill_effect(skill_id: String, origin: Vector2, targets: Array) -> void
func show_damage_number(position: Vector2, damage: float, is_crit: bool) -> void
```

---

## 3. 数据驱动内容系统

### 3.1 ContentDatabase

所有游戏内容通过Resource配置，不硬编码在脚本中。

```gdscript
class_name ContentDatabase extends Node

var characters: Dictionary = {}  # {character_id: CharacterResource}
var skills: Dictionary = {}
var equipment: Dictionary = {}
var enemies: Dictionary = {}
var maps: Dictionary = {}

func _ready():
    load_all_content()

func load_all_content():
    characters = load_directory("res://content/characters/")
    skills = load_directory("res://content/skills/")
    equipment = load_directory("res://content/equipment/")
    enemies = load_directory("res://content/enemies/")
    maps = load_directory("res://content/maps/")

func get_character(id: String) -> CharacterResource
func get_skill(id: String) -> SkillResource
```

### 3.2 Resource示例

**角色配置**：

```gdscript
# res://content/characters/ironguard.tres
class_name CharacterResource extends Resource

@export var character_id: String = "ironguard"
@export var display_name: String = "铁卫"
@export var description: String = "近战、聚怪、反击"
@export var icon: Texture2D
@export var model_scene: PackedScene

@export_group("Base Stats")
@export var base_health: float = 1000.0
@export var base_move_speed: float = 250.0
@export var base_damage_mult: float = 1.0

@export_group("Starting Kit")
@export var starting_skills: Array[String] = ["shield_bash", "taunt"]
@export var starting_passive: String = "block_recovery"

@export_group("Gameplay")
@export var resource_type: String = "rage"  # rage/mana/energy
@export var max_resource: float = 100.0
```

**敌人配置**：

```gdscript
# res://content/enemies/zombie.tres
class_name EnemyResource extends Resource

@export var enemy_id: String = "zombie"
@export var display_name: String = "腐化行尸"
@export var category: String = "swarm"  # swarm/disruptor/support/anti_build/controller
@export var model_scene: PackedScene

@export_group("Stats")
@export var base_health: float = 100.0
@export var move_speed: float = 120.0
@export var damage: float = 15.0
@export var attack_range: float = 80.0
@export var attack_cooldown: float = 1.5

@export_group("AI")
@export var ai_type: String = "simple_chase"
@export var aggro_range: float = 800.0
@export var leash_range: float = 1500.0

@export_group("Network")
@export var sync_precision: String = "low"  # low/medium/high
@export var can_use_swarm_sync: bool = true

@export_group("Rewards")
@export var exp_value: float = 10.0
@export var drop_table: String = "common_enemy"
```

---

## 4. 实体ID与生命周期管理

### 4.1 稳定ID系统

```gdscript
class_name EntityIDManager extends Node

var next_id: int = 1
var entity_map: Dictionary = {}  # {entity_id: Entity}

func allocate_id() -> int:
    var id = next_id
    next_id += 1
    return id

func register_entity(entity: Entity) -> void:
    entity_map[entity.entity_id] = entity

func unregister_entity(entity_id: int) -> void:
    entity_map.erase(entity_id)

func get_entity(entity_id: int) -> Entity:
    return entity_map.get(entity_id)
```

**为什么需要稳定ID**：
- 网络同步需要引用实体
- 掉落物需要记录归属
- 重连恢复需要匹配实体
- 技能目标需要持久引用

### 4.2 对象池

```gdscript
class_name EntityPool extends Node

var pools: Dictionary = {}  # {entity_type: Array[Entity]}
var active_entities: Dictionary = {}  # {entity_id: Entity}

func get_entity(entity_type: String) -> Entity:
    if not pools.has(entity_type):
        pools[entity_type] = []
    
    if pools[entity_type].is_empty():
        return create_new_entity(entity_type)
    else:
        return pools[entity_type].pop_back()

func return_entity(entity: Entity) -> void:
    entity.reset()
    pools[entity.entity_type].append(entity)
    active_entities.erase(entity.entity_id)
```

---

## 5. 关键设计决策

### 5.1 为什么分离战斗规则和表现

| 好处 | 说明 |
|---|---|
| 网络同步简单 | 只同步规则状态，不同步粒子 |
| 单元测试可行 | 可以测试战斗逻辑而不启动场景 |
| 快照恢复容易 | 只序列化规则状态 |
| 性能档切换 | 低配关闭粒子不影响战斗 |
| 回放系统 | 可以录制规则输入重放 |

### 5.2 为什么单人多人共用逻辑

| 好处 | 说明 |
|---|---|
| 避免双倍维护成本 | 不需要两套战斗代码 |
| 平衡一致性 | 单人数值等于多人数值 |
| 测试覆盖完整 | 单人测试即测试多人逻辑 |
| 架构天然联网 | 从第一天就按联网设计 |

**实现方式**：
- 单人：主机模式，peer_id=1，无网络连接
- 多人：主机模式，peer_id=1/2/3/4，有网络连接

### 5.3 为什么使用Resource配置

| 好处 | 说明 |
|---|---|
| 热重载 | 修改配置不需要重启游戏 |
| 版本控制友好 | .tres是文本格式，可diff |
| 批量平衡 | 可以用脚本批量修改 |
| 导入外部数据 | 可以从Excel/JSON导入 |
| 编辑器友好 | 可视化编辑，不需要写代码 |

### 5.4 为什么需要稳定ID

| 场景 | 需求 |
|---|---|
| 网络同步 | "击中实体42"而非"击中第3个僵尸" |
| 状态恢复 | 重连后恢复"玩家2的角色" |
| 技能持续效果 | "实体42身上的灼烧" |
| 掉落归属 | "实体42掉落的装备" |
| Boss机制 | "Boss1召唤的小怪" |

---

## 6. 项目目录结构

```
project/
├─ addons/
│  └─ godotsteam/              # GodotSteam插件
│
├─ core/                       # 核心系统（无Godot场景依赖）
│  ├─ game_session.gd
│  ├─ entity.gd
│  ├─ entity_id_manager.gd
│  └─ random_stream.gd
│
├─ gameplay/                   # 游戏逻辑
│  ├─ combat/
│  │  ├─ combat_simulation.gd
│  │  ├─ damage_system.gd
│  │  ├─ ability_system.gd
│  │  └─ status_effect_system.gd
│  ├─ actors/
│  │  ├─ player_state.gd
│  │  ├─ enemy_state.gd
│  │  └─ projectile_state.gd
│  ├─ spawn/
│  │  ├─ spawn_director.gd
│  │  └─ enemy_system.gd
│  ├─ progression/
│  │  ├─ experience_system.gd
│  │  ├─ upgrade_system.gd
│  │  └─ equipment_system.gd
│  └─ loot/
│     ├─ drop_system.gd
│     └─ loot_table.gd
│
├─ net/                        # 网络系统
│  ├─ network_session.gd
│  ├─ input_buffer.gd
│  ├─ snapshot_serializer.gd
│  └─ reconnect_handler.gd
│
├─ presentation/               # 表现层
│  ├─ entity_view.gd
│  ├─ presentation_layer.gd
│  ├─ particle_manager.gd
│  ├─ audio_manager.gd
│  ├─ damage_number.gd
│  └─ camera_controller.gd
│
├─ ui/                         # UI系统
│  ├─ hud.tscn
│  ├─ upgrade_panel.tscn
│  ├─ pause_menu.tscn
│  └─ end_screen.tscn
│
├─ content/                    # 数据驱动配置
│  ├─ characters/
│  │  ├─ ironguard.tres
│  │  └─ elementalist.tres
│  ├─ skills/
│  │  ├─ lightning_chain.tres
│  │  └─ fireball.tres
│  ├─ equipment/
│  │  └─ storm_capacitor.tres
│  ├─ enemies/
│  │  ├─ zombie.tres
│  │  └─ elite_modifiers.tres
│  ├─ maps/
│  │  └─ ash_city.tres
│  └─ content_database.gd
│
├─ scenes/                     # Godot场景
│  ├─ main.tscn               # 主场景
│  ├─ game.tscn               # 游戏场景
│  └─ lobby.tscn              # 大厅场景
│
├─ tests/                      # 单元测试
│  ├─ test_damage_system.gd
│  ├─ test_status_effects.gd
│  ├─ test_spawn_director.gd
│  └─ test_snapshot_serializer.gd
│
├─ third_party_licenses/       # 第三方许可证
│
├─ project.godot
└─ export_presets.cfg
```

---

## 7. 模块依赖图

```
content/
   ↑
   │
core/ ← gameplay/ → net/
   ↑        ↑        ↑
   │        │        │
   └────────┴────────┴──── presentation/
                              ↑
                              │
                             ui/
```

**依赖规则**：
- ✓ core 不依赖任何其他模块
- ✓ gameplay 依赖 core 和 content
- ✓ net 依赖 core 和 gameplay
- ✓ presentation 依赖 gameplay 和 net
- ✓ ui 依赖 presentation
- ✗ core 不能依赖 gameplay
- ✗ gameplay 不能依赖 net
- ✗ gameplay 不能依赖 presentation

---

## 8. 测试策略

### 8.1 单元测试（GdUnit4）

```gdscript
# tests/test_damage_system.gd
extends GdUnitTestSuite

func test_basic_damage():
    var damage_system = DamageSystem.new()
    var instance = DamageInstance.new()
    instance.base_damage = 100.0
    instance.damage_type = "physical"
    instance.is_crit = false
    
    var result = damage_system.calculate_damage(instance)
    assert_float(result).is_equal(100.0)

func test_crit_damage():
    var damage_system = DamageSystem.new()
    var instance = DamageInstance.new()
    instance.base_damage = 100.0
    instance.is_crit = true
    # 假设暴击倍率2.0
    
    var result = damage_system.calculate_damage(instance)
    assert_float(result).is_equal(200.0)
```

### 8.2 集成测试

```gdscript
# tests/test_combat_integration.gd
extends GdUnitTestSuite

func test_player_kills_enemy():
    var session = GameSession.new()
    var combat = CombatSimulation.new()
    
    # 创建玩家
    var player = combat.spawn_player("ironguard", Vector2(500, 500))
    
    # 创建敌人
    var enemy = combat.spawn_enemy("zombie", Vector2(600, 500))
    
    # 玩家攻击敌人
    var skill = combat.cast_skill(player, "basic_attack", enemy.position)
    
    # 断言敌人受到伤害
    assert_bool(enemy.health < enemy.max_health).is_true()
```

### 8.3 网络测试

```gdscript
# tests/test_snapshot_serialization.gd
extends GdUnitTestSuite

func test_snapshot_roundtrip():
    var session = GameSession.new()
    var combat = CombatSimulation.new()
    
    # 生成快照
    var snapshot = combat.generate_snapshot()
    
    # 序列化
    var serialized = var_to_bytes(snapshot)
    
    # 反序列化
    var deserialized = bytes_to_var(serialized)
    
    # 恢复状态
    combat.apply_snapshot(deserialized)
    
    # 断言状态一致
    assert_that(combat.players.size()).is_equal(snapshot.players.size())
```

---

## 9. 性能考虑

### 9.1 避免的反模式

```gdscript
# ✗ 错误：粒子系统决定伤害
func _on_particle_hit_enemy(enemy):
    enemy.take_damage(50)  # 表现层不能修改规则

# ✓ 正确：战斗规则决定伤害，粒子只是表现
func apply_damage(target_id, damage):
    var target = entity_manager.get_entity(target_id)
    target.health -= damage
    presentation.play_hit_effect(target.position)
```

```gdscript
# ✗ 错误：直接遍历场景树
for enemy in get_tree().get_nodes_in_group("enemies"):
    if enemy.global_position.distance_to(player.global_position) < 500:
        enemy.take_damage(10)

# ✓ 正确：使用空间哈希
var nearby = spatial_grid.query_circle(player.position, 500)
for entity_id in nearby:
    var enemy = entity_manager.get_entity(entity_id)
    combat.apply_damage(enemy, 10)
```

### 9.2 内存管理

- 使用对象池复用敌人、投射物、伤害数字
- 死亡实体5秒后回收
- 粒子系统限制最大实例数
- 音效并发数限制（32个）

---

## 10. 迁移检查清单

从本架构设计到实际代码实现时，必须确保：

- [ ] GameSession不包含任何Node2D/Sprite
- [ ] CombatSimulation不调用音效播放
- [ ] 技能配置在.tres文件中，不在.gd脚本中
- [ ] 所有实体有entity_id字段
- [ ] 随机数来自RandomNumberGenerator，不用randf()
- [ ] 网络RPC有@rpc注解和权限检查
- [ ] 单人模式不创建MultiplayerPeer
- [ ] 表现层从战斗状态读取，不写入
- [ ] 单元测试覆盖核心伤害公式
- [ ] 集成测试覆盖玩家-敌人-掉落完整流程

---

## 参考资料

1. Godot官方架构最佳实践：<https://docs.godotengine.org/zh-cn/4.x/tutorials/best_practices/>
2. GDScript类型提示：<https://docs.godotengine.org/zh-cn/4.x/tutorials/scripting/gdscript/static_typing.html>
3. Resource系统：<https://docs.godotengine.org/zh-cn/4.x/tutorials/scripting/resources.html>
4. GdUnit4测试框架：<https://github.com/MikeSchulze/gdUnit4>
