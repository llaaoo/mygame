# ⚔️ Combat Contracts — 确定性战斗运行时契约

> **状态**: 已固化  
> **版本**: 1.5  
> **最后更新**: 2026-05-23  
> **适用范围**: `res://gameplay/abilities/` `res://gameplay/combat/` `res://entities/components/` `res://gameplay/inventory/` `res://gameplay/status/`
> 
> **历史路径对照**: `skills/`→`gameplay/abilities/`, `systems/`→`gameplay/combat/`, `components/`→`entities/components/`, `items/`→`content/items/` + `gameplay/inventory/`

---

## 🏛️ 架构稳定性声明

技能系统已完成完整的「架构硬化」路径（Review → P0副作用收敛 → P1阶段机收敛 → 近战收敛 → 契约法典化）。**12条契约覆盖了战斗系统的全部关键路径，不再需要架构级别的大改。**

后续开发属于以下三类之一：

| 类别 | 定义 | 改动范围 | 示例 |
|------|------|----------|------|
| **纯增量** | 在现有框架内新增实例 | 新建文件 + 注册，核心零改动 | 新投射物技能、新Modifier、新Condition、新Buff |
| **新分支** | 现有框架预留了扩展点 | 加 `match` 分支 + 一个 `_execute_*()` 方法 | 引导/蓄力技能、新 SkillType 枚举值 |
| **新层级** | 需要系统级别的能力 | 新增独立模块，不改现有契约 | 联网 RPC 层、技能进化树、元素反应系统 |

**关键原则**: 永远不会出现"推翻重来"。最坏情况是"加一层"或"开新分支"。

---

## CONTRACT 0: 架构分层（不可逆）

```
数据层 (纯 Resource, 无逻辑)
  SkillData / SkillPool / SkillLoadout / Buff / DamageModifier / Condition
        │
运行时层 (Node, 持有状态)
  SkillInstance / SkillManager / SkillExecutor / CombatExecutor / CombatEventBus
        │
管线层 (纯函数变换)
  DamageModifier.Modify(ctx)  →  四阶段 FLAT→MULTIPLY→OVERRIDE→FINAL
        │
事件层 (观察者)
  CombatEventBus.subscribe()  +  TriggeredEffect (入口+条件+转发)
        │
调试层 (追踪)
  CombatDebugger / CombatTrace / CombatDebugUI
```

**禁止**: 上层直接访问下层内部状态。数据层禁止持有 Node 引用。

---

## CONTRACT 1: CombatExecutor 是唯一世界写入口

### ✅ 合法

```
CombatExecutor.report_hit()        ← Projectile / FlameStorm / 近战
CombatExecutor.report_damage()     ← HealthComponent
CombatExecutor.report_kill()       ← HealthComponent
CombatExecutor.report_cast()       ← SkillExecutor
CombatExecutor.report_bonus_damage() ← TriggeredEffect
CombatExecutor.report_exp_bonus()  ← TriggeredEffect / Enemy._on_died
CombatExecutor.report_heal()            ← HealthComponent
CombatExecutor.report_status_applied()  ← BuffManager
CombatExecutor.report_status_removed()  ← BuffManager
CombatExecutor.check_trigger_cooldown() ← TriggeredEffect
```

### ❌ 禁止

```gdscript
# 禁止任何非 Executor 代码直接:
health.take_damage(x)           # 必须通过 report_hit / report_bonus_damage
stats.add_experience(x)         # 必须通过 report_exp_bonus
CombatEventBus.instance.emit()  # 必须通过 CombatExecutor
target.hp -= x                  # 绝对禁止
```

**唯一例外**: `HealthComponent.take_damage()` 自身（它是伤害接收者，不是发起者）。

---

## CONTRACT 2: Modifier 必须是纯函数

```
input ctx (DamageContext)
    ↓
modify numbers only
    ↓
return (void)
```

### ✅ 合法

- 修改 `ctx.final_damage`
- 修改 `ctx.tags`
- 修改 `ctx.meta`
- 读取 `ctx.caster` 的 `StatsComponent` 属性

### ❌ 禁止

- `emit` 事件
- `spawn` 节点
- 修改 `condition` 状态
- 调用 `take_damage` / `heal`
- 持有可变状态

---

## CONTRACT 3: Condition 必须无副作用

### ✅ 合法

```gdscript
func evaluate(ctx: Dictionary) -> bool:
    return ctx["target"].hp < ctx["target"].max_hp * 0.3
```

