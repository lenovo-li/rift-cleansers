# UI与角色朝向改进方案

## 📋 概述

本文档提供两个独立的改进方案：
1. **精美卡牌式升级UI** - 替换原有的简单按钮界面
2. **智能角色朝向系统** - 解决后退时技能朝向问题

---

## 🎨 方案A：卡牌式升级UI

### 新增文件
- `ui/upgrade_card.gd` - 单张卡牌组件
- `ui/upgrade_panel_v2.gd` - 改进的升级面板

### 视觉特性
✨ **卡牌设计**
- 渐变背景 + 圆角边框 + 阴影
- 悬浮时放大效果（1.08倍）
- 点击时缩小反馈（0.95倍）
- 底部光效动画
- 按类型显示不同颜色主题：
  - 技能：蓝色 (0.4, 0.7, 1.0)
  - 装备：橙色 (1.0, 0.65, 0.2)
  - 被动：紫色 (0.7, 0.4, 1.0)

✨ **动画效果**
- 入场：卡牌依次从小到大弹出（0.08秒间隔）
- 选中：放大并淡出
- 其他卡片：同时淡出

### 如何使用

#### 方法1：替换现有面板
在 `game_scene.gd` 或相关场景脚本中：

```gdscript
# 原来
var upgrade_panel: Control = preload("res://ui/upgrade_panel.gd").new()

# 改为
var upgrade_panel: Control = preload("res://ui/upgrade_panel_v2.gd").new()
```

#### 方法2：同时保留两个版本
添加切换选项到设置面板：
```gdscript
# settings_panel.gd
var use_card_ui: bool = SaveData.get_setting("card_ui", true)

# game_scene.gd
var panel_script: String = "res://ui/upgrade_panel_v2.gd" if Settings.card_ui else "res://ui/upgrade_panel.gd"
var upgrade_panel: Control = load(panel_script).new()
```

### 自定义调整

修改 `upgrade_card.gd` 中的常量：
```gdscript
const CARD_WIDTH: float = 280.0      # 卡牌宽度
const CARD_HEIGHT: float = 360.0     # 卡牌高度
```

修改悬浮缩放比例（第78行）：
```gdscript
var target_scale: float = 1.08 if _hover else 1.0  # 改为 1.12 更明显
```

---

## 🎯 方案B：智能角色朝向系统

### 新增文件
- `gameplay/actors/facing_controller.gd` - 朝向控制器类

### 五种朝向模式

| 模式 | 说明 | 适用场景 |
|------|------|----------|
| **MOVE_DIRECTION** | 原版：朝向移动方向 | 保持原有手感 |
| **LOCK_ENEMY** | 自动锁定最近敌人 | 近战肉搏 |
| **SMART_CAST** ⭐ | 移动跟随方向，施法朝向敌人 | **推荐默认** |
| **MOUSE_AIM** | 鼠标/右摇杆瞄准 | 精确控制 |
| **KEEP_FACING** | 保持朝向（后退不转身） | 魂系风格 |

### 集成到 player_m1.gd

#### 步骤1：添加控制器实例

在 `player_m1.gd` 顶部添加：
```gdscript
var facing_controller: FacingController = null
```

#### 步骤2：初始化（在 _ready 中）

```gdscript
func _ready() -> void:
	# ... 现有代码 ...
	
	# 初始化朝向控制器
	facing_controller = FacingController.new()
	facing_controller.mode = FacingController.Mode.SMART_CAST  # 默认智能施法模式
	facing_controller.current_facing = facing
```

#### 步骤3：修改 _move 函数

找到 `player_m1.gd:314-331` 的 `_move` 函数，修改如下：

```gdscript
func _move(delta: float, direction: Vector3) -> void:
	if _dash_time > 0.0:
		_dash_time -= delta
		velocity = _dash_velocity
	else:
		var speed: float = move_speed * status.speed_multiplier()
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			
			# ===== 新增：使用朝向控制器 =====
			var is_casting: bool = false  # 如果需要检测施法状态，在施法时设置为 true
			facing = facing_controller.update(delta, global_position, direction, 
				get_tree().get_nodes_in_group("enemies"), is_casting)
			# ================================
			
			rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), 0.25)
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
	velocity.y = 0.0
	move_and_slide()
	global_position = Vector3(clampf(global_position.x, -ARENA_HALF, ARENA_HALF), 0.0,
			clampf(global_position.z, -ARENA_HALF, ARENA_HALF))
```

#### 步骤4：（可选）施法时标记状态

在 `cast_skill` 函数中，施法瞬间通知控制器：

```gdscript
func cast_skill(skill_id: String) -> Dictionary:
	if is_dead or not ability_system.can_cast(skill_id):
		return {}
	
	# 施法瞬间更新朝向（SMART_CAST 模式会自动朝向敌人）
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	facing = facing_controller.update(0.0, global_position, Vector3.ZERO, enemies, true)
	
	# ... 原有施法逻辑 ...
```

#### 步骤5：（可选）添加模式切换快捷键

在 `_physics_process` 中添加：

```gdscript
# 切换朝向模式（Tab 键）
if Input.is_action_just_pressed("toggle_facing_mode"):
	_cycle_facing_mode()

# 锁定/切换目标（T 键）
if Input.is_action_just_pressed("lock_target"):
	if facing_controller.mode == FacingController.Mode.LOCK_ENEMY:
		facing_controller.cycle_lock_target(global_position, get_tree().get_nodes_in_group("enemies"))
	else:
		facing_controller.mode = FacingController.Mode.LOCK_ENEMY
		facing_controller.locked_target = null
```

