class_name GrayriverValidator
extends RefCounted
static func validate(raw: Dictionary) -> Array[String]:
	var errors: Array[String]=[]
	var source:=ExplorationContentCatalog.new()
	var recipes:=CastingSupplies.new().crafting_recipes
	var ids:Dictionary={}
	var enemy_ids:Dictionary={}
	for i in range(raw.get("regions",[]).size()):
		var region:Dictionary=raw.regions[i]
		var field:="%s.regions[%d]"%[GrayriverDefinition.PATH,i]
		if ids.has(region.id):errors.append(field+".id: duplicate '"+str(region.id)+"'")
		ids[region.id]=true
		for j in range(region.get("notes",[]).size()):
			var note:Dictionary=region.notes[j]
			for id in note.get("crafts",[]):
				if not recipes.has(id):errors.append(field+".notes[%d].crafts: unknown '%s'"%[j,id])
			if note.has("template"):
				var parts:=str(note.template).split("/")
				var found:=false
				if parts.size()==2 and source.regions.has(parts[0]):
					for original in source.regions[parts[0]].discoveries:
						if original.id==parts[1]:found=true
				if not found:errors.append(field+".notes[%d].template: unknown '%s'"%[j,note.template])
		for encounter in region.get("encounters",[]):
			if encounter.has("character"):
				var key:=str(encounter.character)
				if not key.is_valid_identifier() or not ResourceLoader.exists("res://content/characters/river_%s.tres"%key): errors.append(field+".encounters.character: unknown '"+key+"'")
			var id:=str(encounter.get("id",""))
			if id.is_empty() or enemy_ids.has(id):errors.append(field+".encounters.id: missing/duplicate '"+id+"'")
			enemy_ids[id]=true
			var profile:=str(encounter.get("profile","guard"))
			if not profile.is_valid_identifier() or not ResourceLoader.exists("res://content/exploration/enemies/%s.tres"%profile):errors.append(field+".encounters.profile: unknown '"+profile+"'")
		for collection in ["notes","encounters","stations","puzzles","facilities","exits","valves","events","deliveries","props"]:
			for j in range(region.get(collection,[]).size()):
				var point:Vector2=GrayriverDefinition.vector(region[collection][j].pos)
				if not point.is_finite() or absf(point.x)>float(region.size[0])*.5-30 or absf(point.y)>float(region.size[1])*.5-30:errors.append(field+".%s[%d].pos: outside region"%[collection,j])
	# The first exit is the return chain used by multi-floor map projection.
	for region in raw.get("regions",[]):
		if region.id=="camp": continue
		var chain: Dictionary={}
		var current: Dictionary=region
		while current.id!="camp":
			var exits: Array=current.get("exits",[])
			if chain.has(current.id) or exits.is_empty():
				errors.append(str(region.id)+".exits[0]: return chain must reach camp without cycles")
				break
			chain[current.id]=true
			if not exits[0].get("required_claims",[]).is_empty(): errors.append(str(current.id)+".exits[0]: return route must be unconditional")
			var parents: Array=raw.regions.filter(func(r: Dictionary): return r.id==exits[0].target)
			if parents.is_empty():
				errors.append(str(current.id)+".exits[0]: missing return region")
				break
			current=parents[0]
	return errors
