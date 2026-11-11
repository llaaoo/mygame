class_name GrayriverValidator
extends RefCounted
## Raw authoring boundary. Never compile a chapter while validating its source.
const COLLECTIONS := ["notes", "encounters", "stations", "patches", "puzzles", "facilities", "exits", "valves", "events", "deliveries", "props"]
const ENTRY_TYPES := {
	"id":TYPE_STRING,"title":TYPE_STRING,"pos":TYPE_ARRAY,"template":TYPE_STRING,
	"text":TYPE_STRING,"intro":TYPE_STRING,"description":TYPE_STRING,"kind":TYPE_STRING,
	"requires_clear":TYPE_BOOL,"heal":TYPE_BOOL,"irreversible":TYPE_BOOL,
	"clean":TYPE_BOOL,"lit":TYPE_BOOL,"boss":TYPE_BOOL,"optional":TYPE_BOOL,
	"materials":TYPE_DICTIONARY,"rewards":TYPE_DICTIONARY,"harvest":TYPE_DICTIONARY,
	"actions":TYPE_ARRAY,"equipment":TYPE_ARRAY,"crafts":TYPE_ARRAY,"leads":TYPE_ARRAY,
	"required_claims":TYPE_ARRAY,"routes":TYPE_ARRAY,"work":TYPE_ARRAY,"methods":TYPE_ARRAY,
	"assembly":TYPE_DICTIONARY,"choices":TYPE_ARRAY,"paths":TYPE_ARRAY,
	"presentation_profile":TYPE_STRING,"profile":TYPE_STRING,"character":TYPE_STRING,
	"tactics":TYPE_STRING,"group":TYPE_STRING,"target":TYPE_STRING,"scene":TYPE_STRING,
	"service":TYPE_STRING,"hint":TYPE_STRING,"completion_text":TYPE_STRING,
	"already_text":TYPE_STRING,"locked_message":TYPE_STRING,"state":TYPE_STRING,
	"disabled_by_claim":TYPE_STRING,"cleaned_by_claim":TYPE_STRING,
	"arrival":TYPE_ARRAY,"heat_offset":TYPE_ARRAY,"reading_margin":TYPE_FLOAT,
	"hp":TYPE_FLOAT,"speed":TYPE_FLOAT,"detect_range":TYPE_FLOAT,
	"radius":TYPE_FLOAT,"duration":TYPE_FLOAT,"regeneration_hours":TYPE_FLOAT,
}
static func validate(raw: Variant, path := "res://content/frontier/grayriver.json") -> Array[String]:
	var errors: Array[String]=[]
	if not raw is Dictionary: return [path+": expected an object"]
	if not _required(raw,["regions","roads","quests","landmarks"],path,errors): return errors
	_types(raw,{"regions":TYPE_ARRAY,"roads":TYPE_ARRAY,"quests":TYPE_ARRAY,"landmarks":TYPE_ARRAY},path,errors)
	if not errors.is_empty(): return errors
	var regions:=_objects(raw.regions,path+".regions",errors)
	for i in regions.size():
		var region: Dictionary=regions[i]
		var field:="%s.regions[%d]"%[path,i]
		_required(region,["id","title","description","size","entry"],field,errors)
		_types(region,{"id":TYPE_STRING,"title":TYPE_STRING,"description":TYPE_STRING,"size":TYPE_ARRAY,"entry":TYPE_ARRAY,"open_field":TYPE_BOOL,"room_type":TYPE_STRING,"presentation_environment":TYPE_STRING},field,errors)
		_point(region.get("size"),field+".size",errors,true)
		_point(region.get("entry"),field+".entry",errors)
		if region.has("presentation_environment"): _resource(region.presentation_environment,EnvironmentProfile,field+".presentation_environment",errors)
		for collection in COLLECTIONS:
			if not region.has(collection): continue
			var entries:=_objects(region[collection],field+"."+collection,errors)
			for j in entries.size(): _entry(entries[j],collection,"%s.%s[%d]"%[field,collection,j],errors)
		for j in _objects(region.get("obstacles",[]),field+".obstacles",errors).size():
			var obstacle: Dictionary=region.obstacles[j]
			var at:="%s.obstacles[%d]"%[field,j]
			_required(obstacle,["position","size","kind"],at,errors)
			_types(obstacle,{"kind":TYPE_STRING},at,errors)
			_point(obstacle.get("position"),at+".position",errors)
			_point(obstacle.get("size"),at+".size",errors,true)
	for i in raw.roads.size():
		var road: Variant=raw.roads[i]
		var at:="%s.roads[%d]"%[path,i]
		if not road is Array: errors.append(at+": expected an array"); continue
		for j in road.size(): _point(road[j],at+"[%d]"%j,errors)
	for collection in ["landmarks","quests"]:
		var entries:=_objects(raw[collection],path+"."+collection,errors)
		for i in entries.size():
			var entry: Dictionary=entries[i]
			var at:="%s.%s[%d]"%[path,collection,i]
			_required(entry,["id","title","description"],at,errors)
			_types(entry,{"id":TYPE_STRING,"title":TYPE_STRING,"description":TYPE_STRING,"points":TYPE_FLOAT},at,errors)
			if collection=="landmarks": _point(entry.get("pos"),at+".pos",errors)
			else:
				_required(entry,["required_claims","points"],at,errors)
				for key in ["required_claims","required_clears","unlock_claims","discovery_claims"]:
					if entry.has(key): _strings(entry[key],at+"."+key,errors)
	# Structural/resource errors must stop before indexing fields or resolving templates.
	if not errors.is_empty(): return errors
	var source:=ExplorationContentCatalog.new()
	var recipes:=CastingSupplies.new().crafting_recipes
	var ids: Dictionary={};var enemy_ids: Dictionary={}
	for i in regions.size():
		var region: Dictionary=regions[i]
		var field:="%s.regions[%d]"%[path,i]
		if region.id.is_empty() or ids.has(region.id): errors.append(field+".id: missing/duplicate '"+region.id+"'")
		ids[region.id]=region
		for j in region.get("notes",[]).size():
			var note: Dictionary=region.notes[j]
			for id in note.get("crafts",[]):
				if not recipes.has(id): errors.append(field+".notes[%d].crafts: unknown '%s'"%[j,id])
			if note.has("template"):
				var parts:=str(note.template).split("/")
				var found:=false
				if parts.size()==2 and source.regions.has(parts[0]):
					for original in source.regions[parts[0]].discoveries:
						if original.id==parts[1]: found=true
				if not found: errors.append(field+".notes[%d].template: unknown '%s'"%[j,note.template])
		for j in region.get("encounters",[]).size():
			var encounter: Dictionary=region.encounters[j]
			var id: String=encounter.id
			if id.is_empty() or enemy_ids.has(id): errors.append(field+".encounters[%d].id: missing/duplicate '%s'"%[j,id])
			enemy_ids[id]=true
		for collection in COLLECTIONS:
			for j in region.get(collection,[]).size():
				var point:=Vector2(float(region[collection][j].pos[0]),float(region[collection][j].pos[1]))
				if absf(point.x)>float(region.size[0])*.5-30 or absf(point.y)>float(region.size[1])*.5-30: errors.append(field+".%s[%d].pos: outside region"%[collection,j])
	# Return-chain semantics follow raw structure checks; no typed-resource build recursion.
	for region in regions:
		if region.id=="camp": continue
		var chain: Dictionary={};var current: Dictionary=region
		while current.id!="camp":
			var exits: Array=current.get("exits",[])
			if chain.has(current.id) or exits.is_empty(): errors.append(str(region.id)+".exits[0]: return chain must reach camp without cycles"); break
			chain[current.id]=true
			if not exits[0].get("required_claims",[]).is_empty(): errors.append(str(current.id)+".exits[0]: return route must be unconditional")
			if not ids.has(exits[0].target): errors.append(str(current.id)+".exits[0]: missing return region"); break
			current=ids[exits[0].target]
	return errors