添加辅助函数：

```gdscript
func _cycle_facing_mode() -> void:
	var modes: Array = [
		FacingController.Mode.SMART_CAST,
		FacingController.Mode.KEEP_FACING,
		FacingController.Mode.LOCK_ENEMY,
	]
	var current_idx: int = modes.find(facing_controller.mode)
	var next_idx: int = (current_idx + 1) % modes.size()
	facing_controller.mode = modes[next_idx]
	
	var mode_names: Dictionary = {
		FacingController.Mode.SMART_CAST: "智能施法",
		FacingController.Mode.KEEP_FACING: "保持朝向",
		FacingController.Mode.LOCK_ENEMY: "锁定敌人",
	}
	print("[朝向模式] %s" % mode_names.get(facing_controller.mode, "未知"))
```

### HUD 显示锁定状态

在 `hud.gd` 的 `_info_label` 更新中添加：

```gdscript
var lock_status: String = player.facing_controller.get_lock_status()
_info_label.text = "... %s" % lock_status if lock_status else "..."
```

---

## 🎮 按键配置建议

在 `project.godot` 或 InputMap 中添加：

```gdscript
# 可选：朝向模式切换
"toggle_facing_mode": KEY_TAB

# 可选：锁定目标
"lock_target": KEY_T
```

---

## 📊 各方案对比

### UI方案对比

| 特性 | 原版 | 卡牌式 v2 |
|------|------|-----------|
| 视觉风格 | 简单按钮 | 精美卡牌 |
| 动画效果 | 无 | 入场/选中动画 |
| 悬浮反馈 | 无 | 放大+光效 |
| 类型区分 | 纯文本 | 颜色主题 |
| 性能开销 | 极低 | 低 |

### 朝向方案对比

| 模式 | 优点 | 缺点 | 推荐度 |
|------|------|------|--------|
| MOVE_DIRECTION | 原版手感 | 后退打空 | ⭐⭐ |
| SMART_CAST | 自由移动+精准施法 | 无 | ⭐⭐⭐⭐⭐ |
| KEEP_FACING | 魂系风格，适合近战 | 需要手动调整朝向 | ⭐⭐⭐⭐ |
| LOCK_ENEMY | 简单直观 | 失去方向控制 | ⭐⭐⭐ |
| MOUSE_AIM | 精确瞄准 | 需要鼠标/右摇杆 | ⭐⭐⭐ |

---

## 🚀 推荐实施顺序

### 阶段1：快速改进（30分钟）
1. 添加 `FacingController` 类
2. 集成 SMART_CAST 模式到 player_m1.gd
3. 测试后退施法效果

### 阶段2：UI升级（1小时）
1. 添加卡牌UI组件
2. 创建升级面板 v2
3. 在游戏场景中切换使用

### 阶段3：完善功能（可选）
1. 添加朝向模式切换快捷键
2. HUD显示锁定状态
3. 添加设置选项让玩家选择UI风格和朝向模式

---

## 🧪 测试建议

### 朝向系统测试
```gdscript
# 在 player_m1.gd 添加调试输出
func _physics_process(delta: float) -> void:
	# ... 原有代码 ...
	
	if Input.is_action_just_pressed("ui_page_down"):  # Page Down 键
		print("[朝向测试] facing: %s, move_dir: %s, mode: %d" % 
			[facing, _desired_direction(), facing_controller.mode])
```

### UI测试场景
创建 `tests/ui_upgrade_test.gd`：
```gdscript
extends Node

func _ready() -> void:
	var panel = preload("res://ui/upgrade_panel_v2.gd").new()
	panel.pause_game = false
	panel.roll_choices = func() -> Array:
		return [
			{"type": "skill", "title": "盾击", "desc": "冲锋并击退敌人"},
			{"type": "equipment", "title": "暴击护符", "desc": "暴击率+12%"},
			{"type": "passive", "title": "狂怒强化", "desc": "怒气>80时伤害+30%"},
		]
	add_child(panel)
	panel.request()
```

---

## 💡 进一步优化建议

### UI方面
1. **技能图标**：为每个技能添加真实图标（替换 ColorRect）
2. **稀有度系统**：普通/稀有/史诗用不同边框颜色
3. **粒子特效**：选中时播放星光粒子
4. **音效增强**：悬浮/选中/确认的独立音效

### 朝向方面
1. **锁定UI指示器**：在敌人头顶显示锁定标记
2. **朝向预览**：地面显示攻击方向指示器
3. **自适应智能**：根据技能类型自动选择最佳朝向模式
4. **手柄优化**：右摇杆原生支持（MOUSE_AIM 模式）

---

## 📝 注意事项

1. **网络同步**：如果是联机模式，`facing` 变化需要同步到主机
2. **性能**：朝向控制器每帧查找最近敌人，敌人数量>100时考虑优化
3. **兼容性**：确保原有存档、回放系统不受影响
4. **音效**：卡牌UI的音效调用需要 SfxManager 支持 "ui_hover" 和 "ui_click"

---

## 🔗 相关文件

- `ui/upgrade_card.gd` - 卡牌组件
- `ui/upgrade_panel_v2.gd` - 新升级面板
- `gameplay/actors/facing_controller.gd` - 朝向控制器
- `gameplay/actors/player_m1.gd` - 需要修改的玩家脚本
- `ui/hud.gd` - HUD（可选添加锁定状态显示）
