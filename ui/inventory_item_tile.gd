class_name InventoryItemTile
extends Button
signal secondary_requested(uid: String,position: Vector2)
signal activated(uid: String)
var item_uid := ""
var accept_item: Callable
var request_drop: Callable
var _row: BoxContainer
var _content: MarginContainer
var _grid_layout := false
var _art: TextureRect
var _title: Label
var _subtitle: Label
var _count: Label
func present(texture: Texture2D,title: String,subtitle: String,count := "",grid := false) -> void:
 if not _row or _grid_layout!=grid:
  if _content:
   remove_child(_content); _content.queue_free()
  _grid_layout=grid
  var margin:=MarginContainer.new(); _content=margin; margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side,10)
  for side in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,6)
  add_child(margin)
  _row=VBoxContainer.new() if grid else HBoxContainer.new(); _row.add_theme_constant_override("separation",12); margin.add_child(_row)
  _art=TextureRect.new(); _art.custom_minimum_size=Vector2(36,36) if grid else Vector2(32,32)
  if grid: _art.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
  _art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; _art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; _row.add_child(_art)
  var words:=VBoxContainer.new(); words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  words.size_flags_vertical=Control.SIZE_SHRINK_CENTER; words.add_theme_constant_override("separation",2); _row.add_child(words)
  _title=Label.new(); _title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
  _title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; words.add_child(_title); GameUIStyle.apply_label(_title,14)
  _title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER if grid else HORIZONTAL_ALIGNMENT_LEFT
  _subtitle=Label.new(); _subtitle.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
  _subtitle.size_flags_horizontal=Control.SIZE_EXPAND_FILL; words.add_child(_subtitle); GameUIStyle.apply_label(_subtitle,12,GameUIStyle.TEXT_MUTED)
  _count=Label.new(); _count.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; _count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER if grid else HORIZONTAL_ALIGNMENT_RIGHT; _row.add_child(_count); GameUIStyle.apply_label(_count,14)
  for child in find_children("*","Control",true,false): child.mouse_filter=Control.MOUSE_FILTER_IGNORE
 _title.text=title; _subtitle.text=subtitle; _count.text=count; _art.texture=texture
 _subtitle.visible=not grid and not subtitle.is_empty()
 custom_minimum_size.y=maxf(112 if grid else 58,ceilf(_title.get_theme_font("font").get_height(_title.get_theme_font_size("font_size"))+(_subtitle.get_theme_font("font").get_height(_subtitle.get_theme_font_size("font_size")) if _subtitle.visible else 0))+16)
 text=""; icon=null
func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed:
  if event.button_index==MOUSE_BUTTON_RIGHT:
   secondary_requested.emit(item_uid,get_global_mouse_position()); accept_event()
  elif event.button_index==MOUSE_BUTTON_LEFT and event.double_click:
   activated.emit(item_uid); accept_event()
func _get_drag_data(_position: Vector2) -> Variant:
 if item_uid.is_empty(): return null
 var preview:=Label.new(); preview.text=_title.text if _title else text; GameUIStyle.apply_label(preview,14)
 set_drag_preview(preview)
 return {"kind":"inventory_item","uid":item_uid}
func _can_drop_data(_position: Vector2,data: Variant) -> bool:
 return data is Dictionary and data.get("kind","")=="inventory_item" and data.get("uid") is String and accept_item.is_valid() and accept_item.call(data.uid)
func _drop_data(_position: Vector2,data: Variant) -> void:
 if _can_drop_data(_position,data) and request_drop.is_valid(): request_drop.call(data.uid)
