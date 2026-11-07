# 📚 项目文档索引

> 版本: v3.1 | 最后更新: 2026-11-07

---

当前阅读入口：[战斗、探索与鼠标整备](CONTROL_SCHEME.md)、[技能能力迁移与新键位](LEGACY_SKILL_INTEGRATION.md)、[项目使用审计](PROJECT_USAGE_AUDIT.md)、[灰河谷首玩验证](GRAYRIVER_FIRST30.md)、[架构边界](ARCHITECTURE.md)。下方早期分析与各轮交付记录含历史范围，不能当作当前接入清单。

## 文档层级

```
PROJECT_ANALYSIS.md (历史项目分析 — 当前使用情况见PROJECT_USAGE_AUDIT.md)
    │
    ├── PROJECT_IMPROVEMENTS.md (当前改进点 — 已完成链路 + 剩余工作)
    ├── CODE_REVIEW_2026_11_04.md (当前代码审查 — 已复现边界问题、重构顺序与验收)
    ├── REFACTOR_PROGRESS.md (A—D重构验收 — 事务、状态、区域、内容、组件、测试与CI)
    │
    ├── EXPLORATION_COMBINATION_DESIGN.md (当前方向 — 探索与条件组合战斗方案)
    ├── FIVE_ELEMENT_IMPLEMENTATION.md (当前交付 — 七批实现、实际场景、部分消费、敌人反馈与实验记录)
    ├── REGION_CONTENT_EXPANSION.md (最新玩法内容 — 三处多解遭遇、永久返营捷径、实地记录与狱中复核委托)
    ├── PLAYTEST_REVIEW_2026_11_05.md (章节试玩 — 通关与冷启动复核、近战/组合收益、捷径回报及操作提示问题)
    ├── PLAYTEST_FIXES.md (试玩迭代 — 当前动作反馈、双向检修通路、本区无奖励试战、教学与战斗对照)
    ├── SURVIVAL_EXPEDITION.md (远征生存 — 饮食饮水、疲劳休整、借火烹饪、水质、采集再生与兼容)
    ├── ALCHEMY_REPAIR.md (多解支线 — 即时检修、图纸与部件、永久材料回收与桌面试玩)
    ├── RPG_ATTRIBUTES.md (属性成长 — 有效主属性、施法准备、环境耐受、任务处理方式与扩展边界)
    ├── SYSTEM_CONTENT_READINESS.md (当前系统检查 — 可扩内容、校验缺口、世界条件、敌人配置与扩充顺序)
    ├── VISUAL_UI_POLISH.md (画面与反馈 — 元素特效、法阵/恩赐寿命、镜头、技能栏及响应式配置页)
    ├── FOUR_ELEMENT_ATTUNEMENT.md (最新扩充 — 地面/材料准备、流息与毒契、持续防护与主动消费)
    ├── ELEMENT_FAMILY_DESIGN.md (最新分类 — 四类基础元素，凝霜并入水系，形态与归属分开)
    ├── EMERGENT_CASTING_DESIGN.md (元素基线 — 火水雷毒与水系凝霜、法术/Buff/装备交叉、现有介质链与后续顺序)
    ├── CONDITIONAL_COMBAT_TECHNICAL_PLAN.md (技术落地 — 架构能力核对、组件边界与迭代批次)
    ├── FIRE_SIGIL_PROTOTYPE.md (已实现原型 — 火阵＋火花触发火球、试玩和测试)
    ├── BUFF_CASTING_DESIGN.md (恩赐取舍 — 持续收益、资格、保留增益、主动消费与材料联动)
    ├── OUTWARD_INTERACTION_REVIEW.md (当前迭代准则 — 复用工具、空间条件、用途转换与世界反馈)
    ├── CASTING_MATERIALS_DESIGN.md (当前实装 — 法术联动、施法材料、营地加工与世界机关)
    ├── SPELL_BUFF_EQUIPMENT_ITERATION.md (当前联动扩充 — 残魂、层数Buff、净化、固定构筑装备)
    ├── MVP_RELEASE.md (当前可运行版本 — 九区域、24法术组合规则、回响与毒性、七种材料、营地委托、世界交互与验证)
    ├── ROGUELITE_PIVOT_PLAN.md (历史方向 — roguelite 转型与试验场参考)
    ├── MAP_GENERATION.md (地图生成 — seed、模板、布局约束与扩展方式)
    │
    ├── ARCHITECTURE.md (当前职责、所有权与请求/查询/事实边界)
    │       │
    │       ├── COMBAT_CONTRACTS.md (战斗内部 12 条契约)
    │       ├── WORLD_CONTRACTS.md (世界内部 9 条契约)
    │       ├── PHYSICS_LAYERS.md (物理层 11 层标准)
    │       ├── skill_architecture.md (技能内容生产方式)
    │       └── equipment_system.md (装备、词缀、套装与存档)
    │
    └── RUNTIME_TOPOLOGY.md (运行时拓扑 — 时钟、事务、区域作用域与持久化)
```

