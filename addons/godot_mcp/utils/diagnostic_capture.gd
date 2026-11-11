@tool
extends Logger
## Synchronous tool scope. Runtime/script errors must not become successful MCP replies.
var _mutex := Mutex.new()
var _active := false
var _failed := false
var _messages: Array[String]=[]
var _diagnostics: Array[Dictionary]=[]
const LIMIT := 200

func begin() -> void:
	_active=true
	OS.add_logger(self)

func finish(result: Dictionary={}) -> Dictionary:
	OS.remove_logger(self)
	_mutex.lock()
	_active=false
	var output: Array=_messages.duplicate()
	output.append_array(result.get("output",[]))
	result["output"]=output
	result["diagnostics"]=_diagnostics.duplicate(true)
	result["success"]=bool(result.get("success",true)) and not _failed
	if _failed and not result.has("error"):
		result["error"]="Script execution reported an engine or script error."
	_mutex.unlock()
	return result

func _log_message(message: String,_error: bool) -> void:
	_mutex.lock()
	if _active and _messages.size()<LIMIT:_messages.append(message.trim_suffix("\n"))
	_mutex.unlock()

func _log_error(function: String,file: String,line: int,code: String,rationale: String,_editor_notify: bool,error_type: int,_script_backtraces: Array[ScriptBacktrace]) -> void:
	_mutex.lock()
	if _active:
		if error_type!=Logger.ERROR_TYPE_WARNING:_failed=true
		if _diagnostics.size()<LIMIT:
			_diagnostics.append({"function":function,"file":file,"line":line,"message":rationale if not rationale.is_empty() else code,"type":error_type})
	_mutex.unlock()
