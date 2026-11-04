class_name CommandBus
extends Node
## CommandBus — 跨 Runtime 边界的异步命令总线
##
## 规则:
## 1. 谁产生事件，谁 emit
## 2. 谁处理，谁 subscribe
## 3. 同步请求/查询走公开接口；需要延迟的世界工作走此队列
## 4. 异步（不保证同帧处理）

## 最大队列大小（超出丢弃旧命令）
const MAX_QUEUE_SIZE := 128

var _queue: Array[RuntimeCommand] = []
var scope_id := 1
## {String cmd_type: Array[Dictionary{"target": Target, "callback": Callable}]}
var _subscribers: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## 发送命令（入队）
func emit(cmd: RuntimeCommand) -> void:
	if cmd.scope_id == 0:
		cmd.scope_id = scope_id
	if cmd.scope_id != scope_id:
		return
	if _queue.size() >= MAX_QUEUE_SIZE:
		_queue.pop_front()
	_queue.append(cmd)


## 订阅命令类型（广播模式——接收所有 target 的命令）
func subscribe(cmd_type: String, callback: Callable) -> void:
	subscribe_for_target(cmd_type, RuntimeCommand.Target.ALL, callback)


## 订阅命令类型 + 指定目标 Runtime（定向订阅）
func subscribe_for_target(cmd_type: String, target: RuntimeCommand.Target, callback: Callable) -> void:
	if not _subscribers.has(cmd_type):
		_subscribers[cmd_type] = []
	var entry := {"target": target, "callback": callback}
	_subscribers[cmd_type].append(entry)


## 取消订阅
func unsubscribe(cmd_type: String, callback: Callable) -> void:
	if not _subscribers.has(cmd_type):
		return
	var entries: Array = _subscribers[cmd_type]
	for i in range(entries.size() - 1, -1, -1):
		if entries[i]["callback"] == callback:
			entries.remove_at(i)


## 处理队列（由 GameRuntime._process 驱动）
func dispatch(max_per_tick: int = 16) -> void:
	var processed := 0
	while _queue.size() > 0 and processed < max_per_tick:
		var cmd: RuntimeCommand = _queue.pop_front()
		if cmd.scope_id == scope_id:
			_dispatch_one(cmd)
		processed += 1

func finish_region() -> void:
	# Keep persistent world facts; discard combat/simulation work owned by the old region.
	# A destroyed object may enqueue follow-up transient work while recording its state.
	var processed := 0
	while not _queue.is_empty() and processed < MAX_QUEUE_SIZE * 4:
		var command: RuntimeCommand = _queue.pop_front()
		if command.scope_id == scope_id and command.target == RuntimeCommand.Target.WORLD:
			_dispatch_one(command)
		processed += 1
	_queue.clear()
	scope_id += 1


func _dispatch_one(cmd: RuntimeCommand) -> void:
	var entries: Array = _subscribers.get(cmd.type, [])
	for entry: Dictionary in entries:
		var sub_target: int = entry["target"]
		# ALL 订阅者接收所有命令，定向订阅者仅接收匹配 target
		if sub_target == RuntimeCommand.Target.ALL or sub_target == cmd.target:
			var cb: Callable = entry["callback"]
			if cb.is_valid():
				cb.call(cmd)


func _to_string() -> String:
	var total := 0
	for entries: Array in _subscribers.values():
		total += entries.size()
	return "CommandBus(queue=%d, subs=%d)" % [_queue.size(), total]
