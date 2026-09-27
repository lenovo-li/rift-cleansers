# 《裂界清扫者》联机架构设计

> 版本：v1.0  
> 日期：2026-09-27  
> 基于：Godot 4.7.2 + GodotSteam MultiplayerPeer  
> 状态：设计完成，待实现

---

## 执行摘要

**架构模型**：主机权威 Listen Server，支持1-4人合作

**核心原则**：
1. 房主同时运行服务器逻辑和本地客户端
2. 主机负责所有游戏规则，客户端只提交输入和请求
3. 单人模式复用相同战斗逻辑，但不建立网络连接
4. 普通敌群使用低成本群组同步，不逐个精确同步
5. 粒子、伤害数字、尸体不同步

---

## 1. 网络拓扑

### 1.1 单人模式

```
┌─────────────┐
│ 本地主机逻辑 │
│ GameSession │
│ CombatSim   │
│ SpawnDir    │
└─────────────┘
       │
       ▼
┌─────────────┐
│ 本地表现层   │
│ Player视图  │
│ 粒子/音效   │
└─────────────┘
```

- 无网络连接
- 所有逻辑本地运行
- 随机种子由玩家选择或时间戳生成

### 1.2 多人模式（Listen Server）

```
        房主设备                     客户端1                客户端2                客户端3
┌──────────────────┐          ┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│  主机逻辑（权威）  │◄─输入──►│ 客户端逻辑    │      │ 客户端逻辑    │      │ 客户端逻辑    │
│  ┌────────────┐  │          │  ┌────────┐  │      │  ┌────────┐  │      │  ┌────────┐  │
│  │GameSession │  │          │  │本地预测│  │      │  │本地预测│  │      │  │本地预测│  │
│  │CombatSim   │  │          │  │粒子/音效│ │      │  │粒子/音效│ │      │  │粒子/音效│ │
│  │SpawnDir    │  │          │  └────────┘  │      │  └────────┘  │      │  └────────┘  │
│  │NetSession  │  │          │              │      │              │      │              │
│  └────────────┘  │          └──────────────┘      └──────────────┘      └──────────────┘
│        ▲         │                  │                     │                     │
│        │         │                  │                     │                     │
│  ┌────────────┐  │          ┌──────────────────────────────────────────────────────┐
│  │房主本地视图│  │          │            Steam Relay / ENet传输                      │
│  └────────────┘  │          └──────────────────────────────────────────────────────┘
└──────────────────┘
```

**关键特征**：
- 房主既运行服务器逻辑，也运行自己的客户端视图
- 客户端通过Steam Relay或ENet连接到房主
- 主机决定所有游戏状态，客户端插值显示

### 1.3 为什么不用完全P2P锁步

| 问题 | 锁步方案 | 主机权威方案 |
|---|---|---|
| 大量实体同步 | 所有客户端必须一致 | 主机决定，客户端近似 |
| 中途加入 | 需要完整状态同步 | 发送当前快照即可 |
| 掉线恢复 | 难以追赶 | 重新下载快照 |
| 作弊防护 | 依赖全客户端校验 | 主机校验即可 |
| 延迟容忍 | 需要全员低延迟 | 客户端可预测 |
| 调试难度 | 状态分叉难定位 | 主机日志即权威 |

---

## 2. 权威边界划分

### 2.1 主机权威（服务器决定）

| 系统 | 主机负责内容 |
|---|---|
| **玩家** | 最终位置、生命、护盾、资源、冷却校验 |
| **敌人** | 生成位置、AI决策、生命、死亡 |
| **技能** | 冷却验证、资源消耗、触发合法性 |
| **伤害** | 命中判定、最终伤害数值、暴击、状态叠加 |
| **掉落** | 掉落位置、掉落内容、拾取判定 |
| **升级** | 经验分配、升级时机、选项池生成 |
| **装备** | 装备掉落、属性生效 |
| **Boss** | 阶段切换、机制触发、技能释放 |
| **地图事件** | 触发时机、目标选择、奖励生成 |
| **随机数** | 全部随机数由主机种子生成 |
| **胜负** | 胜利条件、失败条件、奖励结算 |

### 2.2 客户端本地（不同步）

| 系统 | 客户端本地内容 |
|---|---|
| **输入** | 键盘/鼠标/手柄原始输入采样 |
| **移动预测** | 本地玩家移动插值 |
| **粒子** | 技能粒子、拖尾、火花、碎屑 |
| **音效** | 音效播放、音量衰减 |
| **音乐** | 背景音乐、战斗音乐过渡 |
| **伤害数字** | 浮动数字动画 |
| **屏幕效果** | 震动、闪光、模糊、色差 |
| **尸体** | 敌人尸体、血迹、碎片 |
| **UI动画** | 按钮悬停、卡片翻转、过渡 |
| **镜头** | 镜头跟随、震动、缩放 |

