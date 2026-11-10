# 地图制作验证

2026-11-10，北京时间。契约与操作见[MAP_AUTHORING](MAP_AUTHORING.md)。

## 最终提交归档

实现提交`daf111e17a37f2fe57835444d2d9ba97ed6ae89c`通过`git archive`导出无`.godot`副本。Godot4.6.3 Recovery模式、`taskset -c 0,1`首次导入退出0，无脚本错误或警告；[导入日志](playtests/map-authoring/cold-import.log)。

```sh
python3 tools/run_tests.py --suite all --jobs 3
```

最终 **132/132通过，退出0**，见[完整结果](playtests/map-authoring/archive-tests.log)。地图、内容、输入、存档、角色/成长、NPC/生产、状态、战斗和启动检查均包含在内；后续只归档文档和证据，没有再次修改运行代码。

较早全套为131/132，一项旧验证将`camp.exits[0]`当作档案窖。迁场景后合法的门排序改变，已改为按`archive.enter / archive.leave`稳定ID定位，而非限制作者的节点排序；地理来返、生命不补满的实际断言保留。最终全套重新导入后完整重跑，不将前次部分结果当作通过。

## 数据与制作检查

当前共同校验链涵盖 **5个场景地图、29条通路、9个命名落点**，其余历史区域仍参与章节连接与条件检查。新增`map_authoring`覆盖：

- 档案窖迁移前后的3名敌人、6项发现、身份、位置、角色/装备定义、知识、材料奖励、制造知识、湿地介质、碰撞尺寸和返程坐标，与[旧预算夹具](../tests/fixtures/archive_pre_scene_budget.json)一致。
- 未保存的入口节点移动能更新所有来门和默认出生点；重新读取原场景仍是原位置，叠加基底没有积累障碍或门。
- 缺失/空场景、悬空落点、错配返门、重复落点、锁住自己的返程均拒绝；错误保留来源场景/节点路径。
- 一整面墙封死道路时，即使目标坐标自身空旷也会报告不可达；真正开放通路后通过，使用实际RegionNavigation网格。
- 平移阀门预制组同时平移其通道，原Resource路径点不被修改。

见[制作检查](playtests/map-authoring/map-authoring.log)、[目录结果](playtests/map-authoring/map-catalog.log)、[实际地理来返](playtests/map-authoring/geographic-returns.log)。

## 原生地图试玩

同一最终归档在Xorg窗口运行`test_map_preview_input.gd`，Godot退出0。实际键鼠验证移动、M地图、F离开客栈/档案窖、F5/F9和重置所选地图。档案窖3名敌人均保持正常AI；没有授予演示装备或技能。

测试准备一份有标记的正式存档，使用受控位置/生命值验证读写与恢复，不当作盲测或自然预算通关。试玩不会读取该正式进度，F5/F9、换区、重置之后正式文件逐字节不变；重新打开正式游戏仍是原进度和真实文件仓库。地图试玩只使用MemorySaveRepository。

[原生输入日志](playtests/map-authoring/native-preview-input.log)、[退出结果](playtests/map-authoring/native-runner.log)、[本地地图](playtests/map-authoring/preview-local-map.png)、[客栈试玩](playtests/map-authoring/preview-inn-start.png)、[档案窖试玩](playtests/map-authoring/preview-archive-start.png)。

## 原生编辑器操作

从最终归档另复制编辑器工作副本，只启用本插件及临时观测探针，原有第三方编辑器插件不参与此项验证。探针记录可见控件矩形和选中节点，主要功能验证使用X11原生鼠标/键盘，不通过直接调用按钮回调证明可用。

错误夹具将客栈入口放入床体：点击“保存并检查当前地图”，显示出生点和来门落点阻挡；点击错误行后，编辑器实际选中`默认入口落点`。恢复场景后，点击检查显示5/29/9通过，再点击“保存并试玩当前地图”，实际启动独立客栈游戏。无效与有效案例的编辑器进程均退出0。

[原生按钮结果](playtests/map-authoring/editor-input-result.log)、[错误与实际选择](playtests/map-authoring/editor-error-selection.json)、[通过结果](playtests/map-authoring/editor-valid-result.json)、[阻挡诊断截图](playtests/map-authoring/editor-blocked-spawn.png)、[检查通过截图](playtests/map-authoring/editor-validation-passed.png)、[由按钮启动试玩](playtests/map-authoring/editor-isolated-play.png)。[错误案例完整日志](playtests/map-authoring/editor-invalid-map.log)保留预期领域错误；[有效案例完整日志](playtests/map-authoring/editor-valid-map.log)保留编辑器/游戏输出。

## 默认预算与独立进程重进

同最终归档运行[镇中76步输入](../tools/playtests/town_cells_journey.json)：正常新档步行、读手册、领物资、进客栈、寄存/取回、睡一小时、交易、制造火石、阅读公署文书并保存。正常AI，无传送、补发物品或属性修改；属于已知路线引导输入。

关闭第一个Godot进程，将实际生成的[存档](playtests/map-authoring/normal-route-save_3.sav)作为第二进程唯一起点。种子与原保存文件的SHA256均为`8b2a263f4c3462f29172ac017fb58b9fdadc9324ddf8fcad74a889d9b9eede1c`。

13组记录完全一致：口袋、背包、装备、快捷槽、战利品、NPC账户、关系、成长、追踪、武技、固定容器、已访地区与领取事实。箱内炭屑5份且UID仍为`item.79`；火石1、随身炭屑0、烤饼2、净水3、谷粮1、客栈老板钱币16。时钟继续推进，不要求两个进程的动态时间读数逐字节相同。

[比较结果](playtests/map-authoring/normal-reentry-result.log)、[状态摘要](playtests/map-authoring/normal-route-summary.json)、[76次输入](playtests/map-authoring/normal-route-input.log)、[首进日志](playtests/map-authoring/normal-route.log)、[第二进程日志](playtests/map-authoring/normal-reentry.log)、[重进截图](playtests/map-authoring/normal-reentry.png)。

## 平台与覆盖边界

环境为Linux、Godot4.6.3、X11/Compatibility、Mesa llvmpipe。游戏原生输入日志只有驱动不支持切换VSync的预期警告；编辑器另外报告缺少VK_KHR_surface的探测错误，仍使用Compatibility完成操作。编辑器副本使用Dummy音频与2个资源工作线程；没有据此做目标设备性能或完整第三方插件共存验收。

错误案例关闭编辑器时另有ObjectDB及1个Resource残留诊断，有效案例无该诊断；两个主功能案例都退出0。为区分插件与引擎生命周期，另禁用地图插件，仅用临时探针执行同样的标准EditorInterface节点选择。该对照在关闭时也出现“脚本文档尚未完成”及原生退出崩溃，退出-6，见[控制条件](playtests/map-authoring/editor-disabled-control.json)、[对照退出结果](playtests/map-authoring/editor-disabled-control-result.log)、[原生日志尾部](playtests/map-authoring/editor-disabled-control-tail.log)。对照不是鼠标输入验收，也不计作通过；不能据此定位精确引擎原因。本轮不宣称云端编辑器退出无泄漏/无崩溃。地图校验子进程的独立日志没有这些残留，独立游戏输入和完整回归也无该诊断。

本轮覆盖静态布局、连接、制作操作和已知路线，不代表任意地形/脚本均可自动生成，不替代战斗平衡或未知内容的盲测。历史室外内容仍渐进迁移，未扩写新任务或两小时冒险。GitHub Actions保持停用。
