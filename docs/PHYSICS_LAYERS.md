# 🔧 物理层与碰撞掩码标准

> 版本: v1.0 | 最后更新: 2026-05-23

---

## 核心原则

| 原则 | 说明 |
|------|------|
| **Layer = Gameplay Domain** | 物理分类，不是对象分类 |
| **Mask = "谁检测谁"** | 每一个 Area2D / RayCast 的检测目标 |
| **Tag = Gameplay Meaning** | 元素类型、阵营、状态等走 tags |
| **Condition = 规则判断** | 伤害免疫、克制关系走 conditions |

---

## 物理层分配（11 层）

```
Layer  名称              用途                          检测方(典型 Mask)
─────────────────────────────────────────────────────────────────
 1     WORLD_STATIC      墙/地形/建筑/岩石/树           ACTOR, PROJECTILE
 2     ACTOR             玩家/敌人/NPC                  HITBOX, SENSOR, SURFACE
 3     HITBOX            主动攻击区域(刀挥砍/AoE/投射物命中区)  HURTBOX
 4     HURTBOX           受击区域(角色受击盒/弱点)       HITBOX, PROJECTILE
 5     PROJECTILE        投射物本体                      WORLD_STATIC, HURTBOX, SURFACE
 6     INTERACTION       门/箱子/机关/可交互物           ACTOR
 7     SURFACE           元素地面(火/油/冰/毒/水)        ACTOR
 8     SENSOR            纯检测(AI视野/拾取范围/传播范围)  ACTOR
 9     NAVIGATION        导航障碍(临时/动态/关闭的门)     AI_PATHFINDING
10     ITEM              掉落物                          ACTOR
11     TRIGGER           纯事件(切图/剧情/区域触发)       ACTOR
```

---

## 各节点类型标准配置

### CharacterBody2D（玩家 / 敌人）

```
CollisionShape2D (根碰撞体):
  layer = ACTOR
  mask  = WORLD_STATIC | ACTOR    ⚠️ 必须含 ACTOR，否则角色间互穿！

Hurtbox (Area2D 子节点):
  layer = HURTBOX
  mask  = HITBOX | PROJECTILE

MeleeHitbox (Area2D 子节点):
  layer = HITBOX
  mask  = HURTBOX

InteractionArea (Area2D 子节点):
  layer = SENSOR
  mask  = INTERACTION

PickupArea (Area2D 子节点):
  layer = SENSOR
  mask  = ITEM
```

### Portal / Trigger

```
Area2D:
  layer = TRIGGER
  mask  = ACTOR
  monitoring = true
```

### Projectile

```
Area2D:
  layer = PROJECTILE
  mask  = WORLD_STATIC | HURTBOX | SURFACE
```

### MapObject（油桶 / 木箱 / 栅栏 / 冰墙）

```
根节点 (StaticBody2D 或 Node2D):
  collision_layer = WORLD_STATIC

HitArea (Area2D 子节点):
  layer = HURTBOX
  mask  = HITBOX | PROJECTILE

InteractionArea (Area2D 子节点):
  layer = INTERACTION
  mask  = SENSOR
```

### Surface（燃烧地面 / 油污 / 冰面）

```
Area2D:
  layer = SURFACE
  mask  = ACTOR
```

### Item（掉落物）

```
Area2D:
  layer = ITEM
  mask  = SENSOR
```

---

## 反模式 ⚠️

| ❌ 不要 | ✅ 应该 |
|--------|--------|
| 为每种敌人建 Layer (EnemyLayer) | 统一用 ACTOR + tags ["undead", "boss"] |
| 为每种元素建 Layer (FireLayer) | 统一用 SURFACE + data.type = "fire" |
| Layer = 游戏内容分类 | Layer = 物理分类 |
| 单个节点混用多个 Domain 的 layer | 拆成多个子节点，各司其职 |

---

## 与项目架构的关系

```
Physics Layer  → Broad Phase 过滤（"谁碰到谁"）
Tags           → Gameplay 含义（"火/冰/亡灵/Boss"）
Conditions     → 规则判断（"火焰免疫""倍率调整"）
Effect Graph   → 事件链（"ON_HIT → 挂 burning"）
```

这四层各司其职，互不替代。详见 [COMBAT_CONTRACTS.md](./COMBAT_CONTRACTS.md) 和 [WORLD_CONTRACTS.md](./WORLD_CONTRACTS.md)。

---

## 迁移指南

当前项目所有节点使用默认值（layer=1, mask=1），需逐节点迁移：

1. **CharacterBody2D**（Player, Enemy）→ 根体 layer=ACTOR, mask=WORLD_STATIC|ACTOR（缺 ACTOR 会导致角色互穿）
2. **Area2D**（Portal）→ layer=TRIGGER, mask=ACTOR
3. **Area2D**（Hitbox/Hurtbox）→ 分别设 HITBOX/HURTBOX
4. **MapObject**（oil_barrel 等）→ layer=WORLD_STATIC, HitArea=HURTBOX
5. **新增节点**按上表配置，不再使用默认值


---

## 已知问题 & 经验教训

### 2025-07-23：Actor-Actor 碰撞穿透

**现象**：玩家和敌人互相穿过，无碰撞。

**根因**：CharacterBody2D 的 `collision_mask` 只设了 `WORLD_STATIC`（bit 1），但双方 `collision_layer=ACTOR`（bit 2）。mask 不含 ACTOR → 互不可见。

**教训**：Actor 的 `collision_mask` 必须包含 `ACTOR` 自身（即 `WORLD_STATIC | ACTOR = 3`），否则角色之间永远是幽灵。

### 2025-07-23：MapObject 破坏后仍阻挡

**现象**：油桶爆炸后，StaticBody2D 未禁用，玩家无法通过。

**根因**：`oil_barrel_data.tres` 缺少 `blocks_path = true`，导致 `_on_destroyed()` 中的 `_remove_collision()` 从不被调用。

**教训**：所有阻挡通行的 MapObject 必须在其 `.tres` 数据中显式设置 `blocks_path = true`。
