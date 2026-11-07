class_name InventoryItemTile
extends Button
signal secondary_requested(uid: String,position: Vector2)
signal activated(uid: String)
var item_uid := ""
var accept_item: Callable
var request_drop: Callable
func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed:
  if event.button_index==MOUSE_BUTTON_RIGHT:
   secondary_requested.emit(item_uid,get_global_mouse_position()); accept_event()
  elif event.button_index==MOUSE_BUTTON_LEFT and event.double_click:
   activated.emit(item_uid); accept_event()
func _get_drag_data(_position: Vector2) -> Variant:
 if item_uid.is_empty(): return null
 var preview:=Label.new(); preview.text=text; GameUIStyle.apply_label(preview,14)
 set_drag_preview(preview)
 return {"kind":"inventory_item","uid":item_uid}
func _can_drop_data(_position: Vector2,data: Variant) -> bool:
 return data is Dictionary and data.get("kind","")=="inventory_item" and data.get("uid") is String and accept_item.is_valid() and accept_item.call(data.uid)
func _drop_data(_position: Vector2,data: Variant) -> void:
 if _can_drop_data(_position,data) and request_drop.is_valid(): request_drop.call(data.uid)