### 2.3 混合（主机决定+客户端预测）

| 系统 | 主机 | 客户端 |
|---|---|---|
| **玩家移动** | 最终位置权威 | 本地预测+插值 |
| **投射物** | 轨迹关键点 | 平滑插值 |
| **Boss位置** | 权威坐标 | 客户端插值 |
| **精英敌人** | 位置和状态 | 移动插值 |

---

## 3. 同步策略与频率

### 3.1 玩家同步

**上行（客户端→主机）**：

```gdscript
# 30Hz不可靠有序
{
  "tick": 12345,
  "seq": 567,
  "input": {
    "move_x": 0.8,
    "move_y": -0.3,
    "dash": false,
    "active_skill": false,
    "ultimate": false
  },
  "aim_direction": Vector2(0.7, 0.7),
  "timestamp": 123456789
}
```

**下行（主机→客户端）**：

```gdscript
# 15-20Hz可靠快照
{
  "tick": 12345,
  "players": [
    {
      "peer_id": 1,
      "position": Vector2(1200, 800),
      "velocity": Vector2(150, 0),
      "health": 850,
      "max_health": 1000,
      "shield": 200,
      "status_effects": [
        {"type": "fire_dot", "stacks": 3, "remaining": 2.5}
      ]
    }
  ]
}
```

**频率**：
- 输入上传：30Hz（不可靠，顺序保证）
- 状态快照：15-20Hz（可靠）
- 关键事件：立即发送（可靠）

### 3.2 Boss与精英同步

**精英敌人**（10-15Hz）：

```gdscript
{
  "entity_id": 42,
  "position": Vector2(1500, 900),
  "health": 3200,
  "max_health": 5000,
  "target_player": 2,
  "state": "charging",  # idle/moving/charging/casting
  "elite_modifiers": ["teleporter", "vampire"]
}
```

**Boss**（10-15Hz + 阶段事件）：

```gdscript
# 定期快照
{
  "entity_id": 1,
  "position": Vector2(1600, 1200),
  "health": 45000,
  "max_health": 100000,
  "phase": 2,
  "current_attack": "summon_wave"
}

# 阶段切换事件（可靠）
{
  "event": "boss_phase_change",
  "boss_id": 1,
  "new_phase": 3,
  "invulnerable_until": 125.5
}
```

### 3.3 普通敌群同步（关键创新）

**问题**：1000只普通敌人不能逐个发送位置

**方案**：群组参数同步

```gdscript
# 主机生成群组
{
  "swarm_id": 15,
  "spawn_time": 120.5,
  "spawn_center": Vector2(2000, 1500),
  "enemy_type": "zombie",
  "count": 50,
  "target_player": 3,
  "formation": "circle",
  "spread": 200,
  "random_seed": 987654
}
```

**客户端还原**：
1. 根据相同种子生成50只僵尸的初始位置
2. 根据formation参数排列
3. 所有僵尸朝target_player移动
4. 低频率（2-5Hz）同步群组中心位置纠偏

**例外情况**：
- 距离玩家<500像素的敌人：升级为精确同步（10Hz）
- 被控制（眩晕/冰冻）的敌人：短暂精确同步
- 死亡瞬间：发送死亡事件（可靠）

```gdscript
# 精确同步近战敌人
{
  "entity_id": 12345,
  "position": Vector2(1050, 820),
  "health": 80,
  "state": "attacking"
}

# 死亡事件
{
  "event": "enemy_died",
  "entity_id": 12345,
  "position": Vector2(1055, 822),
  "killed_by": 2  # 玩家ID
}
```

### 3.4 技能与伤害同步

**技能请求（客户端→主机）**：

```gdscript
{
  "request": "cast_skill",
  "skill_id": "lightning_chain",
  "direction": Vector2(0.8, 0.6),
  "target_position": Vector2(1300, 900),  # 可选
  "tick": 12346
}
```

**技能结果（主机→客户端）**：

```gdscript
{
  "event": "skill_cast",
  "caster_id": 2,
  "skill_id": "lightning_chain",
  "origin": Vector2(1200, 800),
  "targets": [42, 43, 51],  # entity_id列表
  "damage_dealt": [450, 400, 350],
  "effects": ["shocked", "shocked", "shocked"]
}
```

**伤害批量结算**：

