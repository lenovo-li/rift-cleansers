# 《裂界清扫者》2人联机原型计划

> 版本：v1.0  
> 日期：2026-09-27  
> 前置：M1十分钟垂直切片完成  
> 工期：3-4周  
> 状态：待启动

---

## 执行摘要

**目标**：在10分钟垂直切片基础上，尽早验证2人联机技术可行性

**不做完整4人**：先验证最小联机单元（2人），确认架构可行后再扩展

**核心验证点**：
1. 主机权威架构可行
2. 100-150ms延迟下可玩
3. 敌群同步策略有效
4. 掉线重连不丢失进度
5. 客户端预测平滑

---

## 1. 原型范围

### 1.1 复用M1内容

- ✓ 1个角色（铁卫）
- ✓ 6个技能
- ✓ 6种敌人
- ✓ 1个Boss
- ✓ 10分钟时间线

### 1.2 新增网络功能

- [ ] ENet局域网连接
- [ ] 主机创建/客户端加入
- [ ] 玩家移动同步
- [ ] 技能请求→主机结算
- [ ] 敌人群组同步
- [ ] Boss状态同步
- [ ] 掉落同步
- [ ] 经验升级同步
- [ ] 掉线AI托管
- [ ] 30秒内重连恢复

### 1.3 暂不实现

- ✗ Steam集成（M4再做）
- ✗ 3-4人测试
- ✗ 主机迁移
- ✗ 公共匹配
- ✗ 语音聊天
- ✗ 完整UI（简单文本调试UI即可）

---

## 2. 技术实现清单

### 2.1 Week 1：连接与基础同步

#### 任务1.1：ENet连接

```gdscript
# net/network_session.gd
class_name NetworkSession extends Node

var peer: ENetMultiplayerPeer
var is_host: bool = false

func create_host(port: int = 7777, max_clients: int = 3):
    peer = ENetMultiplayerPeer.new()
    peer.create_server(port, max_clients)
    multiplayer.multiplayer_peer = peer
    is_host = true
    print("主机创建成功: 端口 %d" % port)

func join_host(ip: String, port: int = 7777):
    peer = ENetMultiplayerPeer.new()
    peer.create_client(ip, port)
    multiplayer.multiplayer_peer = peer
    is_host = false
    print("正在连接主机: %s:%d" % [ip, port])

func _ready():
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    multiplayer.connection_failed.connect(_on_connection_failed)

func _on_peer_connected(id: int):
    print("玩家加入: %d" % id)

func _on_peer_disconnected(id: int):
    print("玩家离开: %d" % id)
```

**测试**：
- 主机启动，客户端连接
- 显示"玩家2加入"
- 客户端断开，显示"玩家2离开"

#### 任务1.2：玩家生成与ID分配

```gdscript
# gameplay/actors/player_spawner.gd
class_name PlayerSpawner extends Node

@export var spawn_points: Array[Vector2] = [
    Vector2(500, 500),
    Vector2(700, 500)
]

func spawn_players():
    if multiplayer.is_server():
        # 主机生成所有玩家
        for peer_id in multiplayer.get_peers():
            spawn_player_for_peer(peer_id)
        
        # 生成主机自己的玩家
        spawn_player_for_peer(1)

func spawn_player_for_peer(peer_id: int):
    var player_state = PlayerState.new()
    player_state.peer_id = peer_id
    player_state.entity_id = entity_id_manager.allocate_id()
    player_state.character_id = "ironguard"
    player_state.position = spawn_points[get_player_index(peer_id)]
    
    game_session.add_player(player_state)
    
    # 通知客户端创建视图
    rpc("create_player_view", player_state.entity_id, peer_id, player_state.position)

@rpc("authority", "call_local", "reliable")
func create_player_view(entity_id: int, peer_id: int, position: Vector2):
    presentation_layer.spawn_player_view(entity_id, peer_id, position)
```

**测试**：
- 2个玩家在不同位置出现
- 主机看到2个玩家
- 客户端看到2个玩家

#### 任务1.3：输入采集与上传

