# 裂界清扫者 (Rift Cleansers)

> 1-4人在线合作肉鸽动作游戏 | Co-op Roguelike Action Game

[![Godot](https://img.shields.io/badge/Godot-4.7.2-blue.svg)](https://godotengine.org/)
[![License](https://img.shields.io/badge/license-TBD-lightgrey.svg)](LICENSE)

---

## 🎮 游戏简介

多个时代和文明被"裂界"撕碎并拼接。裂界会复制生物、机械和记忆，制造不断增殖的怪物。玩家隶属于裂界清扫局，进入即将崩溃的世界碎片，从弱小战士成长为移动天灾。

### 核心特色

- **1-4人合作**：单人完整体验，多人协作增强
- **技能进化**：每个技能1/3/5/8级明显质变
- **元素反应**：火冰雷风毒暗影可自组合、可跨玩家触发
- **敌人功能化**：治疗、加盾、冲锋、分割地图、吞噬元素
- **主机权威联机**：掉线重连、延迟补偿、状态同步

---

## 🛠️ 技术栈

- **引擎**：Godot 4.7.2 (MIT)
- **语言**：GDScript（强制类型标注）
- **网络**：ENet（开发期）→ GodotSteam + Steam Relay（发布版）
- **架构**：主机权威 Listen Server
- **渲染**：低多边形3D，Forward+渲染器
- **平台**：Windows 10/11，Steam首发

---

## 📂 项目结构

```
project/
├─ docs/                    # 技术文档（架构、联机、性能、路线图）
├─ addons/                  # 第三方插件（GodotSteam等）
├─ assets/                  # 美术资源（模型、纹理、音频）
├─ core/                    # 核心系统（无Godot依赖）
├─ gameplay/                # 游戏逻辑（战斗、AI、技能）
├─ net/                     # 网络系统（同步、RPC、重连）
├─ presentation/            # 表现层（粒子、音效、UI）
├─ content/                 # 数据驱动配置（.tres Resource）
├─ scenes/                  # Godot场景（.tscn）
├─ tests/                   # 单元测试
└─ third_party_licenses/    # 第三方许可证
```

---

## 🚀 开发路线

当前阶段：**M0 技术试验**（2周）

```
M0: 技术试验 (2周) → 验证1000敌人可行性
  ↓
M1: 10分钟单人灰盒 (4-6周) → 验证核心体验
  ↓
M2: 2人联机原型 (3-4周) → 验证联机架构
  ↓
M3: 垂直切片美术 (8-12周) → 美术提升
  ↓
M4: 1-4人完整联机 (6-8周) → Steam集成
  ↓
M5: 内容扩充 (4-6月) → 4角色、2地图
  ↓
M6: 发布准备 (2-3月) → Early Access
```

详见：[开发阶段路线图](docs/07_DEVELOPMENT_PHASES_ROADMAP.md)

---

## 📖 技术文档

| 文档 | 内容 |
|---|---|
| [技术栈决策](docs/01_TECHNOLOGY_STACK_DECISION.md) | 为什么选择Godot？技术对比与风险分析 |
| [联机架构](docs/02_MULTIPLAYER_ARCHITECTURE_DESIGN.md) | 1-4人主机权威网络设计 |
| [游戏架构](docs/03_GAMEPLAY_TECHNICAL_ARCHITECTURE.md) | 模块划分、数据驱动、战斗规则 |
| [性能架构](docs/04_PERFORMANCE_AND_ENTITY_ARCHITECTURE.md) | 1000-2000敌人实现方案 |
| [技术风险](docs/09_TECHNICAL_RISK_REGISTER.md) | 风险识别与应对计划 |

完整索引：[技术文档导航](docs/00_TECHNICAL_DOCUMENT_INDEX.md)

---

## 🎯 MVP范围（Early Access）

- ✅ **4个角色**：铁卫、元素术士、机械师、影行者
- ✅ **24-32个技能**：每个角色6-8个，四段进化
- ✅ **2张地图**：灰烬王城、生体工厂
- ✅ **20+敌人**：普通、功能、精英、2个Boss
- ✅ **25-40件装备**：改变规则而非微小数值
- ✅ **1-4人联机**：Steam好友邀请、掉线重连
- ✅ **手柄支持**：完整映射和振动

---

## 🔧 本地开发

### 环境要求

- Godot 4.7.2+
- Git 2.45+
- Git LFS 3.5+
- Blender 4.2 LTS（美术资源）

### 运行游戏

```bash
# 克隆仓库
git clone https://github.com/lenovo-li/rift-cleansers.git
cd rift-cleansers

# 使用Godot打开项目
godot --path . --editor

# 或直接运行（F5）
godot --path . res://scenes/main.tscn
```

### 性能测试

```bash
# 1000敌人压力测试
godot --path . --script tests/stress_test_1000.gd
```

---

## 🤝 贡献指南

当前项目处于**早期开发阶段**，暂不接受外部贡献。

待M2（2人联机原型）完成后将开放Issue反馈。

---

## 📜 许可证

- **游戏代码**：待定（发布前决定）
- **Godot引擎**：[MIT License](https://godotengine.org/license/)
- **第三方资源**：见 [third_party_licenses/](third_party_licenses/)

---

## 📞 联系方式

- **GitHub Issues**：[提交Bug或建议](https://github.com/lenovo-li/rift-cleansers/issues)
- **开发者**：[@lenovo-li](https://github.com/lenovo-li)

---

## 🎖️ 致谢

- [Godot Engine](https://godotengine.org/) - MIT开源游戏引擎
- [GodotSteam](https://godotsteam.com/) - Steamworks集成
- [Kenney Assets](https://kenney.nl/) - CC0美术资源
- [Quaternius](https://quaternius.com/) - CC0低模资源

---

**开发中** | 2026-09-27 启动
