class_name CommandBus
extends Node
## CommandBus — 跨 Runtime 边界的异步命令总线
## 单例 (Autoload)，所有 Runtime 间的通信唯一通道
##
## 规则:
## 1. 谁产生事件，谁 emit
## 2. 谁处理，谁 subscribe
## 3. 不跨级调用
## 4. 异步（不保证同帧处理）

## 最大队列大小（超出丢弃旧命令）
const MAX_QUEUE_SIZE := 128

var _queue: Array[RuntimeCommand] = []
var _subscribers: Dictionary = {}  ## {String type: Array[Callable]}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## 发送命令（入队）
func emit(cmd: RuntimeCommand) -> void:
	if _queue.size() >= MAX_QUEUE_SIZE:
		_queue.pop_front()
	_queue.append(cmd)


## 订阅命令类型
func subscribe(cmd_type: String, callback: Callable) -> void:
	if not _subscribers.has(cmd_type):
		_subscribers[cmd_type] = []
	_subscribers[cmd_type].append(callback)


## 取消订阅
func unsubscribe(cmd_type: String, callback: Callable) -> void:
	if _subscribers.has(cmd_type):
		_subscribers[cmd_type].erase(callback)


## 处理队列（由 GameRuntime._process 驱动）
func dispatch(max_per_tick: int = 16) -> void:
	var processed := 0
	while _queue.size() > 0 and processed < max_per_tick:
		var cmd: RuntimeCommand = _queue.pop_front()
		_dispatch_one(cmd)
		processed += 1


func _dispatch_one(cmd: RuntimeCommand) -> void:
	var callbacks: Array = _subscribers.get(cmd.type, [])
	if cmd.target != RuntimeCommand.Target.ALL:
		# 定向命令也通知 ALL 订阅者，但标记 target
		pass
	
	for cb: Callable in callbacks:
		cb.call(cmd)


func _to_string() -> String:
	return "CommandBus(queue=%d, subs=%d)" % [_queue.size(), _subscribers.size()]
