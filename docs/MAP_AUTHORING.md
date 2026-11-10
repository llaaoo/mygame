# 地图制作工作流

2026-11-10，北京时间。本轮完善制作与校验工具，沿用既有敌人、配方、库存和任务预算。镇中地点的实际用途见[TOWN_MAP_CELLS](TOWN_MAP_CELLS.md)，验证见[MAP_AUTHORING_VALIDATION](MAP_AUTHORING_VALIDATION.md)。

## 编辑、检查与试玩

项目已启用`addons/map_authoring`编辑器插件。打开Godot 2D地图场景，右侧切到**地图制作**页：

- **保存并检查当前地图**：保存后走真实章节装配与领域校验，包含目标落点、返程、持久ID、资源引用、几何和运行时导航；错误保留场景/节点路径，点击可选中对应节点。
- **检查灰河谷地图目录**：检查所有已登记地图及其与历史区域的连接。
- **保存并试玩当前地图**：检查成功、进程正常结束且场景未再次修改时，启动独立地图试玩。下拉框可选择默认出生点或一个命名落点。

试玩使用正式人物、控制、库存规则和正常AI，沿用默认起始预算，不授予演示装备或技能。F5/F9只读写本次内存存档；重置会保持所选地图/入口并重新开始。退出后正式旅程文件不变。试玩入口为[demos/map_preview.tscn](../demos/map_preview.tscn)，未收到编辑器请求时默认客栈。

校验在独立的Godot运行进程中执行，避免将深层玩法服务实例化为编辑器placeholder；编辑器保持可响应。报告须等子进程结束并检查退出状态，超时或异常退出不能显示通过。本地请求/报告仅存`.godot`，不进入正式存档或版本库。

也可直接运行：

```sh
python3 tools/run_tests.py --tests maps map_authoring map_preview_input content
godot --headless --path . --script res://tools/validate_maps.gd
```

`maps`和正式内容检查使用同一编译与校验链，不维护第二套玩法规则。

## 新建地图

1. 在Godot文件系统中复制[室内模板](../content/maps/templates/interior_cell.tscn)或[室外模板](../content/maps/templates/field_cell.tscn)到正式内容目录，不直接修改模板作为正式区域。
2. 对根节点`region_definition`执行Make Unique，填写独立稳定`id/title/description`、`authored_size`及环境配置。`change_me`模板ID不能通过检查。室外模板设置`open_field`，房屋/地牢使用室内模板；`floor_style`支持wood/stone/ground/overlay。
3. 将场景加入[MapCellCatalog](../content/maps/grayriver/catalog.tres)。新区域必须在章节中接通来路与返路，不能仅凭目录登记变成已发现地点。
4. 只在节点上编辑位置。根变换为单位变换，允许Node2D父组平移；地图根之间通过通路连接，不把AuthoredMapCell嵌套为房间预制组。不支持旋转/缩放，家具大小由`footprint`决定。
5. 通过命名落点接门，再摆家具和内容点。检查、试玩、保存重进；修改已发布持久ID或删除已有内容时遵守[局部迁移规则](SAVE_SYSTEM.md)。

室外底图、道路、森林生成与尚未迁移的老区域仍保留原数据来源；现有`camp`通过场景叠加编辑镇中房屋与入口，其原区域元数据由旧定义继承。新增完整室外场景、房屋与地牢则都可使用同一节点流程。本轮没有把整张野外重做为手工地图，也没有扩写新的冒险内容。

## 出生点与通路

实例化[arrival.tscn](../gameplay/maps/arrival.tscn)得到MapArrival。每张地图恰有一个`default_entry=true`节点；它决定默认出生点，`region_definition.authored_entry`保持零。`id`在本区域内唯一，常用`entry`、`from_north`等；移动节点就是移动所有引用该落点的门的目的地。

`minimum_enemy_distance`是可选的初始敌人间距检查，单位为世界距离。零表示不启用额外间距限制，不能等同于自动保证安全；希望安全落点时，应超过附近敌人的感知距离并留出准备空间。敌人感知圈在编辑器显示，试玩仍按实际AI运行。

门是MapFeature，`definition`使用ExplorationExitData：

