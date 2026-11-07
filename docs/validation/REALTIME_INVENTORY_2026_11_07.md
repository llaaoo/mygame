# 实时选材与行囊验证

2026-11-07。实现边界见[实时交互架构](../REALTIME_INVENTORY.md)，操作见[键表](../CONTROL_SCHEME.md)。本轮沿用地图、敌人、配方、角色默认属性和预算，没有增加外部素材。

## 实测

云端Godot 4.6.3、Linux Xorg dummy、OpenGL compatibility / Mesa llvmpipe软件渲染，隔离数据/配置/缓存新档。`test_realtime_interaction.gd`通过真实Godot键鼠事件执行；正常AI、100HP/60MP上限及默认再生保留。知识、少量物资和接近守林兵的位置是明确受控夹具，不能据此声称自然首玩或战斗平衡通过。

| 项目 | 观察结果 |
|---|---|
| M点击与中键按住 | 指定Q火石阵，确认无消费/施法；中键改Q霜盐，旧松键不触发；R与E绑定独立 |
| 实际组合 | Q布阵8MP+火石1份；R在阵内触发火球12MP，首次组合共20MP；共用冷却未因选材重置 |
| 输入边界 | 确认与真正的新R按键在同帧仅提交一次；原UI松键不补发；轮盘保持防御朝向，可移动、闪避取消 |
| 喷洒 | 显式固定毒剂UID；最终归档图形样本1个脉冲2MP/1剂，原3剂瓶余2剂。开轮盘停止，已付不退；滚轮选另一同名3剂瓶，原瓶余量不变；再选清水瓶不改Q |
| 身体与鼠标管理 | 实际拖拽盾到副手，显示实际主副手；输入数量2转移炭屑，右键菜单键盘确认丢1；9穿戴槽完整 |
| 落地与拾取 | 清水瓶整件丢弃生成真实容器，原快捷实物不可用；F打开地面袋，点击拾回保留原UID/3剂 |
| 完整界面实时性 | 0.55秒失衡在开背包0.8秒后恢复，库存世界时钟推进；作者配置守林兵的近身站位夹具在2.8秒开背包暴露中造成24HP伤害，告警出现 |
| 保存与小窗口 | 实际save_3写盘、销毁游戏再进入，逐槽来源相同；800×600物理窗口完整显示行囊 |

专项`inventory_lifecycle`另用受控静止夹具验证满包穿戴/交换/拒绝卸下、直接丢装备、满包拾取失败不损失、拆分数量守恒、喷剂2剂与武器涂层期限跨真实保存/重进、跨区卸载/挂载、超距与已放下背包拒绝，以及异常坐标拒绝。该测试不提供AI手感证据。

专项`slot_materials`验证两个水引槽独立固定霜盐/雷晶粉、7/9MP真实预览、实际生成冰面、只扣目标槽材料、不加料选项覆盖旧全局修饰、技能实例不变及保存重进。

## 回归与证据

验证代码提交`950119d0b40391a34a99929f6b866acac4c7450e`。使用`git archive`导出到`/tmp/mygame-realtime-final-6whprsl1`，导出时确认无`.godot`。完整回归入口为`python3 tools/run_tests.py --suite all --jobs 3 --timeout 120`。

- 最终干净归档首次导入通过（8.9秒），完整 **77/77** 通过；日志`/tmp/mygame-tests-_obkekkx`。
- 同一归档原生图形`realtime_interaction`通过，退出0；日志`/tmp/grayriver-first30/realtime-final-archive/runtime.log`，截图`/tmp/realtime-ui-final-archive`。首次组合8+12MP、喷剂1脉冲2MP/1剂、开背包24HP受伤。
- 无授予/无瞬移的新档`visual_interface`在生产代码相同的`b18bf15`归档原生图形通过：真实WASD走到手册、F阅读、鼠标K编组、M选材取消、13槽滚动、地图与小窗口，日志`/tmp/grayriver-first30/realtime-natural-ui-archive/runtime.log`。后续提交只调整测试脚本。
- 原生图形仅出现驱动不支持VSync切换的警告，无脚本错误；无头runner严格将脚本错误、警告及非零退出判失败。

补充：早一次图形归档复测在闪避松键后的短动作状态断言失败。检查将闪避输入移至安全站位、在接受帧检查动作与体力支付，等待其自然结束后再设置近身AI暴露样本，避免把进行中的闪避/敌人接近准备混入菜单检查。未修改AI、闪避时长、角色属性或放宽资源规则；最终归档与图形均使用修正后的脚本。

## 覆盖限制

真实输入在云端Linux原生窗口内注入Godot输入系统，覆盖GUI命中、焦点、拖拽和游戏请求链；不是人工长时间试玩、实体鼠标驱动/系统热键、Windows/macOS或目标硬件性能验收。界面未暂停世界由时钟、恢复和正常AI命中分别证明。火阵组合费用样本不等于同档战斗平衡比较；本轮没有重新作自然首30分钟通关或扩展剧情/关卡。

GitHub Actions继续只保留在`.github/disabled-workflows/`，云端验证不启动Actions。

## 截图

截图属于上述正常模拟、受控物资/知识的操作样本；最后一张来自无授予的新档手册流程。

- [实时轮盘：资源与快捷栏保留可见](../review/realtime-inventory/material-wheel.png)
- [真实纸娃娃与数量管理](../review/realtime-inventory/paper-doll.png)
- [背包打开时仍受伤](../review/realtime-inventory/live-menu-under-attack.png)
- [800×600窗口](../review/realtime-inventory/small-inventory.png)
- [新档读手册后缺料明确显示](../review/realtime-inventory/natural-newgame-sources.png)
