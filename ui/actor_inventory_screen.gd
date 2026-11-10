class_name ActorInventoryScreen
extends CanvasLayer
## One live inventory/gear screen. Every mutation goes through injected domain requests.
var actor: Player
var actions: InventoryActions
var session: CampaignSession
var use_request: Callable
var notify: Callable
var navigation_request: Callable
var _navigation: ExpeditionNavigation
var page_request: Callable:
 set(value):
  page_request=value
  if is_instance_valid(_navigation): _navigation.navigate=value; _navigation.visible=value.is_valid()
var configure_request: Callable
var _view_context: Dictionary={}
var _categories: Dictionary={}
var _containers: Dictionary={}
var _gear_column: VBoxContainer
var _gear_scroll: ScrollContainer
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
var _needs_label: Label
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
func resume() -> void:
 if _view_context.is_empty(): open(); return
 open(str(_view_context.mode))
 container_filter=str(_view_context.container); selected_slot=int(_view_context.slot)
 _search.text=str(_view_context.query)
 selected=str(_view_context.selected) if session.inventory.item(str(_view_context.selected)) else ""
 _refresh()
func close() -> void:
 if visible: _view_context={"mode":mode,"container":container_filter,"slot":selected_slot,"query":_search.text,"selected":selected}
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
 background.color=GameUIStyle.modal_backdrop(.6); add_child(background)
 _panel=PanelContainer.new(); _panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 _panel.add_theme_stylebox_override("panel",GameUIStyle.panel_style(.98)); background.add_child(_panel)
 GameUIStyle.decorate(_panel)
 var root:=VBoxContainer.new(); root.add_theme_constant_override("separation",12); _panel.add_child(root)
 var header:=HBoxContainer.new(); root.add_child(header)
 GameUIStyle.folio_title(header,"行囊与穿戴")
 var close_button:=FoundationWidgets.button("关闭",close); close_button.size_flags_horizontal=Control.SIZE_SHRINK_END; header.add_child(close_button)
 _navigation=GameUIStyle.navigation(root,"inventory",page_request)
 _summary=FoundationWidgets.label("",13,true); root.add_child(_summary)
 _columns=HBoxContainer.new(); _columns.add_theme_constant_override("separation",18); _columns.size_flags_vertical=Control.SIZE_EXPAND_FILL; root.add_child(_columns)
 _gear_scroll=ScrollContainer.new(); _gear_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; _gear_scroll.follow_focus=true
 _gear_scroll.custom_minimum_size.x=238; _columns.add_child(_gear_scroll)
 var gear:=VBoxContainer.new(); _gear_column=gear; gear.size_flags_horizontal=Control.SIZE_EXPAND_FILL; _gear_scroll.add_child(gear)
 gear.add_child(FoundationWidgets.label("当前穿戴",18))
 _portrait=PaperDollView.new(); _portrait.actor=actor; _portrait.select_slot=_select_slot; _portrait.equip_uid=_equip
 gear.add_child(_portrait)
 _stats=FoundationWidgets.label("",13,true); gear.add_child(_stats)
 _needs_label=FoundationWidgets.label("",12,true); gear.add_child(_needs_label)
 if actor.survival: gear.add_child(FoundationWidgets.button("恢复与休整",actor.survival.show_rules))
 _bag=VBoxContainer.new(); _bag.size_flags_horizontal=Control.SIZE_EXPAND_FILL; _columns.add_child(_bag)
 var category:=HBoxContainer.new(); _bag.add_child(category)
 for pair in [["全部","all"],["装备","equipment"],["补给 / 材料","supplies"]]:
  var button:=FoundationWidgets.button(pair[0],func(): mode=pair[1]; selected_slot=-1; _invalidate())
  GameUIStyle.apply_tab(button,mode==pair[1]); _categories[pair[1]]=button
  category.add_child(button)
 var containers:=HBoxContainer.new(); _bag.add_child(containers)
 for pair in [["随身全部","all"],["口袋","pocket"],["背包","pack"],["地面","ground"]]:
  var button:=FoundationWidgets.button(pair[0],func(): container_filter=pair[1]; _invalidate())
  GameUIStyle.apply_tab(button,container_filter==pair[1]); _containers[pair[1]]=button
  containers.add_child(button)
 _search=LineEdit.new(); _search.clear_button_enabled=true; _search.placeholder_text="搜索拥有的物品…"; _search.text_changed.connect(func(_text): _invalidate()); _bag.add_child(_search)
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
 var footer:=HBoxContainer.new(); footer.add_theme_constant_override("separation",14); root.add_child(footer)
 footer.add_child(FoundationWidgets.label("双击使用 / 换装 · 右键操作\nEsc 返回世界 · 界面不暂停",12,true))
 footer.add_child(drop_zone)
 _alert=FoundationWidgets.label("",14); root.add_child(_alert)
 _popup=PopupMenu.new(); add_child(_popup); _popup.id_pressed.connect(_context_action)
