# 《裂界清扫者》性能与实体架构

> 版本：v1.0  
> 日期：2026-09-27  
> 目标：1000-2000个敌人 @ 60 FPS  
> 状态：设计完成，待验证

---

## 执行摘要

**性能目标**：
- 单人中端PC：500敌人 @ 60 FPS
- 四人中端PC：1000敌人 @ 60 FPS
- 四人高端PC：2000敌人 @ 60 FPS

**核心策略**：
1. MultiMesh实例化渲染（同类敌人共享网格）
2. 对象池（复用实体，避免频繁分配）
3. 空间网格分区（O(1)范围查询）
4. 分层逻辑更新（近处10Hz，远处2Hz）
5. 群体移动（群组AI而非个体AI）
6. 伤害批量结算（0.1秒tick而非每帧）

---

## 1. 性能预算

### 1.1 帧时间预算（60 FPS = 16.67ms）

| 系统 | 预算 | 说明 |
|---|---:|---|
| 游戏逻辑 | 6ms | 战斗规则、AI、技能 |
| 渲染 | 8ms | GPU绘制、粒子、后处理 |
| 网络 | 1ms | 序列化、发送、接收 |
| 音频/UI | 1ms | 音效混合、UI更新 |
| 缓冲 | 0.67ms | 余量 |

### 1.2 实体数量预算

| 类型 | 单人 | 双人 | 四人 | 同步策略 |
|---|---:|---:|---:|---|
| 玩家 | 1 | 2 | 4 | 15Hz精确 |
| Boss | 1 | 1 | 1 | 10Hz精确 |
| 精英 | 5-10 | 8-15 | 10-20 | 10Hz精确 |
| 普通敌人 | 500 | 800 | 1000-2000 | 群组参数 |
| 投射物 | 100 | 150 | 200 | 事件 |
| 掉落物 | 50 | 80 | 100 | 事件 |
| 粒子系统 | 20 | 30 | 40 | 不同步 |
| 伤害数字 | 50 | 80 | 100 | 不同步 |

### 1.3 内存预算

| 阶段 | 目标 | 最大 |
|---|---:|---:|
| 启动 | 200 MB | 300 MB |
| 游戏中 | 500 MB | 800 MB |
| 峰值 | 700 MB | 1 GB |
| 临时分配 | <10 MB/秒 | <50 MB/秒 |

### 1.4 网络带宽预算

| 人数 | 主机上行 | 主机下行 | 客户端上行 | 客户端下行 |
|---:|---:|---:|---:|---:|
| 2人 | 2 KB/s | 14 KB/s | 2 KB/s | 14 KB/s |
| 4人 | 6 KB/s | 42 KB/s | 2 KB/s | 14 KB/s |

---

## 2. 敌人实体架构

### 2.1 不要这样做（每个敌人独立节点）

```gdscript
# ✗ 反模式：1000个独立CharacterBody2D
class_name Enemy extends CharacterBody2D

var health: float = 100.0
var navigation_agent: NavigationAgent2D
var animation_player: AnimationPlayer
var collision_shape: CollisionShape2D

func _physics_process(delta):
    # 每帧计算路径、移动、碰撞 = 1000次physics_process调用
    var next_position = navigation_agent.get_next_path_position()
    velocity = (next_position - global_position).normalized() * speed
    move_and_slide()
```

**问题**：
- 1000个节点树遍历
- 1000次独立物理计算
- 1000次独立AI决策
- 内存碎片化
- GC压力大

### 2.2 推荐做法（数据导向+批量处理）

```gdscript
# ✓ 正确：轻量级数据结构
class_name EnemyEntity extends RefCounted

var entity_id: int
var enemy_type: String  # "zombie", "demon"
var position: Vector2
var velocity: Vector2
var health: float
var max_health: float
var target_player_id: int
var ai_state: String
var swarm_id: int = -1
var last_update_time: float = 0.0
var update_tier: int = 1  # 1=每帧, 2=5Hz, 3=2Hz

# 批量管理器
class_name EnemyManager extends Node

var entities: Array[EnemyEntity] = []
var spatial_grid: SpatialGrid
var object_pool: Dictionary = {}

func update_batch(delta: float):
    # 分层更新
    update_tier1_enemies(delta)  # 近距离，10Hz
    update_tier2_enemies(delta)  # 中距离，5Hz
    update_tier3_enemies(delta)  # 远距离，2Hz
```