static func _entry(entry: Dictionary, collection: String, field: String, errors: Array[String]) -> void:
	var before:=errors.size()
	_types(entry,ENTRY_TYPES,field,errors)
	_point(entry.get("pos"),field+".pos",errors)
	var required: Array=["id","title"]
	match collection:
		"notes": required.append("text")
		"encounters": required=["id"]
		"exits": required=["title","target"]
		"patches": required=["state","radius","duration"]
		"props": required=["id","scene"]
		"deliveries": required.append_array(["description","methods"])
		"events": required.append_array(["text","choices"])
		"valves": required.append("paths")
		"puzzles": required=[] if entry.has("template") else ["id","title","hint","routes"]
		"facilities": required=[] if entry.has("template") else ["id","title","service","requires_clear","description","assembly"]
	_required(entry,required,field,errors)
	for key in ["required_claims","actions","equipment","crafts"]:
		if entry.has(key): _strings(entry[key],field+"."+key,errors)
	for key in ["materials","rewards","harvest"]:
		if entry.has(key): _amounts(entry[key],field+"."+key,errors)
	for key in ["arrival","heat_offset"]:
		if entry.has(key): _point(entry[key],field+"."+key,errors)
	# Remaining consumers require these fields' verified primitive types.
	if errors.size()!=before: return
	if entry.has("presentation_profile"): _resource(entry.presentation_profile,WorldAnimationProfile,field+".presentation_profile",errors)
	if collection=="encounters":
		for key in ["character","profile","tactics"]:
			if key=="profile" or entry.has(key):
				var name: String=entry.get(key,"guard")
				var path: String={"character":"res://content/characters/river_%s.tres","profile":"res://content/exploration/enemies/%s.tres","tactics":"res://content/tactics/territories/%s.tres"}[key]%name
				if not name.is_valid_identifier(): errors.append(field+"."+key+": invalid resource name '"+name+"'")
				else:
					var type: Variant=ActorCharacterData if key=="character" else ExplorationEnemyProfile if key=="profile" else EncounterTactics
					_resource(path,type,field+"."+key,errors)
	if collection in ["puzzles","facilities"] and entry.has("template"):
		_resource("res://content/exploration/%s.tres"%entry.template,SpellPuzzleData if collection=="puzzles" else RepairFacilityData,field+".template",errors)
	if collection=="props": _resource("res://world/object/%s.tscn"%entry.scene,PackedScene,field+".scene",errors)
	for key in ["methods","work"]:
		if entry.has(key):
			var methods:=_objects(entry[key],field+"."+key,errors)
			for i in methods.size(): _method(methods[i],field+".%s[%d]"%[key,i],errors)
	if entry.has("assembly"): _method(entry.assembly,field+".assembly",errors)
	if entry.has("routes"):
		var routes:=_objects(entry.routes,field+".routes",errors)
		for i in routes.size():
			var at:=field+".routes[%d]"%i
			_types(routes[i],{"id":TYPE_STRING,"required_surface":TYPE_STRING,"hold_seconds":TYPE_FLOAT},at,errors)
			_strings(routes[i].get("steps",[]),at+".steps",errors)
	if entry.has("leads"):
		var leads:=_objects(entry.leads,field+".leads",errors)
		for i in leads.size(): _types(leads[i],{"region":TYPE_STRING,"claim":TYPE_STRING},field+".leads[%d]"%i,errors)
	if entry.has("choices"):
		var choices:=_objects(entry.choices,field+".choices",errors)
		for i in choices.size():
			var at:=field+".choices[%d]"%i
			_required(choices[i],["id","title","text"],at,errors)
			_types(choices[i],{"id":TYPE_STRING,"title":TYPE_STRING,"text":TYPE_STRING},at,errors)
			_strings(choices[i].get("grants_claims",[]),at+".grants_claims",errors)
	if entry.has("paths"):
		var paths:=_objects(entry.paths,field+".paths",errors)
		for i in paths.size():
			var at:=field+".paths[%d]"%i
			_required(paths[i],["title","points"],at,errors)
			_types(paths[i],{"title":TYPE_STRING,"points":TYPE_ARRAY},at,errors)
			if paths[i].get("points") is Array:
				for j in paths[i].points.size(): _point(paths[i].points[j],at+".points[%d]"%j,errors)
