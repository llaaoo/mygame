class_name ActorInventoryScreen
extends CanvasLayer
## One live inventory/gear screen. Every mutation goes through injected domain requests.
var actor: Player
var actions: InventoryActions
var session: CampaignSession
var use_request: Callable
var notify: Callable
var navigation_request: Callable
var ground_id := ""
var selected := ""
var mode := "all"
var selected_slot := -1
var container_filter := "all"
var _panel: PanelContainer
var _columns: HBoxContainer
var _bag: VBoxContainer
var _details: VBoxContainer
var _detail_scroll: ScrollContainer
var _portrait: PaperDollView
var _grid: GridContainer
var _search: LineEdit
var _summary: Label
var _stats: Label
var _state_label: Label
var _quantity: SpinBox
var _popup: PopupMenu
var _dirty := true
var _refresh_time:=0.0
var _detail_clock:=0.0
var _last_health:=100
var _alert: Label
var _message := ""
var _message_time := 0.0
var _tiles: Dictionary={}
var _detail_signature: Dictionary={}
var _portrait_signature: Array=[]
func _ready() -> void:
 layer=GameUIStyle.LAYER_MODAL
 add_to_group("modal_ui")
 _build(); hide()
 session.inventory.changed.connect(_invalidate)
 actor.health_component.health_changed.connect(_health_changed)
 get_viewport().size_changed.connect(_layout)
 _layout()
func _exit_tree() -> void:
 if session and session.inventory.changed.is_connected(_invalidate): session.inventory.changed.disconnect(_invalidate)
func open(focus := "all",ground := "") -> void:
 if actor.health_component.is_dead or not GameUIStyle.can_open(self): return
 mode=focus; ground_id=ground; selected=""; selected_slot=-1; container_filter="all"
 _search.text=""; _last_health=actor.health_component.hp
 _dirty=true; show(); GameUIStyle.begin_modal(self); _refresh()
func open_item(definition_id: String, preferred_uid := "") -> void:
 open("equipment" if session.inventory.definitions.get(definition_id) is EquipmentData else "all")
 var sources:=session.inventory.actor_containers(actor.actor_context.id)
 sources.push_front(actor.actor_context.id+".gear")
 for container in sources:
  for row in session.inventory.entries(container):
   if row.definition!=definition_id or not preferred_uid.is_empty() and row.uid!=preferred_uid: continue
   _select(row.uid)
   var tile: Control=_tiles.get(row.uid)
   if tile:
    var parent:=tile.get_parent()
    while parent:
     if parent is ScrollContainer: parent.ensure_control_visible(tile)
     parent=parent.get_parent()
   return
 _message="这件实物已不在随身容器。"; _message_time=3
func close() -> void:
 _popup.hide(); hide(); GameUIStyle.end_modal(self)
func _input(event: InputEvent) -> void:
 if not visible or not event is InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_ESCAPE: return
 # Escape dismisses a picker first; otherwise it always returns to combat,
 # including while a quantity/search field owns keyboard focus.
 if _popup.visible: return
 for picker in _details.find_children("*","OptionButton",true,false):
  if picker.get_popup().visible: return
 close(); get_viewport().set_input_as_handled()
func _unhandled_input(event: InputEvent) -> void:
 if not visible or not event is InputEventKey or not event.pressed or event.echo: return
 if event.keycode==KEY_ESCAPE: close(); get_viewport().set_input_as_handled()
 elif event.keycode==KEY_O and not get_viewport().gui_get_focus_owner() is LineEdit:
  mode="equipment"; selected_slot=-1; _invalidate(); get_viewport().set_input_as_handled()
 elif event.keycode==KEY_N and not get_viewport().gui_get_focus_owner() is LineEdit:
  mode="supplies"; selected_slot=-1; _invalidate(); get_viewport().set_input_as_handled()
 elif event.keycode in [KEY_I,KEY_TAB,KEY_K,KEY_G,KEY_J,KEY_M] and not get_viewport().gui_get_focus_owner() is LineEdit:
  close()
  if event.keycode!=KEY_I and navigation_request.is_valid(): navigation_request.call(event.keycode)
  get_viewport().set_input_as_handled()