```gdscript
# net/input_collector.gd
class_name InputCollector extends Node

var local_player_id: int = 1
var input_tick: int = 0

func _process(_delta):
    if not multiplayer.multiplayer_peer:
        return  # 单人模式
    
    var input_data = collect_input()
    input_tick += 1
    
    if multiplayer.is_server():
        # 主机直接应用
        network_session.process_input(1, input_data)
    else:
        # 客户端发送到主机
        rpc_id(1, "submit_input", input_data)

func collect_input() -> Dictionary:
    return {
        "tick": input_tick,
        "move_x": Input.get_axis("move_left", "move_right"),
        "move_y": Input.get_axis("move_up", "move_down"),
        "dash": Input.is_action_just_pressed("dash"),
        "skill_1": Input.is_action_just_pressed("skill_1"),
        "aim_direction": get_aim_direction()
    }
```

**测试**：
- 客户端移动，主机看到移动
- 主机移动，客户端看到移动
- 打印输入包，确认30Hz发送

### 2.2 Week 2：战斗同步

#### 任务2.1：主机权威移动

```gdscript
# net/network_session.gd
@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_input(input_data: Dictionary):
    if not multiplayer.is_server():
        return
    
    var peer_id = multiplayer.get_remote_sender_id()
    process_input(peer_id, input_data)

func process_input(peer_id: int, input_data: Dictionary):
    var player = game_session.get_player_by_peer_id(peer_id)
    if not player:
        return
    
    # 应用移动
    var move_dir = Vector2(input_data.move_x, input_data.move_y)
    if move_dir.length() > 1.0:
        move_dir = move_dir.normalized()
    
    player.velocity = move_dir * player.move_speed
    player.position += player.velocity * get_process_delta_time()
    
    # 处理技能请求
    if input_data.skill_1:
        request_cast_skill(player, "shield_bash", input_data.aim_direction)

# 定期广播状态快照
var snapshot_timer: float = 0.0
const SNAPSHOT_INTERVAL = 0.05  # 20Hz

func _process(delta):
    if not multiplayer.is_server():
        return
    
    snapshot_timer += delta
    if snapshot_timer >= SNAPSHOT_INTERVAL:
        snapshot_timer -= SNAPSHOT_INTERVAL
        broadcast_snapshot()

func broadcast_snapshot():
    var snapshot = generate_snapshot()
    rpc("sync_snapshot", snapshot)

@rpc("authority", "call_remote", "unreliable")
func sync_snapshot(snapshot: Dictionary):
    apply_snapshot(snapshot)
```

**测试**：
- 客户端输入，主机计算，客户端看到结果
- 延迟100ms，移动仍平滑
- 客户端断网，主机玩家继续移动

#### 任务2.2：客户端预测

```gdscript
# presentation/player_view.gd
class_name PlayerView extends Node2D

var entity_id: int
var peer_id: int
var is_local: bool = false

var predicted_position: Vector2
var server_position: Vector2
var velocity: Vector2

func _process(delta):
    if is_local and multiplayer.get_unique_id() == peer_id:
        # 本地玩家：预测移动
        var input = input_collector.get_last_input()
        var move_dir = Vector2(input.move_x, input.move_y).normalized()
        predicted_position += move_dir * move_speed * delta
        position = predicted_position
    else:
        # 远程玩家：插值到服务器位置
        position = position.lerp(server_position, 0.3)

func on_server_update(new_position: Vector2):
    server_position = new_position
    
    if is_local:
        # 校正偏差
        var error = predicted_position.distance_to(server_position)
        if error > 50:  # 超过50像素校正
            predicted_position = predicted_position.lerp(server_position, 0.5)
```

**测试**：
- 本地玩家移动立即响应（无延迟感）
- 150ms延迟，仍感觉流畅
- 服务器校正时平滑过渡

#### 任务2.3：技能同步

