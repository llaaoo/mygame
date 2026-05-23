class_name RuntimeCommand
extends RefCounted
## RuntimeCommand — 跨 Runtime 边界的异步命令
## 所有 Runtime 之间的通信必须走 CommandBus，禁止直接调用

enum Target {
	COMBAT,        ## CombatRuntime
	WORLD,         ## WorldRuntime
	SIMULATION,    ## SimulationRuntime
	UI,            ## UIRuntime
	SAVE,          ## SaveRuntime
	ALL,           ## 广播
}

var type: String = ""           ## "HIT_REQUEST" / "DESTROYED" / "SURFACE_CHANGE" / "RESPAWN" / "CHUNK_LOAD"
var source: String = ""         ## 发起 Runtime 名称
var target: Target = Target.ALL ## 目标 Runtime
var payload: Dictionary = {}    ## 数据
var timestamp: int = 0          ## Time.get_ticks_msec()


static func create(cmd_type: String, src: String, tgt: Target, data: Dictionary = {}) -> RuntimeCommand:
	var cmd := RuntimeCommand.new()
	cmd.type = cmd_type
	cmd.source = src
	cmd.target = tgt
	cmd.payload = data
	cmd.timestamp = Time.get_ticks_msec()
	return cmd


func _to_string() -> String:
	return "RuntimeCommand(%s | %s → %s | %s)" % [type, source, Target.keys()[target], payload]