func _layout() -> void:
 if not _panel: return
 var viewport:=get_viewport().get_visible_rect().size
 var extent:=Vector2(minf(1280,viewport.x-32),minf(760,viewport.y-32))
 _panel.offset_left=-extent.x*.5; _panel.offset_right=extent.x*.5; _panel.offset_top=-extent.y*.5; _panel.offset_bottom=extent.y*.5
 _gear_scroll.custom_minimum_size.x=210 if viewport.x<1080 else 250
 _detail_scroll.custom_minimum_size.x=250 if viewport.x<1080 else 290
 _bag.custom_minimum_size.x=240
 _grid.columns=2 if viewport.x<1200 else 3
func _invalidate() -> void: _dirty=true
func _process(delta: float) -> void:
 if not visible: return
 if actor.health_component.is_dead: close(); return
 if not ground_id.is_empty() and not session.ground_available(actor,ground_id):
  ground_id=""; _invalidate(); _message="地面物资已不在附近。"; _message_time=3
 _refresh_time+=delta; _message_time=maxf(0,_message_time-delta)
 if _dirty and _refresh_time>.1 and not get_viewport().gui_is_dragging() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _popup.visible: _refresh()
 var context:=actor.actor_context
 _summary.text="口袋 %d/%d格 · 背包 %d/%d格%s · 负重 %.1f / %.0fkg · 生命 %d/%d"%[session.inventory.occupied_slots(context.id+".pocket"),context.rules.pocket_capacity,session.inventory.occupied_slots(context.id+".pack"),context.rules.pack_capacity,"（已放下，不可远程整理）" if not session.inventory.is_attached(context.id+".pack") else "",session.inventory.weight(context.id),context.rules.carry_limit+float(ActorProgression.values(actor).carry_bonus),actor.health_component.hp,actor.health_component.max_hp]
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
   if definition: _state_label.text=_item_state_text(item,definition)
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
 for id in _categories: GameUIStyle.apply_tab(_categories[id],mode==id)
 for id in _containers: GameUIStyle.apply_tab(_containers[id],container_filter==id)
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
   tile.expand_icon=true; tile.add_theme_constant_override("icon_max_width",34)
   tile.custom_minimum_size=Vector2(112,84); tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL; tile.clip_text=true
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
 if actor.survival:
  var needs:=actor.survival.needs
  _needs_label.text="旅途状态\n饱食 %.0f · 饮水 %.0f\n疲劳 %.0f"%[needs.nutrition,needs.hydration,needs.fatigue]
  _needs_label.tooltip_text=actor.survival.timers_line()
 var stats:=actor.stats_component
 _stats.text="力量 %d · 智力 %d\n敏捷 %d · 耐力 %d\n生命 %d · 法力 %d"%[stats.effective_stat("strength"),stats.effective_stat("intelligence"),stats.effective_stat("agility"),stats.effective_stat("endurance"),actor.health_component.max_hp,actor.mana_component.max_mp]
func _select(uid: String) -> void:
 if uid!=selected and is_instance_valid(_quantity): _quantity.value=1
 var previous:=selected
 selected=uid
 for key in [previous,uid]:
  if _tiles.has(key): GameUIStyle.apply_button(_tiles[key],GameUIStyle.ACCENT,key==selected)
 _show_detail()