```gdscript
# net/network_session.gd
func request_cast_skill(player: PlayerState, skill_id: String, direction: Vector2):
    if not ability_system.can_cast(player, skill_id):
        return  # 冷却中或资源不足
    
    # 主机执行技能
    var result = ability_system.cast_skill(player, skill_id, direction)
    
    # 广播技能效果
    rpc("on_skill_cast", player.entity_id, skill_id, player.position, direction, result.targets)

@rpc("authority", "call_local", "reliable")
func on_skill_cast(caster_id: int, skill_id: String, origin: Vector2, direction: Vector2, targets: Array):
    # 客户端播放技能表现
    presentation_layer.play_skill_effect(skill_id, origin, direction)
    
    # 播放命中效果
    for target_id in targets:
        var target_pos = entity_manager.get_entity(target_id).position
        presentation_layer.play_hit_effect(target_pos)
```

**测试**：
- 客户端按技能键，主机结算，双方看到技能效果
- 技能命中敌人，双方看到伤害数字
- 冷却由主机控制，客户端无法作弊

### 2.3 Week 3：敌人与Boss同步

#### 任务3.1：敌群参数同步

```gdscript
# net/enemy_synchronizer.gd
class_name EnemySynchronizer extends Node

func spawn_enemy_swarm(type: String, count: int, center: Vector2):
    if not multiplayer.is_server():
        return
    
    var swarm_id = swarm_manager.allocate_swarm_id()
    var params = {
        "swarm_id": swarm_id,
        "enemy_type": type,
        "count": count,
        "center": center,
        "target_player": select_random_player(),
        "formation": "loose",
        "seed": randi()
    }
    
    # 主机生成实体
    swarm_manager.create_swarm(params)
    
    # 广播参数
    rpc("client_spawn_swarm", params)

@rpc("authority", "call_remote", "reliable")
func client_spawn_swarm(params: Dictionary):
    # 客户端根据参数生成近似群组
    swarm_manager.create_swarm(params)

# 低频同步群组中心
var swarm_sync_timer: float = 0.0
const SWARM_SYNC_INTERVAL = 0.2  # 5Hz

func _process(delta):
    if not multiplayer.is_server():
        return
    
    swarm_sync_timer += delta
    if swarm_sync_timer >= SWARM_SYNC_INTERVAL:
        swarm_sync_timer -= SWARM_SYNC_INTERVAL
        sync_swarm_centers()

func sync_swarm_centers():
    var swarm_data = []
    for swarm in swarm_manager.get_active_swarms():
        swarm_data.append({
            "id": swarm.swarm_id,
            "center": swarm.center_position
        })
    
    rpc("update_swarm_centers", swarm_data)
```

**测试**：
- 主机生成100只僵尸
- 客户端看到100只僵尸（位置近似）
- 群组移动方向一致

#### 任务3.2：Boss精确同步

```gdscript
# net/boss_synchronizer.gd
class_name BossSynchronizer extends Node

var boss_sync_timer: float = 0.0
const BOSS_SYNC_INTERVAL = 0.1  # 10Hz

func _process(delta):
    if not multiplayer.is_server():
        return
    
    boss_sync_timer += delta
    if boss_sync_timer >= BOSS_SYNC_INTERVAL:
        boss_sync_timer -= BOSS_SYNC_INTERVAL
        sync_boss_state()

func sync_boss_state():
    var boss = boss_manager.get_active_boss()
    if not boss:
        return
    
    rpc("update_boss", {
        "entity_id": boss.entity_id,
        "position": boss.position,
        "health": boss.health,
        "phase": boss.current_phase,
        "current_attack": boss.current_attack
    })

@rpc("authority", "call_remote", "unreliable")
func update_boss(data: Dictionary):
    var boss_view = presentation_layer.get_boss_view(data.entity_id)
    if boss_view:
        boss_view.server_position = data.position
        boss_view.update_health(data.health)
        boss_view.set_phase(data.phase)

# Boss阶段切换（可靠事件）
func on_boss_phase_change(boss_id: int, new_phase: int):
    rpc("boss_phase_changed", boss_id, new_phase)

@rpc("authority", "call_local", "reliable")
func boss_phase_changed(boss_id: int, new_phase: int):
    var boss_view = presentation_layer.get_boss_view(boss_id)
    boss_view.play_phase_transition(new_phase)
```