---

## 3. MultiMesh实例化渲染

### 3.1 原理

```
传统渲染：
  draw_enemy_1() → GPU调用1
  draw_enemy_2() → GPU调用2
  ...
  draw_enemy_1000() → GPU调用1000
  总计：1000 Draw Calls

MultiMesh：
  draw_all_zombies([pos1, pos2, ..., pos500]) → GPU调用1
  draw_all_demons([pos1, pos2, ..., pos300]) → GPU调用1
  总计：2 Draw Calls
```

### 3.2 实现

```gdscript
class_name EnemyRenderer extends Node2D

var multimesh_instances: Dictionary = {}  # {enemy_type: MultiMeshInstance2D}

func _ready():
    # 为每种敌人类型创建MultiMesh
    for enemy_type in ["zombie", "demon", "skeleton"]:
        var mmi = MultiMeshInstance2D.new()
        mmi.multimesh = MultiMesh.new()
        mmi.multimesh.transform_format = MultiMesh.TRANSFORM_2D
        mmi.multimesh.instance_count = 500  # 预分配
        mmi.multimesh.mesh = load_enemy_mesh(enemy_type)
        add_child(mmi)
        multimesh_instances[enemy_type] = mmi

func update_rendering(enemies: Array[EnemyEntity]):
    # 按类型分组
    var groups = {}
    for enemy in enemies:
        if not groups.has(enemy.enemy_type):
            groups[enemy.enemy_type] = []
        groups[enemy.enemy_type].append(enemy)
    
    # 批量更新Transform
    for enemy_type in groups:
        var mmi = multimesh_instances[enemy_type]
        var group = groups[enemy_type]
        mmi.multimesh.instance_count = group.size()
        
        for i in group.size():
            var transform = Transform2D()
            transform.origin = group[i].position
            mmi.multimesh.set_instance_transform_2d(i, transform)
```

### 3.3 限制与优化

**限制**：
- 同类敌人共享材质和动画
- 不支持每个实例独立骨骼动画

**优化**：
- 变体通过顶点色区分
- 简单动画用Shader UV滚动
- 受击闪白用Shader参数

```gdscript
# Shader实现简单动画
shader_type canvas_item;

uniform sampler2D sprite_sheet;
uniform int frame_count = 4;
uniform float anim_speed = 10.0;

void fragment() {
    float frame = mod(TIME * anim_speed, float(frame_count));
    int frame_index = int(floor(frame));
    
    vec2 uv = UV;
    uv.x = (uv.x + float(frame_index)) / float(frame_count);
    
    COLOR = texture(sprite_sheet, uv);
}
```

---

## 4. 空间网格分区

### 4.1 原理

```
全遍历查询（O(N)）：
for enemy in all_enemies:  # 1000次
    if enemy.distance_to(player) < 500:
        targets.append(enemy)

空间网格（O(1)）：
cell_x = int(player.x / CELL_SIZE)
cell_y = int(player.y / CELL_SIZE)
for dx in [-1, 0, 1]:
    for dy in [-1, 0, 1]:
        for enemy in grid[cell_x+dx][cell_y+dy]:  # ~10次
            if enemy.distance_to(player) < 500:
                targets.append(enemy)
```

### 4.2 实现

