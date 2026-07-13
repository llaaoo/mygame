# Roguelite 转型规划

> 状态: v0.1
> 日期: 2026-07-13
> 目标: 将当前 ARPG 原型转为短局制动作 roguelite，同时最大化复用现有战斗、技能、世界物件、敌人、UI 与美术资产。

---

## 一、转型结论

当前项目不适合继续扩成传统 RPG。已有系统的优势集中在：

- 高频战斗反馈。
- 数据驱动技能与 Buff。
- 可破坏物、机关、陷阱、宝箱、表面反应。
- 敌人、Boss、召唤物与技能标签体系。
- CombatExecutor / CommandBus / Runtime 边界已经收敛。

因此新方向应是：

> 短局地牢动作 roguelite：房间遭遇 + 随机奖励 + 局内构筑 + Boss 层 + 局外解锁。

核心原则：

- 不重写战斗系统。
- 不推翻 Runtime 架构。
- 不继续扩传统 RPG 长线任务、NPC 日程、装备纸娃娃。
- 先用手工房间模板证明一局 run 好玩，再做程序化地图。
- 所有新系统围绕 run / room / reward 三个概念收敛。

---

## 二、新游戏循环

```
营地 / 开始界面
    ↓
选择角色 / 初始技能
    ↓
进入随机地牢 run
    ↓
房间遭遇：战斗 / 机关 / 宝箱 / 精英 / 商店 / 事件
    ↓
清场后选择奖励：技能 / 遗物 / 属性 / 恢复 / 货币
    ↓
推进层数与难度
    ↓
Boss 房
    ↓
死亡或通关
    ↓
结算局外货币、解锁、新难度
```

第一版只需要：

- 1 个主题：监狱。
- 6 个普通房间。
- 1 个精英房。
- 1 个 Boss 房。
- 每个房间清场后三选一奖励。
- 死亡后重置 run。

---

## 三、保留、改造、冻结

### 保留为核心

| 系统 | 文件/目录 | 用途 |
|------|----------|------|
| 战斗权威 | `gameplay/combat/combat_executor.gd` | 所有伤害、治疗、击杀、施法事件继续走唯一入口 |
| 事件总线 | `core/event/combat_event_bus.gd` | 奖励、目标、精通、触发效果观察战斗事件 |
| 技能执行 | `gameplay/abilities/runtime/skill_executor.gd` | 局内技能释放与构筑核心 |
| 技能数据 | `gameplay/abilities/data/*.tres` | 技能池、奖励池、敌人技能池 |
| SkillPool / Loadout | `gameplay/abilities/registry/`, `loadout/` | 初始构筑与局内替换 |
| Buff / Status | `gameplay/status/` | 遗物、技能升级、表面状态的基础 |
| MapObject | `world/object/` | 房间机关、油桶、冰墙、木箱、破墙 |
| Surface | `gameplay/interaction/` | 房间环境交互与高密度战斗热点 |
| Enemy / Boss | `entities/enemy/`, `entities/boss/` | 遭遇池与层末 Boss |
| HUD / 技能栏 / 伤害数字 | `ui/` | 短局战斗界面 |

### 改造成 roguelite 系统

| 原系统 | 新定位 |
|--------|--------|
| Quest | 房间目标、挑战目标、Boss 击杀目标 |
| 装备系统 | 局内遗物、被动祝福、少量局外解锁 |
| 技能树 / 精通 | 局内 perk 池与局外解锁树 |
| 宝箱 / 掉落表 | 奖励节点、房间结算奖励、商店商品 |
| Portal | 房间出口、层间入口、Boss 门 |
| Overworld | 房间模板库和营地，不再作为连续大世界核心 |

### 冻结或降级

| 系统 | 处理 |
|------|------|
| NPC 日程 / WorldTime | 冻结。只保留营地 NPC 或事件房文本用途 |
| 多阶段剧情任务 | 冻结。后续只做挑战、成就或局外解锁条件 |
| 传统背包网格 | 降级。第一版不做装备堆叠管理 |
| 大地图持久化 | 降级。run 内状态可丢弃，局外只保存解锁 |
| 城镇生活模拟 | 暂不投入 |

---

## 四、新模块边界

新增模块只处理 roguelite 流程，不接管战斗和世界底层。

