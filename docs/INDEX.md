# 📚 项目文档索引

> 版本: v2.1 | 最后更新: 2026-05-24

---

## 文档层级

```
ARCHITECTURE.md (宪法 — 六层边界)
    │
    ├── COMBAT_CONTRACTS.md (战斗内部 12 条契约)
    ├── WORLD_CONTRACTS.md (世界内部 9 条契约)
    ├── PHYSICS_LAYERS.md (物理层 11 层标准)
    └── skill_architecture.md (技能内容生产方式)
```

每份文档回答不同层级的问题。从上往下读，逐层深入。

---

## 文档概要

### [ARCHITECTURE.md](./ARCHITECTURE.md)

**回答的问题**: 项目分几层？每层管什么？依赖方向是什么？

**核心内容**:
- 六层边界模型（core / gameplay / entities / world / content / ui）
- 依赖方向铁律
- Action Layer — ✅ 已实现（PlayerAction + poll_actions + try_action）
- WorldObject 体系 — ✅ 已实现（7 种物体 + 交互框架）
- Content vs Gameplay 边界
- 下一阶段优先级

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
| 理解项目架构 | ARCHITECTURE.md |
| 新增技能 | skill_architecture.md |
| 新增 Modifier/Condition | COMBAT_CONTRACTS.md 扩展指南 |
| 新增表面状态 | WORLD_CONTRACTS.md CONTRACT 4 |
| 新增 WorldObject | ARCHITECTURE.md §五 |
| 新增 NPC 对话 | 查阅 world/object/npc.gd 内注释 |
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