func _build() -> void:
 var background:=ColorRect.new(); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 background.color=GameUIStyle.modal_backdrop(.38); add_child(background)
 _panel=PanelContainer.new(); _panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 _panel.add_theme_stylebox_override("panel",GameUIStyle.panel_style(.98)); background.add_child(_panel)
 var root:=VBoxContainer.new(); root.add_theme_constant_override("separation",12); _panel.add_child(root)
 var header:=HBoxContainer.new(); root.add_child(header)
 var title:=FoundationWidgets.label("行囊与穿戴",26); title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; header.add_child(title)
 var close_button:=FoundationWidgets.button("关闭",close); close_button.size_flags_horizontal=Control.SIZE_SHRINK_END; header.add_child(close_button)
 root.add_child(FoundationWidgets.label("世界持续运行 · 双击使用 / 换装 · 右键操作 · 拖入穿戴槽或明确的丢弃区",12,true))
 _summary=FoundationWidgets.label("",13,true); root.add_child(_summary)
 _columns=HBoxContainer.new(); _columns.add_theme_constant_override("separation",18); _columns.size_flags_vertical=Control.SIZE_EXPAND_FILL; root.add_child(_columns)
 var gear:=VBoxContainer.new(); gear.custom_minimum_size.x=260; _columns.add_child(gear)
 gear.add_child(FoundationWidgets.label("当前穿戴",18))
 _portrait=PaperDollView.new(); _portrait.actor=actor; _portrait.select_slot=_select_slot; _portrait.equip_uid=_equip
 gear.add_child(_portrait)
 _stats=FoundationWidgets.label("",13,true); gear.add_child(_stats)
 _bag=VBoxContainer.new(); _bag.size_flags_horizontal=Control.SIZE_EXPAND_FILL; _columns.add_child(_bag)
 var category:=HBoxContainer.new(); _bag.add_child(category)
 for pair in [["全部","all"],["装备","equipment"],["补给 / 材料","supplies"]]:
  var button:=FoundationWidgets.button(pair[0],func(): mode=pair[1]; selected_slot=-1; _invalidate())
  category.add_child(button)
 var containers:=HBoxContainer.new(); _bag.add_child(containers)
 for pair in [["随身全部","all"],["口袋","pocket"],["背包","pack"],["地面","ground"]]:
  var button:=FoundationWidgets.button(pair[0],func(): container_filter=pair[1]; _invalidate())
  containers.add_child(button)
 _search=LineEdit.new(); _search.placeholder_text="搜索拥有的物品…"; _search.text_changed.connect(func(_text): _invalidate()); _bag.add_child(_search)
 var scroll:=ScrollContainer.new(); scroll.name="InventoryGridScroll"; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; _bag.add_child(scroll)
 _grid=GridContainer.new(); _grid.columns=3; _grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 _grid.add_theme_constant_override("h_separation",6); _grid.add_theme_constant_override("v_separation",6); scroll.add_child(_grid)
 _detail_scroll=ScrollContainer.new(); _detail_scroll.custom_minimum_size.x=270
 _detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; _detail_scroll.follow_focus=true
 _columns.add_child(_detail_scroll)
 _details=VBoxContainer.new(); _details.size_flags_horizontal=Control.SIZE_EXPAND_FILL; _details.add_theme_constant_override("separation",9); _detail_scroll.add_child(_details)
 var drop_zone:=InventoryItemTile.new(); drop_zone.name="GroundDropZone"; drop_zone.text="拖到此处丢弃到地面 · 可拾回"
 GameUIStyle.apply_button(drop_zone,GameUIStyle.GOLD)
 drop_zone.accept_item=func(uid: String): return session.inventory.locate(uid) in session.inventory.actor_containers(actor.actor_context.id)+[actor.actor_context.id+".gear"]
 drop_zone.request_drop=func(uid: String): _select(uid); _drop_quantity(session.inventory.item(uid).quantity)
 root.add_child(drop_zone)
 _alert=FoundationWidgets.label("",14); root.add_child(_alert)
 _popup=PopupMenu.new(); add_child(_popup); _popup.id_pressed.connect(_context_action)
