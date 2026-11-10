# 插件接入与测试诊断验证

2026-11-10，Linux云端，Godot 4.6.3，原生Xorg dummy/Mesa llvmpipe。

## 已完成的定向验证

- `python3 -m unittest tools/test_run_tests.py -v`：7项通过，包含零退出码脚本错误、带ANSI的警告、非零退出、超时、导入失败、前置失败/跳过、空/失败/待定JUnit结果、继承输入探针识别与同一检出目录竞争锁。使用伪引擎注入失败，证明runner会报错；不代表游戏验收。
- `python3 tools/run_tests.py --tests gut_domain foundation_inventory world_depth_knowledge --timeout 300`：3/3通过，逐项日志无脚本错误/引擎错误/警告。GUT含9个用例、35条断言；两个原有集成检查继续验证真实装备/交易与统一知识/身份/保存。
- 原生Godot编辑器：独立XDG目录，从`Project → Tools → GUT → Run All`发出实际X11鼠标输入。预先把项目`.gutconfig.json`复制到该隔离编辑器的GUT配置目录，没有修改测试状态或库存。显示2脚本、9/9用例、35断言通过，插件结果文件记录errors/failures/orphans/pending均0。见`gut-native-editor.png`与`gut-editor-results.json`。
- GUT上游版本/引擎匹配经已连接GitHub插件查询。逐文件散列通过`sha256sum --check docs/dependencies/gut-9.6.1.sha256`校验；唯一本地补丁关闭默认自动联网更新，测试断言未修改。

## 平台和覆盖限制

当前会话未提供桌面js/计算机控制工具；Cloud Environment状态支持远程桌面，但观察状态unknown。实际编辑器使用现成Xorg/Mesa，截图来自该窗口，不把它称作通过ChatGPT桌面桥控制。编辑器在结果采集后停止，日志不是“进程正常退出0”的证明。

原生编辑器启动有驱动不支持V-Sync的警告，以及尝试初始化Vulkan时缺少`VK_KHR_surface`的两条错误；随后Compatibility/OpenGL窗口可用、GUT可运行。本轮没有把这些平台诊断隐藏或称为编辑器日志全绿。关闭自动联网检查后，不再出现此前`[GUT] Could not get version info, response code: 0`的启动错误；修前日志亦保留。

本轮没有改游戏战斗、AI、存档规则，也没有新增自然游玩/2小时内容量/目标设备性能验收。GUT领域检查补充现有集成测试，不能替代后者。已存插件和已接通ChatGPT连接器分开登记于[开发工具](../../DEVELOPMENT_TOOLS.md)。GitHub Actions保持停用。

## 完整归档回归

最终归档来源、首次导入与完整runner结果在运行结束后追加；未完成前不将定向通过写成全量通过。