```gdscript
class_name SpatialGrid extends RefCounted

const CELL_SIZE: int = 200  # 单元格大小
var cells: Dictionary = {}  # {cell_key: Array[int]}  # entity_id数组
var entity_positions: Dictionary = {}  # {entity_id: Vector2}

func _cell_key(pos: Vector2) -> Vector2i:
    return Vector2i(int(pos.x / CELL_SIZE), int(pos.y / CELL_SIZE))

func insert(entity_id: int, position: Vector2):
    var key = _cell_key(position)
    if not cells.has(key):
        cells[key] = []
    cells[key].append(entity_id)
    entity_positions[entity_id] = position

func update(entity_id: int, old_pos: Vector2, new_pos: Vector2):
    var old_key = _cell_key(old_pos)
    var new_key = _cell_key(new_pos)
    
    if old_key != new_key:
        # 从旧格子移除
        if cells.has(old_key):
            cells[old_key].erase(entity_id)
        
        # 加入新格子
        if not cells.has(new_key):
            cells[new_key] = []
        cells[new_key].append(entity_id)
    
    entity_positions[entity_id] = new_pos

func query_circle(center: Vector2, radius: float) -> Array[int]:
    var results: Array[int] = []
    var cell_radius = int(ceil(radius / CELL_SIZE))
    var center_cell = _cell_key(center)
    
    for dx in range(-cell_radius, cell_radius + 1):
        for dy in range(-cell_radius, cell_radius + 1):
            var key = Vector2i(center_cell.x + dx, center_cell.y + dy)
            if cells.has(key):
                for entity_id in cells[key]:
                    var pos = entity_positions[entity_id]
                    if pos.distance_squared_to(center) <= radius * radius:
                        results.append(entity_id)
    
    return results
```

### 4.3 使用场景

```gdscript
# 范围技能查询目标
func cast_aoe_skill(center: Vector2, radius: float):
    var targets = spatial_grid.query_circle(center, radius)
    for entity_id in targets:
        var enemy = entity_manager.get_entity(entity_id)
        apply_damage(enemy, 150)

# 玩家拾取经验球
func update_pickup(player: PlayerState, delta: float):
    var nearby_drops = spatial_grid.query_circle(player.position, player.pickup_radius)
    for drop_id in nearby_drops:
        pickup_drop(player, drop_id)
```

---

## 5. 分层逻辑更新

### 5.1 更新频率分级

```gdscript
class_name EnemyManager extends Node

var tier1_enemies: Array[int] = []  # <300px，10Hz
var tier2_enemies: Array[int] = []  # 300-800px，5Hz
var tier3_enemies: Array[int] = []  # >800px，2Hz

var tier1_timer: float = 0.0
var tier2_timer: float = 0.0
var tier3_timer: float = 0.0

const TIER1_INTERVAL = 0.1  # 10Hz
const TIER2_INTERVAL = 0.2  # 5Hz
const TIER3_INTERVAL = 0.5  # 2Hz

func _process(delta):
    # 每帧：重新分级
    reclassify_enemies()
    
    # Tier 1: 10Hz
    tier1_timer += delta
    if tier1_timer >= TIER1_INTERVAL:
        tier1_timer -= TIER1_INTERVAL
        update_tier1_logic()
    
    # Tier 2: 5Hz
    tier2_timer += delta
    if tier2_timer >= TIER2_INTERVAL:
        tier2_timer -= TIER2_INTERVAL
        update_tier2_logic()
    
    # Tier 3: 2Hz
    tier3_timer += delta
    if tier3_timer >= TIER3_INTERVAL:
        tier3_timer -= TIER3_INTERVAL
        update_tier3_logic()

func reclassify_enemies():
    tier1_enemies.clear()
    tier2_enemies.clear()
    tier3_enemies.clear()
    
    var closest_player_pos = get_closest_player_position()
    
    for enemy in all_enemies:
        var dist = enemy.position.distance_to(closest_player_pos)
        if dist < 300:
            tier1_enemies.append(enemy.entity_id)
        elif dist < 800:
            tier2_enemies.append(enemy.entity_id)
        else:
            tier3_enemies.append(enemy.entity_id)

func update_tier1_logic():
    for entity_id in tier1_enemies:
        var enemy = get_entity(entity_id)
        update_full_ai(enemy, TIER1_INTERVAL)
        update_collision(enemy)

func update_tier3_logic():
    for entity_id in tier3_enemies:
        var enemy = get_entity(entity_id)
        simple_move_towards_player(enemy, TIER3_INTERVAL)
        # 跳过碰撞检测
```

### 5.2 远距离简化