func _layout() -> void:
 if not _panel: return
 var viewport:=get_viewport().get_visible_rect().size
 var extent:=Vector2(minf(1110,viewport.x-32),minf(610,viewport.y-32))
 _panel.offset_left=-extent.x*.5; _panel.offset_right=extent.x*.5; _panel.offset_top=-extent.y*.5; _panel.offset_bottom=extent.y*.5
 if viewport.x<1000:
  if _detail_scroll.get_parent()!=_bag: _detail_scroll.reparent(_bag)
  _detail_scroll.custom_minimum_size=Vector2(0,170)
 else:
  if _detail_scroll.get_parent()!=_columns: _detail_scroll.reparent(_columns)
  _detail_scroll.custom_minimum_size=Vector2(270,0)
 _grid.columns=3 if viewport.x>=1080 else 2
func _invalidate() -> void: _dirty=true
func _process(delta: float) -> void:
 if not visible: return
 if actor.health_component.is_dead: close(); return
 if not ground_id.is_empty() and not session.ground_available(actor,ground_id):
  ground_id=""; _invalidate(); _message="地面物资已不在附近。"; _message_time=3
 _refresh_time+=delta; _message_time=maxf(0,_message_time-delta)
 if _dirty and _refresh_time>.1 and not get_viewport().gui_is_dragging() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _popup.visible: _refresh()
 var context:=actor.actor_context
 _summary.text="口袋 %d/%d格 · 背包 %d/%d格%s · 负重 %.1f / %.0fkg · 生命 %d/%d"%[session.inventory.entries(context.id+".pocket").size(),context.rules.pocket_capacity,session.inventory.entries(context.id+".pack").size(),context.rules.pack_capacity,"（已放下，不可远程整理）" if not session.inventory.is_attached(context.id+".pack") else "",session.inventory.weight(context.id),context.rules.carry_limit,actor.health_component.hp,actor.health_component.max_hp]
 _alert.text=_message if _message_time>0 else ""
 _refresh_stats()
 _detail_clock+=delta
 if _detail_clock>=.15:
  _detail_clock=0
  _show_detail()
 if is_instance_valid(_state_label) and _state_label.is_inside_tree():
  var item:=_selected_item()
  if item:
   var definition:=session.inventory.equipment_definition(item.uid) if session.inventory.definitions.get(item.definition_id) is EquipmentData else session.inventory.definitions.get(item.definition_id) as ItemData
   if definition: _state_label.text=session.inventory.state_text(item.uid)+"\n单件重量 %.1fkg · 数量 %d"%[definition.weight,item.quantity]
func _health_changed(hp: int,_max_hp: int) -> void:
 if visible and hp<_last_health: _message="正在受伤！Esc关闭界面返回战斗。"; _message_time=3; _alert.add_theme_color_override("font_color",GameUIStyle.DANGER)
 _last_health=hp
func _rows() -> Array[Dictionary]:
 var rows: Array[Dictionary]=[]
 var context:=actor.actor_context
 var containers:=session.inventory.actor_containers(context.id)
 containers.append(context.id+".gear")
 if not ground_id.is_empty() and session.ground_available(actor,ground_id): containers.append(ground_id)
 for container in containers:
  var kind: String="ground" if container==ground_id else "pocket" if container.ends_with(".pocket") else "pack" if container.ends_with(".pack") else "gear"
  if container_filter!="all" and container_filter!=kind: continue
  for row in session.inventory.entries(container):
   var definition:=session.inventory.equipment_definition(row.uid) if session.inventory.definitions.get(row.definition) is EquipmentData else session.inventory.definitions.get(row.definition) as ItemData
   if not definition: continue
   if mode=="equipment" and not definition is EquipmentData or mode=="supplies" and definition is EquipmentData: continue
   if selected_slot>=0 and (not definition is EquipmentData or definition.slot_type!=selected_slot): continue
   if not _search.text.is_empty() and not (definition.display_name+definition.description).contains(_search.text): continue
   var record:=row.duplicate(true); record["container"]=container; record["place"]=kind; rows.append(record)
 return rows
