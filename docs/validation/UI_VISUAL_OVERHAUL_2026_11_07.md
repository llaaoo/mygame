# 2026-11-07 灰河谷UI与视觉改造验证

## 实现范围

统一字体、线性图标、颜色、按钮与滚动样式；HUD收拢资源和情境信息；Tab侧栏导航、K三栏编组、工作台配方详情、M来源选择与规则展开。更新草地、道路细节、树、建筑、场景设施、水面、色调与角色身体，装备仍来自实际穿戴。

新增素材24个文件的散列已核对，许可、作者、实际下载路径、修改和字体体积见[素材清单](../../content/art/THIRD_PARTY_ASSETS.md)。

## 实际键鼠与GUI

- `visual_interface`：隔离新档，正常AI、默认属性、无授予物品/知识、无瞬移。通过WASD真正走到镇中手册，以F阅读，再用M选择喷洒介质、选择树脂喷洒，核对选择不扣实物；K显示新学动作，13槽可独立滚动；G地图、Tab、Esc、800×600窗口布局。
- 同一测试在headless完成，最终日志`/tmp/mygame-tests-n1_qpzdn/visual_interface.log`。从最终代码归档运行的Xorg/OpenGL兼容GUI版本`/tmp/grayriver-first30/ui-shipping-review/runtime.log`退出0；逐项检查日志无脚本错误/运行错误，只有Mesa驱动不支持VSync切换的已知平台警告。
- `controls_workflow`的GUI版本验证独立E/1、鼠标菜单、键位文本编辑、K入口、真实附近工作台、原料扣除、快捷物品使用/取消、改键与重置、目标距离重验、鼠标不穿透攻击。使用显式夹具原料和工作台位置，恢复正常AI；这部分不是无干预自然流程。最终代码归档版本日志`/tmp/grayriver-first30/ui-shipping-controls/runtime.log`，退出0，只有同一VSync平台警告。
- 最终相关headless检查：`content`、`visual_interface`、`controls_workflow`通过，`/tmp/mygame-tests-1e0tbb65`；自然手册与M选材扩展后的`visual_interface`也通过，`/tmp/mygame-tests-9mzw8nz9`。
- `ui_system`保留长正文换行与滚轮、多个窗口大小、焦点跳过禁用项、Esc、锁定模态和引导/蓄力取消；`unified_quickslots`与`world_pointer_input`继续验证实际混合槽位输入、保存和点击归属。

图形平台为云端Linux、Godot4.6.3、Xorg dummy、Mesa llvmpipe软件渲染；不是Windows/macOS原生高DPI或目标显卡性能验收。实际观察了渲染截图，测试脚本可重现，非设计稿。

## 场景构图检查

另用隔离实例、正常AI和属性，在镇中建筑、河桥、林地设置镜头位置截帧；此类受控位置只核对图集、绘制顺序和布局，不作为自然探索/路线安全/战斗平衡证明。脚本`/tmp/grayriver-art-tour.gd`，最终代码归档日志`/tmp/grayriver-first30/ui-shipping-art/runtime.log`，退出0且只有VSync平台警告。建筑为单门多窗；截图已按交付代码归档重新获取。

## 源码归档回归

被验证的完整代码提交：`3688a2a3744a5b38012176d66830f528aa954ec7`。从`git archive HEAD`导出至`/tmp/mygame-ui-cold-3688a2a`，导出后断言无`.godot`缓存，然后运行：

```bash
python3 /tmp/mygame-ui-cold-3688a2a/tools/run_tests.py --suite all --jobs 3
```

首次导入通过，最终 **74/74** 检查通过；日志`/tmp/mygame-tests-n1_qpzdn`，runner记录`/tmp/visual-cold-verified.log`。没有脚本错误、运行错误或警告；不是只读取中途进度。后续提交只归档本记录与截图，未改代码。

初次归档发现项目级自定义Theme会在字体导入前加载，报字体缓存缺失。已改为HUD/远征UI进入树时将Theme安装到Window，再从全新的无缓存归档重新验证；没有把第二次热导入当作首次导入通过。

全部新增素材24个文件的体积与SHA-256核对通过；58个本地文档链接和`git diff --check`通过。GitHub Actions工作流仍放在`.github/disabled-workflows/`，没有启用或触发工作流。远端main在准备合并时为`ff743dbf4797ebb89ecf950cb3fd87d873cbfe74`，无保护及必需检查，仓库rulesets为空；PR交付前另查提交检查状态。

## 截图

以下为实际游戏渲染，受控构图明确单列：

| 场景 | 截图 |
|---|---|
| 正常新档HUD | [world-hud.png](../review/ui-overhaul/world-hud.png) |
| Tab远征菜单 | [expedition-menu.png](../review/ui-overhaul/expedition-menu.png) |
| 正常读手册后K编组 | [quickslot-binder.png](../review/ui-overhaul/quickslot-binder.png) |
| M选择树脂喷洒后的拒绝原因与费用 | [material-selection.png](../review/ui-overhaul/material-selection.png) |
| 工作台加工后真实余量 | [workbench.png](../review/ui-overhaul/workbench.png) |
| 800×600菜单 | [small-window.png](../review/ui-overhaul/small-window.png) |
| 镇中建筑，受控构图 | [town-architecture.png](../review/ui-overhaul/town-architecture.png) |
| 林地，受控构图 | [forest.png](../review/ui-overhaul/forest.png) |
| 河桥，受控构图 | [river-bridge.png](../review/ui-overhaul/river-bridge.png) |