func _select_slot(slot: int) -> void:
 selected_slot=slot; mode="equipment"; container_filter="all"
 selected=str(session.inventory.equipped(actor.actor_context.id).get(str(slot),"")); _invalidate()
func _selected_item() -> ItemInstance: return session.inventory.item(selected)
func _item_state_text(item: ItemInstance,definition: ItemData) -> String:
 var text:=session.inventory.state_text(item.uid)+"\n单件重量 %.1fkg · 数量 %d"%[definition.weight,item.quantity]
 if SurvivalCatalog.FOODS.has(definition.id):
  var food: Dictionary=SurvivalCatalog.FOODS[definition.id]
  text+="\n食用：饱食%+.0f · 饮水%+.0f · 疲劳%+.0f"%[food.nutrition,food.hydration,food.fatigue]
 return text
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
 var signature: Dictionary={"permission":permission,"uid":selected,"item":item.snapshot() if item else {},"location":session.inventory.locate(selected),"gear":session.inventory.entries(actor.actor_context.id+".gear"),"accessible":session.inventory.actor_containers(actor.actor_context.id),"ground":ground_id,"shortcuts":actor.skill_manager.shortcuts.snapshot()}
 if signature==_detail_signature: return
 _detail_signature=signature.duplicate(true)
 var old_quantity:=int(_quantity.value) if is_instance_valid(_quantity) else 1
 FoundationWidgets.clear(_details); _quantity=null; _state_label=null
 if not item:
  var icon:=TextureRect.new(); icon.texture=GameUIStyle.icon("backpack"); icon.modulate=Color(GameUIStyle.GOLD,.45)
  icon.custom_minimum_size=Vector2(48,64); icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  _details.add_child(icon)
  _details.add_child(FoundationWidgets.label("为下一程做好准备",20))
  _details.add_child(FoundationWidgets.label("选择物品查看用途与操作；点身体部位筛选同槽装备。",14,true))
  FoundationWidgets.disclosure(_details,"行囊操作","双击使用或换装，右键管理。材料可查看已知用途；实物可直接绑定快捷槽。物品满载时，可丢弃到地面并随后拾回。")
  return
 var location:=session.inventory.locate(item.uid)
 var definition:=session.inventory.equipment_definition(item.uid) if session.inventory.definitions.get(item.definition_id) is EquipmentData else session.inventory.definitions.get(item.definition_id) as ItemData
 _details.add_child(FoundationWidgets.label(definition.display_name,20))
 _state_label=FoundationWidgets.label(_item_state_text(item,definition),13,true)
 _details.add_child(_state_label)
 _quantity=SpinBox.new(); _quantity.prefix="数量 "; _quantity.min_value=1; _quantity.max_value=item.quantity; _quantity.step=1; _quantity.value=mini(old_quantity,item.quantity); _quantity.visible=item.quantity>1; _details.add_child(_quantity)
 if location==ground_id and not ground_id.is_empty():
  _details.add_child(FoundationWidgets.button("取走所选数量",func(): _result(actions.take(ground_id,selected,int(_quantity.value)))))
  _details.add_child(FoundationWidgets.button("尽量取走这一叠",func(): _result(actions.take(ground_id,selected,item.quantity))))
  return
 if location not in session.inventory.actor_containers(actor.actor_context.id)+[actor.actor_context.id+".gear"]:
  _details.add_child(FoundationWidgets.label("实物已不在随身容器。",14,true)); return
 if definition is EquipmentData:
  if location.ends_with(".gear"):
   _details.add_child(FoundationWidgets.button("卸下装备",func(): _result(actions.unequip(definition.slot_type)),not permission.is_empty()))
  else: _details.add_child(FoundationWidgets.button("装备这件",_equip.bind(item.uid),not permission.is_empty()))
  if not permission.is_empty(): _details.add_child(FoundationWidgets.label(permission,13,true))
 elif definition.use_profile or SurvivalCatalog.FOODS.has(definition.id):
  _details.add_child(FoundationWidgets.button("选择这瓶喷剂" if definition.use_profile and definition.use_profile.kind==ItemUseDefinition.Kind.SPRAY else "使用一份",_use.bind(item.uid)))
 if not location.ends_with(".gear"):
  _details.add_child(FoundationWidgets.button("移至口袋" if location.ends_with(".pack") else "移至背包",_transfer_selected))
  if item.quantity>1: _details.add_child(FoundationWidgets.button("拆分所选数量",func(): _result(actions.split(selected,int(_quantity.value)))))
 _details.add_child(FoundationWidgets.button("丢弃所选数量",func(): _drop_quantity(int(_quantity.value))))
 _details.add_child(FoundationWidgets.button("丢弃整叠",_drop_quantity.bind(item.quantity)))
 # Keep the useful action above explanations and bulk management.
 for node in _details.get_children():
  if node is Button:
   GameUIStyle.primary(node); _details.move_child(node,2); break
 if definition is EquipmentData or definition.use_profile or SurvivalCatalog.FOODS.has(definition.id):
  var index:=_details.get_child_count()
  _binding_picker(item,definition)
  var caption:=_details.get_child(index); var grid:=_details.get_child(index+1)
  _details.move_child(caption,3); _details.move_child(grid,4)
 _details.add_child(HSeparator.new())
 FoundationWidgets.disclosure(_details,"物品说明",definition.description)
 if definition is EquipmentData:
  var current:=actor.get_node("EquipmentManager").get_equipment(definition.slot_type) as EquipmentData
  FoundationWidgets.disclosure(_details,"属性与当前装备比较",FoundationWidgets.comparison(current,definition))
  if definition.moveset: FoundationWidgets.disclosure(_details,"武器动作",definition.moveset.describe())
 else: _material_uses(definition)
