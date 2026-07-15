class_name ItemPickup
extends Pickup

@export var item_data: ItemData
@export var quantity: int = 1

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _label: Label = $Label


func _ready() -> void:
	auto_destroy = false
	super._ready()
	_refresh_visual()


func setup(item: ItemData, count: int = 1) -> void:
	item_data = item
	quantity = maxi(1, count)
	if is_node_ready():
		_refresh_visual()


func _on_collected(player: Player) -> void:
	if not item_data or not player or not player.inventory:
		_collectible = true
		return
	var added := player.inventory.add_item(item_data, quantity)
	if added >= quantity:
		queue_free()
		return
	if added > 0:
		quantity -= added
		_refresh_visual()
	_collectible = true


func _refresh_visual() -> void:
	if not item_data:
		return
	var texture := item_data.icon
	if item_data is EquipmentData:
		texture = (item_data as EquipmentData).get_icon_texture()
	_sprite.texture = texture
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_label.text = item_data.display_name if quantity == 1 else "%s x%d" % [item_data.display_name, quantity]
	_label.modulate = SlotButton.get_rarity_color(item_data.rarity)
