# ⚔️ Combat Contracts — 确定性战斗运行时契约

> **状态**: 已固化  
> **版本**: 1.0  
> **最后更新**: 2025-07  
> **适用范围**: `res://skills/` `res://systems/` `res://components/`

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
CombatExecutor.report_heal()       ← HealthComponent
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
| `ON_STATUS_*` | `IDLE`, `EVENT`, `POST` |
| `ON_DODGE/CRIT` | `IDLE`, `EVENT` |

### 施法完整阶段序列

```
SkillManager._execute()
  ├─ begin_cast_sequence()        → INPUT
  ├─ SkillExecutor.execute()
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

```
res://skills/
  data/       → SkillData .tres (纯数据, 禁止脚本依赖)
  registry/   → SkillPool (ID索引)
  loadout/    → SkillLoadout (槽位映射)
  manager/    → SkillManager (装备/冷却/委托)
  runtime/    → SkillExecutor / SkillInstance / CastContext / DamageContext / Projectile
  modifiers/  → DamageModifier 子类 (纯函数)
  scenes/     → 技能场景 (.tscn + 脚本, 可引用 systems/)
  
res://systems/
  CombatEvent / CombatEventBus / CombatExecutor / CombatPhase / CombatScope
  TriggeredEffect / conditions/ / effect_graph/ / debug/

res://components/
  HealthComponent / ManaComponent / StatsComponent / CombatComponent
  (纯组件, 不持有技能/战斗逻辑, 通过 Executor 发射事件)

res://items/
  Buff / BuffManager / EquipmentManager / Inventory / ItemData
```

### 依赖方向（单向）

```
skills/scenes/  ──→  systems/ (CombatExecutor)
skills/runtime/ ──→  systems/ (CombatExecutor, CombatDebugger)
components/     ──→  systems/ (CombatExecutor)
systems/        ──→  skills/data/ (SkillData, Buff — 纯数据引用)
entities/       ──→  components/ + skills/manager/ + systems/
```

**禁止反向依赖**: `systems/` 不能引用 `entities/`。

---

## CONTRACT 8: 标签体系

| 来源 | 标签 | 说明 |
|------|------|------|
| Fireball | `["fire"]` | SkillData.tags |
| FlameStorm | `["fire"]` | SkillData.tags |
| ShadowBolt | `["shadow"]` | SkillData.tags |
| IceArmor | `["ice"]` | SkillData.tags |
| ShadowStep | `["shadow"]` | SkillData.tags |
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
CombatComponent (近战) → begin_hit → report_hit → take_damage → HealthComponent
Enemy.perform_attack   → begin_hit → report_hit → take_damage → HealthComponent
OnHitFireBonus         →             report_bonus_damage → take_damage (Executor内部)

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

---

## 📐 扩展指南

### 新技能类型
1. `SkillData` 加字段 → 2. `SkillExecutor.execute()` 加 `match` 分支 → 3. 加 `_execute_*()` 方法

### 新 Modifier
1. 继承 `DamageModifier` → 2. 设置 `stage` → 3. 覆写 `modify(ctx)` (纯函数)

### 新触发效果
1. 继承 `TriggeredEffect` → 2. 设 `trigger_type` + `conditions` → 3. 覆写 `_execute()` (内部只调 `CombatExecutor.report_*()`)

### 新条件
1. 继承 `Condition` → 2. 覆写 `evaluate(ctx) -> bool` (无副作用)