func _binding_picker(item: ItemInstance,definition: ItemData) -> void:
 _details.add_child(FoundationWidgets.label("一键绑定快捷槽",12,true))
 var grid:=GridContainer.new(); grid.columns=7; grid.name="QuickBind"; _details.add_child(grid)
 for source in QuickslotLoadout.SOURCES:
  var binding:=actor.skill_manager.shortcuts.binding(source)
  var active: bool=binding.get("kind","")=="item" and binding.get("item_id","")==definition.id and (binding.get("uid","").is_empty() or binding.get("uid","")==item.uid)
  var button:=Button.new(); button.text=InputBindings.label(InputBindings.action_for_source(source))
  button.name="Bind_"+source; button.tooltip_text="将这件实物绑定到 "+button.text
  GameUIStyle.apply_button(button,GameUIStyle.GOLD,active); button.custom_minimum_size=Vector2(30,32)
  button.pressed.connect(func():
   var uid:=item.uid if definition is EquipmentData or definition.use_profile and definition.use_profile.kind==ItemUseDefinition.Kind.SPRAY else ""
   var ok:=actor.skill_manager.shortcuts.bind_item(source,definition.id,uid)
   _message="已绑定到 "+button.text if ok else "无法绑定。"; _message_time=3
   if ok and actions.save_request.is_valid(): actions.save_request.call()
   _show_detail())
  grid.add_child(button)
func _material_uses(definition: ItemData) -> void:
 var uses: Array[String]=[]
 for operation in SpellOperationCatalog.default_catalog().operations:
  var used:=false
  for payload in operation.payloads:
   if payload.material_id==definition.id: used=true; uses.append(operation.action.display_name+" · "+payload.title)
  if used and configure_request.is_valid():
   _details.add_child(FoundationWidgets.button("配置「"+operation.action.display_name+"」",configure_request.bind(operation.action),not actor.skill_manager.knows_action(operation.action)))
 var supplies:=actor.skill_manager.combinations.supplies
 for recipe_id in supplies.crafting_recipes:
  var recipe: CraftingRecipe=supplies.crafting_recipes[recipe_id]
  if recipe.inputs.has(definition.id) and supplies.knows_recipe(recipe_id): uses.append("制造 · "+actor.skill_manager.combinations.supplies.title(recipe.output_id))
 if not uses.is_empty(): FoundationWidgets.disclosure(_details,"用途与配方", "\n".join(uses))
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