每份文档回答不同层级的问题。从上往下读，逐层深入。

> 当前设计重点：探索获得知识、法术组合规则、技能与装备；自由搭配；世界反馈；优先完善条件组合。后续玩法规划先阅读 `EXPLORATION_COMBINATION_DESIGN.md`。该文档包含已落地的MVP方向与后续产品规划；实现范围见MVP_RELEASE，当前架构以ARCHITECTURE和REFACTOR_PROGRESS为准。旧房间制roguelite保留作战斗试验场。

> 历史阶段顺序：技能用途与世界条件 → Buff层数、防护与兑现 → 装备构筑。魂术、层数消费、净化/保护、4件固定装备已接通，详见`SPELL_BUFF_EQUIPMENT_ITERATION.md`；该阶段之后生存与真实库存已继续接入，当前范围见RPG_FOUNDATION、ITEM_ACTIONS_AND_REACTIONS及PROJECT_USAGE_AUDIT。

> 默认入口已更新为 `grayriver.tscn`（灰河谷），原 `mvp.tscn` 保留为监狱验证场；灰河谷交付与验证边界见 `GRAYRIVER_FRONTIER.md`、`GRAYRIVER_PLAYTEST.md`，原验证场见 `MVP_RELEASE.md`；旧 `main.tscn` 保留为回归场景。启动与操作见根目录 README。

---

## 文档概要

### [RPG_ATTRIBUTES.md](./RPG_ATTRIBUTES.md)

力量、智力、敏捷、耐力对战斗、危险环境和任务的实际作用；加点预览、装备/Buff贡献、狱中复核可选交付、存档兼容与下一阶段用途。

---

### [PLAYTEST_REVIEW_2026_11_05.md](./PLAYTEST_REVIEW_2026_11_05.md)

正常新存档、主动敌人AI和真实键鼠输入辅助完成九区域与首领；记录已复现问题、组合投入回报、捷径用途、保存恢复和下一轮优化顺序，并明确试玩覆盖边界。

---

### [ELEMENT_FAMILY_DESIGN.md](./ELEMENT_FAMILY_DESIGN.md)

最新元素分类：水、凝霜归入同一水系，四类基础元素；解释形态差异、兼容迁移及后续内容原则。

---

### [FIVE_ELEMENT_IMPLEMENTATION.md](./FIVE_ELEMENT_IMPLEMENTATION.md)

元素构筑试玩当前交付，包含七批实现、能力审计、操作路线、恩赐取舍、阀门与实际地面条件、敌人局部移动、配置记录和验证边界。

---

### [EMERGENT_CASTING_DESIGN.md](./EMERGENT_CASTING_DESIGN.md)

先锚定火、水、雷、毒四类基础元素，凝霜并入水系；以法术形式、Buff保留/消费、材料、装备条件与环境组成可推导的玩法。列清现有水引介质链、后续候选、实施顺序和验收标准。

---

### [EXISTING_SPELL_INTERACTION_PLAN.md](./EXISTING_SPELL_INTERACTION_PLAN.md)

当前优先：深化现有工具的多用途、条件连锁与操作空间；基础火花性质复用、震荡碎冰、定点水引/树脂/毒雾、可复用环境规则与验证。

---

### [SPELL_BUFF_EQUIPMENT_ITERATION.md](./SPELL_BUFF_EQUIPMENT_ITERATION.md)