func _refresh() -> void:
 _dirty=false; _refresh_time=0
 var gear: Array=[session.inventory.entries(actor.actor_context.id+".gear"),session.inventory.is_attached(actor.actor_context.id+".pack")]
 if gear!=_portrait_signature:
  _portrait_signature=gear.duplicate(true); _portrait.refresh()
 _refresh_stats()
 var rows:=_rows()
 var retained: Dictionary={}
 for index in range(rows.size()):
  var row: Dictionary=rows[index]
  var definition:=session.inventory.equipment_definition(row.uid) if session.inventory.definitions.get(row.definition) is EquipmentData else session.inventory.definitions.get(row.definition) as ItemData
  var tile:=_tiles.get(row.uid) as InventoryItemTile
  if not is_instance_valid(tile):
   tile=InventoryItemTile.new(); tile.item_uid=row.uid; tile.name="Item_"+row.uid.replace(".","_")
   tile.expand_icon=true; tile.add_theme_constant_override("icon_max_width",26)
   tile.custom_minimum_size=Vector2(110,72); tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL; tile.clip_text=true
   tile.pressed.connect(_select.bind(row.uid)); tile.activated.connect(_activate); tile.secondary_requested.connect(_context)
   _tiles[row.uid]=tile; _grid.add_child(tile)
  var caption: String=definition.display_name+" ×%d\n"%row.quantity+{"pocket":"口袋","pack":"背包","gear":"已穿戴","ground":"地面"}[row.place]
  if tile.text!=caption: tile.text=caption
  tile.icon=InterfaceIcons.item(definition)
  tile.tooltip_text=definition.display_name+"\n"+session.inventory.state_text(row.uid)
  GameUIStyle.apply_button(tile,GameUIStyle.ACCENT,selected==row.uid)
  if tile.get_index()!=index: _grid.move_child(tile,index)
  retained[row.uid]=true
 for uid in _tiles.keys():
  if retained.has(uid): continue
  var tile:=_tiles[uid] as InventoryItemTile
  _tiles.erase(uid)
  if is_instance_valid(tile):
   _grid.remove_child(tile); tile.queue_free()
 var placeholder:=_grid.get_node_or_null("EmptyInventory") as Label
 if rows.is_empty() and not placeholder:
  placeholder=FoundationWidgets.label("这里没有符合条件的实物。",14,true); placeholder.name="EmptyInventory"; placeholder.custom_minimum_size.x=220; _grid.add_child(placeholder)
 elif not rows.is_empty() and placeholder:
  _grid.remove_child(placeholder); placeholder.queue_free()
 _show_detail()
func _refresh_stats() -> void:
 var stats:=actor.stats_component
 _stats.text="力量 %d · 智力 %d\n敏捷 %d · 耐力 %d\n生命 %d · 法力 %d"%[stats.effective_stat("strength"),stats.effective_stat("intelligence"),stats.effective_stat("agility"),stats.effective_stat("endurance"),actor.health_component.max_hp,actor.mana_component.max_mp]
func _select(uid: String) -> void:
 if uid!=selected and is_instance_valid(_quantity): _quantity.value=1
 selected=uid; _show_detail()
func _select_slot(slot: int) -> void:
 selected_slot=slot; mode="equipment"; container_filter="all"
 selected=str(session.inventory.equipped(actor.actor_context.id).get(str(slot),"")); _invalidate()
