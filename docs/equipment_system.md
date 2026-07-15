# 装备系统

装备系统由静态资源、装备负载计算、掉落拾取、UI 和存档五部分组成。新增内容应优先通过 `.tres` 配置完成。

## 数据结构

- `EquipmentData`：装备本体，包含槽位、等级、图标索引、基础属性、战斗修正、词缀和套装。
- `EquipmentAffixData`：可在多件装备间复用的词缀资源。
- `EquipmentSetData`：套装定义，持有多个 `EquipmentSetBonus` 阈值。
- `EquipmentCatalog`：扫描 `res://content/items/equipment` 并提供 ID 查询和稀有度抽取。

固定属性使用 `stat_modifiers`，百分比属性使用 `stat_multipliers`。构筑相关修正使用 `combat_modifiers`，当前支持：

- `damage.all`、`damage.<skill_tag>`
- `cooldown.all`、`cooldown.<skill_tag>`
- `mana_cost.all`、`mana_cost.<skill_tag>`
- `damage_reduction`
- `healing_received`
- `crit_chance`、`crit_damage`

## 运行时约束

`EquipmentManager` 是装备效果的唯一汇总入口。每次换装时先移除旧负载 Buff，再汇总装备、词缀和已解锁套装阈值，最后应用一份新的永久 Buff。不要从 UI 或拾取物直接修改玩家属性。

装备存档保存资源路径和槽位。装备产生的运行时 Buff 不单独保存，加载时由装备资源重建，避免重复叠加。

## 新增装备

1. 在 `content/items/equipment` 新建 `EquipmentData` 资源。
2. 设置唯一 `id`、槽位、稀有度、物品等级和 `icon_atlas_index`。
3. 组合基础属性、战斗修正、词缀和可选套装。
4. 运行 `tests/test_equipment_system.gd`，确认目录数量、唯一 ID、图标和属性可逆性。