```gdscript
# 每0.1秒批量发送
{
  "event": "damage_batch",
  "damages": [
    {"target": 42, "value": 150, "type": "fire", "crit": false},
    {"target": 43, "value": 320, "type": "physical", "crit": true},
    {"target": 51, "value": 180, "type": "lightning", "crit": false}
  ]
}
```

### 3.5 掉落与升级同步

**掉落生成（主机广播）**：

```gdscript
{
  "event": "drop_spawned",
  "drop_id": 789,
  "type": "exp_orb",
  "position": Vector2(1300, 850),
  "value": 25
}
```

**升级事件（主机→目标玩家）**：

```gdscript
{
  "event": "level_up",
  "player_id": 2,
  "new_level": 8,
  "options": [
    {"type": "skill_upgrade", "skill_id": "fireball", "to_level": 4},
    {"type": "new_skill", "skill_id": "ice_nova"},
    {"type": "passive", "passive_id": "crit_chance"}
  ]
}
```

**选择响应（客户端→主机）**：

```gdscript
{
  "request": "upgrade_choice",
  "option_index": 0,
  "tick": 12500
}
```

---

## 4. 延迟补偿与预测

### 4.1 客户端预测

**本地玩家移动**：
1. 客户端立即应用输入到本地位置
2. 同时发送输入给主机
3. 主机返回权威位置
4. 如果偏差>阈值，平滑校正

```gdscript
# 客户端预测代码（伪代码）
func _process(delta):
    var input = get_input()
    predicted_position += input.direction * speed * delta
    send_input_to_server(input)

func on_server_position_received(server_pos):
    var error = predicted_position.distance_to(server_pos)
    if error > CORRECTION_THRESHOLD:
        # 平滑插值到服务器位置
        predicted_position = lerp(predicted_position, server_pos, 0.3)
```

**队友玩家插值**：
- 不预测，直接插值
- 使用线性或三次插值
- 保留0.1-0.2秒缓冲

### 4.2 延迟容忍设计

| 延迟 | 体验 | 优化措施 |
|---:|---|---|
| 0-50ms | 完美 | 无需特殊处理 |
| 50-100ms | 良好 | 客户端预测足够 |
| 100-150ms | 可玩 | 增大校正阈值，明显插值 |
| 150-200ms | 勉强可玩 | 显示延迟警告，建议重连 |
| >200ms | 不可玩 | 强制断开或降级为观察者 |

---

## 5. 连接与房间管理

### 5.1 开发阶段（ENet）

```gdscript
# 创建主机
var peer = ENetMultiplayerPeer.new()
peer.create_server(7777, 4)  # 端口7777，最多4人
multiplayer.multiplayer_peer = peer

# 加入主机
var peer = ENetMultiplayerPeer.new()
peer.create_client("192.168.1.100", 7777)
multiplayer.multiplayer_peer = peer
```

### 5.2 Steam阶段（GodotSteam）

```gdscript
# 创建Steam大厅（房主）
Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, 4)

# 监听大厅创建
func _on_lobby_created(connect_result, lobby_id):
    if connect_result == 1:
        current_lobby_id = lobby_id
        # 设置MultiplayerPeer
        var peer = SteamMultiplayerPeer.new()
        peer.create_host(0, [])  # Steam自动处理端口
        multiplayer.multiplayer_peer = peer

# 加入Steam大厅
Steam.joinLobby(lobby_id)

func _on_lobby_joined(lobby_id, permissions, locked, response):
    if response == 1:
        # 获取房主Steam ID
        var host_id = Steam.getLobbyOwner(lobby_id)
        var peer = SteamMultiplayerPeer.new()
        peer.create_client(host_id, 0, [])
        multiplayer.multiplayer_peer = peer
```

**Steam Relay优势**：
- 自动处理NAT穿透
- 无需玩家端口转发
- Valve提供中继服务器
- 延迟通常<150ms

### 5.3 房间状态机

```
[未连接] ──创建/加入──> [连接中] ──成功──> [大厅]
                            │              │
                            │              ├──开始游戏──> [游戏中]
                            │              │                │
                            └──失败──> [错误]               │
                                                          ├──游戏结束──> [结算]
                                                          │                │
                                                          └──掉线──────> [重连中]
                                                                          │
                                                                          ├──成功──> [游戏中]
                                                                          └──超时──> [断开]
```

---

## 6. 掉线与重连

### 6.1 掉线检测

- **心跳超时**：5秒无数据包视为掉线
- **主动断开**：客户端发送disconnect事件
- **网络切换**：移动网络/WiFi切换检测

