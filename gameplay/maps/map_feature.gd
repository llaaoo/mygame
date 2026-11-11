@tool
class_name MapFeature
extends Node2D
## Position belongs to the scene. Compilation copies the Resource and sets pos.
@export var definition: Resource:
	set(value):
		definition=value
		queue_redraw()
static func collection_for(value: Resource) -> String:
	if value is ExplorationExitData: return "exits"
	if value is ExplorationDiscoveryData: return "discoveries"
	if value is SurvivalStationData: return "survival_stations"
	if value is MapAmenityData: return "amenities"
	if value is WorldStorageData: return "storage"
	if value is ExplorationEncounterData: return "encounters"
	if value is ExplorationPropData: return "fixed_props"
	if value is SpellPuzzleData: return "spell_objects"
	if value is ExplorationWorldEventData: return "events"
	if value is SurfaceValveData: return "valves"
	if value is SurfacePatchData: return "surface_patches"
	if value is DeliverySiteData: return "delivery_sites"
	if value is AwakeningSiteData: return "awakening_sites"
	if value is RepairFacilityData: return "facilities"
	return ""
func _draw() -> void:
	if not Engine.is_editor_hint(): return
	draw_circle(Vector2.ZERO,12,Color(.3,.75,.85,.3))
	draw_arc(Vector2.ZERO,80,0,TAU,40,Color(.3,.75,.85,.25),1)
	draw_line(Vector2(-16,0),Vector2(16,0),Color.SKY_BLUE,2)
	draw_line(Vector2(0,-16),Vector2(0,16),Color.SKY_BLUE,2)
	if definition is ExplorationEncounterData and is_finite(definition.detect_range) and definition.detect_range>0:
		draw_arc(Vector2.ZERO,definition.detect_range,0,TAU,64,Color(.9,.3,.2,.25),1)
	elif definition is SurfacePatchData and is_finite(definition.radius) and definition.radius>0:
		draw_circle(Vector2.ZERO,definition.radius,Color(.25,.65,.85,.15))
	if definition and "title" in definition:
		draw_string(GameUIStyle.font(),Vector2(-70,-22),str(definition.title),HORIZONTAL_ALIGNMENT_LEFT,240,14,Color.WHITE)
