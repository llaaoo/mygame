class_name HarvestProfile
extends Resource
@export var parts: Array[HarvestPart]=[]
func validation_errors() -> Array[String]:
	var errors: Array[String]=[];var seen: Dictionary={}
	for part in parts:
		if not part or not HarvestPart.valid(part.snapshot()) or seen.has(part.id): errors.append("Invalid/duplicate anatomical part")
		else: seen[part.id]=true
	return errors
func initialize(store: InventoryService,owner_id: String) -> void:
	var container:=owner_id+".anatomy"
	if store.has_container(container): return
	store.ensure_container(container,owner_id,"cache",maxi(1,parts.size()))
	for part in parts:
		store.receive_into(container,part.raw_item,1)
		for row in store.entries(container):
			if row.definition==part.raw_item and not row.properties.has("harvest"):
				var properties: Dictionary=row.properties.duplicate(true);properties["harvest"]=part.snapshot();store.set_properties(row.uid,properties);break
