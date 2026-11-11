extends SceneTree
## Invalid append/assignment diagnostics belong to this isolated child process.
func _initialize() -> void:
	var state:=SerializedStateChartState.new();state.name=&"root"
	var child:=SerializedStateChartState.new();child.name=&"child";child.active=true
	state.children.append(child)
	var property: Dictionary={}
	for entry: Dictionary in state.get_property_list():
		if entry.name=="children":property=entry
	if property.get("hint")!=PROPERTY_HINT_TYPE_STRING or property.get("hint_string")!="24/17:SerializedStateChartState":quit(1);return
	if state.children.get_typed_script()!=state.get_script():quit(1);return
	state.children.append(Resource.new())
	state.children=[Resource.new()]
	if state.children.size()!=1 or state.children[0]!=child:quit(1);return
	var path:="user://state-chart-resource-probe.tres"
	if ResourceSaver.save(state,path)!=OK:quit(1);return
	var restored:=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE) as SerializedStateChartState
	if not restored or restored.name!=&"root" or restored.children.size()!=1:quit(1);return
	var nested:=restored.children[0] as SerializedStateChartState
	if not nested or nested.name!=&"child" or not nested.active or restored.children.get_typed_script()!=restored.get_script():quit(1);return
	print("PASS state chart resource guard: nested values, typed append/assignment rejection and Inspector hint")
	quit()