| 距离 | 更新频率 | AI复杂度 | 碰撞检测 | 动画 |
|---|---:|---|---|---|
| <300px | 10Hz | 完整 | 精确 | 完整骨骼 |
| 300-800px | 5Hz | 简化 | 简化 | LOD动画 |
| >800px | 2Hz | 仅朝向 | 无 | Shader晃动 |
| >1500px | 暂停 | 无 | 无 | 不可见 |

---

## 6. 群体移动

### 6.1 群组AI

```gdscript
class_name EnemySwarm extends RefCounted

var swarm_id: int
var enemy_ids: Array[int] = []
var center_position: Vector2
var target_player_id: int
var formation: String = "loose"  # loose/tight/line

func update(delta: float):
    # 1. 更新群组中心
    update_swarm_center()
    
    # 2. 群组决策（只计算一次）
    var group_target = get_group_target()
    var group_direction = (group_target - center_position).normalized()
    
    # 3. 批量应用个体偏移
    for i in enemy_ids.size():
        var enemy = entity_manager.get_entity(enemy_ids[i])
        var offset = get_formation_offset(i, formation)
        enemy.target_position = center_position + offset
        enemy.velocity = group_direction * enemy.move_speed
```

### 6.2 网络同步

```gdscript
# 主机发送群组参数，客户端还原
{
  "swarm_id": 15,
  "center": Vector2(1500, 1000),
  "target_player": 2,
  "formation": "loose",
  "count": 50
}

# 客户端根据参数还原50个敌人位置
func restore_swarm(params: Dictionary):
    for i in params.count:
        var offset = get_formation_offset(i, params.formation)
        var enemy_pos = params.center + offset
        spawn_client_enemy(enemy_pos)
```

---

## 7. 对象池

### 7.1 实现

```gdscript
class_name ObjectPool extends Node

var pools: Dictionary = {}  # {type: Array[Object]}
var active_objects: Dictionary = {}  # {instance_id: Object}

func get_object(type: String) -> RefCounted:
    if not pools.has(type):
        pools[type] = []
    
    var pool = pools[type]
    if pool.is_empty():
        return create_new(type)
    else:
        var obj = pool.pop_back()
        active_objects[obj.get_instance_id()] = obj
        return obj

func return_object(obj: RefCounted):
    obj.reset()  # 重置到初始状态
    var type = obj.get_type()
    pools[type].append(obj)
    active_objects.erase(obj.get_instance_id())

func prewarm(type: String, count: int):
    for i in count:
        var obj = create_new(type)
        pools[type].append(obj)
```

### 7.2 池化对象

```gdscript
class_name PoolableEnemy extends RefCounted:
    var entity_id: int
    var position: Vector2
    var health: float
    # ...其他字段
    
    func reset():
        entity_id = 0
        position = Vector2.ZERO
        health = 0
        # 重置所有字段

# 预热对象池
func _ready():
    object_pool.prewarm("enemy_zombie", 500)
    object_pool.prewarm("projectile", 200)
    object_pool.prewarm("exp_orb", 100)
```

---

## 8. 伤害批量结算

### 8.1 问题

```gdscript
# ✗ 每个投射物每帧检测命中
func _process(delta):
    for projectile in projectiles:
        for enemy in enemies:  # 100 * 1000 = 100,000次
            if projectile.overlaps(enemy):
                apply_damage(enemy, projectile.damage)
```

### 8.2 解决方案

```gdscript
class_name DamageAccumulator extends Node

var pending_damages: Array[DamageInstance] = []
var tick_timer: float = 0.0
const TICK_INTERVAL = 0.1  # 10Hz批量结算

func queue_damage(target_id: int, damage: float, type: String):
    pending_damages.append({
        "target_id": target_id,
        "damage": damage,
        "type": type
    })

func _process(delta):
    tick_timer += delta
    if tick_timer >= TICK_INTERVAL:
        tick_timer -= TICK_INTERVAL
        process_batch()

func process_batch():
    # 按目标聚合
    var aggregated = {}
    for dmg in pending_damages:
        if not aggregated.has(dmg.target_id):
            aggregated[dmg.target_id] = 0.0
        aggregated[dmg.target_id] += dmg.damage
    
    # 批量应用
    for target_id in aggregated:
        var enemy = entity_manager.get_entity(target_id)
        enemy.health -= aggregated[target_id]
        if enemy.health <= 0:
            kill_enemy(enemy)
    
    # 网络：一次性发送批量伤害
    if multiplayer.is_server():
        rpc("sync_damage_batch", aggregated)
    
    pending_damages.clear()
```