2026-11-05技能→Buff→装备联动：残魂条件、蕴魂分层兑现、净化与防护、固定构筑装备、实际玩法和验证边界。

---

### [CODE_REVIEW_2026_11_04.md](./CODE_REVIEW_2026_11_04.md)

基于当前main的代码审查，记录存档恢复、施法意图/冷却、Buff事务、命中语义和预览重复计算的复现结果，以及分批重构建议；实施状态见文首和 [重构进展](./REFACTOR_PROGRESS.md)。

---

### [REFACTOR_PROGRESS.md](./REFACTOR_PROGRESS.md)

A—D批次实现与验收，包含施法/状态事务、命中结果、周期边界、共享区域生命周期、组件和内容拆分、独立fixture与统一runner/CI。

---

### [BUFF_CASTING_DESIGN.md](./BUFF_CASTING_DESIGN.md)

对照Outward的Discipline/Rage与恩赐消费，定义普通施法保留、Shift显式消费的选择，以及实际形态、材料叠加和资源回滚。

---

### [OUTWARD_INTERACTION_REVIEW.md](./OUTWARD_INTERACTION_REVIEW.md)

核对Outward公开技能数据，解释本轮如何把现有法阵、准备、近战、材料与地面连接起来，以及验证规则和继续迭代的判断标准。

---

### [MVP_RELEASE.md](./MVP_RELEASE.md)

当前探索 MVP 的区域、技能组合、进度与存档语义、模块分工及验证限制。先阅读根目录 README 试玩，再对照本文开展后续迭代。

---

### [CASTING_MATERIALS_DESIGN.md](./CASTING_MATERIALS_DESIGN.md)

当前法术联动、回响连续准备、七种施法素材、加工与消耗规则、地面反应和六处法术机关；列出首版实现范围与后续生存制造边界。

---

### [CONDITIONAL_COMBAT_TECHNICAL_PLAN.md](./CONDITIONAL_COMBAT_TECHNICAL_PLAN.md)

**回答的问题**：当前架构能否支持探索与条件组合设计，需要新增和迭代哪些能力？

**核心内容**：
- 基于当前代码的覆盖矩阵，区分可复用、部分满足和缺失。
- 法术组合规则解析、个人动作会话、法阵、武器准备、防御、能力知识与固定奖励的归属。
- 现有施法、Buff、事件、装备、世界状态、区域与存档组件的改造清单。
- 早期覆盖矩阵、分批交付顺序与后续设计边界；公共技能/状态/区域重构已落地，实际接口与验收见REFACTOR_PROGRESS。

**何时阅读**：实施当前方案、修改公共接口或评估开发依赖之前。

---

### [EXPLORATION_COMBINATION_DESIGN.md](./EXPLORATION_COMBINATION_DESIGN.md)

**回答的问题**：探索、自由成长和条件组合战斗如何形成一个可实现的 2D 动作 RPG？

**核心内容**：
- 探索奖励、已学能力、装备配置和临时条件的边界。
- 法阵与武器附魔两套体系，六个主动法术组合规则及判定、消耗、中断、冲突规则。
- Buff、世界反应、敌人窗口、装备取舍、知识日志和存档设计。
- 首个监狱区域样板、对现有代码的复用方式、实施顺序与验收门槛。

**何时阅读**：当前产品设计、玩法实现、内容扩展与优先级讨论之前。文中规划不等于已有实现。

---

### [PROJECT_ANALYSIS.md](./PROJECT_ANALYSIS.md)

**回答的问题**: 项目整体状态如何？每个文件做什么？接下来该做什么？

**核心内容**:
- 完整目录树（含每个子目录和文件的用途说明）
- 六层每层所有文件的详细功能描述
- 架构优势与当前问题评估
- 分级迭代建议（P0/P1/P2 优先级 + 停止线）

**何时阅读**: 新人入职、架构评审、迭代规划前。

---

### [PROJECT_IMPROVEMENTS.md](./PROJECT_IMPROVEMENTS.md)

**回答的问题**: 当前哪些架构改进已经完成？还剩哪些文档、验证和工程卫生工作？