func _selected_item() -> ItemInstance: return session.inventory.item(selected)
func _equipment_permission(item: ItemInstance) -> String:
 if not item: return ""
 var definition:=session.inventory.definitions.get(item.definition_id) as EquipmentData
 if not definition: return ""
 if session.inventory.locate(item.uid).ends_with(".gear"):
  return actions.unequip_reason(definition.slot_type)
 return actions.equip_reason(item.uid)
func _show_detail() -> void:
 var item:=_selected_item()
 var permission:=_equipment_permission(item)
 var signature: Dictionary={"permission":permission,"uid":selected,"item":item.snapshot() if item else {},"location":session.inventory.locate(selected),"gear":session.inventory.entries(actor.actor_context.id+".gear"),"accessible":session.inventory.actor_containers(actor.actor_context.id),"ground":ground_id}
 if signature==_detail_signature: return
 _detail_signature=signature.duplicate(true)
 var old_quantity:=int(_quantity.value) if is_instance_valid(_quantity) else 1
 FoundationWidgets.clear(_details); _quantity=null; _state_label=null
 if not item:
  _details.add_child(FoundationWidgets.label("选择物品，或点击身体部位查看可穿戴装备。",16,true)); return
 var location:=session.inventory.locate(item.uid)
 var definition:=session.inventory.equipment_definition(item.uid) if session.inventory.definitions.get(item.definition_id) is EquipmentData else session.inventory.definitions.get(item.definition_id) as ItemData
 _details.add_child(FoundationWidgets.label(definition.display_name,20))
 _details.add_child(FoundationWidgets.label(definition.description,14,true))
 _state_label=FoundationWidgets.label(session.inventory.state_text(item.uid)+"\n单件重量 %.1fkg · 数量 %d"%[definition.weight,item.quantity],13,true)
 _details.add_child(_state_label)
 _quantity=SpinBox.new(); _quantity.min_value=1; _quantity.max_value=item.quantity; _quantity.step=1; _quantity.value=mini(old_quantity,item.quantity); _details.add_child(_quantity)
 if location==ground_id and not ground_id.is_empty():
  _details.add_child(FoundationWidgets.button("取走所选数量",func(): _result(actions.take(ground_id,selected,int(_quantity.value)))))
  _details.add_child(FoundationWidgets.button("尽量取走这一叠",func(): _result(actions.take(ground_id,selected,item.quantity))))
  return
 if location not in session.inventory.actor_containers(actor.actor_context.id)+[actor.actor_context.id+".gear"]:
  _details.add_child(FoundationWidgets.label("实物已不在随身容器。",14,true)); return
 if definition is EquipmentData:
  var current:=actor.get_node("EquipmentManager").get_equipment(definition.slot_type) as EquipmentData
  FoundationWidgets.disclosure(_details,"属性与当前装备比较",FoundationWidgets.comparison(current,definition))
  if definition.moveset: FoundationWidgets.disclosure(_details,"武器动作",definition.moveset.describe())
  if location.ends_with(".gear"):
   _details.add_child(FoundationWidgets.button("卸下装备",func(): _result(actions.unequip(definition.slot_type)),not permission.is_empty()))
  else: _details.add_child(FoundationWidgets.button("装备这件",_equip.bind(item.uid),not permission.is_empty()))
  if not permission.is_empty(): _details.add_child(FoundationWidgets.label(permission,13,true))
 elif definition.use_profile or SurvivalCatalog.FOODS.has(definition.id):
  _details.add_child(FoundationWidgets.button("选择这瓶喷剂" if definition.use_profile and definition.use_profile.kind==ItemUseDefinition.Kind.SPRAY else "使用一份",_use.bind(item.uid)))
 if not location.ends_with(".gear"):
  _details.add_child(FoundationWidgets.button("移至口袋" if location.ends_with(".pack") else "移至背包",_transfer_selected))
  if item.quantity>1: _details.add_child(FoundationWidgets.button("拆分所选数量",func(): _result(actions.split(selected,int(_quantity.value)))))
 _details.add_child(FoundationWidgets.button("丢弃一件",_drop_quantity.bind(1)))
 _details.add_child(FoundationWidgets.button("丢弃所选数量",func(): _drop_quantity(int(_quantity.value))))
 _details.add_child(FoundationWidgets.button("丢弃整叠",_drop_quantity.bind(item.quantity)))
 if definition is EquipmentData or definition.use_profile or SurvivalCatalog.FOODS.has(definition.id): _binding_picker(item,definition)
