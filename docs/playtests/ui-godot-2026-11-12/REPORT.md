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

最终专项和干净归档全套结果继续补充在此。GitHub Actions保持停用。
