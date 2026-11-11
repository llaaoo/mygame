# 动作可靠性与内容预检

本批处理项目审查中优先级最高的操作一致性和制作边界，沿用现有地图、敌人、配方、费用和物资预算。

## 本批实现

| 问题 | 当前处理 | 负责边界 |
|---|---|---|
| 投瓶虚线只看墙，实弹还会撞角色 | 预览与每段飞行共用mask 11、投掷者排除及2单位碰撞偏移 | `ThrowTrajectory`、`ItemActionController.aim_endpoint()`、`ThrownDose` |
| 物品拒绝或喷洒中断只有通用提示/无提示 | 请求返回具体原因；途中中断经现有玩家动作反馈；主动结束静默 | `OperationResult`、物品/喷洒执行器、Session请求适配、`ActorActionController` |
| 坏JSON、短坐标或模板缺失可在校验前被装配 | 结构与资源预检先行；失败返回空章节及字段诊断 | `GrayriverDefinition`、`GrayriverValidator`、地图/内容检查工具 |
| 交易输入测试依赖名称拼接价格 | 可见控件稳定身份＋真实鼠标；价格独立从领域查询，核对双方库存与事实 | `InputSceneProbe`、商店/课程/K页控件、`test_depth_input` |

反馈沿用同一玩家HUD通道及短去重窗口，不新增全局消息总线。已提交的投瓶/喷剂费用不退款；成功提交不会误报取消，选定实物失效不换用另一件。原bool请求保留兼容，结构化结果逐层传递到玩家入口。

预检只负责安全装配所需的原始形状、引用和基本约束；装配后仍运行完整领域验证。定义Resource保持共享只读，不增加存档格式或第二份内容权威。

实际灰河谷入口也先检查原始内容：坏JSON或字段结构错误显示可滚动的启动诊断，停用角色与存档快捷输入，不调度战役bootstrap、不选槽/加载旅程。编辑器检查当前地图时，目录中的空场景项会作为错误保留，不能跳过后误报成功。

## 验证入口与边界

```sh
python3 tools/run_tests.py --tests content maps content_preflight item_actions spray_channel throw_trajectory_input item_feedback_input depth_input unified_quickslots --jobs 2
python3 tools/run_tests.py --suite all --jobs 2
```

投瓶与反馈测试使用隔离存档、受控实物/位置和真实键鼠事件；碰撞对照使用静止碰撞体。世界模拟与远处原有AI继续运行，但这些测试不代表自然新档通关、战斗平衡、动态目标预测或目标设备性能。预览反映当前场景，敌人仍可能在飞行期间移动。图形检查使用云端Linux的Godot原生窗口，不能代替最终设备体验。

实测日志、截图、冻结源码版本与完整回归结果归档于[验证记录](playtests/reliable-actions/REPORT.md)。后续再深化内容制作流程、学习路径和多次远征经济，本批不扩展地图与内容数量。