---

## 9. 粒子与音效限制

### 9.1 粒子预算

```gdscript
class_name ParticleManager extends Node

const MAX_PARTICLES = 30
var active_particles: Array[GPUParticles2D] = []

func spawn_particle(type: String, position: Vector2):
    # 超出预算，复用最老的
    if active_particles.size() >= MAX_PARTICLES:
        var oldest = active_particles.pop_front()
        oldest.emitting = false
        object_pool.return_object(oldest)
    
    var particle = object_pool.get_object("particle_" + type)
    particle.position = position
    particle.emitting = true
    active_particles.append(particle)
```

### 9.2 音效限制

```gdscript
class_name AudioManager extends Node

const MAX_CONCURRENT_SOUNDS = 32
var active_players: Array[AudioStreamPlayer2D] = []

func play_sound(sound: AudioStream, position: Vector2, volume: float = 0.0):
    if active_players.size() >= MAX_CONCURRENT_SOUNDS:
        # 停止最低优先级的音效
        var lowest_priority = find_lowest_priority_sound()
        lowest_priority.stop()
        active_players.erase(lowest_priority)
    
    var player = object_pool.get_object("audio_player")
    player.stream = sound
    player.position = position
    player.volume_db = volume
    player.play()
    active_players.append(player)
```

---

## 10. 压力测试场景

### 10.1 测试配置

```gdscript
# tests/stress_test.gd
extends Node

func setup_stress_test():
    # 4个模拟玩家
    for i in 4:
        spawn_player(Vector2(500 + i * 200, 500))
    
    # 1000个普通敌人（分10个群组）
    for i in 10:
        spawn_swarm("zombie", 100, Vector2(randf() * 2000, randf() * 1500))
    
    # 20个精英
    for i in 20:
        spawn_elite("demon", Vector2(randf() * 2000, randf() * 1500))
    
    # 4个持续伤害区域
    for i in 4:
        spawn_damage_zone(Vector2(randf() * 2000, randf() * 1500), 300, 10)
    
    # 大量粒子
    enable_full_particle_effects()

func run_test(duration: float = 600.0):  # 10分钟
    var start_time = Time.get_ticks_msec()
    var frame_times: Array[float] = []
    
    while (Time.get_ticks_msec() - start_time) / 1000.0 < duration:
        var frame_start = Time.get_ticks_usec()
        await get_tree().process_frame
        var frame_end = Time.get_ticks_usec()
        
        var frame_time = (frame_end - frame_start) / 1000.0  # ms
        frame_times.append(frame_time)
    
    # 统计
    print_test_results(frame_times)
```

### 10.2 性能指标

```gdscript
func print_test_results(frame_times: Array):
    frame_times.sort()
    
    var avg = frame_times.reduce(func(a, b): return a + b) / frame_times.size()
    # 帧时间已升序排序：最慢的1%帧位于尾部
    var p99 = frame_times[int(frame_times.size() * 0.99)]
    var max_frame = frame_times[frame_times.size() - 1]
    
    print("=== 性能测试结果 ===")
    print("平均帧时间: %.2f ms" % avg)
    print("99百分位帧时间: %.2f ms" % p99)
    print("1%% Low FPS: %.1f" % (1000.0 / p99))
    print("最大帧时间: %.2f ms" % max_frame)
    print("平均FPS: %.1f" % (1000.0 / avg))
    print("活跃实体: %d" % entity_manager.get_active_count())
    print("内存使用: %.1f MB" % (OS.get_static_memory_usage() / 1024.0 / 1024.0))
```

### 10.3 退出条件

