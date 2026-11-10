# Godot MCP：实际连接与隔离检查

本项目已有`addons/godot_mcp`。当前会话使用项目内Python客户端直接连接原生HTTP MCP桥；不是假设ChatGPT已注册了Godot内建工具，也不依赖Node.js或付费AI接口。脚本与游戏规则仍以Git源码和真实运行结果为准。

## 启动与发现

```sh
# 启动正常Godot编辑器并显式开启本地MCP桥；不要和完整回归同时运行
godot --editor --path . -- --mcp-server

python3 tools/godot_mcp.py info
python3 tools/godot_mcp.py list
python3 tools/godot_mcp.py call get_project_info
```

本轮实连地址为`http://127.0.0.1:9080/mcp`；可用`--url`或`GODOT_MCP_URL`指定实际地址。插件配置版本为1.0.0，握手`serverInfo.version`为2.0.0；不要把两个标识混为插件升级。本轮没有升级上游插件，修改的是仓库内既有实现。

默认开放30个核心工具。先用`list`读取实际schema，再按需启用已注册的高级工具：

```sh
python3 tools/godot_mcp.py enable audit_project_health get_runtime_info \
  get_runtime_performance_snapshot get_runtime_scene_tree call_runtime_node_method \
  evaluate_runtime_expression simulate_runtime_input_event get_runtime_screenshot

python3 tools/godot_mcp.py --timeout 45 call audit_project_health \
  --arguments '{"search_path":"res://gameplay","max_results":200}' --wait
```

`enable`仅调用本地插件的工具状态接口，并重新检查工具列表；不改变游戏知识、权限、库存或项目规则。连接状态与工具真实可用性分开判断。若本地桥启用了认证，用环境变量`GODOT_MCP_TOKEN`提供令牌，不把令牌写进仓库或截图。

## 运行真实世界，隔离正式存档

```sh
python3 tools/godot_mcp.py call run_project \
  --arguments '{"scene_path":"res://demos/mcp_inspection.tscn"}'

python3 tools/godot_mcp.py --timeout 30 call get_runtime_info --wait
python3 tools/godot_mcp.py --timeout 30 call get_runtime_performance_snapshot --wait
python3 tools/godot_mcp.py --timeout 30 call call_runtime_node_method \
  --arguments '{"node_path":"/root/MCPInspection","method_name":"query_profile","arguments":["sample-1"]}' --wait

python3 tools/godot_mcp.py call stop_project
```

检查场景继承真实灰河谷，只替换为`MemorySaveRepository`、关闭自动持久化并在受控空地起步；正常AI、真实消耗、默认知识和物资保持原规则，没有额外赠送演示装备。MCP运行探针仅挂在这个开发场景中，没有加入正式入口或存档。`query_profile`测量只读查询，不推进战斗或替玩家准备条件。必须检查`sample_id`、`has_focus`、交互物数量与运行场景，不能拿有焦点与无焦点的样本混比。

真实输入示例（按下之后还要发相应松开事件）：

```sh
python3 tools/godot_mcp.py call simulate_runtime_input_event --wait \
  --arguments '{"event":{"type":"key","keycode":73,"physical_keycode":73,"pressed":true}}'
python3 tools/godot_mcp.py call simulate_runtime_input_event --wait \
  --arguments '{"event":{"type":"key","keycode":73,"physical_keycode":73,"pressed":false}}'
python3 tools/godot_mcp.py call get_runtime_screenshot --wait \
  --arguments '{"save_path":"user://inspection.png"}'
```

`get_scene_tree`读编辑器场景；运行时树使用`get_runtime_scene_tree`。运行时`evaluate_runtime_expression`使用Godot的Expression，并非完整GDScript，不能假设支持自定义`class_name`类型判断。复杂只读检查使用检查场景中的明确方法。截图证明该平台可以显示，不证明自然通关、平衡或目标设备性能。

## 结果判定与修正的根因

- `pending`和`stale`不算新结果。`--wait`在服务端请求期限内轮询，不靠重新执行超时操作获得成功。未等待的待返回/旧数据退出码为3，错误为1，已完成结果为0。客户端校验JSON-RPC响应ID，保留会话头，并识别`isError`、`success=false`、`valid=false`和健康审查失败。
- 原探针在没有新消息时回退到旧缓存，并标成`success`。现在只用请求之后的消息序号完成请求；方法回复还匹配参数，表达式回复匹配节点，避免不同调用混用。
- 原脚本审查剥掉`class_name`后匿名编译，使`CampaignSession`自身类型和`WorldCondition.Knowledge`失去原身份。编辑器里普通非`@tool`脚本的`can_instantiate`也不能代表编译有效。现在保存的文件在隔离Godot运行进程批量检查，保留真实路径，不重载编辑器中的活动脚本。
- 审查worker异步返回，源文件散列变化时拒绝结果，30秒超时后终止；插件退出时取消未完成worker。独立XDG/Windows应用数据目录隔离自动加载配置，启动后立即恢复编辑器环境变量。请求、日志和结果留在`.godot/mcp-validation/`，不进版本库。编译结果和进程退出状态都需有效；不完整报告不能算成功。
- 未保存的命名脚本返回`requires_saved_context`，而不是伪造语法错误。匿名片段仍可检查。编辑器脚本执行仅支持同步语句，Logger捕获真实打印与引擎/脚本错误；运行时报错不能返回成功。脚本在报错前可能已修改编辑器，诊断捕获不等于事务回滚，修改后仍检查Git差异。

Godot 4.6 API依据：[Logger](https://docs.godotengine.org/en/4.6/classes/class_logger.html)、[Script](https://docs.godotengine.org/en/4.6/classes/class_script.html)。MCP不代替[统一回归流程](DEVELOPMENT_TOOLS.md)：先定向、关闭编辑器、稳定源码、提交归档、首次导入，再完整回归。GitHub Actions保持停用。