func _binding_picker(item: ItemInstance,definition: ItemData) -> void:
 var picker:=OptionButton.new()
 for source in QuickslotLoadout.SOURCES: picker.add_item(InputBindings.label(InputBindings.action_for_source(source)))
 _details.add_child(picker)
 _details.add_child(FoundationWidgets.button("绑定所选快捷槽",func():
  var uid:=item.uid if definition is EquipmentData or definition.use_profile and definition.use_profile.kind==ItemUseDefinition.Kind.SPRAY else ""
  var ok:=actor.skill_manager.shortcuts.bind_item(QuickslotLoadout.SOURCES[picker.selected],definition.id,uid)
  _message="已绑定。" if ok else "无法绑定。"; _message_time=3
  if ok and actions.save_request.is_valid(): actions.save_request.call()))
func _result(result: OperationResult) -> void:
 _message="已完成 · %d件"%result.moved if result.accepted else _reason(result.reason)
 _message_time=3; _alert.add_theme_color_override("font_color",GameUIStyle.TEXT_MAIN if result.accepted else GameUIStyle.GOLD)
 _invalidate(); _show_detail()
func _reason(value: String) -> String:
 return {"capacity":"容器已满，物品保留原处。","invalid_quantity":"数量已变化，请重新选择。","stale_plan":"物品发生变化，请重试。","not_owned":"实物已不在身上。"}.get(value,value)
func _equip(uid: String) -> void: _result(actions.equip(uid))
func _drop_quantity(quantity: int) -> void: _result(actions.drop(selected,quantity))
func _transfer_selected() -> void:
 var location:=session.inventory.locate(selected)
 var destination:=actor.actor_context.id+(".pocket" if location.ends_with(".pack") else ".pack")
 _result(actions.transfer(selected,destination,int(_quantity.value)))
func _use(uid: String) -> void:
 if not use_request.is_valid(): return
 close(); use_request.call(uid)
func _activate(uid: String) -> void:
 _select(uid)
 var item:=session.inventory.item(uid)
 if not item: return
 if session.inventory.locate(uid)==ground_id: _result(actions.take(ground_id,uid,item.quantity)); return
 var definition:=session.inventory.equipment_definition(item.uid) if session.inventory.definitions.get(item.definition_id) is EquipmentData else session.inventory.definitions.get(item.definition_id) as ItemData
 if definition is EquipmentData:
  if session.inventory.locate(uid).ends_with(".gear"): _result(actions.unequip(definition.slot_type))
  else: _equip(uid)
 elif definition.use_profile or SurvivalCatalog.FOODS.has(definition.id): _use(uid)
func _context(uid: String,point: Vector2) -> void:
 _select(uid); _popup.clear()
 var item:=_selected_item()
 if not item: return
 if session.inventory.locate(uid)==ground_id: _popup.add_item("取走这一叠",0)
 else:
  _popup.add_item("使用 / 穿戴",0)
  _popup.add_item("丢弃一件",1); _popup.add_item("丢弃整叠",2)
  if not session.inventory.locate(uid).ends_with(".gear"): _popup.add_item("移动所选数量",3)
 _popup.position=Vector2i(point if get_viewport().gui_embed_subwindows else get_viewport().get_screen_transform()*point); _popup.popup()
func _context_action(id: int) -> void:
 match id:
  0: _activate(selected)
  1: _drop_quantity(1)
  2:
   var item:=_selected_item()
   if item: _drop_quantity(item.quantity)
  3: _transfer_selected()
