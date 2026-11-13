class_name QuickLootView
extends VBoxContainer
## A local view of the original corpse inventory; no preview stash or loot rolls.
var game: GrayriverGame
var source_id := ""
var ground := false
var _signature := ""
var _clock := 0.0
var _selected_harvest := ""
var _harvest_details: Dictionary={}
var _subtitles: Dictionary={}
var _take_buttons: Dictionary={}
func _ready() -> void:
 add_theme_constant_override("separation",8)
 _refresh()
func _process(delta: float) -> void:
 _clock+=delta
 if _clock>=.2: _clock=0; _refresh()
func _refresh() -> void:
 if not _available(): return
 var entries:=_entries()
 var signature:=str(entries.map(func(entry):return [entry.id,entry.uid,entry.kind,entry.item,entry.title]))
 if signature==_signature:
  for entry in entries:
   var uid:=str(entry.uid)
   if _subtitles.has(uid): _subtitles[uid].text=str(entry.subtitle)
   if entry.kind=="harvest" and _take_buttons.has(uid): _take_buttons[uid].disabled=not game.loot.harvesting.reason(source_id,uid,entry.part).is_empty()
  return
 if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): return
 _signature=signature
 _harvest_details.clear()
 _subtitles.clear(); _take_buttons.clear()
 FoundationWidgets.clear(self)
 if entries.is_empty(): add_child(FoundationWidgets.label("已搜空。",14,true)); return
 for entry in entries:
  var row:=VBoxContainer.new(); row.add_theme_constant_override("separation",4); add_child(row)
  var header:=HBoxContainer.new(); row.add_child(header)
  var definition:=game.session.inventory.definitions.get(str(entry.item)) as ItemData
  var icon:=TextureRect.new(); icon.texture=InterfaceIcons.item(definition); icon.custom_minimum_size=Vector2(36,36)
  icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; header.add_child(icon)
  var words:=VBoxContainer.new(); words.size_flags_horizontal=Control.SIZE_EXPAND_FILL; header.add_child(words)
  var harvest: bool=entry.kind=="harvest"
  if harvest:
   var inspect:=FoundationWidgets.button(str(entry.title),_inspect_part.bind(str(entry.uid)))
   inspect.alignment=HORIZONTAL_ALIGNMENT_LEFT; words.add_child(inspect)
  else: words.add_child(FoundationWidgets.label(str(entry.title),14))
  var subtitle:=FoundationWidgets.label(str(entry.subtitle),12,true); words.add_child(subtitle); _subtitles[str(entry.uid)]=subtitle
  var refused:=game.loot.harvesting.reason(source_id,str(entry.uid),entry.part) if harvest else ""
  var uid:=str(entry.uid); var kind:=str(entry.kind); var item:=str(entry.item)
  var button:=FoundationWidgets.button("开始专业处理" if harvest else "取走这一项",_take.bind(uid,kind,item),not refused.is_empty())
  button.set_meta("ui_action","quick_harvest" if harvest else "quick_take"); button.set_meta("item_uid",uid)
  _take_buttons[uid]=button
  button.tooltip_text=str(entry.text) if harvest else str(entry.title)+"\n"+str(entry.subtitle)
  if harvest:
   var explanation:=FoundationWidgets.label(str(entry.text),13,true); row.add_child(explanation)
   explanation.visible=uid==_selected_harvest; button.visible=explanation.visible
   _harvest_details[uid]=[explanation,button]
  row.add_child(button); row.add_child(HSeparator.new())
func _inspect_part(uid: String) -> void:
 _selected_harvest="" if _selected_harvest==uid else uid
 for key in _harvest_details:
  for control in _harvest_details[key]: control.visible=key==_selected_harvest
func _take(uid: String,kind: String,item: String) -> void:
 if kind=="harvest": game.loot.harvesting.inspect(source_id,uid); return
 var instance:=game.session.inventory.item(uid)
 var taken:=game.inventory_actions.take(source_id,uid,instance.quantity).moved if ground and instance else game.loot.take(source_id,kind,item,uid) if not ground else 0
 game.ui.notify("已收好。" if taken>0 else "未能带走，物品留在原处。")
 _refresh()
func take_all() -> void:
 var taken:=0
 if ground:
  for entry in _entries():
   var instance:=game.session.inventory.item(str(entry.uid))
   if instance: taken+=game.inventory_actions.take(source_id,instance.uid,instance.quantity).moved
 else: taken=game.loot.take(source_id)
 game.ui.notify("收好%d件物品，未能携带的留在原处。"%taken if taken>0 else "未能带走，检查行囊空间。")
 _refresh()
func _available() -> bool:
 return game.session.ground_available(game.player,source_id) if ground else game.loot.available(source_id)
func _entries() -> Array[Dictionary]:
 if not ground: return game.loot.instance_entries(source_id)
 var result: Array[Dictionary]=[]
 var store:=game.session.inventory
 for row in store.entries(source_id):
  var definition:=store.definitions.get(str(row.definition)) as ItemData
  if definition: result.append({"id":"uid:"+str(row.uid),"uid":row.uid,"kind":"equipment" if definition is EquipmentData else "materials","item":row.definition,"title":definition.display_name,"text":definition.description,"subtitle":"×%d · %s"%[row.quantity,store.state_text(str(row.uid))]})
 return result
