extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var arguments:=OS.get_cmdline_user_args()
	var path:="";var output:=""
	for arg in arguments:
		if arg.begins_with("--scene="): path=arg.trim_prefix("--scene=")
		if arg.begins_with("--report="): output=arg.trim_prefix("--report=")
	var report: Dictionary
	if path.is_empty(): report=MapAuthoringAudit.catalog_report()
	else:
		var scene:=load(path) as PackedScene
		var instance: Node=scene.instantiate() if scene else null
		if instance is AuthoredMapCell: report=MapAuthoringAudit.cell_report(instance)
		else: report={"errors":["Expected AuthoredMapCell: "+path]}
		if instance: instance.free()
	if not output.is_empty():
		var file:=FileAccess.open(output+".tmp",FileAccess.WRITE)
		if file:
			var summary: Dictionary={"errors":report.errors,"scene":path}
			for key in ["cells","passages","arrivals"]: summary[key]=report.get(key,0)
			file.store_string(JSON.stringify(summary));file.close()
			DirAccess.rename_absolute(output+".tmp",output)
	for message in report.errors: push_error(message)
	if report.errors.is_empty(): print("Map authoring passed: %d cells, %d passages, %d named arrivals; content identities, references, geometry and runtime navigation"%[report.cells,report.passages,report.arrivals])
	quit(0 if report.errors.is_empty() else 1)
