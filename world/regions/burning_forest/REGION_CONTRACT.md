# 🔥 Burning Forest — 区域 Gameplay Contract

> **状态**: 制作中  
> **目标**: 20 分钟可玩内容  
> **验证标准**: 3 天完成区域骨架 + 战斗 + 交互

---

## 一、玩家流程

```
入口营地 (安全)
	│
	▼
烧毁道路 (引导教学)
	│  首次接触：燃烧表面 + 可破坏木箱
	│  学会：火球点燃油桶 → 连锁爆炸 → 清理路障
	│
	▼
岔路区
 ┌──────────┴──────────┐
 │                      │
 ▼                      ▼
废弃村庄                燃烧林地
 木桶爆炸链             火焰蔓延教学
 房屋可破坏              地表持续伤害
 室内搜刮                AI 寻路因火焰改变
 │                      │
 └──────────┬──────────┘
			▼
	  地下洞穴入口 (Portal)
			│
			▼
	  洞穴深处 (SubMap)
	  狭窄通道 + 黑暗
	  冰墙堵路 → 用火球融化
			│
			▼
	  Boss Arena
	  火焰领主 + 环境互动
	  击败后 → 打开捷径
			│
			▼
	  捷径返回营地 (Loop Close)
```

---

## 二、系统验证点

### A. WorldRuntime 验证

| 验证项 | 具体场景 |
|--------|---------|
| Chunk 加载 | 营地→道路→岔路，3 个 Chunk |
| Portal 过渡 | 洞穴入口→洞穴深处（显式过渡） |
| WorldState 持久化 | 破坏木箱后离开 Chunk 再返回 → 保持已破坏 |
| SubMap 独立 | 洞穴深处独立场景，返回时村庄状态保留 |

### B. CombatRuntime 验证

| 验证项 | 具体场景 |
|--------|---------|
| AoE 技能 | 烈焰风暴清理成群燃烧亡灵 |
| Projectile | 火球远程引爆油桶 |
| Buff | 进入洞穴前给自己上冰甲 |
| Melee | 近战清理小怪狼群 |
| Modifier | 火焰领主有火焰抗性 TagMultiplierModifier |

### C. Interaction 验证

| 验证项 | 具体场景 |
|--------|---------|
| Fire Spread (Tier B) | 油桶→木箱→木栅栏 连锁 |
| Surface (Tier C) | 燃烧林地的 burning 地面持续伤害 |
| Destroyable (Tier A) | 破坏冰墙（ice 标签 + fire 技能 = 融化） |
| Explosion | 油桶 0 HP → AOE 伤害周围物体 |

### D. Runtime 验证

| 验证项 | 具体场景 |
|--------|---------|
| Event Chain | 炸油桶 → ON_KILL → 传播 → 连锁 ON_KILL |
| Scheduler | Surface burning 倒计时过期 |
| Persistence | 出洞穴后村庄破坏物状态保留 |
| Respawn | 木箱 60s 后重生（测试用） |

---

## 三、敌人配置

| 敌人 | 位置 | 数量 | 预设类型 |
|------|------|------|---------|
| 森林狼 | 烧毁道路 | 2 | 哨兵 (type=0) |
| 燃烧亡灵 | 燃烧林地 | 3 | 士兵 (type=1) |
| 火焰领主 | Boss Arena | 1 | 坦克 (type=2, 高HP+火抗) |

---

## 四、可破坏物与交互物

| 物体 | 位置 | HP | 标签 | 反应 |
|------|------|-----|------|------|
| 木箱 | 道路 | 10 | wooden, flammable | 火→伤害→摧毁→掉落金币 |
| 油桶 | 村庄 | 5 | oil, flammable | 火→引爆(AOE 50伤害, 范围80) |
| 木栅栏 | 道路 | 15 | wooden, obstacle | 摧毁→清路障 |
| 冰墙 | 洞穴 | 20 | ice, obstacle | 火→融化，其他→减半 |
| 房屋 | 村庄 | 30 | wooden, structure | 摧毁→掉落物品+打开通路 |
| 宝箱 | 村庄屋内 | - | container | Interactable(非破坏) |

---

## 五、表面配置

| 表面 | 位置 | 来源 | 效果 |
|------|------|------|------|
| 燃烧地面 | 燃烧林地(预设) | 场景自带 | 每1s造成3点火伤 |
| 油污 | 村庄地面 | 油桶泄漏 | 减速+可被点燃 |
| 燃烧地面 | 村庄 | 油污着火后 | 每1s造成5点火伤 |

---

## 六、文件清单

```
res://world/regions/burning_forest/
├── burning_forest_overworld.tscn    # 主场景
├── region_data.tres                 # RegionData Resource
│
├── chunks/
│   ├── camp.tscn                    # 入口营地
│   ├── road.tscn                    # 烧毁道路
│   ├── fork.tscn                    # 岔路区
│   ├── village.tscn                 # 废弃村庄
│   └── burning_wood.tscn           # 燃烧林地
│
├── submaps/
│   ├── cave_entrance.tscn           # 洞穴入口（Portal 目标）
│   ├── cave_depths.tscn             # 洞穴深处 + 冰墙
│   └── boss_arena.tscn              # Boss 竞技场
│
├── objects/
│   ├── wooden_crate.tscn            # 木箱
│   ├── oil_barrel.tscn              # 油桶
│   ├── wooden_fence.tscn            # 木栅栏
│   ├── ice_wall.tscn                # 冰墙
│   └── village_house.tscn           # 可破坏房屋
│
├── surfaces/
│   ├── burning_ground.tres          # 燃烧地面 SurfaceData
│   └── oil_spill.tres               # 油污 SurfaceData
│
└── encounters/
	├── wolf_pack.tres                # 2只狼
	├── burning_undead.tres           # 3只燃烧亡灵
	└── fire_lord_boss.tres           # Boss 战
```
