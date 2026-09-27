# 《裂界清扫者》项目初始化规范

> 版本：v1.0  
> 日期：2026-09-27  
> 用途：从零创建正式工程  
> 状态：待执行

---

## 执行摘要

本文档定义从零创建正式Godot项目的步骤，确保：
1. 版本控制正确配置
2. 目录结构清晰
3. 命名规范统一
4. 依赖明确记录
5. 旧残留不污染新项目

---

## 1. 环境准备

### 1.1 必需软件

| 软件 | 版本 | 用途 | 下载 |
|---|---|---|---|
| Godot Engine | 4.7.2 stable | 游戏引擎 | https://godotengine.org/download |
| Git | 2.45+ | 版本控制 | https://git-scm.com/ |
| Git LFS | 3.5+ | 大文件管理 | https://git-lfs.com/ |
| Blender | 4.2 LTS | 3D建模 | https://www.blender.org/ |
| VS Code | 最新 | 代码编辑 | https://code.visualstudio.com/ |

### 1.2 可选软件

| 软件 | 用途 |
|---|---|
| Krita | 2D纹理编辑 |
| Inkscape | SVG图标 |
| Audacity | 音频编辑 |
| RenderDoc | GPU调试 |

### 1.3 VS Code扩展

```json
{
  "recommendations": [
    "geequlim.godot-tools",
    "neikeq.godot-csharp-vscode",
    "EditorConfig.EditorConfig"
  ]
}
```

---

## 2. 旧项目清理

### 2.1 处理现有node_modules

```bash
cd D:/project/game/

# 归档或删除旧依赖
if [ -d "node_modules" ]; then
  echo "发现旧node_modules，归档到archive/"
  mkdir -p archive
  mv node_modules archive/node_modules_$(date +%Y%m%d)
fi
```

### 2.2 清理Survive目录

```bash
cd D:/project/game/Survive

# 保留设计文档
mkdir -p ../archive/design_docs_v0.3
cp -r 裂界清扫者_设计文档集_v0.3 ../archive/design_docs_v0.3/
cp 裂界清扫者_文档导航_v0.3.md ../archive/design_docs_v0.3/
cp IDEA.md ../archive/design_docs_v0.3/

# docs目录已包含技术文档，保留
# 删除或移出其他内容
# （建议：在创建新Godot项目前备份整个Survive目录）
cd ..
mv Survive Survive_backup_$(date +%Y%m%d)
```

---

## 3. 创建Godot项目

### 3.1 项目创建

```bash
cd D:/project/game/

# 方式1：命令行
godot --path Survive --editor --quit
# 启动编辑器后自动创建project.godot

# 方式2：编辑器UI
# 打开Godot → 新建项目 → 选择路径 D:/project/game/Survive
```

### 3.2 项目设置

打开 `project.godot`，配置：

```ini
; project.godot
config_version=5

[application]

config/name="裂界清扫者 (Rift Cleansers)"
config/description="1-4人合作肉鸽动作游戏"
config/version="0.1.0"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.7", "Forward Plus")
config/icon="res://icon.svg"

[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/mode=2
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[rendering]

renderer/rendering_method="forward_plus"
textures/canvas_textures/default_texture_filter=0
anti_aliasing/quality/msaa_2d=2

[input]

move_left={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194319,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
move_right={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194321,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
move_up={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194320,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
move_down={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":83,"key_label":0,"unicode":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194322,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
dash={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
skill_1={
"deadzone": 0.5,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":1,"canceled":false,"pressed":false,"double_click":false,"script":null)
]
}
```

---

## 4. Git初始化

### 4.1 初始化仓库

```bash
cd D:/project/game/Survive
git init
git branch -M main
```

### 4.2 配置Git LFS

```bash
git lfs install

# 追踪大文件类型
git lfs track "*.glb"
git lfs track "*.gltf"
git lfs track "*.bin"
git lfs track "*.png"
git lfs track "*.jpg"
git lfs track "*.wav"
git lfs track "*.ogg"
git lfs track "*.mp3"
git lfs track "*.tres"  # Resource文件可能较大
```

### 4.3 创建.gitignore