| 字段 | 含义 |
|---|---|
| `id` | 全章节唯一且稳定的门ID，如`town.inn.enter` |
| `target` | 目标区域ID |
| `target_anchor` | 目标区域中的MapArrival.id |
| `return_exit` | 可选的对门ID；填写时双方须互指，且确实连接同一对区域 |
| `required_* / requires_clear` | 原有知识、事实或清场条件，不由编辑器绕过 |

使用`target_anchor`时，源Resource的`arrival`保持默认INF，不能同时手填目标坐标。旧JSON门的明确坐标继续兼容。所有场景编译完成后再解析连接，不依赖目录顺序，运行时不临时加载目标场景寻找落点。

非camp地图的第一条通路必须是无清场/知识/事实门槛的返程链，并最终到达camp；它也是全图投影使用的父级路径。将返门节点放在其他门之前；有意单向的其他捷径可以不填写return_exit，但不能替代安全返程。

当前已将客栈、作坊、公署和档案窖来返门接入命名落点。返门不会恢复资源或重新生成库存。

## 内容点与预制组

实例化[feature.tscn](../gameplay/maps/feature.tscn)，为definition选择以下类型；复制内容点时先Make Unique并更换自己的持久ID。**Resource.pos保持零，空间位置归Node2D。**

| 类型 | 实际消费者 |
|---|---|
| ExplorationExitData | 原区域旅行与门条件 |
| ExplorationDiscoveryData | 日志、知识、领取事实与原奖励服务 |
| ExplorationEncounterData | 共用敌人、AI、真实装备及死亡战利品 |
| SurvivalStationData | 采集、饮水、烹饪与原再生时钟 |
| MapAmenityData | 休息、制造、装备整备适配器 |
| WorldStorageData | InventoryService的持续实物容器 |
| ExplorationPropData | MapObject场景与持久物体事实 |
| SpellPuzzleData / DeliverySiteData / RepairFacilityData | 原现场作业、交付及修理流程 |
| ExplorationWorldEventData | 原不可逆世界选择与事实 |
| SurfacePatchData / SurfaceValveData | 原地面介质、阀门与反应系统 |

敌人的`persistent_id`填写未加`river.enemy.`前缀的稳定身份，group可指定分组；原元数据读取接口保留为投影，不能用节点顺序重建身份。初始装备和物资仍来自ActorCharacterData，已存在的存档记录优先，不因地图迁移补货。

阀门的路径点在MapFeature局部坐标中编辑，编译时连同控制点一起平移为区域坐标；旧JSON路径仍使用其原区域坐标。SurfacePatch的场景半径限制为0—1024之间的有限正值，防止错误数据触发无界采样。

家具继续使用[furniture.tscn](../gameplay/maps/furniture.tscn)。footprint同时供碰撞、导航和本地地图使用；贴图尺寸/偏移不改变碰撞。同一Node2D预制组可包含家具与内容点，移动组时统一移动；复用带持久身份的组必须为新实例独立定义与ID。

## 校验与所有权

编译复制Resource与叠加基底，反复编译不积累门、障碍物或污染源资源。MapFeature只登记空间，所有费用、库存、任务事实、命中和计时仍交给原服务；编辑器不形成新的状态权威。

检查覆盖：目录丢失/不可实例化资源、类型和身份、变换、出生点、命名落点、双向门配对、返程链、真实玩家/敌人间隙、运行时40单位导航网格可达性、交互位置与墙体、内容资源/材料/条件引用。障碍不会为了迁就交互点被自动删除。感知与战斗中的动态可达性仍需要正常AI试玩；静态检查不能替代平衡或盲测。

档案窖现位于[archive.tscn](../content/maps/grayriver/archive.tscn)，原JSON区域与同一入口已移除以保持单一空间来源。原3名敌人、6项发现、奖励/知识、湿地介质、碰撞尺寸与返程坐标有[迁移前预算夹具](../tests/fixtures/archive_pre_scene_budget.json)核对；区域、角色和领取ID未改变，不提高存档版本。

设计沿用Godot4.6[场景组织与依赖注入](https://github.com/godotengine/godot-docs/blob/4.6/tutorials/best_practices/scene_organization.rst)、原生PackedScene与Resource；异步检查遵循[OS子进程退出状态](https://github.com/godotengine/godot-docs/blob/4.6/classes/class_os.rst)契约。
