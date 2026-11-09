class_name PaperDollView
extends Control
## Read-only portrait of actual equipped instances; never creates an actor or item.
var actor: Player
var select_slot: Callable
var equip_uid: Callable
var slots: Array[InventoryItemTile]=[]
var _visual: ActorEquipmentVisual
var _body: Node2D
func _ready() -> void:
 custom_minimum_size=Vector2(210,260)
 _body=Node2D.new(); add_child(_body)
 _visual=ActorEquipmentVisual.new()
 _visual.animator=(load("res://gameplay/presentation/actors/actor_animation_rig.tscn") as PackedScene).instantiate()
 _visual.animator.preview={"state":"idle","phase":"loop","direction":Vector2.DOWN,"token":"paper-doll"}
 var worn_visual:=actor.get_node_or_null("EquipmentVisual") as ActorEquipmentVisual
 if worn_visual and worn_visual.animator: _visual.animator.profile=worn_visual.animator.profile
 _visual.add_child(_visual.animator)
 _body.add_child(_visual); _body.scale=Vector2(2.8,2.8)
 for slot in range(9):
  var button:=InventoryItemTile.new(); button.name="GearSlot_%d"%slot
  button.custom_minimum_size=Vector2(76,46); button.expand_icon=true; button.add_theme_constant_override("icon_max_width",16)
  GameUIStyle.apply_button(button)
  button.add_theme_font_size_override("font_size",12)
  for state in ["normal","hover","pressed","focus","disabled"]:
   var style:=button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
   style.content_margin_left=3; style.content_margin_right=3
   button.add_theme_stylebox_override(state,style)
  button.pressed.connect(func(): if select_slot.is_valid(): select_slot.call(slot))
  button.accept_item=func(uid: String):
   var item:=actor.actor_context.items.item(uid)
   var definition:=actor.actor_context.items.definitions.get(item.definition_id) as EquipmentData if item else null
   return definition and definition.slot_type==slot and actor.actor_context.items.locate(uid) in actor.actor_context.items.actor_containers(actor.actor_context.id)
  button.request_drop=func(uid: String): if equip_uid.is_valid(): equip_uid.call(uid)
  add_child(button); slots.append(button)
 resized.connect(_layout); _layout(); refresh()
func _layout() -> void:
 if not _body: return
 _body.position=Vector2(size.x*.5,145)
 _body.scale=Vector2.ONE*clampf((size.x-150)/24.0,2.2,3.2)
 for i in range(slots.size()):
  var x:=0.0 if i<5 else size.x-76
  var row:=i if i<5 else i-5
  slots[i].position=Vector2(x,12+row*50)
  slots[i].size=Vector2(76,46)
func refresh() -> void:
 if not is_instance_valid(actor) or not actor.actor_context: return
 var context:=actor.actor_context
 var worn:=context.items.equipped(context.id)
 _visual.items.clear(); _visual.display_uids.clear()
 _visual.inventory_store=context.items
 _visual.preview_pack=context.items.is_attached(context.id+".pack")
 for slot in range(9):
  var uid:=str(worn.get(str(slot),""))
  var item:=context.items.item(uid)
  var definition:=context.items.definitions.get(item.definition_id) as EquipmentData if item else null
  var button:=slots[slot]
  button.item_uid=uid
  button.icon=InterfaceIcons.item(definition) if definition else null
  button.text=EquipmentManager.slot_name(slot)+"\n"+(definition.display_name if definition else "空")
  button.clip_text=true
  button.tooltip_text=EquipmentManager.slot_name(slot)+"："+(definition.display_name+"\n"+context.items.state_text(uid) if definition else "未穿戴")
  if definition: _visual.items.append(definition); _visual.display_uids.append(uid)
 _visual.queue_redraw()