```
gameplay/
├── run/
│   ├── run_manager.gd
│   ├── run_state.gd
│   └── run_seed.gd
├── rooms/
│   ├── room_data.gd
│   ├── room_director.gd
│   ├── encounter_data.gd
│   └── room_pool.gd
└── rewards/
    ├── reward_data.gd
    ├── reward_pool.gd
    ├── reward_resolver.gd
    └── reward_picker_ui.gd

content/
├── rooms/
│   ├── prison/
│   │   ├── prison_cell_room.tscn
│   │   ├── guard_office_room.tscn
│   │   ├── armory_room.tscn
│   │   └── fire_lord_room.tscn
│   └── prison_room_pool.tres
├── rewards/
│   ├── skills/
│   ├── relics/
│   └── run_rewards.tres
└── relics/
```

### RunManager

职责：

- 创建一局 run。
- 持有随机种子、层数、房间序号、难度倍率。
- 请求 RoomDirector 加载下一个房间。
- 接收房间完成事件并打开奖励。
- 处理死亡、通关、结算。

禁止：

- 不直接造成伤害。
- 不直接修改房间内敌人状态。
- 不直接操作 CombatExecutor 以外的战斗结果。

### RoomDirector

职责：

- 根据 `RoomData` 实例化房间模板。
- 生成敌人、机关、宝箱、出口。
- 房间开始时锁门。
- 监听敌人死亡或目标完成。
- 清场后开门并通知 RunManager。

禁止：

- 不创建新战斗规则。
- 不绕过 `CombatExecutor`。
- 不把房间逻辑写进 Player。

### RewardResolver

职责：

- 生成三选一奖励。
- 将奖励应用到 run state、SkillManager、BuffManager、StatsComponent 或遗物列表。
- 记录本局奖励历史，避免重复过多。

禁止：

- UI 不直接改 Player 状态，UI 只把选择交给 RewardResolver。
- 遗物效果不直接订阅并改 HP，必须走 CombatExecutor / Buff / Modifier / TriggeredEffect。

---

## 五、奖励设计

第一阶段只做五类奖励：

| 类型 | 示例 | 实现方式 |
|------|------|----------|
| 技能新增 | 获得 `lightning_bolt` | 加入 SkillPool 并装备到空槽或替换 |
| 技能强化 | 火球伤害 +20% | 增加局内 modifier 或复制 SkillData 变体 |
| 遗物 | 火焰命中附加燃烧 | 注册 TriggeredEffect 或 Buff |
| 属性 | 最大 HP +20 / MP 回复 +1 | 修改 StatsComponent / ManaComponent |
| 恢复 | 回复 30% HP / MP | 通过 Player 公共接口恢复 |

推荐第一批遗物：

- 余烬戒指：火焰技能伤害 +20%。
- 霜裂护符：冻结目标死亡时释放冰爆。
- 雷网导体：闪电技能弹射 +1。
- 毒瓶：AoE 命中附加中毒。
- 骨哨：召唤物上限 +1。
- 油浸火石：打爆油桶时额外生成燃烧地面。

---

## 六、房间类型

第一阶段房间池：

| 类型 | 目标 | 可复用资产 |
|------|------|------------|
| 普通战斗房 | 击杀全部敌人 | `enemy.tscn`, Guard 预设 |
| 机关战斗房 | 战斗中穿插门、压力板、陷阱 | Door, Switch, PressurePlate, SpikeTrap |
| 爆炸物房 | 利用油桶和表面反应清敌 | OilBarrel, SurfaceManager |
| 宝箱房 | 免费或条件宝箱 | Chest, LootTable |
| 精英房 | 强敌 + 更好奖励 | Enemy type 2 或 Boss 小型化 |
| Boss 房 | 层末挑战 | `fire_lord.tscn`, `fire_lord.tres` |

房间完成条件先只支持：

- `kill_all_enemies`
- `survive_seconds`
- `activate_switch`
- `defeat_boss`

---

## 七、第一阶段验收标准

### P0：可玩 run 闭环

- [ ] 从主菜单或临时入口开始新 run。
- [ ] 加载第 1 个房间。
- [ ] 房间生成敌人并锁门。
- [ ] 清场后开门并弹出三选一奖励。
- [ ] 选择奖励后进入下一房间。
- [ ] 第 6 个房间后进入 Boss 房。
- [ ] Boss 死亡后结算通关。
- [ ] 玩家死亡后结算失败并可重新开始。

