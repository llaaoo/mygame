# 编辑器插件本地清理补丁

2026-11-11，Godot 4.6.3。保留上游许可与版本；下列为本项目局部修正，不冒称上游更新。

## Godot MCP

服务器的工具表持有指向DebugToolsNative的Callable，后者持有服务器并订阅其日志信号，形成RefCounted引用环。普通transport stop继续保留工具以支持重新启动；最终plugin退出另调用dispose，断开订阅、释放工具与配置实例、停止未成功启动的transport，并移除Engine中的plugin元数据。既有新鲜消息/错误判断不变。

## State Charts 0.22.4

`SerializedStateChartState.children`原先在共享脚本默认值中声明自类型数组，数组的元素类型又保留该GDScript，导致脚本在实例释放后仍留在内存。将数组的自类型约束移到实例初始化，保留完全相同的Inspector属性hint（23、`24/17:SerializedStateChartState`）、存储字段名和运行时TypedArray检查；setter拒绝不合法的整数组赋值且保留旧值。已有嵌套`.tres`仍可读取、保存并重新加载。没有改变状态机时序或状态数据。

真实独立子进程检查无效append/assignment被拒绝，诊断保留在该测试数据目录`expected-state-child-rejection.log`；这类故意错误不混入正常游戏日志。

## 实测边界

隔离副本中，verbose启用插件编辑器退出原有6个资源泄漏（5个MCP脚本、1个State Charts脚本）；修正后，等待启动完成的120帧退出不再报告资源或ObjectDB泄漏。立即`--quit`仍可能留下GUT原有一秒启动SceneTreeTimer，这与已修复的六个资源引用不同，未屏蔽其诊断。

另外，正常24名AI、相同检查场景在独立聚焦窗口与headless模式中原先均约6–7 FPS，排除了将低帧率简单归因于嵌入窗口或软件渲染。隔离回调计时定位为隐藏敌人状态标签反复设置中文文本的排版开销；距离门控移到投影之前、本地构造后仅在变化时赋值，生命/法力条绘制与AI、模拟时钟仍按原规则运行。详细最终数据以本轮试玩报告为准。
