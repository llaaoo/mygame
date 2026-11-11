# MCP项目审查与查询优化验证

2026-11-10，Godot 4.6.3，Linux云端Xorg/Mesa llvmpipe。当前会话通过`tools/godot_mcp.py`实际连接本地HTTP MCP桥，没有把未连接的ChatGPT插件算作已使用。

## 定向与原生检查

- Python runner与MCP协议检查合计15项通过：含RPC错误、响应ID、会话头、待返回/旧数据轮询、超时不重放、未开放工具拒绝、编译/执行失败识别。
- GUT 15用例、61断言通过：包含原有领域检查、新的真实命名类型上下文、旧消息不能完成新请求、重复打印捕获、库存格数守恒，以及真实Godot子进程的错误脚本夹具。故意的编译错误只在隔离子进程中产生，测试断言worker退出1、结果无效且有实际编译诊断；保留在该用例独立数据目录的`expected-compile-error.log`，不是未解决游戏错误。
- 定向`gut_domain/project_optimization/inventory_stability/rpg_progression_input/world_pointer_input`共5/5通过；新增交互检查沿实际导航和当前物体寻找安全空地，不依赖内容扩充后仍应空置的固定坐标。确认空样本200次查询只扫描一次，强制刷新及F键可以发现新目标，删除与移动使旧目标失效，背包打开仍推进世界时钟并保留正常AI。
- 原生MCP分别审查6个自有源码目录共409个脚本，未报告编译错误、缺失依赖或目录内循环引用。按目录结果和扫描边界分开记录，不把它说成全仓跨目录依赖图证明。
- 受控场景均为24名AI、95个交互物、空焦点，5轮完整标签查询从15024微秒变为413微秒。记录唯一sample_id并确认has_focus=false。该结果为查询微基准，不代表FPS提升；早期工具回退旧消息所得启动期FPS不作为对照数据。
- 经MCP发送I/P/F5/F9并截图：实际背包与成长页可打开，paused=false，世界时钟持续前进；仓库路径确认为`res://core/save/memory_save_repository.gd`。没有调用真实库存接口赠送物品、停止AI、直接触发UI回调或保存正式旅程。
- 故意执行缺失方法的编辑器脚本，实际MCP回复`isError=true/success=false`并给出文件/行号/诊断；打印两次相同字符串保留两次。此错误注入与正常游戏日志区分。

## 平台与覆盖限制

原生编辑器有V-Sync不受支持和Vulkan初始化缺少`VK_KHR_surface`的已知平台诊断，另记录了XServer的`BadWindow`；Compatibility/OpenGL仍可显示并完成输入与截图。运行子进程临时选择Dummy音频，没有把音频设备缺失当游戏脚本错误。软件渲染新鲜单次采样约6 FPS、147ms帧、5.8ms物理帧，尚不构成目标设备性能验收，也没有声称解决全部渲染瓶颈。

启用插件的普通首次导入和正常编辑器退出均报告6个资源仍被引用，进程退出码为0，尚未定位具体引用所有者；没有将其当作无诊断退出。随后另从相同提交重新导出无`.godot`副本，采用统一runner规定的`--recovery-mode`完成首次导入，退出0且无错误/警告。两类日志分别保留为`plugin-enabled-import.log/native-editor.log`与`recovery-import.log`。原生MCP批量检查曾触发每60秒100个RPC的默认限流；恢复额度后重新发起只读查询，未提高限额或重放修改。

检查场景在受控空地起步、默认知识/物资、内存保存；不是自然首玩路线、战斗平衡或2小时Demo验收。UI输入与截图证明当前平台可以交互，不替代真实保存恢复和全套领域验证。未连接的Figma/Context7/Superpowers未调用；Github Actions保持停用。

## 干净归档完整回归

被测源码提交为`71426a8f92aa5e302eee7c2a817512ccb8c5ab69`。另从`git archive`导出无`.godot`副本至`/tmp/grayriver-mcp-regression-71426a8`，recovery首次导入退出0，无错误/警告。运行命令为`taskset -c 0,1,2,3 python3 tools/run_tests.py --suite all --jobs 2 --timeout 300 --source-revision 71426a8 --report /tmp/grayriver-mcp-all-results.json`。回归期间没有改动源码，也没有启动其他Godot测试或图形编辑器；结束后核对归档与源码中的脚本/场景/Resource/Python文件一致。

完整回归被用户中断，最终报告`complete=false`：已完成96项全部通过，剩余48项未完成，未记录断言失败。日志保留于`/tmp/mygame-tests-olpe3tht`，归档报告为[all-results-interrupted.json](all-results-interrupted.json)。已完成全部3项前置、91项并行领域检查与`project_optimization/world_depth_input`两项串行输入检查；`fieldcraft_input`已开始但未生成完成结果。不能宣称144项全量通过。本轮因此没有推送、创建PR或合并；恢复交付前仍须完成统一全量回归。

提交`71426a8`的独立原生归档已复核同样409个脚本；新鲜样本`archive-71426a8-fresh`的焦点查询为325微秒，24名AI/95个交互物/空焦点。I/P实际输入后，背包与成长页均打开、paused=false，时钟由51.86推进到53.06，仓库路径为MemorySaveRepository；[背包截图](inventory.png)与[成长截图](growth.png)来自该提交归档。相关MCP回复使用`archive-`前缀保存；源提交与归档目录见`validation-source.json`。