```bash
cat > .gitignore << 'EOF'
# Godot
.import/
export.cfg
export_presets.cfg
.mono/
data_*/
mono_crash.*.json

# Godot 4+
.godot/

# 构建输出
builds/
dist/
*.x86_64
*.exe
*.dll
*.so
*.dylib
*.pck

# 编辑器
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# 日志
*.log
user://

# 临时文件
*.tmp
*.bak
EOF
```

### 4.4 创建.gitattributes

```bash
cat > .gitattributes << 'EOF'
# Git LFS
*.glb filter=lfs diff=lfs merge=lfs -text
*.gltf filter=lfs diff=lfs merge=lfs -text
*.bin filter=lfs diff=lfs merge=lfs -text
*.png filter=lfs diff=lfs merge=lfs -text
*.jpg filter=lfs diff=lfs merge=lfs -text
*.wav filter=lfs diff=lfs merge=lfs -text
*.ogg filter=lfs diff=lfs merge=lfs -text
*.mp3 filter=lfs diff=lfs merge=lfs -text
*.tres filter=lfs diff=lfs merge=lfs -text

# 文本文件规范化
*.gd text eol=lf
*.tscn text eol=lf
*.tres text eol=lf
*.md text eol=lf
*.json text eol=lf
*.yaml text eol=lf
EOF
```

### 4.5 首次提交

```bash
git add .gitignore .gitattributes .gitlfs.track
git commit -m "chore: 初始化Git仓库和LFS"

git add project.godot
git commit -m "chore: 创建Godot项目"
```

---

## 5. 目录结构

### 5.1 创建目录

```bash
mkdir -p addons
mkdir -p core
mkdir -p gameplay/combat
mkdir -p gameplay/actors
mkdir -p gameplay/spawn
mkdir -p gameplay/progression
mkdir -p gameplay/loot
mkdir -p net
mkdir -p presentation
mkdir -p ui
mkdir -p content/characters
mkdir -p content/skills
mkdir -p content/equipment
mkdir -p content/enemies
mkdir -p content/maps
mkdir -p scenes
mkdir -p tests
mkdir -p third_party_licenses
mkdir -p assets/models
mkdir -p assets/textures
mkdir -p assets/audio/music
mkdir -p assets/audio/sfx
mkdir -p assets/fonts
```

### 5.2 目录说明文档

```bash
cat > README.md << 'EOF'
# 裂界清扫者 (Rift Cleansers)

1-4人在线合作肉鸽动作游戏

## 项目结构

```
project/
├─ addons/              # 第三方插件（GodotSteam等）
├─ assets/              # 美术资源
│  ├─ models/          # 3D模型（.glb）
│  ├─ textures/        # 纹理贴图
│  ├─ audio/           # 音频文件
│  └─ fonts/           # 字体文件
├─ core/                # 核心系统（无Godot场景依赖）
├─ gameplay/            # 游戏逻辑
│  ├─ combat/          # 战斗系统
│  ├─ actors/          # 玩家、敌人、投射物
│  ├─ spawn/           # 生成导演
│  ├─ progression/     # 经验、升级
│  └─ loot/            # 掉落系统
├─ net/                 # 网络系统
├─ presentation/        # 表现层（粒子、音效、UI）
├─ ui/                  # UI场景
├─ content/             # 数据驱动配置（.tres）
│  ├─ characters/
│  ├─ skills/
│  ├─ equipment/
│  ├─ enemies/
│  └─ maps/
├─ scenes/              # Godot场景（.tscn）
├─ tests/               # 单元测试
├─ third_party_licenses/ # 第三方许可证
└─ docs/                # 技术文档
```

## 开发

### 运行游戏

```bash
godot --path . res://scenes/main.tscn
```

### 运行测试

```bash
godot --path . --script tests/run_all_tests.gd
```

### 性能测试

```bash
godot --path . --script tests/stress_test_500.gd
```

## 技术栈

- 引擎：Godot 4.7.2
- 语言：GDScript（强制类型标注）
- 网络：ENet（开发期）→ GodotSteam（Steam版）
- 版本控制：Git + Git LFS

## 文档

- 技术架构：`docs/03_GAMEPLAY_TECHNICAL_ARCHITECTURE.md`
- 联机设计：`docs/02_MULTIPLAYER_ARCHITECTURE_DESIGN.md`
- 开发路线：`docs/07_DEVELOPMENT_PHASES_ROADMAP.md`

## 许可证

游戏代码：待定
引擎：Godot Engine (MIT)
第三方资源：见 `third_party_licenses/`
EOF
```

