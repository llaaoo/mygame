class_name PaperDollView
extends VBoxContainer
## Prototype gear list, rendered from the same real equipment rig as the actor.
var actor: Player
var select_slot: Callable
var equip_uid: Callable
var slots: Array[InventoryItemTile]=[]
var _visual: ActorEquipmentVisual
var _body: Node2D
var _preview: Control
var _worn_caption: Label
func _ready() -> void:
 add_theme_constant_override("separation",5)
 _preview=Control.new(); _preview.custom_minimum_size=Vector2(0,200); _preview.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(_preview)
 var backdrop:=Panel.new(); backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE; backdrop.add_theme_stylebox_override("panel",GameUIStyle.quiet_panel(.22)); _preview.add_child(backdrop)
 _body=Node2D.new(); _preview.add_child(_body)
 _visual=ActorEquipmentVisual.new()
 _visual.animator=(load("res://gameplay/presentation/actors/actor_animation_rig.tscn") as PackedScene).instantiate()
 _visual.animator.preview={"state":"idle","phase":"loop","direction":Vector2.DOWN,"token":"paper-doll"}
 var worn_visual:=actor.get_node_or_null("EquipmentVisual") as ActorEquipmentVisual
 if worn_visual and worn_visual.animator: _visual.animator.profile=worn_visual.animator.profile
 _visual.add_child(_visual.animator); _body.add_child(_visual); _body.scale=Vector2(3,3)
 _worn_caption=FoundationWidgets.label("",14,true); _worn_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; add_child(_worn_caption)
 for slot in range(9):
  var button:=InventoryItemTile.new(); button.name="GearSlot_%d"%slot
  button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; GameUIStyle.apply_button(button,GameUIStyle.GOLD)
  button.pressed.connect(func(): if select_slot.is_valid(): select_slot.call(slot))
  button.accept_item=func(uid: String):
   var item:=actor.actor_context.items.item(uid)
   var definition:=actor.actor_context.items.definitions.get(item.definition_id) as EquipmentData if item else null
   return definition and definition.slot_type==slot and actor.actor_context.items.locate(uid) in actor.actor_context.items.actor_containers(actor.actor_context.id)
  button.request_drop=func(uid: String): if equip_uid.is_valid(): equip_uid.call(uid)
  add_child(button); slots.append(button)
 # Most frequently checked slots stay visible before secondary clothing/jewelry.
 var order: Array[int]=[EquipmentData.SlotType.HEAD,EquipmentData.SlotType.CHEST,EquipmentData.SlotType.RIGHT_HAND,EquipmentData.SlotType.LEFT_HAND,EquipmentData.SlotType.LEGS,EquipmentData.SlotType.FEET,EquipmentData.SlotType.HANDS,EquipmentData.SlotType.AMULET,EquipmentData.SlotType.RING]
 for index in range(order.size()): move_child(slots[order[index]],index+2)
 _preview.resized.connect(_layout); _layout(); refresh()
func _layout() -> void:
 if _body:
  _body.position=Vector2(_preview.size.x*.5,_preview.size.y*.52)
  _body.scale=Vector2.ONE*(2 if _preview.size.x<180 or _preview.size.y<130 else 3)
func set_compact(compact: bool) -> void:
 _preview.custom_minimum_size.y=112 if compact else 200
 _layout()
func refresh() -> void:
 if not is_instance_valid(actor) or not actor.actor_context or not _visual: return
 var context:=actor.actor_context
 var worn:=context.items.equipped(context.id)
 _visual.items.clear(); _visual.display_uids.clear(); _visual.inventory_store=context.items
 _visual.preview_pack=context.items.is_attached(context.id+".pack")
 var names: PackedStringArray=[]
 for slot in range(9):
  var uid:=str(worn.get(str(slot),"")); var item:=context.items.item(uid)
  var definition:=context.items.equipment_definition(uid) if item else null
  var button:=slots[slot]; button.item_uid=uid
  button.present(InterfaceIcons.item(definition) if definition else GameUIStyle.icon("shield"),definition.display_name if definition else "空槽",EquipmentManager.slot_name(slot))
  button._title.get_parent().move_child(button._subtitle,0)
  button.tooltip_text=EquipmentManager.slot_name(slot)+"："+(definition.display_name+"\n"+context.items.state_text(uid) if definition else "未穿戴")
  GameUIStyle.apply_button(button,GameUIStyle.GOLD,definition!=null)
  if definition:
   _visual.items.append(definition); _visual.display_uids.append(uid)
   if slot in [EquipmentData.SlotType.RIGHT_HAND,EquipmentData.SlotType.CHEST]: names.append(definition.display_name)
 _worn_caption.text="\n".join(names); _worn_caption.visible=not names.is_empty()
 _visual.queue_redraw()