static func _method(method: Dictionary, field: String, errors: Array[String]) -> void:
	_required(method,["id","title","duration"],field,errors)
	_types(method,{"id":TYPE_STRING,"title":TYPE_STRING,"animation_id":TYPE_STRING,"duration":TYPE_FLOAT},field,errors)
	_amounts(method.get("material_costs",{}),field+".material_costs",errors)
static func _required(raw: Dictionary, keys: Array, field: String, errors: Array[String]) -> bool:
	var before:=errors.size()
	for key in keys:
		if not raw.has(key): errors.append(field+"."+str(key)+": required field")
	return errors.size()==before
static func _types(raw: Dictionary, fields: Dictionary, field: String, errors: Array[String]) -> void:
	for key in fields:
		if not raw.has(key): continue
		var kind: int=fields[key]
		if kind==TYPE_FLOAT:
			if typeof(raw[key]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(raw[key])): errors.append(field+"."+str(key)+": expected a finite number")
		elif typeof(raw[key])!=kind: errors.append(field+"."+str(key)+": expected "+type_string(kind))
static func _objects(value: Variant, field: String, errors: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var valid:=true
	if not value is Array: errors.append(field+": expected an array"); return result
	for i in value.size():
		if not value[i] is Dictionary:
			errors.append(field+"[%d]: expected an object"%i); valid=false
		else: result.append(value[i])
	if not valid: result.clear()
	return result
static func _strings(value: Variant, field: String, errors: Array[String]) -> void:
	if not value is Array: errors.append(field+": expected an array of strings"); return
	for i in value.size():
		if not value[i] is String: errors.append(field+"[%d]: expected a string"%i)
static func _point(value: Variant, field: String, errors: Array[String], positive := false) -> void:
	if not value is Array or value.size()!=2: errors.append(field+": expected exactly two coordinates"); return
	for i in 2:
		if typeof(value[i]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value[i])) or positive and float(value[i])<=0: errors.append(field+"[%d]: expected a finite%s number"%[i," positive" if positive else ""])
static func _amounts(value: Variant, field: String, errors: Array[String]) -> void:
	if not value is Dictionary: errors.append(field+": expected an amount object"); return
	for key in value:
		if not key is String or typeof(value[key]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value[key])) or float(value[key])!=floorf(float(value[key])): errors.append(field+"."+str(key)+": expected an integer amount")
static func _resource(path: Variant, expected: Variant, field: String, errors: Array[String]) -> void:
	if not path is String or not ResourceLoader.exists(path): errors.append(field+": missing resource '"+str(path)+"'"); return
	var resource:=load(path)
	if not is_instance_of(resource,expected): errors.append(field+": unexpected resource type at '"+path+"'")
