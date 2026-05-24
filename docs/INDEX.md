# 📚 项目文档索引

> 版本: v2.4 | 最后更新: 2026-07-14

---

## 文档层级

```
PROJECT_ANALYSIS.md (完整项目分析 — 架构评估 + 文件功能清单 + 迭代建议)
    │
    ├── ARCHITECTURE.md (宪法 — 六层边界)
    │       │
    │       ├── COMBAT_CONTRACTS.md (战斗内部 12 条契约)
    │       ├── WORLD_CONTRACTS.md (世界内部 9 条契约)
    │       ├── PHYSICS_LAYERS.md (物理层 11 层标准)
    │       └── skill_architecture.md (技能内容生产方式)
    │
    └── RUNTIME_TOPOLOGY.md (运行时拓扑 — 五大 Runtime 边界)
```

每份文档回答不同层级的问题。从上往下读，逐层深入。

---

## 文档概要

### [PROJECT_ANALYSIS.md](./PROJECT_ANALYSIS.md)

**回答的问题**: 项目整体状态如何？每个文件做什么？接下来该做什么？

**核心内容**:
- 完整目录树（含每个子目录和文件的用途说明）
- 六层每层所有文件的详细功能描述
- 架构优势与当前问题评估
- 分级迭代建议（P0/P1/P2 优先级 + 停止线）

**何时阅读**: 新人入职、架构评审、迭代规划前。

---

### [ARCHITECTURE.md](./ARCHITECTURE.md)

**回答的问题**: 项目分几层？每层管什么？依赖方向是什么？

**核心内容**:
- 六层边界模型 + NPC 五层架构（WorldTime→Brain→Task→Action→FSM）
- FSM 铁律（只执行，不决策）
- Enemy vs NPC 根本区别（反应式 vs 生活式）
- Action Layer / WorldObject / Quest / NPC Schedule 各系统状态
- Content vs Gameplay 边界 + 停止线

**何时阅读**: 新人入职第一天。任何架构决策前。

---

### [COMBAT_CONTRACTS.md](./COMBAT_CONTRACTS.md)

**回答的问题**: 伤害怎么算？事件怎么发？状态怎么叠？

**何时阅读**: 修改战斗逻辑时。新增 Modifier/Condition/TriggeredEffect 前。

---

### [WORLD_CONTRACTS.md](./WORLD_CONTRACTS.md)

**回答的问题**: 世界怎么反应？表面怎么传播？MapObject 怎么做？

**何时阅读**: 新增表面状态/ReactionRule 时。实现 MapObject 子类时。

---

### [PHYSICS_LAYERS.md](./PHYSICS_LAYERS.md)

**回答的问题**: collision_layer / collision_mask 怎么设？

**何时阅读**: 新增物理节点时。碰撞检测不工作时。

---

### [skill_architecture.md](./skill_architecture.md)

**回答的问题**: 新增一个技能要改几个文件？

**何时阅读**: 新增技能前。理解"Scene ≠ 技能身份"原则时。

---

## 快速导航

| 想做什么 | 读哪个 |
|---------|--------|
| 了解项目全貌 | PROJECT_ANALYSIS.md |
| 理解项目架构 | ARCHITECTURE.md |
| 新增技能 | skill_architecture.md |
| 新增 Modifier/Condition | COMBAT_CONTRACTS.md 扩展指南 |
| 新增表面状态 | WORLD_CONTRACTS.md CONTRACT 4 |
| 新增 WorldObject | ARCHITECTURE.md §五 |
| 新增 NPC 对话 | 查阅 world/object/npc.gd 内注释 |
| 新增 NPC 日程 | ARCHITECTURE.md §一 NPC 五层架构 |
| 新增交互物体 | 查阅 SignalReceiver / Interactable 基类 |
| 设置碰撞层/掩码 | PHYSICS_LAYERS.md |
| 修复战斗 Bug | COMBAT_CONTRACTS.md 反模式速查 |
| 修复世界 Bug | WORLD_CONTRACTS.md 反模式速查 |

---

## 架构版本历史

| 版本 | 日期 | 主要变更 |
|------|------|---------|
| v1.0 | 2025-07 | 三份核心契约 + RUNTIME_TOPOLOGY 创立 |
| v1.3 | 2026-05 | Entity Archetype 收敛，Scene ≠ 技能身份 |
| v1.4 | 2026-05 | Status/Buff Runtime（DOT/叠加/减速/状态查询） |
| v1.5 | 2026-05 | Surface Runtime + MapObject + 油桶连锁验证 |
| v1.6 | 2026-05 | PHYSICS_LAYERS.md — 物理层 11 层标准 |
| v2.0 | 2026-05 | ARCHITECTURE.md — 六层边界模型 + 停止线 |
| v2.1 | 2026-05 | Action Layer ✅ + WorldObject 7 种 ✅ + NPC 对话 ✅ + Dialogue Manager 集成 |
| v2.2 | 2026-05 | Enemy StateChart 迁移 ✅ + Quest 系统设计 + 事件驱动统一架构 |
| v2.3 | 2026-05 | Quest P1-P3 ✅ + NPC Schedule P1 ✅ + NPC 五层架构 + FSM 铁律 + Enemy/NPC 分离 |
| v2.4 | 2026-05 | PROJECT_ANALYSIS.md — 全项目文件功能清单 + 架构评估 + P0/P1/P2 迭代建议 |
| v2.5 | 2026-05 | P0 完成 + P1.1/P1.2/P1.3 完成 — CombatExecutor 权威、CommandBus 路由、Respawn 闭环、SimulationRuntime 收敛、物理层标准化、Action Layer 统一 |