### ❌ 禁止

```gdscript
func evaluate(ctx: Dictionary) -> bool:
    ctx["target"].take_damage(1)  # 禁止
    return true
```

Condition 只能回答 `bool`，不能改变世界。

---

## CONTRACT 4: EffectGraph 不允许控制时间

### ✅ 合法节点

| 节点 | 功能 |
|------|------|
| `SequenceNode` | 依次执行子节点 |
| `BranchNode` | if/else 分支 |
| `ConditionGateNode` | 条件门（不满足=跳过） |
| `CallableNode` | 执行 Callable |
| `LogNode` | 调试日志 |
| `EmptyNode` | 终端/占位 |

### ❌ 禁止新增

- `LoopNode` — 循环
- `AsyncNode` / `CoroutineNode` — 异步
- `ParallelNode` — 并行
- `DelayNode` / `WaitNode` — 延迟

**原则**: EffectGraph 描述"当前 tick 做什么"，不拥有时间控制权。时间控制属于 Executor。

---

## CONTRACT 5: EventBus 只允许观察，不允许控制

### ✅ 合法

```gdscript
CombatEventBus.subscribe(ON_KILL, func(ev):
    analytics.record_kill(ev.target)
)
```

### ❌ 禁止

```gdscript
CombatEventBus.subscribe(ON_HIT, func(ev):
    ev.target.hp -= 10  # 禁止直接修改世界
)
```

所有 gameplay mutation 必须通过 CombatExecutor。

---

## CONTRACT 6: 阶段机（不可跳号，可向前跳跃）

### 阶段定义

```
IDLE(0) → INPUT(1) → CONDITION(2) → MODIFIER(3) → EFFECT(4) → EVENT(5) → POST(6) → IDLE(0)
```

### 转移规则

| 规则 | 说明 |
|------|------|
| `to > from` | 允许向前跳跃（某些技能类型跳过 CONDITION） |
| `to == IDLE` | 始终允许（重置） |
| `to == EVENT` | 始终允许（异步触发链） |

### 事件-阶段映射

| 事件 | 允许阶段 |
|------|---------|
| `ON_CAST` | `EVENT` |
| `ON_HIT` | `IDLE`, `EVENT` |
| `ON_DAMAGE` | `IDLE`, `EVENT`, `POST` |
| `ON_KILL` | `IDLE`, `EVENT`, `POST` |
| `ON_HEAL` | `IDLE`, `EVENT`, `POST` |
| `ON_STATUS_*` | `IDLE`, `EFFECT`, `EVENT`, `POST` |
| `ON_DODGE/CRIT` | `IDLE`, `EVENT` |

### 施法完整阶段序列

```
SkillManager._execute()
  ├─ begin_cast_sequence()        → INPUT
  ├─ SkillExecutor.execute()
  │    ├─ enter_phase(IDLE)       → 阶段重置（支持从 EVENT 链中安全调用）
  │    ├─ enter_phase(MODIFIER)   → MODIFIER
  │    ├─ enter_phase(EFFECT)     → EFFECT
  │    │    ├─ PROJECTILE: spawn
  │    │    ├─ BUFF: apply_buff + trace
  │    │    ├─ AOE: spawn
  │    │    └─ DASH: tween + buff_trace
  │    ├─ enter_phase(EVENT)      → EVENT
  │    │    └─ ON_CAST 发射
  │    ├─ enter_phase(POST)       → POST
  │    │    └─ trace store / 冷却记录
  │    └─ enter_phase(IDLE)       → IDLE
```

### 异步命中序列

```
Projectile/近战._on_hit()
  ├─ begin_hit_sequence()         → EVENT  (_chain_count=0)
  │    └─ ON_HIT → ON_DAMAGE → ON_KILL → TriggeredEffect链
  └─ end_hit_sequence()           → IDLE
```

---

## CONTRACT 7: 文件夹所有权

> **路径已在 v2.5 更新**，旧路径见下方注释。