**测试**：
- Boss血量同步
- Boss阶段切换同步
- Boss技能释放同步

### 2.4 Week 4：掉线重连

#### 任务4.1：AI托管

```gdscript
# net/disconnect_handler.gd
class_name DisconnectHandler extends Node

func _on_peer_disconnected(peer_id: int):
    var player = game_session.get_player_by_peer_id(peer_id)
    if not player:
        return
    
    # 开启AI托管
    player.is_ai_controlled = true
    player.disconnect_timer = 30.0
    player.reconnect_token = generate_reconnect_token(peer_id)
    
    print("玩家%d掉线，AI托管30秒" % peer_id)
    
    # 通知其他客户端
    rpc("player_disconnected", peer_id)

func _process(delta):
    if not multiplayer.is_server():
        return
    
    for player in game_session.get_disconnected_players():
        player.disconnect_timer -= delta
        
        if player.disconnect_timer <= 0:
            # 超时，移除玩家
            game_session.remove_player(player.peer_id)
            rpc("player_removed", player.peer_id)
            print("玩家%d超时移除" % player.peer_id)

# AI托管逻辑
func update_ai_player(player: PlayerState, delta: float):
    # 简单跟随最近队友
    var closest_ally = find_closest_ally(player)
    if closest_ally:
        var direction = (closest_ally.position - player.position).normalized()
        player.position += direction * player.move_speed * delta
    
    # 基础攻击
    var nearby_enemies = spatial_grid.query_circle(player.position, 300)
    if nearby_enemies.size() > 0:
        ability_system.cast_skill(player, "shield_bash", Vector2.RIGHT)
```

**测试**：
- 客户端断开，角色继续战斗
- AI跟随主机玩家
- AI不选择升级

#### 任务4.2：重连恢复

```gdscript
# net/reconnect_handler.gd
class_name ReconnectHandler extends Node

@rpc("any_peer", "call_remote", "reliable")
func request_reconnect(token: String):
    var peer_id = multiplayer.get_remote_sender_id()
    
    if not validate_reconnect_token(token, peer_id):
        rpc_id(peer_id, "reconnect_failed", "Invalid token")
        return
    
    var player = game_session.get_player_by_reconnect_token(token)
    if not player:
        rpc_id(peer_id, "reconnect_failed", "Player not found")
        return
    
    # 恢复控制
    player.is_ai_controlled = false
    player.peer_id = peer_id
    
    # 发送完整快照
    var snapshot = generate_full_snapshot()
    rpc_id(peer_id, "reconnect_success", snapshot)
    
    print("玩家%d重连成功" % peer_id)

@rpc("authority", "call_local", "reliable")
func reconnect_success(snapshot: Dictionary):
    # 恢复游戏状态
    game_session.apply_full_snapshot(snapshot)
    presentation_layer.rebuild_all_views()
    
    print("重连成功，状态已恢复")
```

**测试**：
- 客户端断开15秒，重连
- 恢复控制，构筑和血量保持
- 未选择的升级保留

---

## 3. 测试矩阵

### 3.1 网络条件测试

| 延迟 | 丢包率 | 预期结果 | 实测 |
|---:|---:|---|---|
| 0ms | 0% | 完美流畅 | [ ] |
| 50ms | 0% | 完美流畅 | [ ] |
| 100ms | 1% | 偶尔抖动，可玩 | [ ] |
| 150ms | 1% | 明显延迟，可玩 | [ ] |
| 150ms | 3% | 抖动明显，勉强可玩 | [ ] |
| 200ms | 3% | 不可玩 | [ ] |

**工具**：
```bash
# Linux: tc命令模拟延迟
sudo tc qdisc add dev eth0 root netem delay 100ms loss 1%

# Windows: Clumsy工具
# 下载: https://jagt.github.io/clumsy/
```

### 3.2 功能测试

