# 河谷镇地图与室内验证

2026-11-10（上海），Godot4.6.3，云端Linux。规则和编辑说明见[地图与室内](TOWN_MAP_CELLS.md)。

针对性检查已通过：三处房门与返门、所有交互可达、场景编辑与Resource不变、无效变换拒绝、错放交互点不删墙、独立室内NPC/库存、进入不治疗、公共容器耗尽不补、喷剂UID/余量、满箱回滚、墙体与过期回调拒绝、实际存档和室内路标恢复、门边落点保留。

`town_cells_input`通过真实键鼠覆盖F进入三处室内、寄存/取出/再存已使用喷剂、与苇娘交谈买卖、客床真实休息一小时并消费补给、柴灶、G室内/全图切换与960×600窗口、F5后重新进入、工作台实际制火石、阅读公署文书及回到正确门口。位置与部分喷剂物资为受控夹具，正常AI和模拟继续，不当作默认新档验收。

## 提交归档与原生界面

玩法提交`e93df9cc8d6105fe051bed321912bde44eb10484`导出为无`.godot`的`git archive`副本。执行`python3 tools/run_tests.py --suite all --jobs 3`：首次导入退出0，**127/127通过**，runner最终退出0。见[完整回归](playtests/town-map-cells/archive-all.log)、[地图领域日志](playtests/town-map-cells/domain-towns.log)。

同归档在Xorg原生窗口运行`town_cells_input`，退出0；前述键鼠、交易、休息、存取、室内/全图、小窗口及保存重进均通过。位置与喷剂仍为显式夹具。见[运行日志](playtests/town-map-cells/native-input.log)、[启动结果](playtests/town-map-cells/native-runner.log)、[输入录像](playtests/town-map-cells/native-input.mp4)。

- [客栈实景](playtests/town-map-cells/inn-common-room.png)、[门口](playtests/town-map-cells/town-inn-door.png)、[店主交谈](playtests/town-map-cells/innkeeper-conversation.png)。
- [部分使用喷剂的实物详情](playtests/town-map-cells/storage-actual-instance.png)、[真实补给交易](playtests/town-map-cells/inn-real-provision-trade.png)、[按小时休息](playtests/town-map-cells/inn-hourly-rest.png)、[柴灶](playtests/town-map-cells/inn-cooking.png)。
- [室内地图](playtests/town-map-cells/inn-local-map.png)、[960×600地图](playtests/town-map-cells/inn-local-map-small.png)、[作坊实际制造](playtests/town-map-cells/workshop-real-crafting.png)、[公署文书](playtests/town-map-cells/records-readable-directory.png)。

## 默认新档：76步实际输入与第二进程重进

同归档、独立新档，用[已提交路线](../tools/playtests/town_cells_journey.json)沿实际WASD路径走完整流程：读手册/领口粮、读门牌、绕房屋到客栈、过卧室门洞寄存、取用、睡眠、实物买卖、离开并走到作坊制造，再进入公署阅读、查看地图并保存。没有发物资/经验、传送或关闭AI。路线是已知地图引导的集成输入，不是盲玩。

|核对项|实测结果|
|---|---|
|客栈寄存|存炭屑7，分两次取出各1；箱内剩5，保留原堆UID`item.79`|
|客床|默认1小时休息完成；实际扣烤饼1、清水1并推进持久时钟|
|苇娘买卖|出售谷粮2得2币，再支付2币购买烤饼1；店主最终仍16币，烤饼6→5、谷粮4→6|
|作坊|口袋炭屑2、晶砂1制火石1；寄存箱内5炭屑不参与扣料|
|最终随身|火石1、饮用水3、烤饼2、谷粮1、晶砂8；炭屑耗尽|
|公署|已阅读门址与行路图；没有远程发现林下档案窖|
|最终地点|河谷公署，约(-190.57,-64.17)，游戏时钟第1天10:12|

随后将该局游戏生成的存档交给第二个Godot进程，精确比较口袋、背包、装备、快捷槽、遗骸、NPC账户、交谈记忆、成长、追踪、武技、全部固定容器，并比较已到地区和世界事实集合，全部一致。两个进程均退出0。见[整局摘要](playtests/town-map-cells/town-cells-summary.json)、[比较结果](playtests/town-map-cells/journey-reentry-comparison.log)、[完整路线日志](playtests/town-map-cells/journey-runtime.log)、[第二进程](playtests/town-map-cells/reentry-runtime.log)。

默认预算证据：[门牌指路](playtests/town-map-cells/01-town-directions.png)、[箱内剩余](playtests/town-map-cells/03-real-storage-remainder.png)、[工作台制造](playtests/town-map-cells/06-workshop-crafting.png)、[公署阅读](playtests/town-map-cells/07-records-readable.png)、[最终保存](playtests/town-map-cells/09-town-cells-saved.png)、[第二进程重进](playtests/town-map-cells/journey-reloaded.png)。

## 平台与覆盖边界

[Godot编辑器实景](playtests/town-map-cells/godot-inn-editor.png)确认场景树、Inspector、家具和交互圈可预览。使用同源码的临时副本，仅在副本关闭原有编辑器插件；没有修改正式项目插件配置。该平台编辑器辅助Vulkan探测报告缺少`VK_KHR_surface`，2D Compatibility视图仍可使用；小字号场景注释显示异常，编辑器预览不计作文字可读性验收。见[编辑器日志](playtests/town-map-cells/editor-preview.log)。游戏的真实UI文字验证和127项回归独立于编辑器预览，未将预览当作玩法通过。

云端Linux、Godot4.6.3、X11/Compatibility、Mesa软件渲染；驱动不支持切换VSync，其警告与玩法脚本错误分开记录。本轮原生游戏运行未出现脚本错误。测试不证明目标设备性能、盲玩易用性或两小时内容量；10:12是包含睡眠跳时的游戏时钟。新地图仍为首批三处单元，未实现跨区域NPC日程、偷窃司法、门锁或租房经济。

GitHub Actions保持停用。