```
res://gameplay/abilities/          ← 旧: res://skills/
  data/       → SkillData .tres (纯数据, 禁止脚本依赖)
  registry/   → SkillPool (ID索引)
  loadout/    → SkillLoadout (槽位映射)
  manager/    → SkillManager (装备/冷却/委托)
  runtime/    → SkillExecutor / SkillInstance / CastContext / DamageContext / Projectile
  archetypes/ → 技能场景 (.tscn + 脚本)  ← 旧: scenes/
  
res://gameplay/combat/             ← 旧: res://systems/
  CombatEvent / CombatEventBus / CombatExecutor / CombatPhase / CombatScope
  TriggeredEffect / conditions/ / effect_graph/ / modifiers/ / debug/

res://entities/components/         ← 旧: res://components/
  HealthComponent / ManaComponent / StatsComponent / CombatComponent
  (纯组件, 不持有技能/战斗逻辑, 通过 Executor 发射事件)

res://gameplay/status/ + res://gameplay/inventory/   ← 旧: res://items/
  Buff / BuffManager / EquipmentManager / Inventory / ItemData
```

### 依赖方向（单向）

```
abilities/archetypes/ ──→  combat/ (CombatExecutor)
abilities/runtime/    ──→  combat/ (CombatExecutor, CombatDebugger)
entities/components/  ──→  combat/ (CombatExecutor)
combat/               ──→  abilities/data/ (SkillData, Buff — 纯数据引用)
entities/             ──→  entities/components/ + abilities/manager/ + combat/
```

**禁止反向依赖**: `combat/` 不能引用 `entities/`。

---

## CONTRACT 8: 标签体系

| 来源 | 标签 | 说明 |
|------|------|------|
| Fireball | `["fire"]` | SkillData.tags |
| FlameStorm | `["fire"]` | SkillData.tags |
| ShadowBolt | `["shadow"]` | SkillData.tags |
| IceArmor | `["ice"]` | SkillData.tags |
| ShadowStep | `["shadow"]` | SkillData.tags |
| IceExplosion | `["ice", "aoe"]` | SkillData.tags |
| 玩家近战 | `["melee", "player"]` | CombatComponent |
| 敌人近战 | `["melee", "enemy"]` | Enemy |

标签用于 `TagMultiplierModifier` 匹配和 `SkillTagCondition` 过滤。

---

## CONTRACT 9: 伤害全链路（唯一路径）

```
伤害来源                → CombatExecutor         → 目标系统
────────────────────────────────────────────────────────────
Projectile._on_body    → begin_hit → report_hit → take_damage → HealthComponent
FlameStorm._on_body    → begin_hit → report_hit → take_damage → HealthComponent
IceExplosion._on_body  → begin_hit → report_hit → take_damage → HealthComponent
CombatComponent (近战) → begin_hit → report_hit → take_damage → HealthComponent
Enemy.perform_attack   → begin_hit → report_hit → take_damage → HealthComponent
OnHitFireBonus         →             report_bonus_damage → take_damage (Executor内部)
TriggeredEffect→Skill  → SkillExecutor.execute() → 完整管线 → trace (独立)

HealthComponent.take_damage
  → report_damage (ON_DAMAGE)
  → report_kill   (ON_KILL, if hp<=0)
    → TriggeredEffect 链执行
```

---

## CONTRACT 10: 防火墙（硬限制）

| 防火墙 | 值 | 位置 |
|--------|-----|------|
| `MAX_EVENT_DEPTH` | 3 | CombatExecutor |
| `MAX_CHAIN_LENGTH` | 5 | CombatExecutor |
| `MAX_DEPTH_HARD` | 5 | CombatEventBus |
| `MAX_GRAPH_DEPTH` | 10 | 预留 |
| `MAX_TRACES` | 50 | CombatDebugger |
| `_phase_violation_limit` | 3 | CombatExecutor |

链式计数在 `begin_hit_sequence()` 中重置为 0（每个命中链独立）。

---

## CONTRACT 11: Buff 生命周期

### 施加
```
BuffManager.apply_buff(buff)
  ├─ buff.apply_to(entity)           ← 修改属性
  ├─ _active_buffs.append(buff)
  ├─ if duration > 0: _buff_remaining[buff] = duration
  ├─ _record_buff_trace("BUFF")      ← trace（若在技能 trace 内）
  └─ CombatExecutor.report_status_applied()  ← ON_STATUS_APPLIED 事件
```

### 自动过期
```
BuffManager._process(delta)
  └─ _expire_buffs(delta)
       for buff in _active_buffs:
         if _buff_remaining[buff] > 0:
           rem -= delta
           if rem <= 0: remove_buff(buff)
```

### 移除
```
BuffManager.remove_buff(buff)
  ├─ buff.remove_from(entity)        ← 还原属性
  ├─ _active_buffs.erase(buff)
  ├─ _buff_remaining.erase(buff)
  ├─ _record_buff_trace("BUFF_REMOVE")  ← trace（必须在事件之前，防泄漏）
  └─ CombatExecutor.report_status_removed()  ← ON_STATUS_REMOVED 事件
       └─ TriggeredEffect 链（如冰甲→冰爆）
```

