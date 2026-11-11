# 操作、表现与工具整改验证

2026-11-11，北京时间；Godot 4.6.3、Linux云端。起点`d73f490`，包含上一轮尚未合并的MCP改动。最终源码提交、原生复测与干净归档全量结果在执行完成后登记；以下定向结果不等于全量已通过。

## 已执行的定向检查

- Python runner/MCP协议/引用审计共20项通过。
- GUT共21用例、168断言通过，包括统一配方登记、知识/库存隔离、MCP回调释放、State Charts嵌套保存/类型拒绝与离屏状态投影门控。故意的类型拒绝在隔离子进程执行，预期诊断留在其独立数据目录，不作为游戏错误。
- 综合17项定向中16项通过，新增的800×600逻辑视口检查发现说明面板最小字体高度超过预留空间，遮住径向选项；改为预留完整字体高度后，`selector_feedback_input`单独复测通过。原始失败报告与修后报告分开保存，没有重试掩盖失败。
- `accessibility_input`实际鼠标点击125%字号，检查普通控件、正文、HUD和失败写入保护；实际点击键位配置后按U，再用U开关地图，旧M不再开图。导航与日志提示、配置重新安装、世界时间和正常AI均检查。字号采用三个互斥按钮，减少额外下拉操作。最初新检查的弹出菜单键盘事件未能完成选择；已保留该开发失败记录，未声称修复整个引擎的PopupMenu输入。
- 既有`realtime_interaction/combat_choices_input/interface_navigation/world_feedback_input/field_work`均通过；武器`actor_animation/animation_demo_input/presentation_system`通过。配方与专业材料的`content_expansion/survival_needs/fieldcraft`通过。

开发过程中还修复了两类实际诊断：新类登记前漏做缓存导入，和武器涂层/WeakRef边界的Variant类型声明。补做recovery导入并修正类型后内容与地图前置通过；没有放宽编译、GUT或runner失败判定。

## 性能根因与隔离对照

诊断阶段用相同24名正常AI场景，只改变敌人状态显示路径。原生聚焦独立窗口与headless原先均约6–7 FPS；低处理器模式为false、max_fps为0。不能把低帧率全部归因于软件渲染、窗口失焦或地形。

两秒隔离采样中，EnemyCharacterStatus回调累计约1.57–1.77秒，其他主要回调明显更低。原先每次刷新都对隐藏中文Label多次追加text，付出排版成本。修后距离门控先于状态投影，字符串一次构造、仅变化时赋值；资源条、AI、Buff和世界时钟保持原行为。

隔离修后headless约141–145 FPS、原生软件渲染约33 FPS（约30.6–34.9ms帧）。场景、AI数量和节点数保持一致；这些是云端特定场景数据，不能视为所有地点或目标硬件的帧率保证。回调与前后日志保存在本目录。

## 插件生命周期

verbose已启动完成的编辑器退出原有6个资源泄漏，分别为MCP回调引用环和State Charts自类型默认数组；局部修后不再报告资源或ObjectDB泄漏。原始日志位于`/tmp/grayriver-diagnostics-20261111`，修后settled日志随本记录保存；补丁边界见[说明](../../dependencies/editor-cleanup-patches.md)。立即`--quit`仍可能暴露GUT的既有启动计时器，不当作相同问题被修复。

## 原生复测与完整回归

待代码冻结提交后，从无`.godot`的git archive执行首次导入、原生复测和`--suite all`。期间不得修改源码或并行运行其他Godot验证。最终以JSON报告的complete、失败诊断与进程状态判定，旧96/144的中断结果不作为本轮全量通过证据。

## 范围与限制

检查使用隔离数据目录与内存场景，控制位置、知识和物资的用例会明确记录夹具；没有改正式旅程、停止正常AI来提升帧率或修改费用平衡。并非自然首玩通关、战斗平衡或两小时内容验收。Figma工具的OAuth尚未接通，本轮没有Figma设计稿；Design Game Studio/Game Studio技能与Godot MCP按实际执行记录使用。手柄支持按用户要求暂缓，GitHub Actions保持停用。