---

## 6. 命名规范

### 6.1 文件命名

| 类型 | 规范 | 示例 |
|---|---|---|
| 脚本 | snake_case.gd | `player_state.gd` |
| 场景 | snake_case.tscn | `main_menu.tscn` |
| Resource | snake_case.tres | `ironguard.tres` |
| 模型 | snake_case.glb | `zombie_01.glb` |
| 纹理 | snake_case.png | `tile_grass.png` |
| 音效 | snake_case.wav | `sword_hit.wav` |

### 6.2 代码命名

```gdscript
# 类名：PascalCase
class_name PlayerState

# 常量：UPPER_SNAKE_CASE
const MAX_HEALTH: float = 1000.0

# 变量：snake_case
var current_health: float = 1000.0

# 私有变量：_snake_case
var _internal_state: int = 0

# 函数：snake_case
func calculate_damage(base: float) -> float:
    return base * damage_multiplier

# 信号：snake_case
signal health_changed(new_value: float)
```

### 6.3 场景节点命名

```
Player (CharacterBody2D)
├─ Sprite (Sprite2D)
├─ CollisionShape (CollisionShape2D)
├─ AnimationPlayer (AnimationPlayer)
└─ HealthBar (ProgressBar)
```

---

## 7. GDScript规范

### 7.1 强制类型标注

```gdscript
# ✓ 正确：明确类型
var health: float = 100.0
var name: String = "Player"
var items: Array[Item] = []

func get_damage(multiplier: float) -> float:
    return base_damage * multiplier

# ✗ 错误：无类型标注
var health = 100.0
var name = "Player"

func get_damage(multiplier):
    return base_damage * multiplier
```

### 7.2 导出变量

```gdscript
@export var max_health: float = 1000.0
@export var move_speed: float = 300.0
@export_range(0, 1) var crit_chance: float = 0.1
@export_file("*.tres") var character_data: String
```

### 7.3 节点引用

```gdscript
# ✓ 正确：@onready缓存
@onready var sprite: Sprite2D = $Sprite
@onready var animation: AnimationPlayer = $AnimationPlayer

# ✗ 错误：每帧get_node
func _process(delta):
    var sprite = get_node("Sprite")  # 慢！
```

---

## 8. 提交规范

### 8.1 Commit消息格式

```
<type>(<scope>): <subject>

<body>

<footer>
```

**类型**：
- `feat`: 新功能
- `fix`: Bug修复
- `refactor`: 重构
- `perf`: 性能优化
- `test`: 测试
- `docs`: 文档
- `chore`: 构建/工具

**示例**：

```bash
git commit -m "feat(combat): 实现盾击技能四段进化"
git commit -m "fix(network): 修复Boss血量同步问题"
git commit -m "perf(enemy): 使用MultiMesh渲染1000敌人"
```

### 8.2 分支策略

```
main            # 稳定版本
  ├─ develop    # 开发主线
  │   ├─ feature/shield-bash-evolution
  │   ├─ feature/multiplayer-sync
  │   └─ fix/boss-health-desync
```

---

## 9. 配置版本管理

### 9.1 配置文件

```gdscript
# core/game_config.gd
class_name GameConfig extends Resource

const VERSION: String = "0.1.0"
const CONFIG_VERSION: int = 1

@export var master_volume: float = 1.0
@export var sfx_volume: float = 1.0
@export var music_volume: float = 1.0
@export var fullscreen: bool = false
@export var vsync: bool = true

func save_to_file():
    ResourceSaver.save(self, "user://config.tres")

static func load_from_file() -> GameConfig:
    if FileAccess.file_exists("user://config.tres"):
        return load("user://config.tres")
    return GameConfig.new()
```

### 9.2 存档版本

```gdscript
# core/save_data.gd
class_name SaveData extends Resource

const SAVE_VERSION: int = 1

@export var version: int = SAVE_VERSION
@export var unlocked_characters: Array[String] = []
@export var unlocked_skills: Array[String] = []

func migrate_from_v1():
    # 未来版本迁移逻辑
    pass
```

