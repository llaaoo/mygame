@tool
extends RefCounted
## Compile named files in their real resource context, never as anonymous stripped copies.
static var _jobs: Dictionary={}

static func diagnose(path: String,source: String,include_warnings: bool) -> Dictionary:
	var capture:=preload("res://addons/godot_mcp/utils/diagnostic_capture.gd").new()
	capture.begin()
	var checked:=context(path,source)
	var captured:=capture.finish()
	var errors: Array=[]
	var warnings: Array=[]
	for entry: Dictionary in captured.diagnostics:
		if int(entry.type)==Logger.ERROR_TYPE_WARNING:
			if include_warnings:warnings.append(entry)
		else:errors.append(entry)
	if checked.has("error"):errors.append({"line":0,"message":checked.error})
	elif not checked.compiled and errors.is_empty():errors.append({"line":0,"message":"Godot could not compile this script in its saved context."})
	return {"valid":errors.is_empty(),"errors":errors,"warnings":warnings,"error_count":errors.size(),"warning_count":warnings.size(),"validation_status":checked.get("validation_status","compiled")}

static func files(paths: Array,include_warnings: bool) -> Dictionary:
	if paths.is_empty():return {"results":{}}
	if not Engine.is_editor_hint():
		var results: Dictionary={}
		for path: String in paths:results[path]=diagnose(path,FileAccess.get_file_as_string(path),include_warnings)
		return {"results":results}
	# Non-tool scripts cannot instantiate in an editor. Validate in an isolated
	# runtime process rather than reloading live editor scripts or stripping names.
	var fingerprint: Array=[]
	for path: String in paths:
		if not FileAccess.file_exists(path):return {"error":"Script removed during validation: "+path}
		fingerprint.append(FileAccess.get_sha256(path))
	var key:=JSON.stringify([paths,include_warnings])
	if not _jobs.has(key):
		var folder:="res://.godot/mcp-validation/%d"%Time.get_ticks_usec()
		if DirAccess.make_dir_recursive_absolute(folder)!=OK:return {"error":"Cannot create validation workspace"}
		var request:=FileAccess.open(folder+"/request.json",FileAccess.WRITE)
		if not request:return {"error":"Cannot write validation request"}
		request.store_string(JSON.stringify({"paths":paths,"include_warnings":include_warnings}));request.close()
		var environment: Dictionary={}
		var keys: Array=["APPDATA","LOCALAPPDATA"] if OS.get_name()=="Windows" else ["XDG_DATA_HOME","XDG_CONFIG_HOME","XDG_CACHE_HOME"]
		for variable: String in keys:
			environment[variable]={"present":OS.has_environment(variable),"value":OS.get_environment(variable)}
			OS.set_environment(variable,ProjectSettings.globalize_path(folder+"/"+variable.to_lower()))
		var args:=PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--log-file",ProjectSettings.globalize_path(folder+"/worker.log"),"--script","res://addons/godot_mcp/native_mcp/script_validation_worker.gd","--",ProjectSettings.globalize_path(folder)])
		var pid:=OS.create_process(OS.get_executable_path(),args,false)
		for variable: String in environment:
			if environment[variable].present:OS.set_environment(variable,environment[variable].value)
			else:OS.unset_environment(variable)
		if pid<0:return {"error":"Cannot launch Godot validation worker"}
		_jobs[key]={"pid":pid,"folder":folder,"fingerprint":fingerprint,"deadline":Time.get_ticks_msec()+30000}
	var job: Dictionary=_jobs[key]
	if job.fingerprint!=fingerprint:
		if OS.is_process_running(job.pid):OS.kill(job.pid)
		_jobs.erase(key);return {"error":"Sources changed during validation; request a new audit"}
	if OS.is_process_running(job.pid):
		if Time.get_ticks_msec()>int(job.deadline):
			OS.kill(job.pid);_jobs.erase(key);return {"error":"Godot validation worker timed out","log":job.folder+"/worker.log"}
		return {"status":"pending","validation_status":"pending","log":job.folder+"/worker.log"}
	_jobs.erase(key)
	var code:=OS.get_process_exit_code(job.pid)
	var response: Variant=JSON.parse_string(FileAccess.get_file_as_string(job.folder+"/result.json")) if FileAccess.file_exists(job.folder+"/result.json") else null
	if code not in [0,1] or not response is Dictionary or not response.get("results") is Dictionary:
		return {"error":"Validation worker did not complete a valid report","exit_code":code,"log":job.folder+"/worker.log"}
	if response.results.size()!=paths.size():return {"error":"Incomplete validation report","log":job.folder+"/worker.log"}
	return response

static func cancel_jobs() -> void:
	for job: Dictionary in _jobs.values():
		if OS.is_process_running(job.pid):OS.kill(job.pid)
	_jobs.clear()

static func context(path: String,source: String) -> Dictionary:
	if not path.is_empty() and FileAccess.file_exists(path) and FileAccess.get_file_as_string(path)==source:
		if Engine.is_editor_hint():return {"error":"Saved scripts must be validated in the isolated runtime worker.","validation_status":"requires_runtime_validation"}
		var script:=load(path) as GDScript
		if script and script.source_code!=source:
			return {"error":"Script cache differs from disk; refresh the editor filesystem before validation.","validation_status":"requires_editor_reload"}
		return {"script":script,"compiled":script!=null and (script.can_instantiate() or script.is_abstract())}
	for line in source.split("\n"):
		if line.strip_edges().begins_with("class_name "):
			return {"error":"Named scripts require their saved project path and current editor cache; anonymous copies cannot validate self-referencing types.","validation_status":"requires_saved_context"}
	var script:=GDScript.new()
	script.source_code=source
	return {"script":script,"compiled":script.reload()==OK}
