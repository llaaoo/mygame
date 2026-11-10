class_name WorldStorageData
extends Resource
## Fixed, non-respawning inventory. Empty containers remain saved.
@export var id := ""
@export var title := ""
@export var pos := Vector2.ZERO
@export_range(1, 100) var capacity := 24
## Empty means explicitly public; otherwise only this actor may transfer goods.
@export var access_actor_id := "player"
@export var allow_theft := false
@export var affiliation_id := ""
@export var allow_deposit := true
@export var initial_items: Dictionary = {}
