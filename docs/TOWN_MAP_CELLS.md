# 河谷镇：地图编辑与可进入地点

2026-11-10（上海）。参考开放世界RPG的独立室内单元、门址与持续实物，沿用2D移动、F交互、正常时间和既有领域服务。

## 当前地点

|地点|镇中门口坐标|实际用途|
|---|---|---|
|灰苇客栈|(-4100,2920)|客床按1/3/6游戏小时休息；私人寄存箱；有限公共补给；柴灶；与苇娘交谈及买卖实际补给|
|萨芙整修作坊|(-4250,1570)|原制造配方、装备整备；有限公共原料箱；可读作业记录|
|河谷公署|(-2550,2770)|行路文书与档案索引；公共寄存箱；真实地点引用线索|

镇中门牌、艾妲的新话题和G全图辅助找门。F进入，室内南门F离开，返回同一外部门址。室内G默认显示当前房屋的墙体、家具和交互点，可以切回河谷全图、缩放或放置室内路标。路标保存区域ID，旧存档没有区域字段时仍表示河谷全图。

苇娘是现有SharedActor/ServiceNPC体系中的人物，有自己的钱袋、库存、关系、日程、死亡和遗骸。她提供买卖，不提供拆解、强化或排产。萨芙、艾妲和训练师白天仍在原集市当值，没有将外部人物投影成可隔墙操作的室内柜台。付费装备整修和排产仍找萨芙。

房门和界面不暂停世界，不自动补满生命、法力、库存或计时。客床调用原休息执行链，数秒是准备，成功推进实际小时并消费随身烤饼/清水。室内归镇中需求消耗规则；离线不额外计时。阅读公署文书只记录已读内容及引用线索，不远程发现遗迹、赠送原件或完成任务。

## 在Godot中编辑

[地图目录](../content/maps/grayriver/catalog.tres)登记[镇中门址](../content/maps/grayriver/town_sites.tscn)、[客栈](../content/maps/grayriver/inn.tscn)、[作坊](../content/maps/grayriver/workshop.tscn)和[公署](../content/maps/grayriver/records.tscn)。直接双击场景进入Godot 2D编辑器，选节点并按编辑器F聚焦，平移Node2D。无需在JSON里另填室内坐标，不需要自制插件。

1. 根节点`AuthoredMapCell.region_definition`填写稳定区域ID、名称、描述、边界`authored_size`和默认落点`authored_entry`。`floor_style/floor_tint`负责地面表现。新增场景加入目录；要使用镇中需求规则，再登记到规则Resource的`additional_base_regions`。
2. 复制家具，或实例化[furniture.tscn](../gameplay/maps/furniture.tscn)。调整`form`、`texture`、`footprint`和`solid`。同一footprint供碰撞、寻路和室内地图使用；`visual_size/visual_offset`只控制贴图。窗、地毯和门槛通常不阻挡，墙、床和桌体阻挡。
3. 复制交互点，或实例化[feature.tscn](../gameplay/maps/feature.tscn)。`definition`使用已有类型化Resource：`ExplorationExitData`房门、`ExplorationDiscoveryData`文书、`SurvivalStationData`取水/烹饪/采集、`MapAmenityData`休息/制造/整备、`WorldStorageData`持续容器。编辑器显示位置和80单位交互圈。
4. 坐标只编辑节点位置。Resource的`pos`保持零，由装配时复制并赋值。允许平移父组，不支持旋转或缩放；家具改大小用footprint。未经支持的变换与Resource.pos会报错，避免编辑预览和运行不同。
5. 房门填写目标区域和实际arrival，目标场景提供返门。交互点应放在家具前可站立的位置，门落点须在边界内且没有家具阻挡。生成避让区只约束生成物，不再将合法的门边玩家落点/存档移回默认入口。
6. 运行`python3 tools/run_tests.py --tests content grayriver_routes town_cells town_cells_input`，校验门引用、落点、稳定ID、材料、容器预算、几何和通路。室内不会为迁就错放的交互点自动删除墙体。

已有图片取自项目现有prison_sucai家具及原Kenney城镇素材，没有新增外部下载。更换texture仍须遵守项目素材许可约定。

## 所有权与持久化

`MapCellCatalog`在章节装配时读取场景，`AuthoredMapCell.compile`复制类型化Resource，投影节点位置和家具footprint。场景只提供空间定义与表现，不处理伤害、库存或存档。编译结果进入原`ExplorationRegionData`与内容校验；运行仍走CampaignGame/RegionSession的离区清理、区域挂载和快照。旧野外JSON和程序生成遗迹继续走原路径，镇中三处硬编码房屋由叠加场景替代。

固定容器ID以`storage.`开头，容量、初始物品和访问者由`WorldStorageData`登记。`access_actor_id="player"`用于私人寄存，空字符串表示允许公用，其他所有者拒绝取用。初始物品仅在容器不存在时通过InventoryService建立；空箱也保存，重进、休息和换区不补货。

`WorldStorageService`只做空间/UI适配：每次提交重验区域generation、距离、视线、生命、危险、来源和可携容器，再提交InventoryService的TransferPlan。空间不足整次拒绝；整组保留UID，拆并走原库存规则。喷剂余量、强化和涂层到期仍归物品实例。寄存物不计作随身施法/制造材料；已放下的背包不能远程存取，穿戴物需先卸下。

F焦点与交互提交检查墙体视线，不提供隔墙读书、开箱或操作工作台。过期回调不能离区转移物资。室内路标沿用同一追踪结构，不新建任务权威。

## 边界

这是三处接入真实流程的首批地图单元，未实现全村跨建筑生活模拟、租房收费、偷窃司法、NPC跨区上下班、昼夜门锁、坐椅子、容器重生或程序生成室内。后续应沿同一空间和服务边界扩充，避免增加只显示文字的家具入口。

验证见[地图验证](TOWN_MAP_CELLS_VALIDATION.md)。架构继续遵循Godot4.6[场景组织与依赖注入](https://github.com/godotengine/godot-docs/blob/4.6/tutorials/best_practices/scene_organization.rst)。