### 规则
- `duration = 0` 的 Buff 不加入 `_buff_remaining`，永不过期（装备 Buff）
- `_record_buff_trace` 必须在 `report_status_*` **之前**调用，防止事件链中创建的 SkillExecutor trace 被污染
- Buff trace 统一由 BuffManager 记录，SkillExecutor._execute_buff 不再重复记录
- Dash 技能的 Buff trace 在 tween 之前以预览形式记录（因实际施加在 trace 关闭后）

---

## CONTRACT 11.1: Status 身份与叠加

### Buff.status_id
- `status_id` 非空时，Buff 视为"状态"（burning/frozen/poison 等）
- 供 `StatusCondition`、`BuffManager.has_buff()`、AI 查询
- 同 `status_id` 的 Buff 按 `stack_behavior` 处理叠加

### 叠加规则
| 行为 | 效果 |
|------|------|
| `REFRESH` | 移除旧实例，重新施加（默认） |
| `INTENSITY` | 增加层数（上限 `max_stacks`），层数影响 tick 效果 |
| `INDEPENDENT` | 允许多个同 status_id 实例共存 |

### DOT/HOT
- `tick_damage` / `tick_heal` × 层数 = 每 tick 效果
- `tick_damage_scaling` 叠加 StatsComponent.magic_damage 缩放
- `speed_multiplier` 施加时乘入/移除时除出

### Combat→Status 闭环
- `OnHitApplyStatus`: ON_HIT → SkillTagCondition 匹配 → `BuffManager.apply_buff(status)`
- 已验证: 火球命中 → 挂 burning DOT，全程 trace 记录

### Surface→Status 桥接
- `SurfaceManager.tick_entity_surface()` 每 0.5s 检查实体所在格
- `get_entity_buffs(cell)` 映射: burning → burning.tres, frozen → frozen.tres
- 只对尚未拥有该状态的实体施加


## CONTRACT 12: AoE Trace 规则

### ❌ 禁止
```gdscript
# _emit_hit_event 中过早关闭 trace
CombatDebugger.store(trace)   # 第一个命中就关 → 后续命中全部丢失
remove_meta("_combat_trace")  # meta 删除 → 后续命中找不到 trace
```

### ✅ 正确
```gdscript
# _emit_hit_event: 只更新伤害，不关闭 trace
trace.final_damage = maxi(trace.final_damage, damage)

# 超时处理器: 统一关闭 trace
await get_tree().create_timer(lifetime).timeout
CombatDebugger.store(trace)
```

### 原则
AoE 的 trace 生命周期 = AoE 实例的生命周期。命中事件持续记录，超时统一关闭。
多个命中共享一个 trace，`final_damage` 取最大值（单次最高伤害）。

---

## 🔴 反模式速查

| 反模式 | 正确做法 |
|--------|---------|
| `body.take_damage(x)` 裸调 | `CombatExecutor.report_hit(...)` → `take_damage` |
| `stats.add_experience(x)` 裸调 | `CombatExecutor.report_exp_bonus(...)` |
| `CombatEventBus.instance.emit(ev)` 裸调 | `CombatExecutor.report_*()` |
| `Modifier.modify()` 内 `emit/spawn` | 只改 `ctx.final_damage` / `ctx.tags` / `ctx.meta` |
| `Condition.evaluate()` 内修改状态 | 只返回 `bool` |
| EffectGraph 加 `await/timer/loop` | 只在当前 tick 描述 |
| `TriggeredEffect._execute()` 直接写世界 | 通过 `CombatExecutor.report_*()` |
| AoE `_emit_hit_event` 中 `store(trace)+remove_meta` | 只更新 `final_damage`，超时处理器统一 store |
| BuffManager 事件发射在 trace 记录之前 | `_record_buff_trace` 在 `report_status_*` 之前 |

---

## 📐 扩展指南

### 一、纯增量扩展（零架构改动）

以下操作只需新建文件 + 注册，**不需要改动任何核心系统代码**：

#### 新技能（现有四种类型：PROJECTILE / BUFF / AOE / DASH）