| 功能 | 测试内容 | 状态 |
|---|---|---|
| 连接 | 主机创建，客户端加入 | [ ] |
| 移动 | 双方移动平滑 | [ ] |
| 技能 | 技能释放同步 | [ ] |
| 伤害 | 伤害数值一致 | [ ] |
| 敌群 | 100只敌人同步 | [ ] |
| Boss | Boss血量阶段同步 | [ ] |
| 掉落 | 掉落拾取同步 | [ ] |
| 升级 | 升级选项同步 | [ ] |
| 掉线 | AI托管30秒 | [ ] |
| 重连 | 重连恢复状态 | [ ] |

### 3.3 压力测试

| 场景 | 配置 | 目标 | 实测 |
|---|---|---|---|
| 大量敌人 | 2人+500敌 | 60 FPS | [ ] |
| Boss战 | 2人+Boss+100敌 | 60 FPS | [ ] |
| 技能爆发 | 双方同时释放技能 | 无卡顿 | [ ] |
| 长时游戏 | 完整10分钟 | 无状态分叉 | [ ] |

---

## 4. 调试UI

### 4.1 简单调试面板

```gdscript
# ui/debug_panel.gd
extends CanvasLayer

@onready var label = $Label

func _process(_delta):
    var text = ""
    text += "角色: %s\n" % ("主机" if multiplayer.is_server() else "客户端")
    text += "Peer ID: %d\n" % multiplayer.get_unique_id()
    text += "连接数: %d\n" % multiplayer.get_peers().size()
    text += "延迟: %d ms\n" % get_estimated_latency()
    text += "FPS: %d\n" % Engine.get_frames_per_second()
    text += "实体数: %d\n" % entity_manager.get_active_count()
    
    label.text = text
```

### 4.2 网络日志

```gdscript
# net/network_logger.gd
class_name NetworkLogger extends Node

var log_file: FileAccess

func _ready():
    log_file = FileAccess.open("user://network.log", FileAccess.WRITE)

func log_packet(type: String, data: Dictionary):
    var entry = {
        "time": Time.get_ticks_msec(),
        "type": type,
        "data": data
    }
    log_file.store_line(JSON.stringify(entry))

func log_state_mismatch(entity_id: int, server_val, client_val):
    push_warning("状态不一致: 实体%d, 服务器=%s, 客户端=%s" % [entity_id, server_val, client_val])
    log_packet("mismatch", {"entity": entity_id, "server": server_val, "client": client_val})
```

---

## 5. 退出条件

只有全部通过，才进入M3扩展到4人：

- [ ] 2人可以创建房间并加入
- [ ] 100ms延迟下移动流畅
- [ ] 技能释放同步无明显延迟
- [ ] 500敌人双方FPS ≥ 60
- [ ] Boss血量和阶段一致
- [ ] 掉线AI托管正常
- [ ] 30秒内重连恢复状态
- [ ] 10分钟游戏无严重状态分叉
- [ ] 无P0崩溃Bug

**如果失败**：
- 继续迭代联机原型
- 重新评估网络架构
- 不扩展到4人

---

## 6. 风险应对

### 6.1 技术风险

| 风险 | 应对 |
|---|---|
| ENet延迟补偿不足 | 增大客户端预测窗口 |
| 敌群同步不准确 | 提高同步频率或改精确同步 |
| 重连快照过大 | 压缩或只发送差异 |
| 状态分叉严重 | 增加主机校正频率 |

### 6.2 进度风险

| 风险 | 应对 |
|---|---|
| Week 2未完成同步 | 砍掉重连功能 |
| Week 3 Boss不同步 | 简化为精英同步 |
| 性能不达标 | 降低敌人数量 |

---

## 参考资料

1. 联机架构：`docs/02_MULTIPLAYER_ARCHITECTURE_DESIGN.md`
2. Godot高层多人：<https://docs.godotengine.org/zh-cn/4.x/tutorials/networking/high_level_multiplayer.html>
3. ENet官方文档：<http://enet.bespin.org/Features.html>
