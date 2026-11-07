# 2026-11-07 灰河谷UI与视觉改造验证

## 实现范围

统一字体、线性图标、颜色、按钮与滚动样式；HUD收拢资源和情境信息；Tab侧栏导航、K三栏编组、工作台配方详情、M来源选择与规则展开。更新草地、道路细节、树、建筑、场景设施、水面、色调与角色身体，装备仍来自实际穿戴。

新增素材24个文件的散列已核对，许可、作者、实际下载路径、修改和字体体积见[素材清单](../../content/art/THIRD_PARTY_ASSETS.md)。

## 实际键鼠与GUI

- `visual_interface`：隔离新档，正常AI、默认属性、无授予物品/知识、无瞬移。通过WASD真正走到镇中手册，以F阅读，再用M选择喷洒介质、选择树脂喷洒，核对选择不扣实物；K显示新学动作，13槽可独立滚动；G地图、Tab、Esc、800×600窗口布局。
- 同一测试在headless完成，日志`/tmp/mygame-tests-9mzw8nz9/visual_interface.log`。Xorg/OpenGL兼容GUI版本`/tmp/grayriver-first30/ui-natural-accepted/runtime.log`退出0；逐项检查日志无脚本错误/运行错误，只有Mesa驱动不支持VSync切换的已知平台警告。
- `controls_workflow`的GUI版本验证独立E/1、鼠标菜单、键位文本编辑、K入口、真实附近工作台、原料扣除、快捷物品使用/取消、改键与重置、目标距离重验、鼠标不穿透攻击。使用显式夹具原料和工作台位置，恢复正常AI；这部分不是无干预自然流程。日志`/tmp/grayriver-first30/ui-overhaul-complete/runtime.log`，退出0，只有同一VSync平台警告。
- 最终相关headless检查：`content`、`visual_interface`、`controls_workflow`通过，`/tmp/mygame-tests-1e0tbb65`；自然手册与M选材扩展后的`visual_interface`也通过，`/tmp/mygame-tests-9mzw8nz9`。
- `ui_system`保留长正文换行与滚轮、多个窗口大小、焦点跳过禁用项、Esc、锁定模态和引导/蓄力取消；`unified_quickslots`与`world_pointer_input`继续验证实际混合槽位输入、保存和点击归属。

图形平台为云端Linux、Godot4.6.3、Xorg dummy、Mesa llvmpipe软件渲染；不是Windows/macOS原生高DPI或目标显卡性能验收。实际观察了渲染截图，测试脚本可重现，非设计稿。

## 场景构图检查

另用隔离实例、正常AI和属性，在镇中建筑、河桥、林地设置镜头位置截帧；此类受控位置只核对图集、绘制顺序和布局，不作为自然探索/路线安全/战斗平衡证明。脚本`/tmp/grayriver-art-tour.gd`，日志`/tmp/grayriver-first30/ui-art-tour/runtime.log`，退出0且只有VSync平台警告。建筑后续将重复门面改为单门多窗；最终场景截图按交付版本重新获取。

## 源码归档回归

当前记录对应实现阶段。最终已提交源码的无缓存`git archive`完整回归、截图路径和交付提交将在归档完成后填写，未完成前不以中间绿项宣称全量通过。GitHub Actions保持停用。
