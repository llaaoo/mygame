# 📚 项目文档索引

> 版本: v1.5 | 最后更新: 2026-05-23

---

## 文档层级

```
RUNTIME_TOPOLOGY.md (宪法 — 系统边界)
    │
    ├── COMBAT_CONTRACTS.md (战斗内部契约)
    ├── WORLD_CONTRACTS.md (世界内部契约)
    └── skill_architecture.md (内容生产方式)
```

每份文档回答不同层级的问题。从上往下读，逐层深入。

---

## 文档概要

### [RUNTIME_TOPOLOGY.md](./RUNTIME_TOPOLOGY.md)

**回答的问题**: 五大 Runtime 如何共存不互噬？

**核心内容**:
- 五大 Runtime 边界（Combat / World / Simulation / UI / Save）
- CommandBus 跨 Runtime 异步通信
- 世界激活三级模型（Loaded / Dormant / Abstracted）
- 停止线：不再扩系统，只验证内容能力
- 文件结构总览

**何时阅读**: 新人入职第一天。系统设计决策时。

---

### [COMBAT_CONTRACTS.md](./COMBAT_CONTRACTS.md)

**回答的问题**: 伤害怎么算？事件怎么发？状态怎么叠？

**核心内容**:
- 12 条契约覆盖战斗全链路
- CombatExecutor 唯一世界写入口
- Modifier 四阶段管线（FLAT→MULTIPLY→OVERRIDE→FINAL）
- 阶段机转移规则 + 事件-阶段映射
- Status/Buff 身份、叠加、DOT、Combat→Status 闭环
- 伤害全链路唯一路径
- 反模式速查 + 扩展指南

**何时阅读**: 修改战斗逻辑时。新增 Modifier/Condition/TriggeredEffect 前。

---

### [WORLD_CONTRACTS.md](./WORLD_CONTRACTS.md)

**回答的问题**: 世界怎么反应？表面怎么传播？MapObject 怎么做？

**核心内容**:
- 9 条契约覆盖世界模拟
- MapObject 四接口（Damageable / Interactable / Persistent / Taggable）
- SurfaceReaction 数据驱动规则（7 条默认反应）
- SurfaceManager 外观 + entity-surface 桥接
- PropagationScheduler BFS 队列（MAX_DEPTH=4）
- WorldSpatialIndex 统一空间查询
- WorldState 是真实状态，SceneTree 是表现
- 交互密度三层分区

**何时阅读**: 新增表面状态/ReactionRule 时。实现 MapObject 子类时。

---

### [skill_architecture.md](./skill_architecture.md)

**回答的问题**: 新增一个技能要改几个文件？

**核心内容**:
- Skill = Data Composition（Archetype + Payload + Visual）
- Entity Archetype 收敛（2 个 Scene 覆盖所有投射物/AoE）
- 视觉层独立（ProjectileVisualData / AOEVisualData Resource）
- Data-Driven 原则：新增技能 = 创建 .tres，零代码
- 发展阶段路线图（当前阶段 1：Enum + 半数据驱动）
- 四大后续方向

**何时阅读**: 新增技能前。设计新技能类型时。理解"Scene ≠ 技能身份"原则时。

---

## 快速导航

| 想做什么 | 读哪个 |
|---------|--------|
| 理解系统边界 | RUNTIME_TOPOLOGY.md |
| 新增技能 | skill_architecture.md → COMBAT_CONTRACTS.md 扩展指南 |
| 新增 Modifier/Condition | COMBAT_CONTRACTS.md 扩展指南 |
| 新增表面状态 | WORLD_CONTRACTS.md CONTRACT 4 |
| 新增 MapObject | WORLD_CONTRACTS.md 扩展指南 |
| 新增状态效果 | COMBAT_CONTRACTS.md CONTRACT 11 |
| 修复战斗 Bug | COMBAT_CONTRACTS.md 反模式速查 |
| 修复世界 Bug | WORLD_CONTRACTS.md 反模式速查 |
| 理解数据驱动原则 | skill_architecture.md 核心原则 |

---

## 架构版本历史

| 版本 | 日期 | 主要变更 |
|------|------|---------|
| v1.0 | 2025-07 | 三份核心契约 + RUNTIME_TOPOLOGY 创立 |
| v1.3 | 2026-05 | Entity Archetype 收敛，Scene ≠ 技能身份 |
| v1.4 | 2026-05 | Status/Buff Runtime（DOT/叠加/减速/状态查询） |
| v1.5 | 2026-05 | Surface Runtime + MapObject + 油桶连锁验证 |
