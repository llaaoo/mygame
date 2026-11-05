class_name ElementCatalog
extends RefCounted
const CORE_IDS := ["fire", "water", "lightning", "poison"]
const ASPECT_IDS := ["ice"]
const LEGACY_ELEMENTS := ["shadow", "arcane", "soul", "physical"]
static var _definitions: Array[ElementDefinition] = []
static var _aspects: Array[ElementDefinition] = []

static func all_definitions() -> Array[ElementDefinition]:
	if _definitions.is_empty():
		for id in CORE_IDS:
			_definitions.append(load("res://content/elements/%s.tres" % id) as ElementDefinition)
	return _definitions.duplicate()

static func definition(id: String) -> ElementDefinition:
	for entry in all_definitions() + all_aspects():
		if entry.id == id: return entry
	return null

static func all_aspects() -> Array[ElementDefinition]:
	if _aspects.is_empty():
		for id in ASPECT_IDS:
			_aspects.append(load("res://content/elements/%s.tres" % id) as ElementDefinition)
	return _aspects.duplicate()

static func family_id(id: String) -> String:
	var entry := definition(id)
	return entry.parent_id if entry and not entry.parent_id.is_empty() else id

static func family_definition(id: String) -> ElementDefinition:
	return definition(family_id(id))

static func aspects_for(id: String) -> Array[ElementDefinition]:
	var result: Array[ElementDefinition] = []
	for aspect in all_aspects():
		if aspect.parent_id == family_id(id): result.append(aspect)
	return result

static func is_core_element(id: String) -> bool:
	return id in CORE_IDS

static func is_element(id: String) -> bool:
	# Compatibility query for accepted elemental tags, including form-specific tags.
	return id in CORE_IDS or id in ASPECT_IDS or id in LEGACY_ELEMENTS

static func family_ids(tags: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for tag in tags:
		var id := family_id(tag)
		if is_element(tag) and id not in result: result.append(id)
	return result

static func affinity_label(tags: Array[String]) -> String:
	var names: Array[String] = []
	for id in family_ids(tags):
		var entry := definition(id)
		var title: String = entry.title if entry else {"shadow": "暗影", "arcane": "奥术", "soul": "魂", "physical": "物理"}.get(id, id)
		var forms: Array[String] = []
		for aspect in aspects_for(id):
			if aspect.id in tags: forms.append(aspect.title)
		names.append(title + ("·" + "／".join(forms) if not forms.is_empty() else ""))
	return "／".join(names)

static func can_affect(actor: Node, status: String) -> bool:
	if not is_instance_valid(actor): return false
	var buffs := actor.get_node_or_null("BuffManager") as BuffManager
	return buffs != null and not buffs.is_immune(status)