**核心内容**:
- P0/P1/P2 完成进度
- 火球油桶、陷阱伤害、MapObject 重生三条已完成链路
- 当前文档与测试待同步项
- 后续实施顺序和停止线

**何时阅读**: 接续改进工作、判断当前代码与旧文档冲突时。

---

### [ROGUELITE_PIVOT_PLAN.md](./ROGUELITE_PIVOT_PLAN.md)

**回答的问题**: 项目如何从传统 ARPG 转为 roguelite？哪些系统保留、改造、冻结？第一阶段怎么落地？

**核心内容**:
- 新游戏循环：营地 → 地牢 run → 房间遭遇 → 三选一奖励 → Boss → 结算。
- 保留 CombatExecutor / SkillData / MapObject / Surface / Enemy / UI 等核心资产。
- 冻结 NPC 日程、传统任务和大地图持久化；装备改造为高影响的局内构筑系统。
- 新增 `run / rooms / rewards` 三个模块边界。
- 地图生成实现见 `MAP_GENERATION.md`，包含可复现 seed、模板池和可达性约束。
- 第一阶段验收标准：最小可玩 run 闭环、复用资产验证、构筑感验证。

**何时阅读**: 理解历史转型、现有 run 流程或维护可选房间试验场时。当前产品规划优先阅读 `EXPLORATION_COMBINATION_DESIGN.md`。

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

### [equipment_system.md](./equipment_system.md)

**回答的问题**: 如何配置装备、词缀、套装阈值、战斗修正、掉落和装备存档？

**何时阅读**: 新增装备、调整构筑平衡或修改装备存档时。

---

## 快速导航

| 想做什么 | 读哪个 |
|---------|--------|
| 了解项目全貌 | PROJECT_ANALYSIS.md |
| 了解当前产品方向与条件组合方案 | EXPLORATION_COMBINATION_DESIGN.md |
| 用现有法术、材料、环境和装备形成可推导的变化 | [EMERGENT_CASTING_DESIGN.md](./EMERGENT_CASTING_DESIGN.md) |
| 运行当前 MVP、了解已实现内容与验证边界 | MVP_RELEASE.md |
| 判断架构是否满足新方案、安排技术迭代 | CONDITIONAL_COMBAT_TECHNICAL_PLAN.md |
| 试玩/验证已经实现的火阵组合 | FIRE_SIGIL_PROTOTYPE.md |
| 查看后续施法素材与生存制造设计 | CASTING_MATERIALS_DESIGN.md |
| 了解历史 roguelite 转型与试验场 | ROGUELITE_PIVOT_PLAN.md |
| 查看当前已完成/待改进项 | PROJECT_IMPROVEMENTS.md |
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
| 判断文档是否过时 | PROJECT_IMPROVEMENTS.md |

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
| v2.6 | 2026-05 | P1.4 完成 — COMBAT_CONTRACTS.md / skill_architecture.md / RUNTIME_TOPOLOGY.md 路径同步至实际目录结构 |
| v2.7 | 2026-05 | 文档校准至 2026-05-30 当前状态 — P0/P1 主链完成，三条冒烟链已确认，PROJECT_IMPROVEMENTS.md 纳入索引 |
| v3.0 | 2026-11-04 | 新增探索与条件组合战斗设计基线；旧 roguelite 规划保留为历史与试验场参考，尚未改变玩法代码 |

- [现场组合五轮迭代](FIELD_COMBINATION_ITERATION.md)
- [本地试玩与操作](LOCAL_PLAYTEST.md)
- [首章实际试玩记录](FIELD_CHAPTER_PLAYTEST.md)

- [灰河谷：地区设计与建设](GRAYRIVER_FRONTIER.md)
- [灰河谷：正常角色试玩与交付边界](GRAYRIVER_PLAYTEST.md)

- [共用角色模板与人形敌人](SHARED_CHARACTERS.md)

- [灰河谷装备与战利品：所见即所得、运料支线与持久化](GRAYRIVER_LOOT.md)

2026-11-07：新增 [物品动作、喷洒与真实来源](./ITEM_ACTIONS_AND_REACTIONS.md)，描述共用物品执行器、逐瓶余量、武器涂层、明确来源与临时能量的职责和验证。