```
1. 新建 SkillData .tres  →  res://gameplay/abilities/data/xxx_data.tres
2. 设 archetype           →  "linear_projectile" 或 "persistent_aoe"（复用已有 Archetype）
3. 设 visual 字段         →  projectile_color / scale / aoe_radius / lifetime 等
4. 注册到 SkillPool      →  在 _skill_pool.setup() 中 add_skill()
5. 配置到 Loadout        →  在 SkillLoadout .tres 中映射槽位
```

**不需要新建 Scene 或 .gd 脚本。** Scene = 行为 Archetype（`res://gameplay/abilities/archetypes/`），与技能数量解耦。

- PROJECTILE 类型：设 `archetype = "linear_projectile"`，SkillData 字段注入视觉
- BUFF 类型：新建 `Buff` .tres，设置 `buff_resource` + `buff_duration`（无 Scene）
- AOE 类型：设 `archetype = "persistent_aoe"`，SkillData 字段注入视觉
- DASH 类型：无 Scene，纯 tween 位移，设置 `dash_distance` + `dash_speed`

> 详见 `res://docs/skill_architecture.md` v1.3 Entity Archetype 收敛。

#### 新 Modifier

```
1. 新建 class_name MyModifier extends DamageModifier
2. 在 _init() 中设置 stage（FLAT / MULTIPLY / OVERRIDE / FINAL）
3. 覆写 modify(ctx: DamageContext) → void  （纯函数，只改 ctx 的数字/标签/meta）
4. 在 SkillExecutor._ready() 中 add_modifier(MyModifier.new())
```

#### 新 Condition

```
1. 新建 class_name MyCondition extends Condition
2. 覆写 evaluate(ctx: Dictionary) → bool  （无副作用，只回答 true/false）
3. 在 TriggeredEffect .tres 的 conditions[] 中引用
```

#### 新 TriggeredEffect

```
1. 新建 class_name MyEffect extends TriggeredEffect
2. 设 trigger_type（ON_KILL / ON_HIT / ON_DAMAGE / ON_STATUS_*）
3. 设 conditions[]（可选，AND 逻辑）
4. 覆写 _execute(ctx: Dictionary) → void  （内部只能调 CombatExecutor.report_*()）
```

#### 新 Buff

```
1. 新建 Buff .tres  →  设 stat_modifiers（属性修改）
2. 设 duration（0 = 永久）
3. 在 SkillData .tres 的 buff_resource 中引用
```

---

### 二、新分支扩展（改动一个文件的一个方法）

以下操作需要在一个核心文件中加一个新的 `match` 分支或一个 `_execute_*()` 方法，但**不改动架构**：

#### 新技能形态（第五种 SkillType）

```
1. SkillData  enum SkillType  加值（如 SUMMON = 4）
2. SkillData  加对应 @export 字段（如 summon_scene: PackedScene）
3. SkillExecutor.execute()  加 match 分支 → _execute_summon()
4. 加 _execute_summon() 方法（20-40行，遵循阶段序列）
```

#### 引导/蓄力技能（cast_type 字段已有）

```
1. SkillManager  加引导状态追踪（_channeling_skill, _channel_elapsed）
2. SkillExecutor  加 _execute_channel() 方法
3. 阶段序列: INPUT → CONDITION → EFFECT(spawn visual) → 持续 EVENT → 完成/打断 → POST
```

#### 地面持续效果（Ground AoE）

```
1. SkillData  加 ground_aoe_duration / ground_aoe_tick_rate 字段
2. SkillExecutor  加 _execute_ground_aoe() 方法
3. 新场景：Area2D + Timer 周期 tick + duration 自毁
```

---

### 三、新层级扩展（新增独立模块，不改现有契约）

以下需要新增一个独立模块/文件夹，现有12条契约保持不变：

| 扩展需求 | 新增模块 | 与现有系统的接口 |
|----------|----------|-----------------|
| 多人联网 | `res://networking/` RPC 层 | 拦截 `CombatExecutor.report_*()` → 序列化 → RPC |
| 技能进化树 | `res://skills/evolution/` | 读取 `SkillPool` → 解锁/升级 `SkillData` 变体 |
| 元素反应 | `res://systems/elemental/` | 监听 `ON_DAMAGE` + 元素标签 → 加 `ElementalReactionModifier` |
| 组合技连招 | `res://skills/combo/` | 监听 `ON_CAST` 序列 → 触发连招 `TriggeredEffect` |
| 弹射/穿透投射物 | `res://skills/runtime/` 扩展 | 继承 `Projectile` → 覆写 `_on_hit()` 不 `queue_free()` |