### 6.2 客户端掉线处理

**AI托管（30秒）**：
```gdscript
func on_player_disconnected(peer_id):
    var player = get_player(peer_id)
    player.set_ai_controlled(true)
    player.disconnect_timer = 30.0
    player.reconnect_token = generate_token()
    save_player_snapshot(player)
```

**AI行为**：
- 仅执行基础移动和攻击
- 不选择升级（保留升级点）
- 不拾取装备（保留在地上）
- 跟随最近队友

**超时移除**：
```gdscript
func _process(delta):
    for player in disconnected_players:
        player.disconnect_timer -= delta
        if player.disconnect_timer <= 0:
            remove_player(player)
            adjust_difficulty(-1)  # 降低后续刷新难度
```

### 6.3 重连流程

```
客户端                                主机
   │                                   │
   ├─────── reconnect_request ────────>│
   │        (reconnect_token)          │
   │                                   ├─── 验证token
   │                                   ├─── 恢复玩家控制
   │                                   │
   │<──────── snapshot_full ───────────┤
   │         (完整游戏状态)             │
   │                                   │
   ├─────── reconnect_ack ────────────>│
   │                                   │
   │<──────── resume_game ─────────────┤
   │                                   │
```

**快照内容**：
```gdscript
{
  "game_time": 245.8,
  "random_seed": 123456,
  "players": [...],  # 所有玩家状态
  "boss": {...},     # Boss状态
  "elites": [...],   # 精英列表
  "map_events": [...],
  "your_player": {
    "position": Vector2(1200, 800),
    "health": 850,
    "skills": [...],
    "equipment": [...],
    "pending_upgrades": 2  # 未选择的升级
  }
}
```

### 6.4 主机掉线处理

**MVP版本（简单）**：
```gdscript
func on_host_disconnected():
    show_message("主机断开连接")
    save_local_progress()  # 保存局外奖励
    return_to_menu()
```

**正式版候选（主机迁移）**：

1. **候选主机选择**：
   - 网络延迟最低
   - 帧率稳定
   - 主机定期发送候选列表

2. **迁移流程**：
```gdscript
# 旧主机定期广播
func _on_backup_timer():
    send_to_candidate(get_full_snapshot())

# 候选主机检测掉线
func on_host_timeout():
    if i_am_candidate:
        promote_to_host()
        broadcast("new_host", my_peer_id)
        restore_from_snapshot(latest_snapshot)
        # 清除普通敌人，重建群组
        rebuild_enemy_swarms()
        # 给所有玩家3秒无敌
        apply_grace_period(3.0)
```

3. **限制**：
   - 普通敌群重建（不保证完全相同）
   - 3秒"裂界重构"过渡
   - 目标是实用恢复，非无缝

---

## 7. 网络安全与反作弊

### 7.1 输入验证

```gdscript
# 主机验证客户端请求
func validate_skill_request(peer_id, request):
    var player = get_player(peer_id)
    
    # 1. 冷却检查
    if not player.is_skill_ready(request.skill_id):
        return false
    
    # 2. 资源检查
    if player.mana < get_skill_cost(request.skill_id):
        return false
    
    # 3. 距离检查
    if request.target:
        var dist = player.position.distance_to(request.target)
        if dist > get_skill_range(request.skill_id):
            return false
    
    # 4. 状态检查
    if player.is_stunned or player.is_dead:
        return false
    
    return true
```

### 7.2 数值范围限制

```gdscript
# RPC参数校验
@rpc("any_peer", "call_remote", "unreliable")
func submit_input(input_data: Dictionary):
    # 1. 移动方向归一化
    var move = Vector2(input_data.move_x, input_data.move_y)
    if move.length() > 1.0:
        move = move.normalized()
    
    # 2. 字符串长度限制
    if "chat" in input_data:
        input_data.chat = input_data.chat.substr(0, 200)
    
    # 3. 数组大小限制
    if "targets" in input_data:
        input_data.targets = input_data.targets.slice(0, 10)
    
    apply_input(get_sender_peer_id(), input_data)
```

### 7.3 权限边界

```gdscript
# 只有主机能调用
@rpc("authority", "call_local", "reliable")
func spawn_enemy(type, position):
    pass

# 客户端请求，主机验证后执行
@rpc("any_peer", "call_remote", "reliable")
func request_pick_upgrade(option_index):
    if multiplayer.is_server():
        var peer_id = get_sender_peer_id()
        validate_and_apply_upgrade(peer_id, option_index)
```

### 7.4 禁止行为

