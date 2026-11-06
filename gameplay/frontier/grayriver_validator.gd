class_name GrayriverValidator
extends RefCounted
static func validate(raw: Dictionary) -> Array[String]:
	var errors: Array[String]=[]
	var source:=ExplorationContentCatalog.new()
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
				if id not in CastingSupplies.MATERIAL_IDS:errors.append(field+".notes[%d].crafts: unknown '%s'"%[j,id])
			if note.has("template"):
				var parts:=str(note.template).split("/")
				var found:=false
				if parts.size()==2 and source.regions.has(parts[0]):
					for original in source.regions[parts[0]].discoveries:
						if original.id==parts[1]:found=true
				if not found:errors.append(field+".notes[%d].template: unknown '%s'"%[j,note.template])
		for encounter in region.get("encounters",[]):
			if encounter.has("character") and encounter.character not in GrayriverItems.CHARACTER_IDS: errors.append(field+".encounters.character: unknown '"+str(encounter.character)+"'")
			var id:=str(encounter.get("id",""))
			if id.is_empty() or enemy_ids.has(id):errors.append(field+".encounters.id: missing/duplicate '"+id+"'")
			enemy_ids[id]=true
			if encounter.get("profile","guard") not in ["guard","hunter","sentry"]:errors.append(field+".encounters.profile: unknown '"+str(encounter.profile)+"'")
		for collection in ["notes","encounters","stations","puzzles","facilities","exits","valves","events","deliveries","props"]:
			for j in range(region.get(collection,[]).size()):
				var point:Vector2=GrayriverDefinition.vector(region[collection][j].pos)
				if not point.is_finite() or absf(point.x)>float(region.size[0])*.5-30 or absf(point.y)>float(region.size[1])*.5-30:errors.append(field+".%s[%d].pos: outside region"%[collection,j])
	return errors
