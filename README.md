# 裂界清扫者 (Rift Cleansers)

> 1-4 人合作肉鸽动作游戏 | Co-op Roguelike Action Game

[![Godot](https://img.shields.io/badge/Godot-4.7.2-blue.svg)](https://godotengine.org/)
[![状态](https://img.shields.io/badge/状态-发布准备-green.svg)]()

---

## 🎮 游戏简介

多个时代和文明被"裂界"撕碎并拼接。裂界会复制生物、机械和记忆，制造不断增殖的怪物。玩家隶属于裂界清扫局，进入即将崩溃的世界碎片，从弱小战士成长为移动天灾。

### 核心特色

- **1-4 人合作**：单人完整体验，联机支持 P2P WebRTC 和局域网
- **10 分钟生存挑战**：9:00 地图 Boss 登场，击败即胜利
- **技能进化系统**：四段进化（Lv1/3/5/8），每段有质变效果
- **32 件装备**：16 件通用 + 每角色 3-7 件专属，按拾取角色筛选
- **局外成长**：天赋树、本地成就、排行榜
- **主机权威联机**：掉线 AI 托管、断线重连保留进度

---

## 🚀 快速开始

### 环境要求

- Godot 4.7.2+
- Git 2.45+
- Windows 10/11（手柄支持 Xbox 布局）

### 运行游戏

```bash
# 克隆仓库
git clone <repository-url>
cd Survive

# 在 Godot 中打开项目
godot --path . --editor

# 或直接运行菜单（F5）
godot --path . scenes/menu.tscn
```

### 操作方式

**键盘鼠标**：
- WASD 移动 · 空格/Q/E/R/F/C 六个技能 · Shift 闪避
- 1/2/3 选升级 · T 自动施放 · Esc 菜单

**手柄（Xbox 布局）**：
- 左摇杆移动 · A 闪避 · X/Y/B/LB/RB/RT 技能
- Back 自动施放 · Start 菜单

### 命令行启动

```bash
# 单人游戏
godot --path . scenes/menu.tscn -- --host --name=玩家1 --char=cleric --map=dark_forest

# 局域网联机（主机）
godot --path . scenes/menu.tscn -- --host --name=玩家1 --char=iron_guard

# 局域网联机（客户端）
godot --path . scenes/menu.tscn -- --join=192.168.1.100 --name=玩家2 --char=shadow_walker
```

---

## 🎯 游戏内容

### 角色（4 个）

| 角色 | 定位 | 生命 | 核心机制 |
|---|---|---|---|
| 铁卫 | 近战坦克 | 1200 | 格挡、怒气、嘲讽聚怪、击退 |
| 元素术士 | 远程法师 | 900 | 燃烧→爆燃、减速→碎裂 |
| 影行者 | 刺客 | 760 | 死亡标记放大伤害，刷新影步 |
| 牧师 | 辅助 | 1000 | 治疗、护盾、祝福、复活 |

### 地图（4 张）与 Boss

| 地图 | 环境危险 | Boss | 特点 |
|---|---|---|---|
| 灰烬王城 | 余烬坠落 | 腐化骑士 | 冲锋、召唤精英、狂暴 |
| 霜冻冰原 | 寒霜地带 | 霜冻巫妖 | 冰弹齐射、冰雨、保持距离 |
| 沙海遗迹 | 流沙塌陷 | 沙之巨像 | 震地、钻地突袭、沙暴 |
| 幽暗森林 | 毒孢子云 | 腐木树人 | 根须突刺、毒孢子、再生 |

所有 Boss 三阶段（60% / 30% 切换）+ 随机词缀：狂暴、坚韧、召唤、爆裂

### 装备与成长

- **32 件装备**：每人最多 8 件，满了改掉治疗球
- **9 种精英词缀**：传送、吸血、迅捷、装甲、爆裂、再生、冰霜、燃烧、巨型
- **天赋树**：每个角色 6 个通用 + 1 个专属天赋
- **本地成就**：22 个（角色/地图通关、击杀、技能进化、装备、Boss 词缀、联机等）

---

## 🌐 联机模式

### P2P 联机（WebRTC）

- **无需服务器**：房主生成邀请码，好友发回回应码即可连接
- **跨网络**：不在同一网络也能玩，数据加密直连
- **可选 TURN 中转**：在 `ice_servers.json` 配置（不进仓库）
- **注意**：双方都在对称 NAT 后面且无 TURN 时可能连接失败，改用 Tailscale + 局域网模式

### 局域网联机（ENet）

- 输入主机 IP 直连，UDP 端口默认 24570
- 支持 2-4 人

### 联机特性

- **主机权威**：主机运行完整模拟，客户端预测自己的移动
- **掉线托管**：AI 机器人自动接管，断线重连保留进度
- **共享等级**：每个玩家各自三选一
- **地图同步**：客户端地图不一致时自动换图重进
- **天赋校验**：客户端天赋随握手发送，主机按上限校验

---

## 🎨 视觉与音频

### 美术

- **平滑中模美术**：Blender 程序化生成，顶点色，附 .blend 源文件
- **顶点动画**：角色肢体动作、敌人/Boss/地图零件动画
- **特效**：技能 VFX、伤害数字、命中停顿、屏幕震动、溶解死亡、冲击波 Shader
- **程序化地面**：按地图切换石板/雪地/沙地/林地主题

### 音频

- **音乐**：每张地图 3 首（探索/战斗/Boss），MIDI 作曲 + FluidSynth 渲染
- **音效**：程序化生成（已替换 Kenney 素材）
- **工具**：`tools/audio/compose_music.py` 重新渲染音乐

---

## 🛠️ 技术架构

### 核心系统

- **AbilitySystem / Skill / SkillContext**：技能与冷却，可单元测试
- **CharacterStats / StatusEffects / Reactions**：属性、状态效果、元素反应
- **CharacterCatalog / MapCatalog / Talents / SaveData**：数据驱动的角色、地图、天赋与存档
- **MapBase / MapLayouts**：地图搭建、主题、环境危险
- **Boss**：三阶段 + 技能组合 + 词缀

### 工具链

```bash
# 生成全部模型（Blender 路径 D:/Software/Blender/blender.exe）
python tools/blender/build_models.py

# 音乐作曲与渲染（MIDI → FluidSynth + GeneralUser GS → ogg）
python tools/audio/compose_music.py

# UI 贴图生成
python tools/ui/generate_theme.py
```

---

## 🧪 测试

### 单元测试

```bash
# 运行所有单元测试（83 个）
godot --headless --path . --script res://tests/run_all_tests.gd
```

### 模拟测试

```bash
# 第 1 分钟升级测试（升级 4-6 次）
godot --headless --fixed-fps 60 --path . --script res://tests/sim_first_minute.gd

# 完整 10 分钟对局
godot --headless --fixed-fps 60 --path . --script res://tests/sim_full_run.gd -- --char=shadow_walker --map=sand_ruins --seed=3

# Boss 专项测试
godot --headless --fixed-fps 60 --path . --script res://tests/sim_boss.gd -- --map=frost_wastes --affix=berserk

# 批量平衡测试（并行多局汇总胜率）
python tests/sim_batch.py --chars iron_guard,elementalist,shadow_walker,cleric --seeds 11-22 --jobs 24
```

### 联机测试

```bash
# 联机烟雾测试（掉线重连，--p2p 改走 WebRTC）
python tests/net_smoke.py --seconds 60 --host-map=ash_citadel --p2p

# 单进程 P2P 握手测试
godot --path . --script res://tests/p2p_loopback.gd

# 联机压力测试（500 敌人双端）
python tests/net_stress.py --count 500
```

### 性能测试

```bash
# 500 敌人单机压测
godot --path . --script res://tests/stress_m1_500.gd -- --count=500
```

### 界面截图

```bash
# 生成发布展示截图（需真实渲染）
godot --path . --script res://tests/release_showcase.gd
```

---

## 📊 性能与平衡

### 性能指标

- **500 敌人单机**：平均 396 FPS，1% low 105
- **500 敌人联机**：主机中位数 202 FPS，客户端 240 FPS，客户端下行约 54 KB/s

### 数值平衡（机器人 + 自动施放，灰烬王城，12 个种子）

| 角色 | 胜率 |
|---|---|
| 铁卫 | 9/11（1 局机器人没去打 Boss 超时） |
| 元素术士 | 12/12 |
| 影行者 | 9/12 |
| 牧师 | 12/12 |

定位是爽游，胜率高可以接受。平衡只拉高明显落后的角色，不削弱强势角色。

---

## 📦 设置与发布

### 游戏设置

- 音量、伤害数字、震屏、改键
- 画质（低/中/高）、全屏、垂直同步、帧率上限

### 存档与崩溃日志

- **存档**：`user://save.json`，版本迁移，损坏时备份为 `.corrupt`
- **崩溃日志**：`user://crash_reports/`（只在本机，不上传）
- **成就**：本地存档，不依赖 Steam

---

## 📖 技术文档

| 文档 | 内容 |
|---|---|
| [技术文档索引](docs/00_TECHNICAL_DOCUMENT_INDEX.md) | 文档导航和关系 |
| [技术栈决策](docs/01_TECHNOLOGY_STACK_DECISION.md) | 为什么选择 Godot？技术对比 |
| [联机架构](docs/02_MULTIPLAYER_ARCHITECTURE_DESIGN.md) | 1-4 人主机权威网络设计 |
| [游戏架构](docs/03_GAMEPLAY_TECHNICAL_ARCHITECTURE.md) | 模块划分、数据驱动、战斗规则 |
| [性能架构](docs/04_PERFORMANCE_AND_ENTITY_ARCHITECTURE.md) | 大量敌人实现方案 |
| [开发路线图](docs/07_DEVELOPMENT_PHASES_ROADMAP.md) | 已完成里程碑总结 |
| [技术风险](docs/09_TECHNICAL_RISK_REGISTER.md) | 风险识别与应对结果 |

完整设计文档：[裂界清扫者_设计文档集_v0.3/](裂界清扫者_设计文档集_v0.3/)

---

## ⚠️ 已知限制

### P2P 联机

- **无法打通的情况**：双方都在对称 NAT 后面（部分运营商 NAT、手机热点）时没有 TURN 中转会连接失败，此时改用 Tailscale 等虚拟局域网 + 局域网模式
- **平台支持**：`addons/webrtc_native` 只打包了 Windows x64，其他平台需要从 webrtc-native 1.2.1 补对应库

### 联机缺口

- 没有主机迁移（房主退出即结束）
- 队友特效不能调透明度
- 没有延迟显示
- 没做 4 人 1000 敌人压测

### 其他

- **无 Steam 集成**：成就只有本地版；在线排行榜需要服务器（本轮跳过）
- **辅助功能**：没有色盲模式等选项
- **机器人 AI**：会躲预警圈、投射物和冲锋，有目标优先级；偶尔会在 Boss 登场后不去接战
- **像素字体**：非 12 倍数字号（14/16/18）笔画略粗细不均

---

## 🤝 开发信息

- **开发者**：[@lenovo-li](https://github.com/lenovo-li)
- **引擎**：Godot 4.7.2 (MIT)
- **开发时间线**：M1-M5（单人灰盒 → 联机原型 → 美化扩展 → 内容扩展 → 打磨）→ 发布准备

---

## 📜 许可证

- **游戏代码**：待定（发布前决定）
- **Godot 引擎**：[MIT License](https://godotengine.org/license/)
- **第三方资源**：见 [third_party_licenses/](third_party_licenses/)

### 使用的第三方资源

- Kenney Impact Sounds / Particle Pack（CC0）
- Fusion Pixel Font（SIL OFL 1.1）

---

## 🎖️ 致谢

**参考**：Vampire Survivors（玩法）、Hades（技能进化）

本项目使用 **Godot 4.7.2** 开发。美术模型、音乐、代码为原创。

---

**当前状态**：发布准备 | 详见 [PROGRESS.md](PROGRESS.md)