- ✓ 平均FPS ≥ 60
- ✓ 1% Low ≥ 45
- ✓ 最大帧时间 ≤ 50ms
- ✓ 内存增长 < 10 MB/分钟
- ✓ 无崩溃运行10分钟

---

## 11. 性能分析工具

### 11.1 Godot内置Profiler

```
编辑器 → 调试器 → Profiler

关注指标：
- Process: 逻辑更新耗时
- Physics Process: 物理模拟耗时
- Rendering: GPU绘制耗时
- Memory: 内存分配

热点函数：
- 找到耗时 >2ms 的函数
- 优先优化占比最高的
```

### 11.2 自定义性能标记

```gdscript
func update_enemies(delta):
    var start = Time.get_ticks_usec()
    
    # ... 敌人更新逻辑 ...
    
    var elapsed = (Time.get_ticks_usec() - start) / 1000.0
    if elapsed > 3.0:  # 超过3ms警告
        push_warning("update_enemies took %.2f ms" % elapsed)
```

### 11.3 性能回归检测

```bash
# 每次构建记录性能
./run_stress_test.sh > results/build_123.txt

# 对比基准
python compare_perf.py results/baseline.txt results/build_123.txt
```

---

## 12. 质量档位

### 12.1 图形质量档

```gdscript
enum QualityPreset { LOW, MEDIUM, HIGH, ULTRA }

func apply_quality_preset(preset: QualityPreset):
    match preset:
        QualityPreset.LOW:
            # 敌人
            max_enemy_budget = 500
            use_lod_animations = true
            disable_far_enemies = true
            
            # 渲染
            msaa = Viewport.MSAA_DISABLED
            shadow_quality = RenderingServer.SHADOW_QUALITY_HARD
            
            # 粒子
            max_particles = 15
            particle_draw_distance = 600
            
            # 音效
            max_audio = 16
            
        QualityPreset.HIGH:
            max_enemy_budget = 1500
            use_lod_animations = false
            disable_far_enemies = false
            
            msaa = Viewport.MSAA_4X
            shadow_quality = RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM
            
            max_particles = 40
            particle_draw_distance = 1200
            
            max_audio = 48
```

### 12.2 四人特效透明度

```gdscript
# 设置 → 多人设置 → 队友特效
enum TeammateEffectLevel { FULL, MEDIUM, LOW, MINIMAL }

func apply_teammate_effect_level(level: TeammateEffectLevel):
    match level:
        TeammateEffectLevel.FULL:
            teammate_particle_alpha = 1.0
            teammate_trail_enabled = true
        
        TeammateEffectLevel.MEDIUM:
            teammate_particle_alpha = 0.6
            teammate_trail_enabled = true
        
        TeammateEffectLevel.LOW:
            teammate_particle_alpha = 0.3
            teammate_trail_enabled = false
        
        TeammateEffectLevel.MINIMAL:
            teammate_particle_alpha = 0.1
            teammate_trail_enabled = false
            # 只显示队友轮廓和关键技能
```

---

## 13. 已知性能陷阱

| 陷阱 | 影响 | 检测 | 解决 |
|---|---|---|---|
| 每帧字符串拼接 | GC压力 | Profiler内存峰值 | 缓存字符串 |
| 每帧get_node() | 树遍历 | Profiler热点 | @onready缓存 |
| 大数组临时拷贝 | 内存尖峰 | 内存监控 | 复用数组 |
| 嵌套for循环碰撞 | CPU瓶颈 | 帧时间 | 空间网格 |
| 过多Draw Calls | GPU瓶颈 | RenderDoc | MultiMesh |
| 音效无限制 | 音频混音崩溃 | 崩溃日志 | 并发上限 |

---

## 参考资料

1. Godot性能优化：<https://docs.godotengine.org/zh-cn/4.x/tutorials/performance/>
2. MultiMesh文档：<https://docs.godotengine.org/zh-cn/4.x/classes/class_multimesh.html>
3. Profiler使用：<https://docs.godotengine.org/zh-cn/4.x/tutorials/debug/the_profiler.html>