### P1：复用资产验证

- [ ] 至少 4 个房间模板使用当前监狱 tileset。
- [ ] 至少 3 种敌人预设参与遭遇池。
- [ ] 至少 5 个现有技能可作为奖励出现。
- [ ] 至少 4 种 WorldObject 进入房间模板。
- [ ] 油桶 + 火焰技能 + 表面反应在房间中仍可用。

### P2：构筑感验证

- [ ] 一局内至少获得 5 次奖励。
- [ ] 奖励能明显改变战斗手感。
- [ ] 技能栏能显示当前局内 loadout。
- [ ] 遗物或强化至少有 6 个。

---

## 八、实施顺序

### 第 1 步：文档与命名收敛

- 新增本文档。
- 在 `docs/INDEX.md` 标记项目主方向切换。
- 暂停扩展 RPG 任务、NPC 日程、传统装备。

### 第 2 步：最小 RunManager

- 新建 `gameplay/run/run_state.gd`。
- 新建 `gameplay/run/run_manager.gd`。
- 支持开始 run、结束 run、推进房间编号。
- 暂时使用固定房间序列，不做随机。

### 第 3 步：RoomDirector

- 新建 `gameplay/rooms/room_data.gd`。
- 新建 `gameplay/rooms/room_director.gd`。
- 从当前 `overworld.tscn` 拆或复制出 3 个房间模板。
- 实现清场检测和出口解锁。

### 第 4 步：RewardPicker

- 新建 `gameplay/rewards/reward_data.gd`。
- 新建 `gameplay/rewards/reward_resolver.gd`。
- 新建 `ui/reward_picker_ui.gd` 或放在 `gameplay/rewards/`。
- 第一版只做技能奖励和恢复奖励。

### 第 5 步：Boss 与结算

- 接入 `entities/boss/fire_lord.tscn`。
- Boss 死亡触发 run clear。
- 死亡/通关结算面板。

### 第 6 步：随机与元进度

- 引入 seed。
- 房间池按权重抽取。
- 奖励池按权重抽取。
- 保存局外货币和解锁。

---

## 九、停止线

转型期间禁止：

- 重写 CombatExecutor。
- 新增第二套事件总线。
- 新增第二套技能系统。
- 把 Reward UI 直接接到 Player 内部状态。
- 新增复杂程序生成算法后才验证玩法。
- 继续扩主线任务、NPC 日程、城镇生活模拟。
- 在命中源里绕过 `CombatExecutor.report_hit()`。

允许的局部例外：

- Player 本地输入、瞄准、蓄力、引导继续留在 Player。
- Projectile / SummonEntity 继续走 Godot 物理循环。
- RoomDirector 可以直接管理房间内节点的生成、锁门、出口，但不接管战斗结算。

---

## 十、当前资产复用清单

| 资产 | 用法 |
|------|------|
| 监狱 tileset / props | 第一主题房间模板 |
| Guard_A-F / Guard_Captain | 普通敌人与精英遭遇 |
| FireLord | 第一层 Boss |
| Door / Switch / PressurePlate | 房间锁门、机关门、奖励门 |
| SpikeTrap | 机关房与走廊危险 |
| Chest / LootTable | 宝箱房、奖励房 |
| OilBarrel | 爆炸物房、连锁反应房 |
| BreakableWall / IceWall | 可破坏路径、隐藏奖励 |
| Fireball / Lightning / Poison / Ice / Summon | 奖励技能池 |
| Buff / Status | 遗物与技能强化基础 |
| DamageNumber / BossHPBar / SkillBar | 战斗反馈 |

---

## 十一、设计准则

新方向的判断标准：

| 不再追求 | 改为追求 |
|----------|----------|
| 大世界连续探索 | 10 分钟一局完整体验 |
| 多阶段剧情任务 | 房间目标清晰、奖励即时 |
| 装备背包管理 | 少量高影响遗物 |
| NPC 生活模拟 | 高质量遭遇节奏 |
| 技能数量堆叠 | 构筑组合可感知 |
| 地图全交互 | 房间热点强交互 |

最终目标：

> 每次进入地牢都能用相同底层系统打出不同构筑、不同房间节奏、不同环境解法。