- ✗ 客户端上报最终伤害
- ✗ 客户端决定掉落内容
- ✗ 客户端修改其他玩家状态
- ✗ 客户端控制Boss
- ✗ 客户端加载任意脚本/场景
- ✗ 客户端发送超大数据包

---

## 8. 带宽预算

### 8.1 上行（客户端→主机）

| 内容 | 频率 | 字节/包 | KB/s |
|---|---:|---:|---:|
| 输入数据 | 30Hz | 50B | 1.5 |
| 技能请求 | 事件 | 80B | ~0.5 |
| 升级选择 | 事件 | 20B | ~0.1 |
| **单客户端总计** | | | **~2 KB/s** |

### 8.2 下行（主机→单客户端）

| 内容 | 频率 | 字节/包 | KB/s |
|---|---:|---:|---:|
| 玩家快照（4人） | 15Hz | 200B | 3.0 |
| Boss/精英（10个） | 10Hz | 500B | 5.0 |
| 敌群参数（20群） | 5Hz | 400B | 2.0 |
| 伤害批量 | 10Hz | 300B | 3.0 |
| 掉落/升级事件 | 事件 | 100B | ~1.0 |
| **单客户端总计** | | | **~14 KB/s** |

**4人房间主机总带宽**：
- 上行：3×2 = 6 KB/s
- 下行：3×14 = 42 KB/s
- **总计：~50 KB/s**（400 kbps）

**优化余地**：
- 压缩算法（LZ4/Zstd）可降低30-50%
- 视野剔除：不发送距离>1500px的实体
- 死亡玩家降低更新频率

---

## 9. 测试矩阵

### 9.1 网络条件测试

| 延迟 | 丢包率 | 人数 | 预期结果 |
|---:|---:|---:|---|
| 0ms | 0% | 2 | 完美流畅 |
| 50ms | 0% | 4 | 完美流畅 |
| 100ms | 1% | 4 | 偶尔抖动，可玩 |
| 150ms | 1% | 4 | 明显延迟，可玩 |
| 150ms | 3% | 4 | 抖动明显，勉强可玩 |
| 200ms | 3% | 4 | 不可玩，显示警告 |

**测试工具**：
- Godot编辑器网络模拟器
- Clumsy（Windows网络延迟注入）
- 跨地域Steam好友测试

### 9.2 稳定性测试

| 场景 | 验证内容 |
|---|---|
| 客户端掉线30秒内重连 | AI托管→恢复控制→状态完整 |
| 客户端掉线超时移除 | 难度平滑调整，游戏继续 |
| 主机掉线 | 保存进度，优雅退出（MVP） |
| 客户端低帧率 | 不影响主机帧率 |
| 主机低帧率 | 客户端平滑插值 |
| 大量同时伤害 | 批量发送不丢失 |
| Boss阶段切换 | 所有客户端同步 |
| 20分钟长时游戏 | 无内存泄漏，无状态分叉 |

---

## 10. 实现里程碑

### M2：2人联机原型（3-4周）

**目标**：
- ENet局域网连接
- 2名玩家移动同步
- 技能请求→主机结算→广播结果
- 敌人群组同步
- Boss血量同步
- 掉线重连

**不包括**：
- Steam集成
- 4人完整测试
- 主机迁移
- 完整UI

### M4：完整联机（6-8周）

**目标**：
- GodotSteam + Steam Relay
- 1-4人房间
- 好友邀请
- 完整掉线重连
- 四人性能优化
- 延迟显示UI
- 队友特效透明度

---

## 11. 已知技术限制

| 限制 | 原因 | 缓解措施 |
|---|---|---|
| 主机性能决定上限 | Listen Server架构 | 显示主机配置要求 |
| 延迟>200ms不可玩 | 动作游戏特性 | 区域限制，延迟警告 |
| 普通敌群不精确 | 带宽限制 | 玩家距离近时升级精确 |
| 主机掉线严重 | 权威单点 | MVP保存进度，正式版迁移 |
| 无跨平台 | Steam限制 | 仅Windows首发 |

---

## 参考资料

1. Godot高层多人游戏：<https://docs.godotengine.org/zh-cn/4.x/tutorials/networking/high_level_multiplayer.html>
2. GodotSteam MultiplayerPeer：<https://godotsteam.com/tutorials/multiplayer_peer/>
3. Steam Networking Sockets文档：<https://partner.steamgames.com/doc/api/ISteamNetworkingSockets>
4. Valve延迟补偿文章：<https://developer.valvesoftware.com/wiki/Latency_Compensating_Methods_in_Client/Server_In-game_Protocol_Design_and_Optimization>
