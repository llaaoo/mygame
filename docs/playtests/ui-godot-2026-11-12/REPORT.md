# Godot UI核心路径验证

当前记录对应 `codex/godot-ui-vertical`。实际实现范围见[接入说明](../../UI_GODOT_IMPLEMENTATION.md)。

- 真实输入夹具：`tests/test_ui_vertical_input.gd`；正常模拟/AI，明确物资、知识、觉醒和位置。
- Linux / Godot4.6.3 / Xorg + gl_compatibility + Mesa llvmpipe；Dummy音频。
- 原型浏览器验收与本轮Godot验收分开保留，不用旧234项浏览器检查代替游戏验证。
- 原生指针事件经窗口坐标换算，几何/命中/返回与磁盘重进由实际结果判定。
- 不构成自然新档通关、目标硬件帧率、真人效率或声音体验验收。

最终原生输入 **89项断言全部通过，进程退出0**。[结果](native-verification.json) · [日志](native-input.log) · [源码与图像散列](manifest.json)。四种尺寸的实际窗口与逻辑视口均与请求相同，见JSON。

[小窗绑定13槽](binding-960x540-125.png) · [小窗比较](comparison-960x720-125.png) · [大窗比较](comparison-1440x900-125.png) · [完整绑定](binding-1920x1080-125.png) · [世界HUD](world-960x540.png) · [当前形式](current-form-world.png) · [物品查看](item-inspection.png)

一次原生检查因复用前轮觉醒测试档被“普通旅人无MP”断言拒绝；最终运行使用全新独立XDG目录，没有复制旧档或放宽判定。反向Tab检查发现展开重建后焦点丢失，已按同UID/操作身份恢复。原生与headless坐标不同，图形输入按窗口变换后发送真实指针事件；没有调用按钮回调代替点击。

## 干净归档全套与验收更新

执行提交 `4785b724b38b0528b19ebc4d8bd16da7fefe504b` 的全新 `git archive`，无`.godot`缓存；runner首次导入成功。运行 `python3 tools/run_tests.py --suite all --jobs 2 --source-revision 4785b724b38b0528b19ebc4d8bd16da7fefe504b`，最终 **157/159，退出1**，保留[原始JSON](archive-all-results.json)，没有改写失败为通过。新增Godot UI专项89项断言、正常AI受击、实物余量、跨区、存档、成长与NPC检查均通过。

两项失败都需要更新旧验收：

- `animation_demo_input`：动作/方向已正确，暂停时进度仍为0；时间轴位于ScrollContainer裁剪之外，测试没有像按钮 helper 那样先滚动到目标。新增显式滚入和裁剪范围断言，再发送原来的真实70%/99%点击，保留原进度和原生rig断言。
- `visual_interface`：原断言要求空闲隐藏整个施法摘要，与本次确认的“当前形式保持可见”冲突。改为从普通新档亲手点击R、返回，核对真实CastPlan结果/费用及零消费，不再用旧显示要求否定新功能。

游戏执行代码在两项验收更新前后保持不变。更新后的提交 `5b8d9bfa498be47321f617825bba74ddb51b24ca` 再从无`.godot`的`git archive`首次导入，执行 `python3 tools/run_tests.py --tests animation_demo_input visual_interface --jobs 1 --source-revision 5b8d9bfa498be47321f617825bba74ddb51b24ca`，**2/2通过、退出0**。[定向JSON](corrected-acceptance-results.json) · [时间轴真实点击日志](corrected-animation_demo_input.log) · [普通新档显示日志](corrected-visual_interface.log)。日志中时间轴进度大于50%，三组原生rig方向均为6，原进度/方向断言保留。

严格核对两次提交差异只有文档及这两个测试脚本，游戏执行代码与本轮原生图形验证相同。因此159个检查均有该执行代码下的有效通过结果，来源逐项见[覆盖映射](coverage.json)。这不是一次159/159绿色全套运行；原始157/159/退出1结果仍如实保留，修订只做了匹配的定向复测，没有重跑未受影响的157项。GitHub Actions保持停用。