---

## 10. 第三方许可证管理

### 10.1 创建许可证目录

```bash
mkdir -p third_party_licenses/godot
mkdir -p third_party_licenses/assets
```

### 10.2 记录Godot许可证

```bash
# 从Godot安装目录复制
cp /path/to/godot/COPYRIGHT.txt third_party_licenses/godot/
cp /path/to/godot/LICENSE.txt third_party_licenses/godot/
```

### 10.3 资产登记模板

```yaml
# third_party_licenses/assets/kenney_asset_pack.yaml
asset_name: Kenney Asset Pack - Prototype Textures
author: Kenney
source_url: https://kenney.nl/assets/prototype-textures
license: CC0 1.0
download_date: 2026-09-27
modified: false
credit_required: false
used_in: 
  - environment/tiles
  - ui/icons
```

---

## 11. 初始提交清单

```bash
# 1. 项目文件
git add project.godot icon.svg

# 2. Git配置
git add .gitignore .gitattributes

# 3. 文档
git add README.md docs/

# 4. 目录结构（保留空目录）
find . -type d -empty -not -path "./.git/*" -exec touch {}/.gitkeep \;
git add **/.gitkeep

# 5. 许可证
git add third_party_licenses/

# 6. 提交
git commit -m "chore: 初始化项目结构

- 创建Godot 4.7.2项目
- 配置Git和Git LFS
- 建立目录结构
- 添加README和技术文档
- 配置命名规范和提交规范"
```

---

## 12. 验证清单

初始化完成后，检查：

- [ ] `godot --path .` 可以打开项目
- [ ] Git LFS正确追踪大文件（`git lfs ls-files`）
- [ ] 目录结构完整
- [ ] README.md存在
- [ ] 技术文档在docs/目录
- [ ] .gitignore排除.godot/
- [ ] 提交历史清晰

---

## 13. 下一步

初始化完成后，开始 **M0: 技术试验**：

1. 创建玩家移动场景
2. 实现俯视镜头
3. 1000方块压力测试
4. 对象池实现
5. 空间网格实现

参见：`docs/07_DEVELOPMENT_PHASES_ROADMAP.md`

---

## 附录：快速初始化脚本

```bash
#!/bin/bash
# init_project.sh

set -e

PROJECT_DIR="D:/project/game/Survive"

echo "=== 裂界清扫者项目初始化 ==="

# 1. 备份旧目录
if [ -d "$PROJECT_DIR" ]; then
    echo "备份现有目录..."
    mv "$PROJECT_DIR" "${PROJECT_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
fi

# 2. 创建新目录
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# 3. 初始化Git
git init
git branch -M main

# 4. 配置Git LFS
git lfs install
git lfs track "*.glb" "*.gltf" "*.bin" "*.png" "*.jpg" "*.wav" "*.ogg" "*.mp3" "*.tres"

# 5. 创建目录结构
mkdir -p addons core gameplay/{combat,actors,spawn,progression,loot} net presentation ui
mkdir -p content/{characters,skills,equipment,enemies,maps}
mkdir -p scenes tests third_party_licenses
mkdir -p assets/{models,textures,audio/{music,sfx},fonts}

# 6. 创建.gitignore（内容见上文）
cat > .gitignore << 'EOF'
.godot/
.import/
builds/
*.log
EOF

# 7. 创建README（内容见上文）
cat > README.md << 'EOF'
# 裂界清扫者
1-4人合作肉鸽动作游戏
EOF

# 8. 首次提交
git add .
git commit -m "chore: 初始化项目"

echo "✓ 项目初始化完成！"
echo "下一步：使用Godot编辑器打开项目并创建project.godot"
```

---

## 参考资料

1. Godot项目组织：<https://docs.godotengine.org/zh-cn/4.x/tutorials/best_practices/project_organization.html>
2. GDScript风格指南：<https://docs.godotengine.org/zh-cn/4.x/tutorials/scripting/gdscript/gdscript_styleguide.html>
3. Git LFS：<https://git-lfs.com/>
4. Conventional Commits：<https://www.conventionalcommits.org/>
