class_name ExplorationContentCatalog
extends RefCounted
var chapter: ExplorationChapterData
var regions: Dictionary = {}
var actions: Dictionary = {}
var spell_rules: Dictionary = {}

func _init(definition: ExplorationChapterData = null) -> void:
	chapter = definition if definition else load("res://content/exploration/chapter.tres") as ExplorationChapterData
	for region in chapter.regions:
		if region:
			regions[region.id] = region
	for action in chapter.actions:
		if action:
			actions[action.get_id()] = action
	for rule in chapter.spell_rules:
		if rule:
			spell_rules[rule.id] = rule
